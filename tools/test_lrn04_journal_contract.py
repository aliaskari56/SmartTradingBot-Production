"""LRN-04 journal contract reference tests (not the MQL5 implementation).

This file pins the proposed canonical ASCII record contract so a future MQL5
codec can be checked against it. It does NOT provide crash-consistent storage,
locking, lifecycle reconstruction, or production journal behavior.
"""
from __future__ import annotations

import re
import zlib
import unittest
from pathlib import Path

FIELDS = (
    "schema", "record_seq", "state", "account_scope", "magic",
    "deal_ticket", "position_id", "lifecycle_id", "symbol_code",
    "direction", "entry_kind", "pnl_minor", "risk_state", "r_scaled",
    "wins_scaled", "losses_scaled", "rsum_scaled", "rcount", "decay_time",
    "previous_record_hash",
)
CHECKSUM_RE = re.compile(r"^[0-9A-F]{8}$")
UINT_RE = re.compile(r"^(0|[1-9][0-9]*)$")
SINT_RE = re.compile(r"^(0|-?[1-9][0-9]*)$")
UINT64_MAX = (1 << 64) - 1
INT64_MIN = -(1 << 63)
INT64_MAX = (1 << 63) - 1
TOKEN_RE = re.compile(r"^[A-Z0-9_-]+$")
SYMBOL_RE = re.compile(r"^[A-Za-z0-9_.-]+$")
MAX_RECORD_BYTES = 1024
ALLOWED = {
    "schema": {"LRN04V1"},
    "state": {"PREPARED", "COMMITTED"},
    "direction": {"BUY", "SELL", "FLAT", "NA"},
    "entry_kind": {"IN", "OUT", "OUT_BY", "INOUT", "SNAPSHOT"},
    "risk_state": {"KNOWN", "UNKNOWN", "NOT_APPLICABLE"},
}


class JournalContractError(ValueError):
    pass


def encode_record(values: dict[str, str]) -> bytes:
    if set(values) != set(FIELDS):
        raise JournalContractError("field set mismatch")
    parts = [values[name] for name in FIELDS]
    for name, value in zip(FIELDS, parts):
        if not value or "|" in value or "\n" in value or "\r" in value:
            raise JournalContractError(f"invalid field: {name}")
        if name in {
            "record_seq", "magic", "deal_ticket", "position_id",
            "lifecycle_id", "wins_scaled", "losses_scaled", "rcount",
            "decay_time",
        }:
            if not UINT_RE.fullmatch(value) or int(value) > UINT64_MAX:
                raise JournalContractError(f"invalid unsigned 64-bit integer: {name}")
        if name in {"pnl_minor", "r_scaled", "rsum_scaled"}:
            if not SINT_RE.fullmatch(value) or not INT64_MIN <= int(value) <= INT64_MAX:
                raise JournalContractError(f"invalid signed 64-bit integer: {name}")
        if name == "symbol_code":
            if not SYMBOL_RE.fullmatch(value):
                raise JournalContractError(f"invalid symbol code: {name}")
        elif name in {"schema", "state", "account_scope", "direction",
                      "entry_kind", "risk_state", "previous_record_hash"}:
            if not TOKEN_RE.fullmatch(value):
                raise JournalContractError(f"invalid token: {name}")
        if name in ALLOWED and value not in ALLOWED[name]:
            raise JournalContractError(f"unsupported enum: {name}")
    body = "|".join(parts).encode("ascii")
    checksum = f"{zlib.crc32(body) & 0xFFFFFFFF:08X}".encode("ascii")
    record = body + b"|" + checksum + b"\n"
    if len(record) > MAX_RECORD_BYTES:
        raise JournalContractError("record too long")
    return record


def decode_record(raw: bytes) -> dict[str, str]:
    if not raw.endswith(b"\n"):
        raise JournalContractError("incomplete record")
    if len(raw) > MAX_RECORD_BYTES:
        raise JournalContractError("record too long")
    try:
        line = raw[:-1].decode("ascii")
    except UnicodeDecodeError as exc:
        raise JournalContractError("non-ASCII record") from exc
    parts = line.split("|")
    if len(parts) != len(FIELDS) + 1:
        raise JournalContractError("field count mismatch")
    checksum = parts[-1]
    if not CHECKSUM_RE.fullmatch(checksum):
        raise JournalContractError("invalid checksum encoding")
    body = "|".join(parts[:-1]).encode("ascii")
    expected = f"{zlib.crc32(body) & 0xFFFFFFFF:08X}"
    if checksum != expected:
        raise JournalContractError("checksum mismatch")
    values = dict(zip(FIELDS, parts[:-1]))
    # Reuse canonical validation and reject non-canonical integer encodings.
    if encode_record(values) != raw:
        raise JournalContractError("non-canonical record")
    return values


def sample() -> dict[str, str]:
    return {
        "schema": "LRN04V1", "record_seq": "1", "state": "PREPARED",
        "account_scope": "ACCTHASH01", "magic": "26093001",
        "deal_ticket": "12345", "position_id": "67890",
        "lifecycle_id": "1", "symbol_code": "EURUSD",
        "direction": "BUY", "entry_kind": "OUT", "pnl_minor": "-1250",
        "risk_state": "KNOWN", "r_scaled": "-250", "wins_scaled": "1",
        "losses_scaled": "0", "rsum_scaled": "-250", "rcount": "1",
        "decay_time": "1792540800", "previous_record_hash": "GENESIS",
    }


class JournalContractTests(unittest.TestCase):
    def test_round_trip_and_golden_checksum(self):
        raw = encode_record(sample())
        self.assertEqual(decode_record(raw), sample())
        self.assertEqual(raw[-9:-1], b"47054993")
        self.assertEqual(raw[-9:-1], f"{zlib.crc32(raw[:-10]) & 0xFFFFFFFF:08X}".encode())

    def test_mql5_codec_source_matches_reference_contract(self):
        """Static source-parity check; this is not an MQL5 runtime test."""
        root = Path(__file__).resolve().parents[1]
        source = (root / "MQL5" / "Include" / "STB" / "STB_LRN04Journal.mqh").read_text(
            encoding="utf-8"
        )

        self.assertIn("#define STB_LRN04_FIELD_COUNT       20", source)
        self.assertIn('#define STB_LRN04_SCHEMA            "LRN04V1"', source)
        self.assertIn("0xEDB88320", source)
        self.assertIn('record=body+"|"+checksum+"\\n";', source)
        self.assertIn("bool STB_LRN04_EncodeRecord(", source)
        self.assertIn("bool STB_LRN04_DecodeRecord(", source)

        macro_slots = (
            ("SCHEMA", 0), ("SEQ", 1), ("STATE", 2), ("ACCOUNT", 3),
            ("MAGIC", 4), ("DEAL", 5), ("POSITION", 6), ("LIFECYCLE", 7),
            ("SYMBOL", 8), ("DIRECTION", 9), ("ENTRY_KIND", 10), ("PNL", 11),
            ("RISK_STATE", 12), ("R", 13), ("WINS", 14), ("LOSSES", 15),
            ("RSUM", 16), ("RCOUNT", 17), ("DECAY_TIME", 18),
            ("PREVIOUS_HASH", 19),
        )
        self.assertEqual(len(macro_slots), len(FIELDS))
        for macro_name, expected_index in macro_slots:
            self.assertRegex(
                source,
                rf"#define STB_LRN04_F_{macro_name}\s+{expected_index}\b",
            )

    def test_torn_tail_rejected(self):
        raw = encode_record(sample())
        for cut in range(1, len(raw) + 1):
            with self.subTest(cut=cut):
                with self.assertRaises(JournalContractError):
                    decode_record(raw[:-cut])

    def test_corruption_rejected(self):
        raw = encode_record(sample())
        changed = bytearray(raw)
        changed[raw.index(b"EURUSD")] = ord("X")
        with self.assertRaises(JournalContractError):
            decode_record(bytes(changed))

    def test_missing_and_extra_fields_rejected(self):
        raw = encode_record(sample())
        with self.assertRaises(JournalContractError):
            decode_record(b"|".join(raw.split(b"|")[:-2]) + b"\n")
        with self.assertRaises(JournalContractError):
            decode_record(raw[:-1] + b"|EXTRA\n")

    def test_unknown_enum_rejected(self):
        values = sample()
        values["state"] = "DONE"
        with self.assertRaises(JournalContractError):
            encode_record(values)

    def test_noncanonical_integer_rejected(self):
        values = sample()
        values["record_seq"] = "01"
        with self.assertRaises(JournalContractError):
            encode_record(values)

    def test_signed_values_and_integer_bounds(self):
        values = sample()
        values["pnl_minor"] = str(INT64_MIN)
        values["r_scaled"] = str(INT64_MAX)
        values["rsum_scaled"] = "-1"
        self.assertEqual(decode_record(encode_record(values)), values)
        values["record_seq"] = str(UINT64_MAX + 1)
        with self.assertRaises(JournalContractError):
            encode_record(values)
        values = sample()
        values["pnl_minor"] = str(INT64_MAX + 1)
        with self.assertRaises(JournalContractError):
            encode_record(values)
        values = sample()
        values["r_scaled"] = "-0"
        with self.assertRaises(JournalContractError):
            encode_record(values)

    def test_delimiter_and_non_ascii_rejected(self):
        values = sample()
        values["symbol_code"] = "EUR|USD"
        with self.assertRaises(JournalContractError):
            encode_record(values)
        with self.assertRaises(JournalContractError):
            decode_record(b"\xff\n")


    def test_crlf_and_bad_checksum_encoding_rejected(self):
        raw = encode_record(sample())
        with self.assertRaises(JournalContractError):
            decode_record(raw[:-1] + bytes((13, 10)))
        bad = raw[:-9] + b"abcdef12\n"
        with self.assertRaises(JournalContractError):
            decode_record(bad)

    def test_symbol_suffix_dot_is_supported(self):
        values = sample()
        values["symbol_code"] = "EURUSD.a"
        self.assertEqual(decode_record(encode_record(values)), values)

    def test_symbol_charset_is_ascii_and_bounded_by_record_limit(self):
        for invalid in ("EUR/USD", "EURUSD:PRO", "EUR€USD"):
            with self.subTest(symbol=invalid):
                values = sample()
                values["symbol_code"] = invalid
                with self.assertRaises(JournalContractError):
                    encode_record(values)

        values = sample()
        values["symbol_code"] = "eurusd.a"
        self.assertEqual(decode_record(encode_record(values)), values)

    def test_negative_leading_zero_is_rejected(self):
        values = sample()
        values["pnl_minor"] = "-01"
        with self.assertRaises(JournalContractError):
            encode_record(values)
        values["pnl_minor"] = "-0007"
        with self.assertRaises(JournalContractError):
            encode_record(values)

    def test_overlong_record_rejected(self):
        values = sample()
        values["symbol_code"] = "S" * 1100
        with self.assertRaises(JournalContractError):
            encode_record(values)


    def test_v2_schema_proposal_has_exactly_26_numbered_fields(self):
        """Guard proposal numbering without treating the proposal as implemented."""
        root = Path(__file__).resolve().parents[1]
        proposal = (
            root / "docs" / "LRN04_SCHEMA_V2_PROPOSAL_20261021.md"
        ).read_text(encoding="utf-8")
        self.assertIn("exactly **26 serialized fields including the checksum**", proposal)
        section = proposal.split("Required fields:", 1)[1].split(
            "\n\nThe 26 fields above", 1
        )[0]
        numbered = re.findall(r"(?m)^(\d+)\. `([a-z_]+)`:", section)
        self.assertEqual(len(numbered), 26)
        self.assertEqual([int(number) for number, _ in numbered], list(range(1, 27)))
        names = [name for _, name in numbered]
        self.assertEqual(len(names), len(set(names)))
        self.assertLess(names.index("rsum_scaled"), names.index("rcount"))
        self.assertEqual(names[-1], "checksum")


def validate_v2_reference_history(records: list[dict[str, str]]) -> None:
    """Validate proposed V2 state transitions in memory; not an MQL5 journal."""
    if not records:
        return
    prepared_by_seq: dict[int, dict[str, str]] = {}
    committed_keys: set[tuple[str, ...]] = set()
    operation_states: dict[str, str] = {}
    previous_digest = "GENESIS"
    previous_seq = 0

    identity_fields = (
        "environment", "server_scope", "account_scope", "magic",
        "operation_id", "deal_ticket", "position_id", "lifecycle_id",
        "symbol_code", "direction", "entry_kind",
    )
    snapshot_fields = (
        "pnl_minor", "risk_state", "r_scaled", "wins_scaled",
        "losses_scaled", "rsum_scaled", "rcount", "decay_time",
    )

    required_fields = {
        "record_seq", "state", "environment", "server_scope", "account_scope",
        "magic", "operation_id", "prepared_seq", "prepared_digest", "deal_ticket",
        "position_id", "lifecycle_id", "symbol_code", "direction", "entry_kind",
        "pnl_minor", "risk_state", "r_scaled", "wins_scaled", "losses_scaled",
        "rsum_scaled", "rcount", "decay_time", "previous_record_digest",
        "record_digest",
    }

    for record in records:
        if not required_fields.issubset(record):
            raise JournalContractError("missing required reference-model field")
        seq_text = record["record_seq"]
        if not UINT_RE.fullmatch(seq_text) or int(seq_text) > UINT64_MAX:
            raise JournalContractError("invalid record sequence encoding")
        seq = int(seq_text)
        if seq != previous_seq + 1:
            raise JournalContractError("sequence gap or reuse")
        if record["previous_record_digest"] != previous_digest:
            raise JournalContractError("previous-record digest mismatch")
        digest = record.get("record_digest", "")
        if not digest:
            raise JournalContractError("missing externally computed record digest")

        state = record["state"]
        op_id = record["operation_id"]
        if not op_id:
            raise JournalContractError("empty operation ID")
        if state == "PREPARED":
            if op_id in operation_states:
                raise JournalContractError("operation ID reused")
            if record["prepared_seq"] != "0" or record["prepared_digest"] != "GENESIS":
                raise JournalContractError("invalid PREPARED reference fields")
            operation_states[op_id] = "PREPARED"
            prepared_by_seq[seq] = record
        elif state == "COMMITTED":
            if operation_states.get(op_id) != "PREPARED":
                raise JournalContractError("orphan or duplicate COMMITTED")
            ref_text = record["prepared_seq"]
            if not UINT_RE.fullmatch(ref_text) or int(ref_text) > UINT64_MAX:
                raise JournalContractError("invalid PREPARED sequence encoding")
            ref_seq = int(ref_text)
            prepared = prepared_by_seq.get(ref_seq)
            if prepared is None or ref_seq >= seq:
                raise JournalContractError("invalid PREPARED sequence reference")
            if record["prepared_digest"] != prepared["record_digest"]:
                raise JournalContractError("PREPARED digest mismatch")
            for name in identity_fields:
                if record[name] != prepared[name]:
                    raise JournalContractError(f"event identity mismatch: {name}")
            for name in snapshot_fields:
                if record[name] != prepared[name]:
                    raise JournalContractError(f"aggregate snapshot mismatch: {name}")
            key = tuple(record[name] for name in (
                "environment", "server_scope", "account_scope", "magic",
                "deal_ticket", "lifecycle_id", "entry_kind",
            ))
            if key in committed_keys:
                raise JournalContractError("duplicate committed event key")
            committed_keys.add(key)
            operation_states[op_id] = "COMMITTED"
        else:
            raise JournalContractError("unsupported state")

        previous_seq = seq
        previous_digest = digest


def v2_reference_record(
    seq: int, state: str, operation_id: str, previous_digest: str,
    record_digest: str, prepared_seq: int = 0, prepared_digest: str = "GENESIS",
) -> dict[str, str]:
    """Small synthetic record for state-machine tests, not a serialized V2 record."""
    record = {
        "record_seq": str(seq), "state": state, "environment": "TESTER",
        "server_scope": "BROKER1", "account_scope": "ACCT1", "magic": "123",
        "operation_id": operation_id, "prepared_seq": str(prepared_seq),
        "prepared_digest": prepared_digest, "deal_ticket": "9001",
        "position_id": "8001", "lifecycle_id": "2", "symbol_code": "EURUSD.a",
        "direction": "BUY", "entry_kind": "OUT", "pnl_minor": "125",
        "risk_state": "KNOWN", "r_scaled": "100", "wins_scaled": "2",
        "losses_scaled": "1", "rsum_scaled": "300", "rcount": "3",
        "decay_time": "1792540800", "previous_record_digest": previous_digest,
        "record_digest": record_digest,
    }
    return record


class JournalV2ReferenceStateTests(unittest.TestCase):
    def test_valid_prepared_committed_pair(self):
        prepared = v2_reference_record(1, "PREPARED", "op-1", "GENESIS", "digest-1")
        committed = v2_reference_record(
            2, "COMMITTED", "op-1", "digest-1", "digest-2",
            prepared_seq=1, prepared_digest="digest-1",
        )
        validate_v2_reference_history([prepared, committed])

    def test_orphan_commit_rejected(self):
        committed = v2_reference_record(
            1, "COMMITTED", "op-1", "GENESIS", "digest-1",
            prepared_seq=0, prepared_digest="GENESIS",
        )
        with self.assertRaises(JournalContractError):
            validate_v2_reference_history([committed])

    def test_mismatched_prepared_digest_rejected(self):
        prepared = v2_reference_record(1, "PREPARED", "op-1", "GENESIS", "digest-1")
        committed = v2_reference_record(
            2, "COMMITTED", "op-1", "digest-1", "digest-2",
            prepared_seq=1, prepared_digest="wrong-digest",
        )
        with self.assertRaises(JournalContractError):
            validate_v2_reference_history([prepared, committed])

    def test_snapshot_mismatch_rejected(self):
        prepared = v2_reference_record(1, "PREPARED", "op-1", "GENESIS", "digest-1")
        committed = v2_reference_record(
            2, "COMMITTED", "op-1", "digest-1", "digest-2",
            prepared_seq=1, prepared_digest="digest-1",
        )
        committed["wins_scaled"] = "999"
        with self.assertRaises(JournalContractError):
            validate_v2_reference_history([prepared, committed])

    def test_sequence_gap_and_chain_mismatch_rejected(self):
        first = v2_reference_record(1, "PREPARED", "op-1", "GENESIS", "digest-1")
        gap = v2_reference_record(
            3, "COMMITTED", "op-1", "digest-1", "digest-3",
            prepared_seq=1, prepared_digest="digest-1",
        )
        with self.assertRaises(JournalContractError):
            validate_v2_reference_history([first, gap])
        broken_chain = v2_reference_record(
            2, "COMMITTED", "op-1", "not-digest-1", "digest-2",
            prepared_seq=1, prepared_digest="digest-1",
        )
        with self.assertRaises(JournalContractError):
            validate_v2_reference_history([first, broken_chain])

    def test_duplicate_commit_rejected(self):
        prepared = v2_reference_record(1, "PREPARED", "op-1", "GENESIS", "digest-1")
        committed = v2_reference_record(
            2, "COMMITTED", "op-1", "digest-1", "digest-2",
            prepared_seq=1, prepared_digest="digest-1",
        )
        duplicate = v2_reference_record(
            3, "COMMITTED", "op-1", "digest-2", "digest-3",
            prepared_seq=1, prepared_digest="digest-1",
        )
        with self.assertRaises(JournalContractError):
            validate_v2_reference_history([prepared, committed, duplicate])

    def test_event_identity_mismatch_rejected(self):
        prepared = v2_reference_record(1, "PREPARED", "op-1", "GENESIS", "digest-1")
        committed = v2_reference_record(
            2, "COMMITTED", "op-1", "digest-1", "digest-2",
            prepared_seq=1, prepared_digest="digest-1",
        )
        committed["deal_ticket"] = "9999"
        with self.assertRaises(JournalContractError):
            validate_v2_reference_history([prepared, committed])

    def test_operation_id_reuse_rejected(self):
        first = v2_reference_record(1, "PREPARED", "op-1", "GENESIS", "digest-1")
        second = v2_reference_record(2, "PREPARED", "op-1", "digest-1", "digest-2")
        with self.assertRaises(JournalContractError):
            validate_v2_reference_history([first, second])

    def test_missing_digest_and_invalid_sequence_rejected(self):
        missing_digest = v2_reference_record(1, "PREPARED", "op-1", "GENESIS", "")
        with self.assertRaises(JournalContractError):
            validate_v2_reference_history([missing_digest])
        invalid_seq = v2_reference_record(1, "PREPARED", "op-1", "GENESIS", "digest-1")
        invalid_seq["record_seq"] = "01"
        with self.assertRaises(JournalContractError):
            validate_v2_reference_history([invalid_seq])

    def test_missing_required_field_rejected(self):
        record = v2_reference_record(1, "PREPARED", "op-1", "GENESIS", "digest-1")
        del record["account_scope"]
        with self.assertRaises(JournalContractError):
            validate_v2_reference_history([record])


if __name__ == "__main__":
    unittest.main()
