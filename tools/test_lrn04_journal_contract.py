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

    def test_sha256_golden_vector_script_is_pinned(self):
        """Static guard for the isolated MQL5 vectors; runtime execution remains separate."""
        import hashlib

        root = Path(__file__).resolve().parents[1]
        script = (root / "MQL5" / "Scripts" / "LRN04_SHA256_GoldenVector.mq5").read_text(
            encoding="utf-8"
        )

        vectors = {
            b"abc": "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD",
            bytes((97, 98, 99, 10)): "EDEAAFF3F1774AD2888673770C6D64097E391BC362D7D6FB34982DDF0EFD18CB",
        }
        for payload, expected in vectors.items():
            with self.subTest(payload=payload):
                self.assertEqual(hashlib.sha256(payload).hexdigest().upper(), expected)
                self.assertIn(expected, script)

        # Guard the key byte-boundary decisions without claiming MQL5 runtime proof.
        self.assertIn("ArrayResize(bytes, length)", script)
        self.assertIn("bytes[i] = (uchar)ch;", script)
        self.assertIn("StringGetCharacter(value, i)", script)
        self.assertIn("CryptEncode(CRYPT_HASH_SHA256, data, key, digest)", script)
        self.assertIn("digest_size != 32", script)
        self.assertNotIn("StringToCharArray", script)

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

    def test_v2_digest_and_numeric_contracts_remain_explicit_release_gates(self):
        """Do not let the proposal's unresolved platform details disappear."""
        root = Path(__file__).resolve().parents[1]
        proposal = (
            root / "docs" / "LRN04_SCHEMA_V2_PROPOSAL_20261021.md"
        ).read_text(encoding="utf-8")
        self.assertIn("Exact digest algorithm", proposal)
        self.assertIn("CRC32 alone is not a collision-resistant identity", proposal)
        self.assertIn("Currency minor-unit conversion, rounding mode", proposal)
        self.assertIn("Reserved sentinels and semantic consistency rules", proposal)
        self.assertIn("File append/read/flush/close semantics", proposal)
        self.assertIn("Do not wire this protocol into `OnTradeTransaction()`", proposal)
        self.assertIn("not approved for runtime use", proposal)
        self.assertIn("not an additional serialized field", proposal)
        self.assertIn("complete serialized PREPARED record", proposal)
        self.assertIn("A truncated or malformed final record fails closed by default", proposal)
        self.assertIn("performs no automatic truncation, compaction, or migration", proposal)
        self.assertNotIn("An incomplete final line may be ignored", proposal)


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
        if not isinstance(record, dict):
            raise JournalContractError("reference-model record must be a mapping")
        if not required_fields.issubset(record):
            raise JournalContractError("missing required reference-model field")
        if set(record) != required_fields:
            raise JournalContractError("unexpected reference-model field")
        if any(not isinstance(record[name], str) for name in required_fields):
            raise JournalContractError("reference-model fields must be strings")
        # Validate every numeric field before using the reference record.
        # This is a model-level contract check; V2 scales and sentinels remain
        # unresolved and are intentionally not guessed here.
        unsigned_fields = (
            "record_seq", "magic", "prepared_seq", "deal_ticket",
            "position_id", "lifecycle_id", "wins_scaled", "losses_scaled",
            "rcount", "decay_time",
        )
        signed_fields = ("pnl_minor", "r_scaled", "rsum_scaled")
        for name in unsigned_fields:
            value = record[name]
            if not UINT_RE.fullmatch(value) or int(value) > UINT64_MAX:
                raise JournalContractError(f"invalid unsigned numeric field: {name}")
        for name in signed_fields:
            value = record[name]
            if not SINT_RE.fullmatch(value) or not INT64_MIN <= int(value) <= INT64_MAX:
                raise JournalContractError(f"invalid signed numeric field: {name}")

        seq_text = record["record_seq"]
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
            if any(status == "PREPARED" for status in operation_states.values()):
                raise JournalContractError("interleaved PREPARED operations are not allowed")
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
            if ref_seq != seq - 1:
                raise JournalContractError("PREPARED and COMMITTED must be adjacent")
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
    def test_noncanonical_numeric_fields_rejected(self):
        numeric_cases = (
            ("magic", "01"),
            ("deal_ticket", "+9001"),
            ("position_id", "-1"),
            ("wins_scaled", "-1"),
            ("pnl_minor", "+125"),
            ("r_scaled", "-01"),
            ("rsum_scaled", str(INT64_MAX + 1)),
            ("decay_time", str(UINT64_MAX + 1)),
        )
        for field, value in numeric_cases:
            with self.subTest(field=field, value=value):
                record = v2_reference_record(
                    1, "PREPARED", "op-1", "GENESIS", "digest-1"
                )
                record[field] = value
                with self.assertRaises(JournalContractError):
                    validate_v2_reference_history([record])

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

    def test_same_event_key_cannot_be_committed_under_new_operation_id(self):
        prepared1 = v2_reference_record(
            1, "PREPARED", "op-1", "GENESIS", "digest-1"
        )
        committed1 = v2_reference_record(
            2, "COMMITTED", "op-1", "digest-1", "digest-2",
            prepared_seq=1, prepared_digest="digest-1",
        )
        # Same environment/account/magic/deal/lifecycle/entry key, but a new
        # operation ID and otherwise valid sequential PREPARED/COMMITTED pair.
        prepared2 = v2_reference_record(
            3, "PREPARED", "op-2", "digest-2", "digest-3"
        )
        committed2 = v2_reference_record(
            4, "COMMITTED", "op-2", "digest-3", "digest-4",
            prepared_seq=3, prepared_digest="digest-3",
        )
        with self.assertRaisesRegex(JournalContractError, "duplicate committed event key"):
            validate_v2_reference_history(
                [prepared1, committed1, prepared2, committed2]
            )

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

    def test_each_identity_field_must_match_prepared_snapshot(self):
        identity_fields = (
            "environment", "server_scope", "account_scope", "magic",
            "operation_id", "deal_ticket", "position_id", "lifecycle_id",
            "symbol_code", "direction", "entry_kind",
        )
        for field in identity_fields:
            with self.subTest(field=field):
                prepared = v2_reference_record(
                    1, "PREPARED", "op-1", "GENESIS", "digest-1"
                )
                committed = v2_reference_record(
                    2, "COMMITTED", "op-1", "digest-1", "digest-2",
                    prepared_seq=1, prepared_digest="digest-1",
                )
                committed[field] = "DIFFERENT"
                with self.assertRaises(JournalContractError):
                    validate_v2_reference_history([prepared, committed])

    def test_each_aggregate_snapshot_field_must_match_prepared(self):
        snapshot_fields = (
            "pnl_minor", "risk_state", "r_scaled", "wins_scaled",
            "losses_scaled", "rsum_scaled", "rcount", "decay_time",
        )
        for field in snapshot_fields:
            with self.subTest(field=field):
                prepared = v2_reference_record(
                    1, "PREPARED", "op-1", "GENESIS", "digest-1"
                )
                committed = v2_reference_record(
                    2, "COMMITTED", "op-1", "digest-1", "digest-2",
                    prepared_seq=1, prepared_digest="digest-1",
                )
                committed[field] = "DIFFERENT"
                with self.assertRaises(JournalContractError):
                    validate_v2_reference_history([prepared, committed])

    def test_unknown_state_rejected(self):
        record = v2_reference_record(1, "DONE", "op-1", "GENESIS", "digest-1")
        with self.assertRaises(JournalContractError):
            validate_v2_reference_history([record])

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

    def test_unexpected_reference_field_rejected(self):
        record = v2_reference_record(1, "PREPARED", "op-1", "GENESIS", "digest-1")
        record["unexpected_extension"] = "must-not-be-ignored"
        with self.assertRaisesRegex(
            JournalContractError, "unexpected reference-model field"
        ):
            validate_v2_reference_history([record])


    def test_non_adjacent_prepared_commit_pair_rejected(self):
        prepared = v2_reference_record(1, "PREPARED", "op-1", "GENESIS", "digest-1")
        intervening = v2_reference_record(
            2, "PREPARED", "op-2", "digest-1", "digest-2"
        )
        committed = v2_reference_record(
            3, "COMMITTED", "op-1", "digest-2", "digest-3",
            prepared_seq=1, prepared_digest="digest-1",
        )
        with self.assertRaises(JournalContractError):
            validate_v2_reference_history([prepared, intervening, committed])

    def test_uncommitted_prepared_at_end_is_valid_prefix(self):
        prepared = v2_reference_record(1, "PREPARED", "op-1", "GENESIS", "digest-1")
        # The reference validator accepts the well-formed prefix. This does not
        # test persistence or projection/application behavior.
        validate_v2_reference_history([prepared])





class JournalV2OperationStateTests(unittest.TestCase):
    def test_interleaved_prepared_operations_rejected(self):
        first = v2_reference_record(1, "PREPARED", "op-1", "GENESIS", "digest-1")
        second = v2_reference_record(2, "PREPARED", "op-2", "digest-1", "digest-2")
        with self.assertRaisesRegex(JournalContractError, "interleaved PREPARED"):
            validate_v2_reference_history([first, second])

    def test_operation_id_cannot_be_reused_after_commit(self):
        prepared = v2_reference_record(1, "PREPARED", "op-1", "GENESIS", "digest-1")
        committed = v2_reference_record(
            2, "COMMITTED", "op-1", "digest-1", "digest-2",
            prepared_seq=1, prepared_digest="digest-1",
        )
        reused = v2_reference_record(3, "PREPARED", "op-1", "digest-2", "digest-3")
        with self.assertRaisesRegex(JournalContractError, "operation ID reused"):
            validate_v2_reference_history([prepared, committed, reused])


class JournalV2ReferenceTypeSafetyTests(unittest.TestCase):
    def test_each_history_item_must_be_a_mapping(self):
        for invalid in (None, 123, "not-a-record", ["not", "a", "mapping"]):
            with self.subTest(value=repr(invalid)):
                with self.assertRaisesRegex(
                    JournalContractError, "record must be a mapping"
                ):
                    validate_v2_reference_history([invalid])

    def test_all_required_reference_fields_must_be_strings(self):
        required = (
            "record_seq", "state", "environment", "server_scope", "account_scope",
            "magic", "operation_id", "prepared_seq", "prepared_digest", "deal_ticket",
            "position_id", "lifecycle_id", "symbol_code", "direction", "entry_kind",
            "pnl_minor", "risk_state", "r_scaled", "wins_scaled", "losses_scaled",
            "rsum_scaled", "rcount", "decay_time", "previous_record_digest",
            "record_digest",
        )
        for field in required:
            for invalid in (None, 123, ["not", "a", "string"]):
                with self.subTest(field=field, value=repr(invalid)):
                    record = v2_reference_record(
                        1, "PREPARED", "op-1", "GENESIS", "digest-1"
                    )
                    record[field] = invalid
                    with self.assertRaisesRegex(
                        JournalContractError, "fields must be strings"
                    ):
                        validate_v2_reference_history([record])



class JournalV2ReferenceNegativeMatrixTests(unittest.TestCase):
    """Broaden state-machine rejection coverage; still only an in-memory model."""

    def _valid_pair(self):
        prepared = v2_reference_record(
            1, "PREPARED", "op-1", "GENESIS", "digest-1"
        )
        committed = v2_reference_record(
            2, "COMMITTED", "op-1", "digest-1", "digest-2",
            prepared_seq=1, prepared_digest="digest-1",
        )
        return prepared, committed

    def test_each_event_identity_field_must_match_prepared_record(self):
        identity_fields = (
            "environment", "server_scope", "account_scope", "magic",
            "operation_id", "deal_ticket", "position_id", "lifecycle_id",
            "symbol_code", "direction", "entry_kind",
        )
        for field in identity_fields:
            with self.subTest(field=field):
                prepared, committed = self._valid_pair()
                committed[field] = "DIFFERENT"
                with self.assertRaises(JournalContractError):
                    validate_v2_reference_history([prepared, committed])

    def test_each_aggregate_snapshot_field_must_match_prepared_record(self):
        snapshot_fields = (
            "pnl_minor", "risk_state", "r_scaled", "wins_scaled",
            "losses_scaled", "rsum_scaled", "rcount", "decay_time",
        )
        for field in snapshot_fields:
            with self.subTest(field=field):
                prepared, committed = self._valid_pair()
                committed[field] = (
                    "UNKNOWN" if field == "risk_state"
                    else ("126" if field == "pnl_minor" else "999")
                )
                with self.assertRaises(JournalContractError):
                    validate_v2_reference_history([prepared, committed])

    def test_interleaved_prepared_operations_are_rejected(self):
        first = v2_reference_record(
            1, "PREPARED", "op-1", "GENESIS", "digest-1"
        )
        second = v2_reference_record(
            2, "PREPARED", "op-2", "digest-1", "digest-2"
        )
        with self.assertRaisesRegex(
            JournalContractError, "interleaved PREPARED"
        ):
            validate_v2_reference_history([first, second])

    def test_operation_id_cannot_be_reused_after_commit(self):
        prepared1, committed1 = self._valid_pair()
        prepared2 = v2_reference_record(
            3, "PREPARED", "op-1", "digest-2", "digest-3"
        )
        with self.assertRaisesRegex(JournalContractError, "operation ID reused"):
            validate_v2_reference_history([prepared1, committed1, prepared2])

    def test_uncommitted_prepared_record_is_accepted_as_a_prefix(self):
        prepared = v2_reference_record(
            1, "PREPARED", "op-1", "GENESIS", "digest-1"
        )
        # Acceptance here means only that the in-memory sequence is a valid
        # prefix. It does not mean PREPARED data is applied to any projection.
        validate_v2_reference_history([prepared])

class JournalRecoveryProposalTests(unittest.TestCase):
    def test_recovery_proposal_covers_fail_closed_conditions(self):
        """Pin key recovery requirements in the proposal; not a storage test."""
        root = Path(__file__).resolve().parents[1]
        doc = (root / "docs" / "LRN04_CRASH_RECOVERY_CONTRACT_20261021.md").read_text(
            encoding="utf-8"
        )
        required_phrases = (
            "Status: design proposal only; not approved or implemented",
            "Treat an unreadable file as empty",
            "Reject the history",
            "COMMITTED without its referenced PREPARED record",
            "Two writer attempts contending",
            "Release remains **BLOCKED / NOT VERIFIED**",
        )
        for phrase in required_phrases:
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, doc)

    def test_recovery_proposal_forbids_silent_repair_and_duplicate_apply(self):
        root = Path(__file__).resolve().parents[1]
        doc = (root / "docs" / "LRN04_CRASH_RECOVERY_CONTRACT_20261021.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("Silently skip malformed bytes", doc)
        self.assertIn("increment aggregate statistics twice", doc.lower())
        self.assertIn("No automatic truncation, compaction, or migration", doc)
        self.assertIn("Do not connect LRN-04 to", doc)



class JournalLockProposalTests(unittest.TestCase):
    def test_lock_contract_requires_atomic_ownership_and_fencing(self):
        root = Path(__file__).resolve().parents[1]
        doc = (root / "docs" / "LRN04_LOCK_OWNERSHIP_CONTRACT_20261021.md").read_text(
            encoding="utf-8"
        )
        for phrase in (
            "Status: proposal only; not implemented or runtime-verified",
            "atomic compare-and-set",
            "lease generation",
            "Only the current owner may release the lock",
            "Do not steal a lock solely because its timestamp appears old",
            "fencing prevents its writes",
            "Release status remains BLOCKED / NOT VERIFIED",
        ):
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, doc)

    def test_lock_contract_rejects_unlocked_fallback(self):
        root = Path(__file__).resolve().parents[1]
        doc = (root / "docs" / "LRN04_LOCK_OWNERSHIP_CONTRACT_20261021.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("No silent fallback to an unlocked writer", doc)
        self.assertIn("operator intervention", doc)
        self.assertIn("Do not wire journal writes into", doc)


class JournalRecoveryPolicyConsistencyTests(unittest.TestCase):
    def test_implementation_plan_fails_closed_on_truncated_tail(self):
        root = Path(__file__).resolve().parents[1]
        plan = (root / "docs" / "LRN04_IMPLEMENTATION_PLAN_20261021.md").read_text(
            encoding="utf-8"
        )
        recovery = (root / "docs" / "LRN04_CRASH_RECOVERY_CONTRACT_20261021.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("reject a truncated final record by default", plan)
        self.assertIn("fail-closed for a truncated final record", plan)
        self.assertIn("Final bytes do not end in LF, or final record is truncated", recovery)
        self.assertIn("Fail closed by default", recovery)
        self.assertIn("No automatic truncation, compaction, or migration", plan)


class JournalV2DecisionChecklistTests(unittest.TestCase):
    def test_unresolved_v2_decisions_and_evidence_are_explicit(self):
        root = Path(__file__).resolve().parents[1]
        checklist = (
            root / "docs" / "LRN04_V2_DECISION_CHECKLIST_20261021.md"
        ).read_text(encoding="utf-8")
        for phrase in (
            "Status: review checklist only",
            "Namespace canonicalization",
            "Digest algorithm",
            "Numeric semantics",
            "Sentinels and semantic constraints",
            "Duplicate COMMITTED policy",
            "File semantics",
            "Lock and fencing",
            "Recovery budget and diagnostics",
            "Cross-language parity",
            "Fault-injection coverage",
            "before the above gates pass",
            "LRN-04: NOT VERIFIED. Release: BLOCKED / NOT VERIFIED.",
        ):
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, checklist)
        self.assertIn("not implement durable persistence", checklist)



class JournalV2ProvisionalDecisionRecordTests(unittest.TestCase):
    def test_provisional_decisions_keep_runtime_approval_explicit(self):
        root = Path(__file__).resolve().parents[1]
        doc = (
            root / "docs" / "LRN04_V2_PROVISIONAL_DECISION_RECORD_20261021.md"
        ).read_text(encoding="utf-8")
        for phrase in (
            "Nothing in this record is approved for runtime use",
            "CRC32 remains only an accidental-corruption checksum",
            "Do not guess account-currency precision",
            "Require immediate adjacency under one writer lock",
            "Reject by default; preserve source bytes",
            "fencing generation",
            "Recovery budget",
            "schema approval, implementation, runtime verification and release acceptance remain outstanding",
        ):
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, doc)

    def test_provisional_record_requires_review_and_terminal_evidence(self):
        root = Path(__file__).resolve().parents[1]
        doc = (
            root / "docs" / "LRN04_V2_PROVISIONAL_DECISION_RECORD_20261021.md"
        ).read_text(encoding="utf-8")
        self.assertIn("APPROVE", doc)
        self.assertIn("REVISE", doc)
        self.assertIn("REJECT", doc)
        self.assertIn("minimum supported terminal build", doc)
        self.assertIn("controlled non-live terminal evidence", doc)
        self.assertIn("Do not enable live deployment", doc)


class JournalIntegrationReleaseGateTests(unittest.TestCase):
    def test_primary_ea_transaction_handler_remains_unwired_to_journal_codec(self):
        """Prevent premature journal integration before V2/runtime gates pass."""
        root = Path(__file__).resolve().parents[1]
        ea = (
            root / "MQL5" / "Experts" / "SmartTradingBot_FINAL.mq5"
        ).read_text(encoding="utf-8")
        start = ea.find("void OnTradeTransaction(")
        self.assertGreaterEqual(start, 0, "primary EA transaction handler missing")
        end = ea.find("\nvoid STB_ToggleDashboard(", start)
        self.assertGreater(end, start, "transaction handler boundary changed")
        handler = ea[start:end]
        self.assertNotIn("STB_LRN04_EncodeRecord(", handler)
        self.assertNotIn("STB_LRN04_DecodeRecord(", handler)
        self.assertNotIn("STB_LRN04_Append", handler)
        self.assertIn("STB_AdaptiveRecordClosedDeal(", handler)

    def test_journal_module_still_declares_persistence_disabled(self):
        root = Path(__file__).resolve().parents[1]
        module = (
            root / "MQL5" / "Include" / "STB" / "STB_LRN04Journal.mqh"
        ).read_text(encoding="utf-8")
        self.assertIn("Persistence is intentionally not", module)
        self.assertIn("bool STB_LRN04_EncodeRecord(", module)
        self.assertIn("bool STB_LRN04_DecodeRecord(", module)
        self.assertNotIn("FileOpen(", module)


if __name__ == "__main__":
    unittest.main()
