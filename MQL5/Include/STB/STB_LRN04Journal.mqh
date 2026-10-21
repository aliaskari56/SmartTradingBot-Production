//+------------------------------------------------------------------+
//| STB_LRN04Journal.mqh                                              |
//| LRN-04 canonical record codec. Persistence is intentionally not   |
//| enabled by this module yet; see the release gate in the design.   |
//+------------------------------------------------------------------+
#ifndef _STB_LRN04_JOURNAL_MQH
#define _STB_LRN04_JOURNAL_MQH

#define STB_LRN04_FIELD_COUNT       20
#define STB_LRN04_MAX_RECORD_CHARS  1024
#define STB_LRN04_SCHEMA            "LRN04V1"

#define STB_LRN04_F_SCHEMA          0
#define STB_LRN04_F_SEQ             1
#define STB_LRN04_F_STATE           2
#define STB_LRN04_F_ACCOUNT         3
#define STB_LRN04_F_MAGIC           4
#define STB_LRN04_F_DEAL            5
#define STB_LRN04_F_POSITION        6
#define STB_LRN04_F_LIFECYCLE       7
#define STB_LRN04_F_SYMBOL          8
#define STB_LRN04_F_DIRECTION       9
#define STB_LRN04_F_ENTRY_KIND      10
#define STB_LRN04_F_PNL             11
#define STB_LRN04_F_RISK_STATE      12
#define STB_LRN04_F_R               13
#define STB_LRN04_F_WINS            14
#define STB_LRN04_F_LOSSES          15
#define STB_LRN04_F_RSUM            16
#define STB_LRN04_F_RCOUNT          17
#define STB_LRN04_F_DECAY_TIME      18
#define STB_LRN04_F_PREVIOUS_HASH   19

// CRC32/ISO-HDLC over the exact ASCII bytes represented by this string.
// All codec inputs are checked as ASCII before this function is called.
uint STB_LRN04_CRC32(const string value)
{
   uint crc=0xFFFFFFFF;
   int length=StringLen(value);

   for(int i=0;i<length;i++)
   {
      uint byteValue=(uint)StringGetCharacter(value,i);
      crc^=byteValue;

      for(int bit=0;bit<8;bit++)
      {
         if((crc&1)!=0)
            crc=(crc>>1)^0xEDB88320;
         else
            crc>>=1;
      }
   }

   return crc^0xFFFFFFFF;
}

string STB_LRN04_CRCText(const string value)
{
   return StringFormat("%08X",(int)STB_LRN04_CRC32(value));
}

bool STB_LRN04_IsToken(const string value)
{
   int length=StringLen(value);
   if(length<1)
      return false;

   for(int i=0;i<length;i++)
   {
      ushort c=StringGetCharacter(value,i);
      bool valid=(c>='A' && c<='Z') ||
                 (c>='0' && c<='9') ||
                 c=='_' || c=='-';

      if(!valid)
         return false;
   }

   return true;
}

bool STB_LRN04_IsSymbolCode(const string value)
{
   int length=StringLen(value);
   if(length<1)
      return false;

   for(int i=0;i<length;i++)
   {
      ushort c=StringGetCharacter(value,i);
      bool valid=(c>='A' && c<='Z') ||
                 (c>='a' && c<='z') ||
                 (c>='0' && c<='9') ||
                 c=='_' || c=='-' || c=='.';
      if(!valid)
         return false;
   }

   return true;
}

bool STB_LRN04_IsDigits(const string value)
{
   int length=StringLen(value);
   if(length<1)
      return false;

   for(int i=0;i<length;i++)
   {
      ushort c=StringGetCharacter(value,i);
      if(c<'0' || c>'9')
         return false;
   }

   return true;
}

bool STB_LRN04_WithinUnsigned64(const string digits)
{
   if(!STB_LRN04_IsDigits(digits))
      return false;
   if(StringLen(digits)>20)
      return false;
   if(StringLen(digits)<20)
      return true;

   return StringCompare(digits,"18446744073709551615",true)<=0;
}

bool STB_LRN04_IsUnsigned64(const string value)
{
   if(value=="0")
      return true;
   if(StringLen(value)>1 && StringGetCharacter(value,0)=='0')
      return false;
   return STB_LRN04_WithinUnsigned64(value);
}

bool STB_LRN04_IsSigned64(const string value)
{
   if(value=="0")
      return true;
   if(StringGetCharacter(value,0)=='-')
   {
      string digits=StringSubstr(value,1);
      if(digits=="0" || !STB_LRN04_IsDigits(digits))
         return false;
      // Reject non-canonical negative values such as -01 and -0007.
      if(StringLen(digits)>1 && StringGetCharacter(digits,0)=='0')
         return false;
      if(StringLen(digits)<19)
         return true;
      if(StringLen(digits)>19)
         return false;
      return StringCompare(digits,"9223372036854775808",true)<=0;
   }

   if(!STB_LRN04_IsUnsigned64(value))
      return false;

   if(StringLen(value)<19)
      return true;
   if(StringLen(value)>19)
      return false;
   return StringCompare(value,"9223372036854775807",true)<=0;
}

bool STB_LRN04_ValidateFields(const string &fields[])
{
   if(ArraySize(fields)!=STB_LRN04_FIELD_COUNT)
      return false;

   for(int i=0;i<STB_LRN04_FIELD_COUNT;i++)
   {
      string value=fields[i];
      if(value=="" || StringFind(value,"|")>=0 ||
         StringFind(value,"\n")>=0 || StringFind(value,"\r")>=0)
         return false;
   }

   if(fields[STB_LRN04_F_SCHEMA]!=STB_LRN04_SCHEMA)
      return false;
   if(fields[STB_LRN04_F_STATE]!="PREPARED" &&
      fields[STB_LRN04_F_STATE]!="COMMITTED")
      return false;
   if(fields[STB_LRN04_F_DIRECTION]!="BUY" &&
      fields[STB_LRN04_F_DIRECTION]!="SELL" &&
      fields[STB_LRN04_F_DIRECTION]!="FLAT" &&
      fields[STB_LRN04_F_DIRECTION]!="NA")
      return false;
   if(fields[STB_LRN04_F_ENTRY_KIND]!="IN" &&
      fields[STB_LRN04_F_ENTRY_KIND]!="OUT" &&
      fields[STB_LRN04_F_ENTRY_KIND]!="OUT_BY" &&
      fields[STB_LRN04_F_ENTRY_KIND]!="INOUT" &&
      fields[STB_LRN04_F_ENTRY_KIND]!="SNAPSHOT")
      return false;
   if(fields[STB_LRN04_F_RISK_STATE]!="KNOWN" &&
      fields[STB_LRN04_F_RISK_STATE]!="UNKNOWN" &&
      fields[STB_LRN04_F_RISK_STATE]!="NOT_APPLICABLE")
      return false;

   int unsignedIndexes[]={STB_LRN04_F_SEQ,STB_LRN04_F_MAGIC,
                          STB_LRN04_F_DEAL,STB_LRN04_F_POSITION,
                          STB_LRN04_F_LIFECYCLE,STB_LRN04_F_WINS,
                          STB_LRN04_F_LOSSES,STB_LRN04_F_RCOUNT,
                          STB_LRN04_F_DECAY_TIME};
   for(int j=0;j<ArraySize(unsignedIndexes);j++)
      if(!STB_LRN04_IsUnsigned64(fields[unsignedIndexes[j]]))
         return false;

   if(!STB_LRN04_IsSigned64(fields[STB_LRN04_F_PNL]) ||
      !STB_LRN04_IsSigned64(fields[STB_LRN04_F_R]) ||
      !STB_LRN04_IsSigned64(fields[STB_LRN04_F_RSUM]))
      return false;

   if(!STB_LRN04_IsToken(fields[STB_LRN04_F_ACCOUNT]) ||
      !STB_LRN04_IsToken(fields[STB_LRN04_F_PREVIOUS_HASH]) ||
      !STB_LRN04_IsSymbolCode(fields[STB_LRN04_F_SYMBOL]))
      return false;

   return true;
}

bool STB_LRN04_EncodeRecord(const string &fields[],string &record)
{
   record="";
   if(!STB_LRN04_ValidateFields(fields))
      return false;

   string body="";
   for(int i=0;i<STB_LRN04_FIELD_COUNT;i++)
   {
      if(i>0)
         body+="|";
      body+=fields[i];
   }

   string checksum=STB_LRN04_CRCText(body);
   record=body+"|"+checksum+"\n";

   // The accepted alphabet is ASCII, so character count equals byte count.
   if(StringLen(record)>STB_LRN04_MAX_RECORD_CHARS)
   {
      record="";
      return false;
   }

   return true;
}

bool STB_LRN04_DecodeRecord(const string raw,string &fields[])
{
   ArrayResize(fields,0);
   int length=StringLen(raw);
   if(length<2 || length>STB_LRN04_MAX_RECORD_CHARS)
      return false;
   if(StringGetCharacter(raw,length-1)!='\n')
      return false;
   if(StringFind(raw,"\r")>=0)
      return false;

   string line=StringSubstr(raw,0,length-1);
   string parts[];
   ushort separator=(ushort)StringGetCharacter("|",0);
   int count=StringSplit(line,separator,parts);
   if(count!=STB_LRN04_FIELD_COUNT+1)
      return false;

   string suppliedChecksum=parts[STB_LRN04_FIELD_COUNT];
   if(StringLen(suppliedChecksum)!=8)
      return false;
   for(int c=0;c<8;c++)
   {
      ushort ch=StringGetCharacter(suppliedChecksum,c);
      if(!((ch>='0' && ch<='9') || (ch>='A' && ch<='F')))
         return false;
   }

   string body="";
   for(int i=0;i<STB_LRN04_FIELD_COUNT;i++)
   {
      if(i>0)
         body+="|";
      body+=parts[i];
   }
   if(suppliedChecksum!=STB_LRN04_CRCText(body))
      return false;

   ArrayResize(fields,STB_LRN04_FIELD_COUNT);
   for(int j=0;j<STB_LRN04_FIELD_COUNT;j++)
      fields[j]=parts[j];

   if(!STB_LRN04_ValidateFields(fields))
   {
      ArrayResize(fields,0);
      return false;
   }

   // Re-encode to ensure canonical serialization, not merely valid values.
   string canonical="";
   if(!STB_LRN04_EncodeRecord(fields,canonical) || canonical!=raw)
   {
      ArrayResize(fields,0);
      return false;
   }

   return true;
}

#endif // _STB_LRN04_JOURNAL_MQH
