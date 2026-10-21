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
