# LRN-04 MQL5 Hash API Feasibility Audit — 2026-10-21

**Status: official-reference feasibility finding only. SHA-256 is a candidate recommendation, not an approved V2 decision.**  
**Branch:** `fix/structure-first-fvg-trailing-20261020`  
**Primary EA:** `MQL5/Experts/SmartTradingBot_FINAL.mq5`

## Official API finding

The official MQL5 Reference documents `CryptEncode()` as a byte-array transformation API and lists `CRYPT_HASH_SHA256` among the supported `ENUM_CRYPT_METHOD` values:

- Function reference: https://www.mql5.com/en/docs/common/CryptEncode
- Named constants reference: https://www.mql5.com/en/docs/constants/namedconstants
- Cryptography overview: https://www.mql5.com/en/book/advanced/crypt/crypt_overview

The documented function returns the number of output bytes, or zero on error. The SHA-256 method is documented as producing a 32-byte digest. This makes SHA-256 a technically plausible candidate for the V2 record-identity digest without implementing a custom hash algorithm.

## Proposed candidate contract for review

If SHA-256 is approved after compatibility and golden-vector testing, freeze all of the following together:

1. Input is the exact canonical serialized record bytes, including its final LF and fixed-width CRC32 checksum.
2. Input bytes are ASCII and must not include an implicit NUL terminator.
3. Output is exactly 32 bytes, encoded as 64 uppercase hexadecimal characters.
4. The first record uses one fixed literal genesis token for `previous_record_digest`; that token is not a hash output.
5. The derived digest is not itself serialized in the same record. The next record references it.
6. The CRC32 checksum remains a separate accidental-corruption check over the exact specified body; it is not used as record identity.
7. Any `CryptEncode(CRYPT_HASH_SHA256,...)` result other than exactly 32 bytes is a hard failure. No fallback to CRC32, SHA-1, or an empty digest is permitted.

For MQL5 byte conversion, the implementation must specify the exact byte count rather than relying on an implicit string terminator. Official MQL5 examples demonstrate use of `StringToCharArray(..., CP_UTF8)` and the `CryptEncode(CRYPT_HASH_SHA256,...)` call; V2 must still pin the precise canonical ASCII byte input and verify it against independent golden vectors.

## Evidence still required

This web-reference audit does **not** prove compatibility with the project's minimum supported MetaTrader build or runtime behavior. Before approving the algorithm:

- Identify the minimum supported terminal/build.
- Compile a tiny isolated MQL5 test using `CRYPT_HASH_SHA256`.
- Compare multiple byte-exact vectors against an independent implementation.
- Include empty/short input, bytes with high-bit values in a negative test (V2 record input itself should remain ASCII), exact LF handling, and NUL-terminator exclusion.
- Confirm uppercase-hex conversion, fixed output length, and failure handling.
- Record the tested terminal build and test output.

## Decision

**Recommendation:** prefer SHA-256 over CRC32 for the derived record-identity digest, subject to the evidence above. Do not mark the V2 digest gate approved solely because the API exists in the current online reference.

No EA source, V1 codec, journal persistence, or runtime behavior was changed. LRN-04 remains **NOT VERIFIED** and release remains **BLOCKED / NOT VERIFIED**.

## CI compile evidence — 2026-10-21

The isolated script and the primary EA were compiled in GitHub Actions on Windows using MetaEditor **5.0.0.6274** at source commit `855d98200825fa87ce2b16dad13bf0fc95c03e04`.

- Primary EA compile workflow: https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39545114865 — **success**. The workflow requires the compiler log to report 0 errors and 0 warnings and checks that a fresh EX5 exists.
- SHA-256 golden-vector script compile is a separate step in that same workflow — **success**. Its compiler log and EX5 are uploaded as workflow artifacts.
- Journal contract reference tests: https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39545114882 — **success**.
- MQL5 static guardrails: https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39545114890 — **success**.
- Trading safety input defaults: https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39545114884 — **success**.

### Evidence boundary

This is compile and CI evidence only. The workflow **compiles** the golden-vector script but does not launch it inside a running MetaTrader terminal. Therefore the script's `[PASS]` output has **not** yet been observed from MQL5 runtime. This does not verify digest behavior at runtime, durable file semantics, locking/fencing, recovery, or EA integration. The V2 digest gate remains pending and release remains **BLOCKED / NOT VERIFIED**.

## Latest CI evidence — 2026-10-21 (empty-input vector)

The isolated MQL5 SHA-256 script now includes three known-answer vectors:

- Empty byte sequence (0 bytes): `E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855`.
- ASCII `abc` (3 bytes): `BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD`.
- ASCII `abc` plus one LF byte (4 bytes): `EDEAAFF3F1774AD2888673770C6D64097E391BC362D7D6FB34982DDF0EFD18CB`.

At commit `a521425f352a87ff7c4d621caa9c6915329de4a1`, the following GitHub Actions checks completed successfully:

- [MetaEditor compile (Windows), run 39545304450](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39545304450): primary EA and isolated SHA-256 script both compiled; the workflow log reports `0 errors, 0 warnings` for the script and confirms a fresh EX5 artifact.
- [LRN-04 journal contract tests, run 39545304484](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39545304484): success.
- [MQL5 static audit, run 39545304505](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39545304505): success.
- [Trading safety defaults, run 39545304457](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39545304457): success.

**Evidence boundary:** the Windows CI workflow compiles the SHA-256 script but does not execute it inside a MetaTrader terminal. The vector outputs have not been observed at MQL5 runtime. Python reference tests and compilation do not establish runtime digest parity, file durability, locking/fencing, recovery, or EA integration. The V2 digest decision remains unapproved; LRN-04 remains **NOT VERIFIED** and release remains **BLOCKED / NOT VERIFIED**.


## Latest CI evidence — documentation commit a0ff2a58 (2026-10-21)

The documentation-only commit `a0ff2a58fe8b3e8548d75ebc0769446e3e7b492c` has now completed all four CI workflows successfully:

- [MetaEditor compile (Windows), run 39545411273](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39545411273): both `SmartTradingBot_FINAL.mq5` and `LRN04_SHA256_GoldenVector.mq5` compiled with **0 errors and 0 warnings** using MetaEditor **5.0.0.6274**. Fresh EX5 files, compiler logs, and provenance metadata were uploaded as artifact `metaeditor-build-a0ff2a58fe8b3e8548d75ebc0769446e3e7b492c`.
- [LRN-04 journal contract tests, run 39545411249](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39545411249): success.
- [MQL5 static audit, run 39545411295](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39545411295): success.
- [Trading safety defaults, run 39545411256](https://github.com/aliaskari56/SmartTradingBot-Production/actions/runs/39545411256): success.

**Evidence boundary remains unchanged:** this run confirms compilation and CI checks only. The SHA-256 script was not executed inside a running MetaTrader terminal, so its runtime `[PASS]` output has not been observed. The V2 digest gate is still unapproved; journal persistence, lock/fencing, crash recovery, and EA integration remain unverified. **LRN-04: NOT VERIFIED; release: BLOCKED / NOT VERIFIED.**
