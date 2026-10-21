"""LRN-04 journal contract reference tests (not the MQL5 implementation).

This file pins the proposed canonical ASCII record contract so a future MQL5
codec can be checked against it. It does NOT provide crash-consistent storage,
locking, lifecycle reconstruction, or production journal behavior.
"""
from __future__ import annotations

import re
import zlib
import unittest

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
        if name in {"schema", "state", "account_scope", "direction",
                    "entry_kind", "risk_state", "symbol_code", "previous_record_hash"}:
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
        self.assertEqual(raw[-9:-1], f"{zlib.crc32(raw[:-10]) & 0xFFFFFFFF:08X}".encode())

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

    def test_overlong_record_rejected(self):
        values = sample()
        values["symbol_code"] = "S" * 1100
        with self.assertRaises(JournalContractError):
            encode_record(values)


if __name__ == "__main__":
    unittest.main()
