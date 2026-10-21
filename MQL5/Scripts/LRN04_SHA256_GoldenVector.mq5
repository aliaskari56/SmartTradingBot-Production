//+------------------------------------------------------------------+
//| LRN04_SHA256_GoldenVector.mq5                                    |
//| Isolated, non-trading CryptEncode SHA-256 contract test.          |
//| Run manually as a Script in MetaEditor/MT5; not wired into the EA.|
//+------------------------------------------------------------------+
#property strict
#property script_show_inputs
#property description "LRN-04 isolated SHA-256 golden-vector test; performs no trading."

// Convert ASCII-only test text to an exact byte array.
// Deliberately does not request or append StringToCharArray's NUL byte.
bool AsciiBytes(const string value, uchar &bytes[])
{
   const int length = StringLen(value);
   if(ArrayResize(bytes, length) != length)
      return false;

   for(int i = 0; i < length; ++i)
   {
      const ushort ch = StringGetCharacter(value, i);
      if(ch > 127)
         return false;
      bytes[i] = (uchar)ch;
   }
   return true;
}

string BytesToUpperHex(const uchar &bytes[], const int count)
{
   string output = "";
   if(count < 0 || count > ArraySize(bytes))
      return "";

   for(int i = 0; i < count; ++i)
      output += StringFormat("%02X", (int)bytes[i]);

   return output;
}

bool CheckVector(const string label,
                 const string input_text,
                 const string expected_hex)
{
   uchar data[];
   uchar key[];
   uchar digest[];

   if(!AsciiBytes(input_text, data))
   {
      Print("[FAIL] ", label, ": input is not ASCII or allocation failed.");
      return false;
   }

   // SHA-256 requires no key. Use an explicitly empty key array.
   ArrayResize(key, 0);
   ResetLastError();
   const int digest_size = CryptEncode(CRYPT_HASH_SHA256, data, key, digest);
   if(digest_size != 32 || ArraySize(digest) < 32)
   {
      Print("[FAIL] ", label, ": CryptEncode returned ", digest_size,
            "; GetLastError=", GetLastError());
      return false;
   }

   const string actual_hex = BytesToUpperHex(digest, digest_size);
   if(actual_hex != expected_hex)
   {
      Print("[FAIL] ", label, ": expected=", expected_hex,
            " actual=", actual_hex);
      return false;
   }

   Print("[PASS] ", label, ": ", actual_hex);
   return true;
}

void OnStart()
{
   int passed = 0;
   int failed = 0;

   // Independent SHA-256 known-answer vectors:
   // SHA256(empty byte sequence)
   if(CheckVector("Empty input (0 bytes)",
                  "",
                  "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"))
      ++passed;
   else
      ++failed;

   // SHA256(ASCII "abc")
   if(CheckVector("ASCII abc (3 bytes)",
                  "abc",
                  "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD"))
      ++passed;
   else
      ++failed;

   // SHA256(ASCII "abc" followed by exactly one LF byte, 0x0A)
   if(CheckVector("ASCII abc + LF (4 bytes)",
                  "abc\n",
                  "EDEAAFF3F1774AD2888673770C6D64097E391BC362D7D6FB34982DDF0EFD18CB"))
      ++passed;
   else
      ++failed;

   Print("LRN04 SHA256 golden-vector summary: passed=", passed,
         " failed=", failed,
         ". This script does not test journal persistence, locking, recovery,",
         " or EA integration.");

   if(failed != 0)
      Print("RESULT: FAIL — SHA-256 contract must not be approved.");
   else
      Print("RESULT: VECTOR CHECKS PASS — terminal execution evidence is still required.");
}
