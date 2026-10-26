//+------------------------------------------------------------------+
//| SmartTradingBot_FINAL.mq5                                        |
//| Main Expert Advisor source for SmartTradingBot-Production        |
//| Standard-library dependencies are bundled below for portability. |
//+------------------------------------------------------------------+
#property strict
#property version   "1.146"
#property description "SmartTradingBot - H4/M15 structure analysis, adaptive scanner, pending-order management, chart controls, and execution safeguards"
// Trade.mqh and its require
// ===== BEGIN INLINED METAQUOTES STANDARD TRADE DEPENDENCIES =====

// ===== BEGIN MQL5/Include/StdLibErr.mqh =====
//+------------------------------------------------------------------+
//|                                                    StdLibErr.mqh |
//|                             Copyright 2000-2026, MetaQuotes Ltd. |
//|                                                     www.mql5.com |
//+------------------------------------------------------------------+
#define ERR_USER_INVALID_HANDLE                            1
#define ERR_USER_INVALID_BUFF_NUM                          2
#define ERR_USER_ITEM_NOT_FOUND                            3
#define ERR_USER_ARRAY_IS_EMPTY                            1000
//+------------------------------------------------------------------+

// ===== END MQL5/Include/StdLibErr.mqh =====

// ===== BEGIN MQL5/Include/Object.mqh =====
//+------------------------------------------------------------------+
//|                                                       Object.mqh |
//|                             Copyright 2000-2026, MetaQuotes Ltd. |
//|                                                     www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Class CObject.                                                   |
//| Purpose: Base class for storing elements.                        |
//+------------------------------------------------------------------+
class CObject
  {
private:
   CObject          *m_prev;               // previous item of list
   CObject          *m_next;               // next item of list

public:
                     CObject(void): m_prev(NULL),m_next(NULL)            {                 }
                    ~CObject(void)                                       {                 }
   //--- methods to access protected data
   CObject          *Prev(void)                                    const { return(m_prev); }
   void              Prev(CObject *node)                                 { m_prev=node;    }
   CObject          *Next(void)                                    const { return(m_next); }
   void              Next(CObject *node)                                 { m_next=node;    }
   //--- methods for working with files
   virtual bool      Save(const int file_handle)                         { return(true);   }
   virtual bool      Load(const int file_handle)                         { return(true);   }
   //--- method of identifying the object
   virtual int       Type(void)                                    const { return(0);      }
   //--- method of comparing the objects
   virtual int       Compare(const CObject *node,const int mode=0) const { return(0);      }
  };
//+------------------------------------------------------------------+

// ===== END MQL5/Include/Object.mqh =====

// ===== BEGIN MQL5/Include/Trade/OrderInfo.mqh =====
//+------------------------------------------------------------------+
//|                                                    OrderInfo.mqh |
//|                             Copyright 2000-2026, MetaQuotes Ltd. |
//|                                                     www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Class COrderInfo.                                                |
//| Appointment: Class for access to order info.                     |
//|              Derives from class CObject.                         |
//+------------------------------------------------------------------+
class COrderInfo : public CObject
  {
protected:
   ulong             m_ticket;
   ENUM_ORDER_TYPE   m_type;
   ENUM_ORDER_STATE  m_state;
   datetime          m_expiration;
   double            m_volume_curr;
   double            m_price_open;
   double            m_stop_loss;
   double            m_take_profit;

public:
                     COrderInfo(void);
                    ~COrderInfo(void);
   //--- methods of access to protected data
   ulong             Ticket(void) const { return(m_ticket); }
   //--- fast access methods to the integer order propertyes
   datetime          TimeSetup(void) const;
   ulong             TimeSetupMsc(void) const;
   datetime          TimeDone(void) const;
   ulong             TimeDoneMsc(void) const;
   ENUM_ORDER_TYPE   OrderType(void) const;
   string            TypeDescription(void) const;
   ENUM_ORDER_STATE  State(void) const;
   string            StateDescription(void) const;
   datetime          TimeExpiration(void) const;
   ENUM_ORDER_TYPE_FILLING TypeFilling(void) const;
   string            TypeFillingDescription(void) const;
   ENUM_ORDER_TYPE_TIME TypeTime(void) const;
   string            TypeTimeDescription(void) const;
   long              Magic(void) const;
   long              PositionId(void) const;
   long              PositionById(void) const;
   //--- fast access methods to the double order propertyes
   double            VolumeInitial(void) const;
   double            VolumeCurrent(void) const;
   double            PriceOpen(void) const;
   double            StopLoss(void) const;
   double            TakeProfit(void) const;
   double            PriceCurrent(void) const;
   double            PriceStopLimit(void) const;
   //--- fast access methods to the string order propertyes
   string            Symbol(void) const;
   string            Comment(void) const;
   string            ExternalId(void) const;
   //--- access methods to the API MQL5 functions
   bool              InfoInteger(const ENUM_ORDER_PROPERTY_INTEGER prop_id,long &var) const;
   bool              InfoDouble(const ENUM_ORDER_PROPERTY_DOUBLE prop_id,double &var) const;
   bool              InfoString(const ENUM_ORDER_PROPERTY_STRING prop_id,string &var) const;
   //--- info methods
   string            FormatType(string &str,const uint type) const;
   string            FormatStatus(string &str,const uint status) const;
   string            FormatTypeFilling(string &str,const uint type) const;
   string            FormatTypeTime(string &str,const uint type) const;
   string            FormatOrder(string &str) const;
   string            FormatPrice(string &str,const double price_order,const double price_trigger,const uint digits) const;
   //--- method for select order
   bool              Select(void);
   bool              Select(const ulong ticket);
   bool              SelectByIndex(const int index);
   //--- additional methods
   void              StoreState(void);
   bool              CheckState(void);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
COrderInfo::COrderInfo(void) : m_ticket(ULONG_MAX),
                               m_type(WRONG_VALUE),
                               m_state(WRONG_VALUE),
                               m_expiration(0),
                               m_volume_curr(0.0),
                               m_price_open(0.0),
                               m_stop_loss(0.0),
                               m_take_profit(0.0)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
COrderInfo::~COrderInfo(void)
  {
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TIME_SETUP"                        |
//+------------------------------------------------------------------+
datetime COrderInfo::TimeSetup(void) const
  {
   return((datetime)OrderGetInteger(ORDER_TIME_SETUP));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TIME_SETUP_MSC"                    |
//+------------------------------------------------------------------+
ulong COrderInfo::TimeSetupMsc(void) const
  {
   return(OrderGetInteger(ORDER_TIME_SETUP_MSC));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TIME_DONE"                         |
//+------------------------------------------------------------------+
datetime COrderInfo::TimeDone(void) const
  {
   return((datetime)OrderGetInteger(ORDER_TIME_DONE));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TIME_DONE_MSC"                     |
//+------------------------------------------------------------------+
ulong COrderInfo::TimeDoneMsc(void) const
  {
   return(OrderGetInteger(ORDER_TIME_DONE_MSC));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TYPE"                              |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE COrderInfo::OrderType(void) const
  {
   return((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TYPE" as string                    |
//+------------------------------------------------------------------+
string COrderInfo::TypeDescription(void) const
  {
   string str;
//---
   return(FormatType(str,OrderType()));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_STATE"                             |
//+------------------------------------------------------------------+
ENUM_ORDER_STATE COrderInfo::State(void) const
  {
   return((ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_STATE" as string                   |
//+------------------------------------------------------------------+
string COrderInfo::StateDescription(void) const
  {
   string str;
//---
   return(FormatStatus(str,State()));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TIME_EXPIRATION"                   |
//+------------------------------------------------------------------+
datetime COrderInfo::TimeExpiration(void) const
  {
   return((datetime)OrderGetInteger(ORDER_TIME_EXPIRATION));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TYPE_FILLING"                      |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING COrderInfo::TypeFilling(void) const
  {
   return((ENUM_ORDER_TYPE_FILLING)OrderGetInteger(ORDER_TYPE_FILLING));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TYPE_FILLING" as string            |
//+------------------------------------------------------------------+
string COrderInfo::TypeFillingDescription(void) const
  {
   string str;
//---
   return(FormatTypeFilling(str,TypeFilling()));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TYPE_TIME"                         |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_TIME COrderInfo::TypeTime(void) const
  {
   return((ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TYPE_TIME" as string               |
//+------------------------------------------------------------------+
string COrderInfo::TypeTimeDescription(void) const
  {
   string str;
//---
   return(FormatTypeTime(str,TypeFilling()));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_MAGIC"                             |
//+------------------------------------------------------------------+
long COrderInfo::Magic(void) const
  {
   return(OrderGetInteger(ORDER_MAGIC));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_POSITION_ID"                       |
//+------------------------------------------------------------------+
long COrderInfo::PositionId(void) const
  {
   return(OrderGetInteger(ORDER_POSITION_ID));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_POSITION_BY_ID"                    |
//+------------------------------------------------------------------+
long COrderInfo::PositionById(void) const
  {
   return(OrderGetInteger(ORDER_POSITION_BY_ID));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_VOLUME_INITIAL"                    |
//+------------------------------------------------------------------+
double COrderInfo::VolumeInitial(void) const
  {
   return(OrderGetDouble(ORDER_VOLUME_INITIAL));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_VOLUME_CURRENT"                    |
//+------------------------------------------------------------------+
double COrderInfo::VolumeCurrent(void) const
  {
   return(OrderGetDouble(ORDER_VOLUME_CURRENT));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_PRICE_OPEN"                        |
//+------------------------------------------------------------------+
double COrderInfo::PriceOpen(void) const
  {
   return(OrderGetDouble(ORDER_PRICE_OPEN));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_SL"                                |
//+------------------------------------------------------------------+
double COrderInfo::StopLoss(void) const
  {
   return(OrderGetDouble(ORDER_SL));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TP"                                |
//+------------------------------------------------------------------+
double COrderInfo::TakeProfit(void) const
  {
   return(OrderGetDouble(ORDER_TP));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_PRICE_CURRENT"                     |
//+------------------------------------------------------------------+
double COrderInfo::PriceCurrent(void) const
  {
   return(OrderGetDouble(ORDER_PRICE_CURRENT));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_PRICE_STOPLIMIT"                   |
//+------------------------------------------------------------------+
double COrderInfo::PriceStopLimit(void) const
  {
   return(OrderGetDouble(ORDER_PRICE_STOPLIMIT));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_SYMBOL"                            |
//+------------------------------------------------------------------+
string COrderInfo::Symbol(void) const
  {
   return(OrderGetString(ORDER_SYMBOL));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_COMMENT"                           |
//+------------------------------------------------------------------+
string COrderInfo::Comment(void) const
  {
   return(OrderGetString(ORDER_COMMENT));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_EXTERNAL_ID"                       |
//+------------------------------------------------------------------+
string COrderInfo::ExternalId(void) const
  {
   return(OrderGetString(ORDER_EXTERNAL_ID));
  }
//+------------------------------------------------------------------+
//| Access functions OrderGetInteger(...)                            |
//+------------------------------------------------------------------+
bool COrderInfo::InfoInteger(const ENUM_ORDER_PROPERTY_INTEGER prop_id,long &var) const
  {
   return(OrderGetInteger(prop_id,var));
  }
//+------------------------------------------------------------------+
//| Access functions OrderGetDouble(...)                             |
//+------------------------------------------------------------------+
bool COrderInfo::InfoDouble(const ENUM_ORDER_PROPERTY_DOUBLE prop_id,double &var) const
  {
   return(OrderGetDouble(prop_id,var));
  }
//+------------------------------------------------------------------+
//| Access functions OrderGetString(...)                             |
//+------------------------------------------------------------------+
bool COrderInfo::InfoString(const ENUM_ORDER_PROPERTY_STRING prop_id,string &var) const
  {
   return(OrderGetString(prop_id,var));
  }
//+------------------------------------------------------------------+
//| Converts the order type to text                                  |
//+------------------------------------------------------------------+
string COrderInfo::FormatType(string &str,const uint type) const
  {
//--- see the type
   switch(type)
     {
      case ORDER_TYPE_BUY:
         str="buy";
         break;
      case ORDER_TYPE_SELL:
         str="sell";
         break;
      case ORDER_TYPE_BUY_LIMIT:
         str="buy limit";
         break;
      case ORDER_TYPE_SELL_LIMIT:
         str="sell limit";
         break;
      case ORDER_TYPE_BUY_STOP:
         str="buy stop";
         break;
      case ORDER_TYPE_SELL_STOP:
         str="sell stop";
         break;
      case ORDER_TYPE_BUY_STOP_LIMIT:
         str="buy stop limit";
         break;
      case ORDER_TYPE_SELL_STOP_LIMIT:
         str="sell stop limit";
         break;
      case ORDER_TYPE_CLOSE_BY:
         str="close by";
         break;
      default :
         str="unknown order type "+(string)type;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the order status to text                                |
//+------------------------------------------------------------------+
string COrderInfo::FormatStatus(string &str,const uint status) const
  {
//--- see the type
   switch(status)
     {
      case ORDER_STATE_STARTED:
         str="started";
         break;
      case ORDER_STATE_PLACED:
         str="placed";
         break;
      case ORDER_STATE_CANCELED:
         str="canceled";
         break;
      case ORDER_STATE_PARTIAL:
         str="partial";
         break;
      case ORDER_STATE_FILLED:
         str="filled";
         break;
      case ORDER_STATE_REJECTED:
         str="rejected";
         break;
      case ORDER_STATE_EXPIRED:
         str="expired";
         break;
      case ORDER_STATE_REQUEST_ADD:
         str="request adding";
         break;
      case ORDER_STATE_REQUEST_MODIFY:
         str="request modifying";
         break;
      case ORDER_STATE_REQUEST_CANCEL:
         str="request cancelling";
         break;
      default :
         str="unknown order status "+(string)status;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the order filling type to text                          |
//+------------------------------------------------------------------+
string COrderInfo::FormatTypeFilling(string &str,const uint type) const
  {
//--- see the type
   switch(type)
     {
      case ORDER_FILLING_RETURN:
         str="return remainder";
         break;
      case ORDER_FILLING_IOC:
         str="cancel remainder";
         break;
      case ORDER_FILLING_FOK:
         str="fill or kill";
         break;
      default:
         str="unknown type filling "+(string)type;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the type of order by expiration to text                 |
//+------------------------------------------------------------------+
string COrderInfo::FormatTypeTime(string &str,const uint type) const
  {
//--- see the type
   switch(type)
     {
      case ORDER_TIME_GTC:
         str="gtc";
         break;
      case ORDER_TIME_DAY:
         str="day";
         break;
      case ORDER_TIME_SPECIFIED:
         str="specified";
         break;
      case ORDER_TIME_SPECIFIED_DAY:
         str="specified day";
         break;
      default:
         str="unknown type time "+(string)type;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the order parameters to text                            |
//+------------------------------------------------------------------+
string COrderInfo::FormatOrder(string &str) const
  {
   string type,price;
   long   tmp_long;
//--- set up
   string symbol_name=this.Symbol();
   int    digits=_Digits;
   if(SymbolInfoInteger(symbol_name,SYMBOL_DIGITS,tmp_long))
      digits=(int)tmp_long;
//--- form the order description
   str=StringFormat("#%I64u %s %s %s",
                    Ticket(),
                    FormatType(type,OrderType()),
                    DoubleToString(VolumeInitial(),2),
                    symbol_name);
//--- receive the price of the order
   FormatPrice(price,PriceOpen(),PriceStopLimit(),digits);
//--- if there is price, write it
   if(price!="")
     {
      str+=" at ";
      str+=price;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the order prices to text                                |
//+------------------------------------------------------------------+
string COrderInfo::FormatPrice(string &str,const double price_order,const double price_trigger,const uint digits) const
  {
   string price,trigger;
//--- Is there its trigger price?
   if(price_trigger)
     {
      price  =DoubleToString(price_order,digits);
      trigger=DoubleToString(price_trigger,digits);
      str    =StringFormat("%s (%s)",price,trigger);
     }
   else
      str=DoubleToString(price_order,digits);
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Selecting an order to access                                     |
//+------------------------------------------------------------------+
bool COrderInfo::Select(void)
  {
   return(OrderSelect(m_ticket));
  }
//+------------------------------------------------------------------+
//| Selecting an order to access                                     |
//+------------------------------------------------------------------+
bool COrderInfo::Select(const ulong ticket)
  {
   if(OrderSelect(ticket))
     {
      m_ticket=ticket;
      return(true);
     }
   m_ticket=ULONG_MAX;
//---
   return(false);
  }
//+------------------------------------------------------------------+
//| Select an order by the index                                     |
//+------------------------------------------------------------------+
bool COrderInfo::SelectByIndex(const int index)
  {
   ulong ticket=OrderGetTicket(index);
   if(ticket==0)
     {
      m_ticket=ULONG_MAX;
      return(false);
     }
   m_ticket=ticket;
//---
   return(true);
  }
//+------------------------------------------------------------------+
//| Stored order's current state                                     |
//+------------------------------------------------------------------+
void COrderInfo::StoreState(void)
  {
   m_type       =OrderType();
   m_state      =State();
   m_expiration =TimeExpiration();
   m_volume_curr=VolumeCurrent();
   m_price_open =PriceOpen();
   m_stop_loss  =StopLoss();
   m_take_profit=TakeProfit();
  }
//+------------------------------------------------------------------+
//| Check order change                                               |
//+------------------------------------------------------------------+
bool COrderInfo::CheckState(void)
  {
   if(m_type==OrderType()            &&
      m_state==State()               &&
      m_expiration==TimeExpiration() &&
      m_volume_curr==VolumeCurrent() &&
      m_price_open==PriceOpen()      &&
      m_stop_loss==StopLoss()        &&
      m_take_profit==TakeProfit())
      return(false);
//---
   return(true);
  }
//+------------------------------------------------------------------+

// ===== END MQL5/Include/Trade/OrderInfo.mqh =====

// ===== BEGIN MQL5/Include/Trade/HistoryOrderInfo.mqh =====
//+------------------------------------------------------------------+
//|                                             HistoryOrderInfo.mqh |
//|                             Copyright 2000-2026, MetaQuotes Ltd. |
//|                                                     www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Class CHistoryOrderInfo.                                         |
//| Appointment: Class for access to history order info.             |
//|              Derives from class CObject.                         |
//+------------------------------------------------------------------+
class CHistoryOrderInfo : public CObject
  {
protected:
   ulong             m_ticket;             // ticket of history order
public:
                     CHistoryOrderInfo(void);
                    ~CHistoryOrderInfo(void);
   //--- methods of access to protected data
   void              Ticket(const ulong ticket) { m_ticket=ticket;  }
   ulong             Ticket(void)         const { return(m_ticket); }
   //--- fast access methods to the integer order propertyes
   datetime          TimeSetup(void) const;
   ulong             TimeSetupMsc(void) const;
   datetime          TimeDone(void) const;
   ulong             TimeDoneMsc(void) const;
   ENUM_ORDER_TYPE   OrderType(void) const;
   string            TypeDescription(void) const;
   ENUM_ORDER_STATE  State(void) const;
   string            StateDescription(void) const;
   datetime          TimeExpiration(void) const;
   ENUM_ORDER_TYPE_FILLING TypeFilling(void) const;
   string            TypeFillingDescription(void) const;
   ENUM_ORDER_TYPE_TIME TypeTime(void) const;
   string            TypeTimeDescription(void) const;
   long              Magic(void) const;
   long              PositionId(void) const;
   long              PositionById(void) const;
   //--- fast access methods to the double order propertyes
   double            VolumeInitial(void) const;
   double            VolumeCurrent(void) const;
   double            PriceOpen(void) const;
   double            StopLoss(void) const;
   double            TakeProfit(void) const;
   double            PriceCurrent(void) const;
   double            PriceStopLimit(void) const;
   //--- fast access methods to the string order propertyes
   string            Symbol(void) const;
   string            Comment(void) const;
   string            ExternalId(void) const;
   //--- access methods to the API MQL5 functions
   bool              InfoInteger(const ENUM_ORDER_PROPERTY_INTEGER prop_id,long &var) const;
   bool              InfoDouble(const ENUM_ORDER_PROPERTY_DOUBLE prop_id,double &var) const;
   bool              InfoString(const ENUM_ORDER_PROPERTY_STRING prop_id,string &var) const;
   //--- info methods
   string            FormatType(string &str,const uint type) const;
   string            FormatStatus(string &str,const uint status) const;
   string            FormatTypeFilling(string &str,const uint type) const;
   string            FormatTypeTime(string &str,const uint type) const;
   string            FormatOrder(string &str) const;
   string            FormatPrice(string &str,const double price_order,const double price_trigger,const uint digits) const;
   //--- method for select history order
   bool              SelectByIndex(const int index);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CHistoryOrderInfo::CHistoryOrderInfo(void) : m_ticket(0)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CHistoryOrderInfo::~CHistoryOrderInfo(void)
  {
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TIME_SETUP"                        |
//+------------------------------------------------------------------+
datetime CHistoryOrderInfo::TimeSetup(void) const
  {
   return((datetime)HistoryOrderGetInteger(m_ticket,ORDER_TIME_SETUP));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TIME_SETUP_MSC"                    |
//+------------------------------------------------------------------+
ulong CHistoryOrderInfo::TimeSetupMsc(void) const
  {
   return(HistoryOrderGetInteger(m_ticket,ORDER_TIME_SETUP_MSC));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TIME_DONE"                         |
//+------------------------------------------------------------------+
datetime CHistoryOrderInfo::TimeDone(void) const
  {
   return((datetime)HistoryOrderGetInteger(m_ticket,ORDER_TIME_DONE));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TIME_DONE_MSC"                     |
//+------------------------------------------------------------------+
ulong CHistoryOrderInfo::TimeDoneMsc(void) const
  {
   return(HistoryOrderGetInteger(m_ticket,ORDER_TIME_DONE_MSC));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TYPE"                              |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE CHistoryOrderInfo::OrderType(void) const
  {
   return((ENUM_ORDER_TYPE)HistoryOrderGetInteger(m_ticket,ORDER_TYPE));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TYPE" as string                    |
//+------------------------------------------------------------------+
string CHistoryOrderInfo::TypeDescription(void) const
  {
   string str;
//---
   return(FormatType(str,OrderType()));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_STATE"                             |
//+------------------------------------------------------------------+
ENUM_ORDER_STATE CHistoryOrderInfo::State(void) const
  {
   return((ENUM_ORDER_STATE)HistoryOrderGetInteger(m_ticket,ORDER_STATE));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_STATE" as string                   |
//+------------------------------------------------------------------+
string CHistoryOrderInfo::StateDescription(void) const
  {
   string str;
//---
   return(FormatStatus(str,State()));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TIME_EXPIRATION"                   |
//+------------------------------------------------------------------+
datetime CHistoryOrderInfo::TimeExpiration(void) const
  {
   return((datetime)HistoryOrderGetInteger(m_ticket,ORDER_TIME_EXPIRATION));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TYPE_FILLING"                      |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING CHistoryOrderInfo::TypeFilling(void) const
  {
   return((ENUM_ORDER_TYPE_FILLING)HistoryOrderGetInteger(m_ticket,ORDER_TYPE_FILLING));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TYPE_FILLING" as string            |
//+------------------------------------------------------------------+
string CHistoryOrderInfo::TypeFillingDescription(void) const
  {
   string str;
//---
   return(FormatTypeFilling(str,TypeFilling()));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TYPE_TIME"                         |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_TIME CHistoryOrderInfo::TypeTime(void) const
  {
   return((ENUM_ORDER_TYPE_TIME)HistoryOrderGetInteger(m_ticket,ORDER_TYPE_TIME));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TYPE_TIME" as string               |
//+------------------------------------------------------------------+
string CHistoryOrderInfo::TypeTimeDescription(void) const
  {
   string str;
//---
   return(FormatTypeTime(str,TypeTime()));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_EXPERT"                            |
//+------------------------------------------------------------------+
long CHistoryOrderInfo::Magic(void) const
  {
   return(HistoryOrderGetInteger(m_ticket,ORDER_MAGIC));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_POSITION_ID"                       |
//+------------------------------------------------------------------+
long CHistoryOrderInfo::PositionId(void) const
  {
   return(HistoryOrderGetInteger(m_ticket,ORDER_POSITION_ID));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_POSITION_BY_ID"                    |
//+------------------------------------------------------------------+
long CHistoryOrderInfo::PositionById(void) const
  {
   return(HistoryOrderGetInteger(m_ticket,ORDER_POSITION_BY_ID));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_VOLUME_INITIAL"                    |
//+------------------------------------------------------------------+
double CHistoryOrderInfo::VolumeInitial(void) const
  {
   return(HistoryOrderGetDouble(m_ticket,ORDER_VOLUME_INITIAL));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_VOLUME_CURRENT"                    |
//+------------------------------------------------------------------+
double CHistoryOrderInfo::VolumeCurrent(void) const
  {
   return(HistoryOrderGetDouble(m_ticket,ORDER_VOLUME_CURRENT));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_PRICE_OPEN"                        |
//+------------------------------------------------------------------+
double CHistoryOrderInfo::PriceOpen(void) const
  {
   return(HistoryOrderGetDouble(m_ticket,ORDER_PRICE_OPEN));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_SL"                                |
//+------------------------------------------------------------------+
double CHistoryOrderInfo::StopLoss(void) const
  {
   return(HistoryOrderGetDouble(m_ticket,ORDER_SL));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_TP"                                |
//+------------------------------------------------------------------+
double CHistoryOrderInfo::TakeProfit(void) const
  {
   return(HistoryOrderGetDouble(m_ticket,ORDER_TP));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_PRICE_CURRENT"                     |
//+------------------------------------------------------------------+
double CHistoryOrderInfo::PriceCurrent(void) const
  {
   return(HistoryOrderGetDouble(m_ticket,ORDER_PRICE_CURRENT));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_PRICE_STOPLIMIT"                   |
//+------------------------------------------------------------------+
double CHistoryOrderInfo::PriceStopLimit(void) const
  {
   return(HistoryOrderGetDouble(m_ticket,ORDER_PRICE_STOPLIMIT));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_SYMBOL"                            |
//+------------------------------------------------------------------+
string CHistoryOrderInfo::Symbol(void) const
  {
   return(HistoryOrderGetString(m_ticket,ORDER_SYMBOL));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_COMMENT"                           |
//+------------------------------------------------------------------+
string CHistoryOrderInfo::Comment(void) const
  {
   return(HistoryOrderGetString(m_ticket,ORDER_COMMENT));
  }
//+------------------------------------------------------------------+
//| Get the property value "ORDER_EXTERNAL_ID"                       |
//+------------------------------------------------------------------+
string CHistoryOrderInfo::ExternalId(void) const
  {
   return(HistoryOrderGetString(m_ticket,ORDER_EXTERNAL_ID));
  }
//+------------------------------------------------------------------+
//| Access functions OrderGetInteger(...)                            |
//+------------------------------------------------------------------+
bool CHistoryOrderInfo::InfoInteger(const ENUM_ORDER_PROPERTY_INTEGER prop_id,long &var) const
  {
   return(HistoryOrderGetInteger(m_ticket,prop_id,var));
  }
//+------------------------------------------------------------------+
//| Access functions OrderGetDouble(...)                             |
//+------------------------------------------------------------------+
bool CHistoryOrderInfo::InfoDouble(const ENUM_ORDER_PROPERTY_DOUBLE prop_id,double &var) const
  {
   return(HistoryOrderGetDouble(m_ticket,prop_id,var));
  }
//+------------------------------------------------------------------+
//| Access functions OrderGetString(...)                             |
//+------------------------------------------------------------------+
bool CHistoryOrderInfo::InfoString(const ENUM_ORDER_PROPERTY_STRING prop_id,string &var) const
  {
   return(HistoryOrderGetString(m_ticket,prop_id,var));
  }
//+------------------------------------------------------------------+
//| Converts the order type to text                                  |
//+------------------------------------------------------------------+
string CHistoryOrderInfo::FormatType(string &str,const uint type) const
  {
//--- see the type
   switch(type)
     {
      case ORDER_TYPE_BUY:
         str="buy";
         break;
      case ORDER_TYPE_SELL:
         str="sell";
         break;
      case ORDER_TYPE_BUY_LIMIT:
         str="buy limit";
         break;
      case ORDER_TYPE_SELL_LIMIT:
         str="sell limit";
         break;
      case ORDER_TYPE_BUY_STOP:
         str="buy stop";
         break;
      case ORDER_TYPE_SELL_STOP:
         str="sell stop";
         break;
      case ORDER_TYPE_BUY_STOP_LIMIT:
         str="buy stop limit";
         break;
      case ORDER_TYPE_SELL_STOP_LIMIT:
         str="sell stop limit";
         break;
      case ORDER_TYPE_CLOSE_BY:
         str="close by";
         break;
      default:
         str="unknown order type "+(string)type;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the order status to text                                |
//+------------------------------------------------------------------+
string CHistoryOrderInfo::FormatStatus(string &str,const uint status) const
  {
//--- see the type
   switch(status)
     {
      case ORDER_STATE_STARTED:
         str="started";
         break;
      case ORDER_STATE_PLACED:
         str="placed";
         break;
      case ORDER_STATE_CANCELED:
         str="canceled";
         break;
      case ORDER_STATE_PARTIAL:
         str="partial";
         break;
      case ORDER_STATE_FILLED:
         str="filled";
         break;
      case ORDER_STATE_REJECTED:
         str="rejected";
         break;
      case ORDER_STATE_EXPIRED:
         str="expired";
         break;
      default:
         str="unknown order status "+(string)status;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the order filling type to text                          |
//+------------------------------------------------------------------+
string CHistoryOrderInfo::FormatTypeFilling(string &str,const uint type) const
  {
//--- see the type
   switch(type)
     {
      case ORDER_FILLING_RETURN:
         str="return remainder";
         break;
      case ORDER_FILLING_IOC:
         str="cancel remainder";
         break;
      case ORDER_FILLING_FOK:
         str="fill or kill";
         break;
      default:
         str="unknown type filling "+(string)type;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the type of order by expiration to text                 |
//+------------------------------------------------------------------+
string CHistoryOrderInfo::FormatTypeTime(string &str,const uint type) const
  {
//--- see the type
   switch(type)
     {
      case ORDER_TIME_GTC:
         str="gtc";
         break;
      case ORDER_TIME_DAY:
         str="day";
         break;
      case ORDER_TIME_SPECIFIED:
         str="specified";
         break;
      case ORDER_TIME_SPECIFIED_DAY:
         str="specified day";
         break;
      default:
         str="unknown type time "+(string)type;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the order parameters to text                            |
//+------------------------------------------------------------------+
string CHistoryOrderInfo::FormatOrder(string &str) const
  {
   string type,price;
   long   tmp_long;
//--- set up
   string symbol_name=this.Symbol();
   int    digits=_Digits;
   if(SymbolInfoInteger(symbol_name,SYMBOL_DIGITS,tmp_long))
      digits=(int)tmp_long;
//--- form the order description
   str=StringFormat("#%I64u %s %s %s",
                    Ticket(),
                    FormatType(type,OrderType()),
                    DoubleToString(VolumeInitial(),2),
                    symbol_name);
//--- receive the price of the order
   FormatPrice(price,PriceOpen(),PriceStopLimit(),digits);
//--- if there is price, write it
   if(price!="")
     {
      str+=" at ";
      str+=price;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the order prices to text                                |
//+------------------------------------------------------------------+
string CHistoryOrderInfo::FormatPrice(string &str,const double price_order,const double price_trigger,const uint digits) const
  {
   string price,trigger;
//--- Is there its trigger price?
   if(price_trigger)
     {
      price  =DoubleToString(price_order,digits);
      trigger=DoubleToString(price_trigger,digits);
      str    =StringFormat("%s (%s)",price,trigger);
     }
   else
      str=DoubleToString(price_order,digits);
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Select a history order on the index                              |
//+------------------------------------------------------------------+
bool CHistoryOrderInfo::SelectByIndex(const int index)
  {
   ulong ticket=HistoryOrderGetTicket(index);
   if(ticket==0)
      return(false);
   Ticket(ticket);
//---
   return(true);
  }
//+------------------------------------------------------------------+

// ===== END MQL5/Include/Trade/HistoryOrderInfo.mqh =====

// ===== BEGIN MQL5/Include/Trade/PositionInfo.mqh =====
//+------------------------------------------------------------------+
//|                                                 PositionInfo.mqh |
//|                             Copyright 2000-2026, MetaQuotes Ltd. |
//|                                                     www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Class CPositionInfo.                                             |
//| Appointment: Class for access to position info.                  |
//|              Derives from class CObject.                         |
//+------------------------------------------------------------------+
class CPositionInfo : public CObject
  {
protected:
   ENUM_POSITION_TYPE m_type;
   double            m_volume;
   double            m_price;
   double            m_stop_loss;
   double            m_take_profit;

public:
                     CPositionInfo(void);
                    ~CPositionInfo(void);
   //--- fast access methods to the integer position propertyes
   ulong             Ticket(void) const;
   datetime          Time(void) const;
   ulong             TimeMsc(void) const;
   datetime          TimeUpdate(void) const;
   ulong             TimeUpdateMsc(void) const;
   ENUM_POSITION_TYPE PositionType(void) const;
   string            TypeDescription(void) const;
   long              Magic(void) const;
   long              Identifier(void) const;
   //--- fast access methods to the double position propertyes
   double            Volume(void) const;
   double            PriceOpen(void) const;
   double            StopLoss(void) const;
   double            TakeProfit(void) const;
   double            PriceCurrent(void) const;
   double            Commission(void) const;
   double            Swap(void) const;
   double            Profit(void) const;
   //--- fast access methods to the string position propertyes
   string            Symbol(void) const;
   string            Comment(void) const;
   //--- access methods to the API MQL5 functions
   bool              InfoInteger(const ENUM_POSITION_PROPERTY_INTEGER prop_id,long &var) const;
   bool              InfoDouble(const ENUM_POSITION_PROPERTY_DOUBLE prop_id,double &var) const;
   bool              InfoString(const ENUM_POSITION_PROPERTY_STRING prop_id,string &var) const;
   //--- info methods
   string            FormatType(string &str,const uint type) const;
   string            FormatPosition(string &str) const;
   //--- methods for select position
   bool              Select(const string symbol);
   bool              SelectByMagic(const string symbol,const ulong magic);
   bool              SelectByTicket(const ulong ticket);
   bool              SelectByIndex(const int index);
   //---
   void              StoreState(void);
   bool              CheckState(void);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPositionInfo::CPositionInfo(void) : m_type(WRONG_VALUE),
                                     m_volume(0.0),
                                     m_price(0.0),
                                     m_stop_loss(0.0),
                                     m_take_profit(0.0)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPositionInfo::~CPositionInfo(void)
  {
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_TICKET"                         |
//+------------------------------------------------------------------+
ulong CPositionInfo::Ticket(void) const
  {
   return((ulong)PositionGetInteger(POSITION_TICKET));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_TIME"                           |
//+------------------------------------------------------------------+
datetime CPositionInfo::Time(void) const
  {
   return((datetime)PositionGetInteger(POSITION_TIME));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_TIME_MSC"                       |
//+------------------------------------------------------------------+
ulong CPositionInfo::TimeMsc(void) const
  {
   return((ulong)PositionGetInteger(POSITION_TIME_MSC));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_TIME_UPDATE"                    |
//+------------------------------------------------------------------+
datetime CPositionInfo::TimeUpdate(void) const
  {
   return((datetime)PositionGetInteger(POSITION_TIME_UPDATE));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_TIME_UPDATE_MSC"                |
//+------------------------------------------------------------------+
ulong CPositionInfo::TimeUpdateMsc(void) const
  {
   return((ulong)PositionGetInteger(POSITION_TIME_UPDATE_MSC));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_TYPE"                           |
//+------------------------------------------------------------------+
ENUM_POSITION_TYPE CPositionInfo::PositionType(void) const
  {
   return((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_TYPE" as string                 |
//+------------------------------------------------------------------+
string CPositionInfo::TypeDescription(void) const
  {
   string str;
//---
   return(FormatType(str,PositionType()));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_MAGIC"                          |
//+------------------------------------------------------------------+
long CPositionInfo::Magic(void) const
  {
   return(PositionGetInteger(POSITION_MAGIC));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_IDENTIFIER"                     |
//+------------------------------------------------------------------+
long CPositionInfo::Identifier(void) const
  {
   return(PositionGetInteger(POSITION_IDENTIFIER));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_VOLUME"                         |
//+------------------------------------------------------------------+
double CPositionInfo::Volume(void) const
  {
   return(PositionGetDouble(POSITION_VOLUME));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_PRICE_OPEN"                     |
//+------------------------------------------------------------------+
double CPositionInfo::PriceOpen(void) const
  {
   return(PositionGetDouble(POSITION_PRICE_OPEN));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_SL"                             |
//+------------------------------------------------------------------+
double CPositionInfo::StopLoss(void) const
  {
   return(PositionGetDouble(POSITION_SL));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_TP"                             |
//+------------------------------------------------------------------+
double CPositionInfo::TakeProfit(void) const
  {
   return(PositionGetDouble(POSITION_TP));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_PRICE_CURRENT"                  |
//+------------------------------------------------------------------+
double CPositionInfo::PriceCurrent(void) const
  {
   return(PositionGetDouble(POSITION_PRICE_CURRENT));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_COMMISSION"                     |
//+------------------------------------------------------------------+
double CPositionInfo::Commission(void) const
  {
//--- property POSITION_COMMISSION is deprecated
   SetUserError(ERR_FUNCTION_NOT_ALLOWED);
   return(0);
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_SWAP"                           |
//+------------------------------------------------------------------+
double CPositionInfo::Swap(void) const
  {
   return(PositionGetDouble(POSITION_SWAP));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_PROFIT"                         |
//+------------------------------------------------------------------+
double CPositionInfo::Profit(void) const
  {
   return(PositionGetDouble(POSITION_PROFIT));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_SYMBOL"                         |
//+------------------------------------------------------------------+
string CPositionInfo::Symbol(void) const
  {
   return(PositionGetString(POSITION_SYMBOL));
  }
//+------------------------------------------------------------------+
//| Get the property value "POSITION_COMMENT"                        |
//+------------------------------------------------------------------+
string CPositionInfo::Comment(void) const
  {
   return(PositionGetString(POSITION_COMMENT));
  }
//+------------------------------------------------------------------+
//| Access functions PositionGetInteger(...)                         |
//+------------------------------------------------------------------+
bool CPositionInfo::InfoInteger(const ENUM_POSITION_PROPERTY_INTEGER prop_id,long &var) const
  {
   return(PositionGetInteger(prop_id,var));
  }
//+------------------------------------------------------------------+
//| Access functions PositionGetDouble(...)                          |
//+------------------------------------------------------------------+
bool CPositionInfo::InfoDouble(const ENUM_POSITION_PROPERTY_DOUBLE prop_id,double &var) const
  {
   return(PositionGetDouble(prop_id,var));
  }
//+------------------------------------------------------------------+
//| Access functions PositionGetString(...)                          |
//+------------------------------------------------------------------+
bool CPositionInfo::InfoString(const ENUM_POSITION_PROPERTY_STRING prop_id,string &var) const
  {
   return(PositionGetString(prop_id,var));
  }
//+------------------------------------------------------------------+
//| Converts the position type to text                               |
//+------------------------------------------------------------------+
string CPositionInfo::FormatType(string &str,const uint type) const
  {
//--- see the type
   switch(type)
     {
      case POSITION_TYPE_BUY:
         str="buy";
         break;
      case POSITION_TYPE_SELL:
         str="sell";
         break;
      default:
         str="unknown position type "+(string)type;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the position parameters to text                         |
//+------------------------------------------------------------------+
string CPositionInfo::FormatPosition(string &str) const
  {
   string tmp,type;
   long   tmp_long;
   ENUM_ACCOUNT_MARGIN_MODE margin_mode=(ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
//--- set up
   string symbol_name=this.Symbol();
   int    digits=_Digits;
   if(SymbolInfoInteger(symbol_name,SYMBOL_DIGITS,tmp_long))
      digits=(int)tmp_long;
//--- form the position description
   if(margin_mode==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      str=StringFormat("#%I64u %s %s %s %s",
                       Ticket(),
                       FormatType(type,PositionType()),
                       DoubleToString(Volume(),2),
                       symbol_name,
                       DoubleToString(PriceOpen(),digits+3));
   else
      str=StringFormat("%s %s %s %s",
                       FormatType(type,PositionType()),
                       DoubleToString(Volume(),2),
                       symbol_name,
                       DoubleToString(PriceOpen(),digits+3));
//--- add stops if there are any
   double sl=StopLoss();
   double tp=TakeProfit();
   if(sl!=0.0)
     {
      tmp=StringFormat(" sl: %s",DoubleToString(sl,digits));
      str+=tmp;
     }
   if(tp!=0.0)
     {
      tmp=StringFormat(" tp: %s",DoubleToString(tp,digits));
      str+=tmp;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Access functions PositionSelect(...)                             |
//+------------------------------------------------------------------+
bool CPositionInfo::Select(const string symbol)
  {
   return(PositionSelect(symbol));
  }
//+------------------------------------------------------------------+
//| Access functions PositionSelect(...)                             |
//+------------------------------------------------------------------+
bool CPositionInfo::SelectByMagic(const string symbol,const ulong magic)
  {
   bool res=false;
   uint total=PositionsTotal();
//---
   for(uint i=0; i<total; i++)
     {
      string position_symbol=PositionGetSymbol(i);
      if(position_symbol==symbol && magic==PositionGetInteger(POSITION_MAGIC))
        {
         res=true;
         break;
        }
     }
//---
   return(res);
  }
//+------------------------------------------------------------------+
//| Access functions PositionSelectByTicket(...)                     |
//+------------------------------------------------------------------+
bool CPositionInfo::SelectByTicket(const ulong ticket)
  {
   return(PositionSelectByTicket(ticket));
  }
//+------------------------------------------------------------------+
//| Select a position on the index                                   |
//+------------------------------------------------------------------+
bool CPositionInfo::SelectByIndex(const int index)
  {
   ulong ticket=PositionGetTicket(index);
   return(ticket>0);
  }
//+------------------------------------------------------------------+
//| Stored position's current state                                  |
//+------------------------------------------------------------------+
void CPositionInfo::StoreState(void)
  {
   m_type       =PositionType();
   m_volume     =Volume();
   m_price      =PriceOpen();
   m_stop_loss  =StopLoss();
   m_take_profit=TakeProfit();
  }
//+------------------------------------------------------------------+
//| Check position change                                            |
//+------------------------------------------------------------------+
bool CPositionInfo::CheckState(void)
  {
   if(m_type==PositionType()  &&
      m_volume==Volume()      &&
      m_price==PriceOpen()    &&
      m_stop_loss==StopLoss() &&
      m_take_profit==TakeProfit())
      return(false);
//---
   return(true);
  }
//+------------------------------------------------------------------+

// ===== END MQL5/Include/Trade/PositionInfo.mqh =====

// ===== BEGIN MQL5/Include/Trade/DealInfo.mqh =====
//+------------------------------------------------------------------+
//|                                                     DealInfo.mqh |
//|                             Copyright 2000-2026, MetaQuotes Ltd. |
//|                                                     www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Class CDealInfo.                                                 |
//| Appointment: Class for access to history deal info.              |
//|              Derives from class CObject.                         |
//+------------------------------------------------------------------+
class CDealInfo : public CObject
  {
protected:
   ulong             m_ticket;             // ticket of history order

public:
                     CDealInfo(void);
                    ~CDealInfo(void);
   //--- methods of access to protected data
   void              Ticket(const ulong ticket)   { m_ticket=ticket;  }
   ulong             Ticket(void)           const { return(m_ticket); }
   //--- fast access methods to the integer position propertyes
   long              Order(void) const;
   datetime          Time(void) const;
   ulong             TimeMsc(void) const;
   ENUM_DEAL_TYPE    DealType(void) const;
   string            TypeDescription(void) const;
   ENUM_DEAL_ENTRY   Entry(void) const;
   string            EntryDescription(void) const;
   long              Magic(void) const;
   long              PositionId(void) const;
   //--- fast access methods to the double position propertyes
   double            Volume(void) const;
   double            Price(void) const;
   double            Commission(void) const;
   double            Swap(void) const;
   double            Profit(void) const;
   //--- fast access methods to the string position propertyes
   string            Symbol(void) const;
   string            Comment(void) const;
   string            ExternalId(void) const;
   //--- access methods to the API MQL5 functions
   bool              InfoInteger(ENUM_DEAL_PROPERTY_INTEGER prop_id,long &var) const;
   bool              InfoDouble(ENUM_DEAL_PROPERTY_DOUBLE prop_id,double &var) const;
   bool              InfoString(ENUM_DEAL_PROPERTY_STRING prop_id,string &var) const;
   //--- info methods
   string            FormatAction(string &str,const uint action) const;
   string            FormatEntry(string &str,const uint entry) const;
   string            FormatDeal(string &str) const;
   //--- method for select deal
   bool              SelectByIndex(const int index);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CDealInfo::CDealInfo(void)
  {
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CDealInfo::~CDealInfo(void)
  {
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_ORDER"                              |
//+------------------------------------------------------------------+
long CDealInfo::Order(void) const
  {
   return(HistoryDealGetInteger(m_ticket,DEAL_ORDER));
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_TIME"                               |
//+------------------------------------------------------------------+
datetime CDealInfo::Time(void) const
  {
   return((datetime)HistoryDealGetInteger(m_ticket,DEAL_TIME));
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_TIME_MSC"                           |
//+------------------------------------------------------------------+
ulong CDealInfo::TimeMsc(void) const
  {
   return(HistoryDealGetInteger(m_ticket,DEAL_TIME_MSC));
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_TYPE"                               |
//+------------------------------------------------------------------+
ENUM_DEAL_TYPE CDealInfo::DealType(void) const
  {
   return((ENUM_DEAL_TYPE)HistoryDealGetInteger(m_ticket,DEAL_TYPE));
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_TYPE" as string                     |
//+------------------------------------------------------------------+
string CDealInfo::TypeDescription(void) const
  {
   string str;
//---
   switch(DealType())
     {
      case DEAL_TYPE_BUY:
         str="Buy type";
         break;
      case DEAL_TYPE_SELL:
         str="Sell type";
         break;
      case DEAL_TYPE_BALANCE:
         str="Balance type";
         break;
      case DEAL_TYPE_CREDIT:
         str="Credit type";
         break;
      case DEAL_TYPE_CHARGE:
         str="Charge type";
         break;
      case DEAL_TYPE_CORRECTION:
         str="Correction type";
         break;
      case DEAL_TYPE_BONUS:
         str="Bonus type";
         break;
      case DEAL_TYPE_COMMISSION:
         str="Commission type";
         break;
      case DEAL_TYPE_COMMISSION_DAILY:
         str="Daily Commission type";
         break;
      case DEAL_TYPE_COMMISSION_MONTHLY:
         str="Monthly Commission type";
         break;
      case DEAL_TYPE_COMMISSION_AGENT_DAILY:
         str="Daily Agent Commission type";
         break;
      case DEAL_TYPE_COMMISSION_AGENT_MONTHLY:
         str="Monthly Agent Commission type";
         break;
      case DEAL_TYPE_INTEREST:
         str="Interest Rate type";
         break;
      case DEAL_TYPE_BUY_CANCELED:
         str="Canceled Buy type";
         break;
      case DEAL_TYPE_SELL_CANCELED:
         str="Canceled Sell type";
         break;
      default:
         str="Unknown type";
     }
//---
   return(str);
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_ENTRY"                              |
//+------------------------------------------------------------------+
ENUM_DEAL_ENTRY CDealInfo::Entry(void) const
  {
   return((ENUM_DEAL_ENTRY)HistoryDealGetInteger(m_ticket,DEAL_ENTRY));
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_ENTRY" as string                    |
//+------------------------------------------------------------------+
string CDealInfo::EntryDescription(void) const
  {
   string str;
//---
   switch(CDealInfo::Entry())
     {
      case DEAL_ENTRY_IN:
         str="In entry";
         break;
      case DEAL_ENTRY_OUT:
         str="Out entry";
         break;
      case DEAL_ENTRY_INOUT:
         str="InOut entry";
         break;
      case DEAL_ENTRY_STATE:
         str="Status record";
         break;
      case DEAL_ENTRY_OUT_BY:
         str="Out By entry";
         break;
      default:
         str="Unknown entry";
     }
//---
   return(str);
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_MAGIC"                              |
//+------------------------------------------------------------------+
long CDealInfo::Magic(void) const
  {
   return(HistoryDealGetInteger(m_ticket,DEAL_MAGIC));
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_POSITION_ID"                        |
//+------------------------------------------------------------------+
long CDealInfo::PositionId(void) const
  {
   return(HistoryDealGetInteger(m_ticket,DEAL_POSITION_ID));
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_VOLUME"                             |
//+------------------------------------------------------------------+
double CDealInfo::Volume(void) const
  {
   return(HistoryDealGetDouble(m_ticket,DEAL_VOLUME));
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_PRICE_OPEN"                         |
//+------------------------------------------------------------------+
double CDealInfo::Price(void) const
  {
   return(HistoryDealGetDouble(m_ticket,DEAL_PRICE));
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_COMMISSION"                         |
//+------------------------------------------------------------------+
double CDealInfo::Commission(void) const
  {
   return(HistoryDealGetDouble(m_ticket,DEAL_COMMISSION));
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_SWAP"                               |
//+------------------------------------------------------------------+
double CDealInfo::Swap(void) const
  {
   return(HistoryDealGetDouble(m_ticket,DEAL_SWAP));
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_PROFIT"                             |
//+------------------------------------------------------------------+
double CDealInfo::Profit(void) const
  {
   return(HistoryDealGetDouble(m_ticket,DEAL_PROFIT));
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_SYMBOL"                             |
//+------------------------------------------------------------------+
string CDealInfo::Symbol(void) const
  {
   return(HistoryDealGetString(m_ticket,DEAL_SYMBOL));
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_COMMENT"                            |
//+------------------------------------------------------------------+
string CDealInfo::Comment(void) const
  {
   return(HistoryDealGetString(m_ticket,DEAL_COMMENT));
  }
//+------------------------------------------------------------------+
//| Get the property value "DEAL_EXTERNAL_ID"                        |
//+------------------------------------------------------------------+
string CDealInfo::ExternalId(void) const
  {
   return(HistoryDealGetString(m_ticket,DEAL_EXTERNAL_ID));
  }
//+------------------------------------------------------------------+
//| Access functions HistoryDealGetInteger(...)                      |
//+------------------------------------------------------------------+
bool CDealInfo::InfoInteger(ENUM_DEAL_PROPERTY_INTEGER prop_id,long &var) const
  {
   return(HistoryDealGetInteger(m_ticket,prop_id,var));
  }
//+------------------------------------------------------------------+
//| Access functions HistoryDealGetDouble(...)                       |
//+------------------------------------------------------------------+
bool CDealInfo::InfoDouble(ENUM_DEAL_PROPERTY_DOUBLE prop_id,double &var) const
  {
   return(HistoryDealGetDouble(m_ticket,prop_id,var));
  }
//+------------------------------------------------------------------+
//| Access functions HistoryDealGetString(...)                       |
//+------------------------------------------------------------------+
bool CDealInfo::InfoString(ENUM_DEAL_PROPERTY_STRING prop_id,string &var) const
  {
   return(HistoryDealGetString(m_ticket,prop_id,var));
  }
//+------------------------------------------------------------------+
//| Converths the type of a  deal to text                            |
//+------------------------------------------------------------------+
string CDealInfo::FormatAction(string &str,const uint action) const
  {
//--- see the type
   switch(action)
     {
      case DEAL_TYPE_BUY:
         str="buy";
         break;
      case DEAL_TYPE_SELL:
         str="sell";
         break;
      case DEAL_TYPE_BALANCE:
         str="balance";
         break;
      case DEAL_TYPE_CREDIT:
         str="credit";
         break;
      case DEAL_TYPE_CHARGE:
         str="charge";
         break;
      case DEAL_TYPE_CORRECTION:
         str="correction";
         break;
      case DEAL_TYPE_BONUS:
         str="bonus";
         break;
      case DEAL_TYPE_COMMISSION:
         str="commission";
         break;
      case DEAL_TYPE_COMMISSION_DAILY:
         str="daily commission";
         break;
      case DEAL_TYPE_COMMISSION_MONTHLY:
         str="monthly commission";
         break;
      case DEAL_TYPE_COMMISSION_AGENT_DAILY:
         str="daily agent commission";
         break;
      case DEAL_TYPE_COMMISSION_AGENT_MONTHLY:
         str="monthly agent commission";
         break;
      case DEAL_TYPE_INTEREST:
         str="interest rate";
         break;
      case DEAL_TYPE_BUY_CANCELED:
         str="canceled buy";
         break;
      case DEAL_TYPE_SELL_CANCELED:
         str="canceled sell";
         break;
      default:
         str="unknown deal type "+(string)action;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the deal direction to text                              |
//+------------------------------------------------------------------+
string CDealInfo::FormatEntry(string &str,const uint entry) const
  {
//--- see the type
   switch(entry)
     {
      case DEAL_ENTRY_IN:
         str="in";
         break;
      case DEAL_ENTRY_OUT:
         str="out";
         break;
      case DEAL_ENTRY_INOUT:
         str="in/out";
         break;
      case DEAL_ENTRY_OUT_BY:
         str="out by";
         break;
      default:
         str="unknown deal entry "+(string)entry;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the deal parameters to text                             |
//+------------------------------------------------------------------+
string CDealInfo::FormatDeal(string &str) const
  {
   string type;
   long   tmp_long;
//--- set up
   string symbol_name=this.Symbol();
   int    digits=_Digits;
   if(SymbolInfoInteger(symbol_name,SYMBOL_DIGITS,tmp_long))
      digits=(int)tmp_long;
//--- form the description of the deal
   switch(DealType())
     {
      //--- Buy-Sell
      case DEAL_TYPE_BUY:
      case DEAL_TYPE_SELL:
         str=StringFormat("#%I64u %s %s %s at %s",
                          Ticket(),
                          FormatAction(type,DealType()),
                          DoubleToString(Volume(),2),
                          symbol_name,
                          DoubleToString(Price(),digits));
         break;

      //--- balance operations
      case DEAL_TYPE_BALANCE:
      case DEAL_TYPE_CREDIT:
      case DEAL_TYPE_CHARGE:
      case DEAL_TYPE_CORRECTION:
      case DEAL_TYPE_BONUS:
      case DEAL_TYPE_COMMISSION:
      case DEAL_TYPE_COMMISSION_DAILY:
      case DEAL_TYPE_COMMISSION_MONTHLY:
      case DEAL_TYPE_COMMISSION_AGENT_DAILY:
      case DEAL_TYPE_COMMISSION_AGENT_MONTHLY:
      case DEAL_TYPE_INTEREST:
         str=StringFormat("#%I64u %s %s [%s]",
                          Ticket(),
                          FormatAction(type,DealType()),
                          DoubleToString(Profit(),2),
                          this.Comment());
         break;

      default:
         str="unknown deal type "+(string)DealType();
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Select a deal on the index                                       |
//+------------------------------------------------------------------+
bool CDealInfo::SelectByIndex(const int index)
  {
   ulong ticket=HistoryDealGetTicket(index);
   if(ticket==0)
      return(false);
   Ticket(ticket);
//---
   return(true);
  }
//+------------------------------------------------------------------+

// ===== END MQL5/Include/Trade/DealInfo.mqh =====

// ===== BEGIN MQL5/Include/Trade/Trade.mqh =====
//+------------------------------------------------------------------+
//|                                                        Trade.mqh |
//|                             Copyright 2000-2026, MetaQuotes Ltd. |
//|                                                     www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| enumerations                                                     |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVELS
  {
   LOG_LEVEL_NO    =0,
   LOG_LEVEL_ERRORS=1,
   LOG_LEVEL_ALL   =2
  };
//+------------------------------------------------------------------+
//| Class CTrade.                                                    |
//| Appointment: Class trade operations.                             |
//|              Derives from class CObject.                         |
//+------------------------------------------------------------------+
class CTrade : public CObject
  {
protected:
   MqlTradeRequest   m_request;              // request data
   MqlTradeResult    m_result;               // result data
   MqlTradeCheckResult m_check_result;       // result check data
   bool              m_async_mode;           // trade mode
   ulong             m_magic;                // expert magic number
   ulong             m_deviation;            // deviation default
   ENUM_ORDER_TYPE_FILLING m_type_filling;
   ENUM_ACCOUNT_MARGIN_MODE m_margin_mode;
   //---
   ENUM_LOG_LEVELS   m_log_level;

public:
                     CTrade(void);
                    ~CTrade(void);
   //--- methods of access to protected data
   void              LogLevel(const ENUM_LOG_LEVELS log_level) { m_log_level=log_level; }
   void              Request(MqlTradeRequest &request) const;
   ENUM_TRADE_REQUEST_ACTIONS RequestAction(void)   const { return(m_request.action);       }
   string            RequestActionDescription(void) const;
   ulong             RequestMagic(void)             const { return(m_request.magic);        }
   ulong             RequestOrder(void)             const { return(m_request.order);        }
   ulong             RequestPosition(void)          const { return(m_request.position);     }
   ulong             RequestPositionBy(void)        const { return(m_request.position_by);  }
   string            RequestSymbol(void)            const { return(m_request.symbol);       }
   double            RequestVolume(void)            const { return(m_request.volume);       }
   double            RequestPrice(void)             const { return(m_request.price);        }
   double            RequestStopLimit(void)         const { return(m_request.stoplimit);    }
   double            RequestSL(void)                const { return(m_request.sl);           }
   double            RequestTP(void)                const { return(m_request.tp);           }
   ulong             RequestDeviation(void)         const { return(m_request.deviation);    }
   ENUM_ORDER_TYPE   RequestType(void)              const { return(m_request.type);         }
   string            RequestTypeDescription(void) const;
   ENUM_ORDER_TYPE_FILLING RequestTypeFilling(void) const { return(m_request.type_filling); }
   string            RequestTypeFillingDescription(void) const;
   ENUM_ORDER_TYPE_TIME RequestTypeTime(void)       const { return(m_request.type_time);    }
   string            RequestTypeTimeDescription(void) const;
   datetime          RequestExpiration(void)        const { return(m_request.expiration);   }
   string            RequestComment(void)           const { return(m_request.comment);      }
   //---
   void              Result(MqlTradeResult &result) const;
   uint              ResultRetcode(void)         const { return(m_result.retcode);          }
   string            ResultRetcodeDescription(void) const;
   int               ResultRetcodeExternal(void) const { return(m_result.retcode_external); }
   ulong             ResultDeal(void)            const { return(m_result.deal);             }
   ulong             ResultOrder(void)           const { return(m_result.order);            }
   double            ResultVolume(void)          const { return(m_result.volume);           }
   double            ResultPrice(void)           const { return(m_result.price);            }
   double            ResultBid(void)             const { return(m_result.bid);              }
   double            ResultAsk(void)             const { return(m_result.ask);              }
   string            ResultComment(void)         const { return(m_result.comment);          }
   //---
   void              CheckResult(MqlTradeCheckResult &check_result) const;
   uint              CheckResultRetcode(void)     const { return(m_check_result.retcode);      }
   string            CheckResultRetcodeDescription(void) const;
   double            CheckResultBalance(void)     const { return(m_check_result.balance);      }
   double            CheckResultEquity(void)      const { return(m_check_result.equity);       }
   double            CheckResultProfit(void)      const { return(m_check_result.profit);       }
   double            CheckResultMargin(void)      const { return(m_check_result.margin);       }
   double            CheckResultMarginFree(void)  const { return(m_check_result.margin_free);  }
   double            CheckResultMarginLevel(void) const { return(m_check_result.margin_level); }
   string            CheckResultComment(void)     const { return(m_check_result.comment);      }
   //--- trade methods
   void              SetAsyncMode(const bool mode)               { m_async_mode=mode;                }
   void              SetExpertMagicNumber(const ulong magic)     { m_magic=magic;                    }
   void              SetDeviationInPoints(const ulong deviation) { m_deviation=deviation;            }
   void              SetTypeFilling(const ENUM_ORDER_TYPE_FILLING filling) { m_type_filling=filling; }
   bool              SetTypeFillingBySymbol(const string symbol);
   void              SetMarginMode(void) { m_margin_mode=(ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE); }
   //--- methods for working with positions
   bool              PositionOpen(const string symbol,const ENUM_ORDER_TYPE order_type,const double volume,
                                  const double price,const double sl,const double tp,const string comment="");
   bool              PositionModify(const string symbol,const double sl,const double tp);
   bool              PositionModify(const ulong ticket,const double sl,const double tp);
   bool              PositionClose(const string symbol,const ulong deviation=ULONG_MAX);
   bool              PositionClose(const ulong ticket,const ulong deviation=ULONG_MAX);
   bool              PositionCloseBy(const ulong ticket,const ulong ticket_by);
   bool              PositionClosePartial(const string symbol,const double volume,const ulong deviation=ULONG_MAX);
   bool              PositionClosePartial(const ulong ticket,const double volume,const ulong deviation=ULONG_MAX);
   //--- methods for working with pending orders
   bool              OrderOpen(const string symbol,const ENUM_ORDER_TYPE order_type,const double volume,
                               const double limit_price,const double price,const double sl,const double tp,
                               ENUM_ORDER_TYPE_TIME type_time=ORDER_TIME_GTC,const datetime expiration=0,
                               const string comment="");
   bool              OrderModify(const ulong ticket,const double price,const double sl,const double tp,
                                 const ENUM_ORDER_TYPE_TIME type_time,const datetime expiration,const double stoplimit=0.0);
   bool              OrderDelete(const ulong ticket);
   //--- additions methods
   bool              Buy(const double volume,const string symbol=NULL,double price=0.0,const double sl=0.0,const double tp=0.0,const string comment="");
   bool              Sell(const double volume,const string symbol=NULL,double price=0.0,const double sl=0.0,const double tp=0.0,const string comment="");
   bool              BuyLimit(const double volume,const double price,const string symbol=NULL,const double sl=0.0,const double tp=0.0,
                              const ENUM_ORDER_TYPE_TIME type_time=ORDER_TIME_GTC,const datetime expiration=0,const string comment="");
   bool              BuyStop(const double volume,const double price,const string symbol=NULL,const double sl=0.0,const double tp=0.0,
                             const ENUM_ORDER_TYPE_TIME type_time=ORDER_TIME_GTC,const datetime expiration=0,const string comment="");
   bool              SellLimit(const double volume,const double price,const string symbol=NULL,const double sl=0.0,const double tp=0.0,
                               const ENUM_ORDER_TYPE_TIME type_time=ORDER_TIME_GTC,const datetime expiration=0,const string comment="");
   bool              SellStop(const double volume,const double price,const string symbol=NULL,const double sl=0.0,const double tp=0.0,
                              const ENUM_ORDER_TYPE_TIME type_time=ORDER_TIME_GTC,const datetime expiration=0,const string comment="");
   //--- method check
   virtual double    CheckVolume(const string symbol,double volume,double price,ENUM_ORDER_TYPE order_type);
   virtual bool      OrderCheck(const MqlTradeRequest &request,MqlTradeCheckResult &check_result);
   virtual bool      OrderSend(const MqlTradeRequest &request,MqlTradeResult &result);
   //--- info methods
   void              PrintRequest(void) const;
   void              PrintResult(void) const;
   //--- positions
   string            FormatPositionType(string &str,const uint type) const;
   //--- orders
   string            FormatOrderType(string &str,const uint type) const;
   string            FormatOrderStatus(string &str,const uint status) const;
   string            FormatOrderTypeFilling(string &str,const uint type) const;
   string            FormatOrderTypeTime(string &str,const uint type) const;
   string            FormatOrderPrice(string &str,const double price_order,const double price_trigger,const uint digits) const;
   //--- trade request
   string            FormatRequest(string &str,const MqlTradeRequest &request) const;
   string            FormatRequestResult(string &str,const MqlTradeRequest &request,const MqlTradeResult &result) const;

protected:
   bool              FillingCheck(const string symbol);
   bool              ExpirationCheck(const string symbol);
   bool              OrderTypeCheck(const string symbol);
   void              ClearStructures(void);
   bool              IsStopped(const string function);
   bool              IsHedging(void) const { return(m_margin_mode==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING); }
   //--- position select depending on netting or hedging
   bool              SelectPosition(const string symbol);
  };
//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTrade::CTrade(void) : m_async_mode(false),
                       m_magic(0),
                       m_deviation(10),
                       m_type_filling(ORDER_FILLING_FOK),
                       m_log_level(LOG_LEVEL_ERRORS)
  {
   SetMarginMode();
//--- initialize protected data
   ClearStructures();
//--- check programm mode
   if(MQLInfoInteger(ENUM_MQL_INFO_INTEGER::MQL_TESTER))
      m_log_level=LOG_LEVEL_ALL;
   if(MQLInfoInteger(ENUM_MQL_INFO_INTEGER::MQL_OPTIMIZATION))
      m_log_level=LOG_LEVEL_NO;
  }
//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTrade::~CTrade(void)
  {
  }
//+------------------------------------------------------------------+
//| Get the request structure                                        |
//+------------------------------------------------------------------+
void CTrade::Request(MqlTradeRequest &request) const
  {
   request.action      =m_request.action;
   request.magic       =m_request.magic;
   request.order       =m_request.order;
   request.symbol      =m_request.symbol;
   request.volume      =m_request.volume;
   request.price       =m_request.price;
   request.stoplimit   =m_request.stoplimit;
   request.sl          =m_request.sl;
   request.tp          =m_request.tp;
   request.deviation   =m_request.deviation;
   request.type        =m_request.type;
   request.type_filling=m_request.type_filling;
   request.type_time   =m_request.type_time;
   request.expiration  =m_request.expiration;
   request.comment     =m_request.comment;
   request.position    =m_request.position;
   request.position_by =m_request.position_by;
  }
//+------------------------------------------------------------------+
//| Get the trade action as string                                   |
//+------------------------------------------------------------------+
string CTrade::RequestActionDescription(void) const
  {
   string str;
//---
   FormatRequest(str,m_request);
//---
   return(str);
  }
//+------------------------------------------------------------------+
//| Get the order type as string                                     |
//+------------------------------------------------------------------+
string CTrade::RequestTypeDescription(void) const
  {
   string str;
//---
   FormatOrderType(str,(uint)m_request.order);
//---
   return(str);
  }
//+------------------------------------------------------------------+
//| Get the order type filling as string                             |
//+------------------------------------------------------------------+
string CTrade::RequestTypeFillingDescription(void) const
  {
   string str;
//---
   FormatOrderTypeFilling(str,m_request.type_filling);
//---
   return(str);
  }
//+------------------------------------------------------------------+
//| Get the order type time as string                                |
//+------------------------------------------------------------------+
string CTrade::RequestTypeTimeDescription(void) const
  {
   string str;
//---
   FormatOrderTypeTime(str,m_request.type_time);
//---
   return(str);
  }
//+------------------------------------------------------------------+
//| Get the result structure                                         |
//+------------------------------------------------------------------+
void CTrade::Result(MqlTradeResult &result) const
  {
   result.retcode   =m_result.retcode;
   result.deal      =m_result.deal;
   result.order     =m_result.order;
   result.volume    =m_result.volume;
   result.price     =m_result.price;
   result.bid       =m_result.bid;
   result.ask       =m_result.ask;
   result.comment   =m_result.comment;
   result.request_id=m_result.request_id;
   result.retcode_external=m_result.retcode_external;
  }
//+------------------------------------------------------------------+
//| Get the retcode value as string                                  |
//+------------------------------------------------------------------+
string CTrade::ResultRetcodeDescription(void) const
  {
   string str;
//---
   FormatRequestResult(str,m_request,m_result);
//---
   return(str);
  }
//+------------------------------------------------------------------+
//| Get the check result structure                                   |
//+------------------------------------------------------------------+
void CTrade::CheckResult(MqlTradeCheckResult &check_result) const
  {
//--- copy structure
   check_result.retcode     =m_check_result.retcode;
   check_result.balance     =m_check_result.balance;
   check_result.equity      =m_check_result.equity;
   check_result.profit      =m_check_result.profit;
   check_result.margin      =m_check_result.margin;
   check_result.margin_free =m_check_result.margin_free;
   check_result.margin_level=m_check_result.margin_level;
   check_result.comment     =m_check_result.comment;
  }
//+------------------------------------------------------------------+
//| Get the check retcode value as string                            |
//+------------------------------------------------------------------+
string CTrade::CheckResultRetcodeDescription(void) const
  {
   string         str;
   MqlTradeResult result;
//---
   result.retcode=m_check_result.retcode;
   FormatRequestResult(str,m_request,result);
//---
   return(str);
  }
//+------------------------------------------------------------------+
//| Open position                                                    |
//+------------------------------------------------------------------+
bool CTrade::PositionOpen(const string symbol,const ENUM_ORDER_TYPE order_type,const double volume,
                          const double price,const double sl,const double tp,const string comment)
  {
//--- check stopped
   if(IsStopped(__FUNCTION__))
      return(false);
//--- clean
   ClearStructures();
//--- check
   if(order_type!=ORDER_TYPE_BUY && order_type!=ORDER_TYPE_SELL)
     {
      m_result.retcode=TRADE_RETCODE_INVALID;
      m_result.comment="Invalid order type";
      return(false);
     }
//--- setting request
   m_request.action   =TRADE_ACTION_DEAL;
   m_request.symbol   =symbol;
   m_request.magic    =m_magic;
   m_request.volume   =volume;
   m_request.type     =order_type;
   m_request.price    =price;
   m_request.sl       =sl;
   m_request.tp       =tp;
   m_request.deviation=m_deviation;
//--- check order type
   if(!OrderTypeCheck(symbol))
      return(false);
//--- check filling
   if(!FillingCheck(symbol))
      return(false);
   m_request.comment=comment;
//--- action and return the result
   return(OrderSend(m_request,m_result));
  }
//+------------------------------------------------------------------+
//| Modify specified opened position                                 |
//+------------------------------------------------------------------+
bool CTrade::PositionModify(const string symbol,const double sl,const double tp)
  {
//--- check stopped
   if(IsStopped(__FUNCTION__))
      return(false);
//--- check position existence
   if(!SelectPosition(symbol))
      return(false);
//--- clean
   ClearStructures();
//--- setting request
   m_request.action  =TRADE_ACTION_SLTP;
   m_request.symbol  =symbol;
   m_request.magic   =m_magic;
   m_request.sl      =sl;
   m_request.tp      =tp;
   m_request.position=PositionGetInteger(POSITION_TICKET);
//--- action and return the result
   return(OrderSend(m_request,m_result));
  }
//+------------------------------------------------------------------+
//| Modify specified opened position                                 |
//+------------------------------------------------------------------+
bool CTrade::PositionModify(const ulong ticket,const double sl,const double tp)
  {
//--- check stopped
   if(IsStopped(__FUNCTION__))
      return(false);
//--- check position existence
   if(!PositionSelectByTicket(ticket))
      return(false);
//--- clean
   ClearStructures();
//--- setting request
   m_request.action  =TRADE_ACTION_SLTP;
   m_request.position=ticket;
   m_request.symbol  =PositionGetString(POSITION_SYMBOL);
   m_request.magic   =m_magic;
   m_request.sl      =sl;
   m_request.tp      =tp;
//--- action and return the result
   return(OrderSend(m_request,m_result));
  }
//+------------------------------------------------------------------+
//| Close specified opened position                                  |
//+------------------------------------------------------------------+
bool CTrade::PositionClose(const string symbol,const ulong deviation)
  {
   bool partial_close=false;
   int  retry_count  =10;
   uint retcode      =TRADE_RETCODE_REJECT;
//--- check stopped
   if(IsStopped(__FUNCTION__))
      return(false);
//--- clean
   ClearStructures();
//--- check filling
   if(!FillingCheck(symbol))
      return(false);
   do
     {
      //--- check
      if(SelectPosition(symbol))
        {
         if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
           {
            //--- prepare request for close BUY position
            m_request.type =ORDER_TYPE_SELL;
            m_request.price=SymbolInfoDouble(symbol,SYMBOL_BID);
           }
         else
           {
            //--- prepare request for close SELL position
            m_request.type =ORDER_TYPE_BUY;
            m_request.price=SymbolInfoDouble(symbol,SYMBOL_ASK);
           }
        }
      else
        {
         //--- position not found
         m_result.retcode=retcode;
         return(false);
        }
      //--- setting request
      m_request.action   =TRADE_ACTION_DEAL;
      m_request.symbol   =symbol;
      m_request.volume   =PositionGetDouble(POSITION_VOLUME);
      m_request.magic    =m_magic;
      m_request.deviation=(deviation==ULONG_MAX) ? m_deviation : deviation;
      m_request.position =PositionGetInteger(POSITION_TICKET);
      //--- check volume
      double max_volume=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
      if(m_request.volume>max_volume)
        {
         m_request.volume=max_volume;
         partial_close=true;
        }
      else
         partial_close=false;
      //--- hedging? just send order
      if(IsHedging())
         return(OrderSend(m_request,m_result));
      //--- order send
      if(!OrderSend(m_request,m_result))
        {
         if(--retry_count!=0)
            continue;
         if(retcode==TRADE_RETCODE_DONE_PARTIAL)
            m_result.retcode=retcode;
         return(false);
        }
      //--- WARNING. If position volume exceeds the maximum volume allowed for deal,
      //--- and when the asynchronous trade mode is on, for safety reasons, position is closed not completely,
      //--- but partially. It is decreased by the maximum volume allowed for deal.
      if(m_async_mode)
         break;
      retcode=TRADE_RETCODE_DONE_PARTIAL;
      if(partial_close)
         Sleep(1000);
     }
   while(partial_close);
//--- succeed
   return(true);
  }
//+------------------------------------------------------------------+
//| Close specified opened position                                  |
//+------------------------------------------------------------------+
bool CTrade::PositionClose(const ulong ticket,const ulong deviation)
  {
//--- check stopped
   if(IsStopped(__FUNCTION__))
      return(false);
//--- check position existence
   if(!PositionSelectByTicket(ticket))
      return(false);
   string symbol=PositionGetString(POSITION_SYMBOL);
//--- clean
   ClearStructures();
//--- check filling
   if(!FillingCheck(symbol))
      return(false);
//--- check
   if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
     {
      //--- prepare request for close BUY position
      m_request.type =ORDER_TYPE_SELL;
      m_request.price=SymbolInfoDouble(symbol,SYMBOL_BID);
     }
   else
     {
      //--- prepare request for close SELL position
      m_request.type =ORDER_TYPE_BUY;
      m_request.price=SymbolInfoDouble(symbol,SYMBOL_ASK);
     }
//--- setting request
   m_request.action   =TRADE_ACTION_DEAL;
   m_request.position =ticket;
   m_request.symbol   =symbol;
   m_request.volume   =PositionGetDouble(POSITION_VOLUME);
   m_request.magic    =m_magic;
   m_request.deviation=(deviation==ULONG_MAX) ? m_deviation : deviation;
//--- close position
   return(OrderSend(m_request,m_result));
  }
//+------------------------------------------------------------------+
//| Close one position by other                                      |
//+------------------------------------------------------------------+
bool CTrade::PositionCloseBy(const ulong ticket,const ulong ticket_by)
  {
//--- check stopped
   if(IsStopped(__FUNCTION__))
      return(false);
//--- check hedging mode
   if(!IsHedging())
      return(false);
//--- check position existence
   if(!PositionSelectByTicket(ticket))
      return(false);
   string symbol=PositionGetString(POSITION_SYMBOL);
   ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(!PositionSelectByTicket(ticket_by))
      return(false);
   string symbol_by=PositionGetString(POSITION_SYMBOL);
   ENUM_POSITION_TYPE type_by=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
//--- check positions
   if(type==type_by)
      return(false);
   if(symbol!=symbol_by)
      return(false);
//--- clean
   ClearStructures();
//--- check filling
   if(!FillingCheck(symbol))
      return(false);
//--- setting request
   m_request.action     =TRADE_ACTION_CLOSE_BY;
   m_request.position   =ticket;
   m_request.position_by=ticket_by;
   m_request.magic      =m_magic;
//--- close position
   return(OrderSend(m_request,m_result));
  }
//+------------------------------------------------------------------+
//| Partial close specified opened position (for hedging mode only)  |
//+------------------------------------------------------------------+
bool CTrade::PositionClosePartial(const string symbol,const double volume,const ulong deviation)
  {
   uint retcode=TRADE_RETCODE_REJECT;
//--- check stopped
   if(IsStopped(__FUNCTION__))
      return(false);
//--- for hedging mode only
   if(!IsHedging())
      return(false);
//--- clean
   ClearStructures();
//--- check filling
   if(!FillingCheck(symbol))
      return(false);
//--- check
   if(SelectPosition(symbol))
     {
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
        {
         //--- prepare request for close BUY position
         m_request.type =ORDER_TYPE_SELL;
         m_request.price=SymbolInfoDouble(symbol,SYMBOL_BID);
        }
      else
        {
         //--- prepare request for close SELL position
         m_request.type =ORDER_TYPE_BUY;
         m_request.price=SymbolInfoDouble(symbol,SYMBOL_ASK);
        }
     }
   else
     {
      //--- position not found
      m_result.retcode=retcode;
      return(false);
     }
//--- check volume
   double position_volume=PositionGetDouble(POSITION_VOLUME);
   if(position_volume>volume)
      position_volume=volume;
//--- setting request
   m_request.action   =TRADE_ACTION_DEAL;
   m_request.symbol   =symbol;
   m_request.volume   =position_volume;
   m_request.magic    =m_magic;
   m_request.deviation=(deviation==ULONG_MAX) ? m_deviation : deviation;
   m_request.position =PositionGetInteger(POSITION_TICKET);
//--- hedging? just send order
   return(OrderSend(m_request,m_result));
  }
//+------------------------------------------------------------------+
//| Partial close specified opened position (for hedging mode only)  |
//+------------------------------------------------------------------+
bool CTrade::PositionClosePartial(const ulong ticket,const double volume,const ulong deviation)
  {
//--- check stopped
   if(IsStopped(__FUNCTION__))
      return(false);
//--- for hedging mode only
   if(!IsHedging())
      return(false);
//--- check position existence
   if(!PositionSelectByTicket(ticket))
      return(false);
   string symbol=PositionGetString(POSITION_SYMBOL);
//--- clean
   ClearStructures();
//--- check filling
   if(!FillingCheck(symbol))
      return(false);
//--- check
   if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
     {
      //--- prepare request for close BUY position
      m_request.type =ORDER_TYPE_SELL;
      m_request.price=SymbolInfoDouble(symbol,SYMBOL_BID);
     }
   else
     {
      //--- prepare request for close SELL position
      m_request.type =ORDER_TYPE_BUY;
      m_request.price=SymbolInfoDouble(symbol,SYMBOL_ASK);
     }
//--- check volume
   double position_volume=PositionGetDouble(POSITION_VOLUME);
   if(position_volume>volume)
      position_volume=volume;
//--- setting request
   m_request.action   =TRADE_ACTION_DEAL;
   m_request.position =ticket;
   m_request.symbol   =symbol;
   m_request.volume   =position_volume;
   m_request.magic    =m_magic;
   m_request.deviation=(deviation==ULONG_MAX) ? m_deviation : deviation;
//--- close position
   return(OrderSend(m_request,m_result));
  }
//+------------------------------------------------------------------+
//| Installation pending order                                       |
//+------------------------------------------------------------------+
bool CTrade::OrderOpen(const string symbol,const ENUM_ORDER_TYPE order_type,const double volume,const double limit_price,
                       const double price,const double sl,const double tp,
                       ENUM_ORDER_TYPE_TIME type_time,const datetime expiration,const string comment)
  {
//--- check stopped
   if(IsStopped(__FUNCTION__))
      return(false);
//--- clean
   ClearStructures();
//--- check filling
   if(!FillingCheck(symbol))
      return(false);
//--- check order type
   if(order_type==ORDER_TYPE_BUY || order_type==ORDER_TYPE_SELL)
     {
      m_result.retcode=TRADE_RETCODE_INVALID;
      m_result.comment="Invalid order type";
      return(false);
     }
//--- check order expiration
   if(type_time==ORDER_TIME_GTC && expiration==0)
     {
      int exp=(int)SymbolInfoInteger(symbol,SYMBOL_EXPIRATION_MODE);
      if((exp&SYMBOL_EXPIRATION_GTC)!=SYMBOL_EXPIRATION_GTC)
        {
         //--- if you place order for an unlimited time and if placing of such orders is prohibited
         //--- try to place order with expiration at the end of the day
         if((exp&SYMBOL_EXPIRATION_DAY)!=SYMBOL_EXPIRATION_DAY)
           {
            //--- if even this is not possible - error
            Print(__FUNCTION__,": Error: Unable to place order without explicitly specified expiration time");
            m_result.retcode=TRADE_RETCODE_INVALID_EXPIRATION;
            m_result.comment="Invalid expiration type";
            return(false);
           }
         type_time=ORDER_TIME_DAY;
        }
     }
//--- setting request
   m_request.action      =TRADE_ACTION_PENDING;
   m_request.symbol      =symbol;
   m_request.magic       =m_magic;
   m_request.volume      =volume;
   m_request.type        =order_type;
   m_request.stoplimit   =limit_price;
   m_request.price       =price;
   m_request.sl          =sl;
   m_request.tp          =tp;
   m_request.type_time   =type_time;
   m_request.expiration  =expiration;
//--- check order type
   if(!OrderTypeCheck(symbol))
      return(false);
//--- check filling
   if(!FillingCheck(symbol))
     {
      m_result.retcode=TRADE_RETCODE_INVALID_FILL;
      Print(__FUNCTION__+": Invalid filling type");
      return(false);
     }
//--- check expiration
   if(!ExpirationCheck(symbol))
     {
      m_result.retcode=TRADE_RETCODE_INVALID_EXPIRATION;
      Print(__FUNCTION__+": Invalid expiration type");
      return(false);
     }
   m_request.comment=comment;
//--- action and return the result
   return(OrderSend(m_request,m_result));
  }
//+------------------------------------------------------------------+
//| Modify specified pending order                                   |
//+------------------------------------------------------------------+
bool CTrade::OrderModify(const ulong ticket,const double price,const double sl,const double tp,
                         const ENUM_ORDER_TYPE_TIME type_time,const datetime expiration,const double stoplimit)
  {
//--- check stopped
   if(IsStopped(__FUNCTION__))
      return(false);
//--- check order existence
   if(!OrderSelect(ticket))
      return(false);
//--- clean
   ClearStructures();
//--- setting request
   m_request.symbol      =OrderGetString(ORDER_SYMBOL);
   m_request.action      =TRADE_ACTION_MODIFY;
   m_request.magic       =m_magic;
   m_request.order       =ticket;
   m_request.price       =price;
   m_request.stoplimit   =stoplimit;
   m_request.sl          =sl;
   m_request.tp          =tp;
   m_request.type_time   =type_time;
   m_request.expiration  =expiration;
//--- action and return the result
   return(OrderSend(m_request,m_result));
  }
//+------------------------------------------------------------------+
//| Delete specified pending order                                   |
//+------------------------------------------------------------------+
bool CTrade::OrderDelete(const ulong ticket)
  {
//--- check stopped
   if(IsStopped(__FUNCTION__))
      return(false);
//--- clean
   ClearStructures();
//--- setting request
   m_request.action    =TRADE_ACTION_REMOVE;
   m_request.magic     =m_magic;
   m_request.order     =ticket;
//--- action and return the result
   return(OrderSend(m_request,m_result));
  }
//+------------------------------------------------------------------+
//| Output full information of request to log                        |
//+------------------------------------------------------------------+
void CTrade::PrintRequest(void) const
  {
   if(m_log_level<LOG_LEVEL_ALL)
      return;
//---
   string str;
   PrintFormat("%s",FormatRequest(str,m_request));
  }
//+------------------------------------------------------------------+
//| Output full information of result to log                         |
//+------------------------------------------------------------------+
void CTrade::PrintResult(void) const
  {
   if(m_log_level<LOG_LEVEL_ALL)
      return;
//---
   string str;
   PrintFormat("%s",FormatRequestResult(str,m_request,m_result));
  }
//+------------------------------------------------------------------+
//| Clear structures m_request,m_result and m_check_result           |
//+------------------------------------------------------------------+
void CTrade::ClearStructures(void)
  {
   ZeroMemory(m_request);
   ZeroMemory(m_result);
   ZeroMemory(m_check_result);
  }
//+------------------------------------------------------------------+
//| Checks forced shutdown of MQL5-program                           |
//+------------------------------------------------------------------+
bool CTrade::IsStopped(const string function)
  {
   if(!::IsStopped())
      return(false);
//--- MQL5 program is stopped
   PrintFormat("%s: MQL5 program is stopped. Trading is disabled",function);
   m_result.retcode=TRADE_RETCODE_CLIENT_DISABLES_AT;
   return(true);
  }
//+------------------------------------------------------------------+
//| Buy operation                                                    |
//+------------------------------------------------------------------+
bool CTrade::Buy(const double volume,const string symbol=NULL,double price=0.0,const double sl=0.0,const double tp=0.0,const string comment="")
  {
//--- check volume
   if(volume<=0.0)
     {
      m_result.retcode=TRADE_RETCODE_INVALID_VOLUME;
      return(false);
     }
//--- check symbol
   string symbol_name=(symbol==NULL) ? _Symbol : symbol;
//--- check price
   if(price==0.0)
      price=SymbolInfoDouble(symbol_name,SYMBOL_ASK);
//---
   return(PositionOpen(symbol_name,ORDER_TYPE_BUY,volume,price,sl,tp,comment));
  }
//+------------------------------------------------------------------+
//| Sell operation                                                   |
//+------------------------------------------------------------------+
bool CTrade::Sell(const double volume,const string symbol=NULL,double price=0.0,const double sl=0.0,const double tp=0.0,const string comment="")
  {
//--- check volume
   if(volume<=0.0)
     {
      m_result.retcode=TRADE_RETCODE_INVALID_VOLUME;
      return(false);
     }
//--- check symbol
   string symbol_name=(symbol==NULL) ? _Symbol : symbol;
//--- check price
   if(price==0.0)
      price=SymbolInfoDouble(symbol_name,SYMBOL_BID);
//---
   return(PositionOpen(symbol_name,ORDER_TYPE_SELL,volume,price,sl,tp,comment));
  }
//+------------------------------------------------------------------+
//| Send BUY_LIMIT order                                             |
//+------------------------------------------------------------------+
bool CTrade::BuyLimit(const double volume,const double price,const string symbol=NULL,const double sl=0.0,const double tp=0.0,
                      const ENUM_ORDER_TYPE_TIME type_time=ORDER_TIME_GTC,const datetime expiration=0,const string comment="")
  {
   string symbol_name;
//--- check volume
   if(volume<=0.0)
     {
      m_result.retcode=TRADE_RETCODE_INVALID_VOLUME;
      return(false);
     }
//--- check symbol
   symbol_name=(symbol==NULL)?Symbol():symbol;
//--- send "BUY_LIMIT" order
   return(OrderOpen(symbol_name,ORDER_TYPE_BUY_LIMIT,volume,0.0,price,sl,tp,type_time,expiration,comment));
  }
//+------------------------------------------------------------------+
//| Send BUY_STOP order                                              |
//+------------------------------------------------------------------+
bool CTrade::BuyStop(const double volume,const double price,const string symbol=NULL,const double sl=0.0,const double tp=0.0,
                     const ENUM_ORDER_TYPE_TIME type_time=ORDER_TIME_GTC,const datetime expiration=0,const string comment="")
  {
   string symbol_name;
//--- check volume
   if(volume<=0.0)
     {
      m_result.retcode=TRADE_RETCODE_INVALID_VOLUME;
      return(false);
     }
//--- check symbol
   symbol_name=(symbol==NULL)?Symbol():symbol;
//--- send "BUY_STOP" order
   return(OrderOpen(symbol_name,ORDER_TYPE_BUY_STOP,volume,0.0,price,sl,tp,type_time,expiration,comment));
  }
//+------------------------------------------------------------------+
//| Send SELL_LIMIT order                                            |
//+------------------------------------------------------------------+
bool CTrade::SellLimit(const double volume,const double price,const string symbol=NULL,const double sl=0.0,const double tp=0.0,
                       const ENUM_ORDER_TYPE_TIME type_time=ORDER_TIME_GTC,const datetime expiration=0,const string comment="")
  {
   string symbol_name;
//--- check volume
   if(volume<=0.0)
     {
      m_result.retcode=TRADE_RETCODE_INVALID_VOLUME;
      return(false);
     }
//--- check symbol
   symbol_name=(symbol==NULL)?Symbol():symbol;
//--- send "SELL_LIMIT" order
   return(OrderOpen(symbol_name,ORDER_TYPE_SELL_LIMIT,volume,0.0,price,sl,tp,type_time,expiration,comment));
  }
//+------------------------------------------------------------------+
//| Send SELL_STOP order                                             |
//+------------------------------------------------------------------+
bool CTrade::SellStop(const double volume,const double price,const string symbol=NULL,const double sl=0.0,const double tp=0.0,
                      const ENUM_ORDER_TYPE_TIME type_time=ORDER_TIME_GTC,const datetime expiration=0,const string comment="")
  {
   string symbol_name;
//--- check volume
   if(volume<=0.0)
     {
      m_result.retcode=TRADE_RETCODE_INVALID_VOLUME;
      return(false);
     }
//--- check symbol
   symbol_name=(symbol==NULL)?Symbol():symbol;
//--- send "SELL_STOP" order
   return(OrderOpen(symbol_name,ORDER_TYPE_SELL_STOP,volume,0.0,price,sl,tp,type_time,expiration,comment));
  }
//+------------------------------------------------------------------+
//| Converts the position type to text                               |
//+------------------------------------------------------------------+
string CTrade::FormatPositionType(string &str,const uint type) const
  {
//--- see the type
   switch(type)
     {
      case POSITION_TYPE_BUY:
         str="buy";
         break;
      case POSITION_TYPE_SELL:
         str="sell";
         break;
      default:
         str="unknown position type "+(string)type;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the order type to text                                  |
//+------------------------------------------------------------------+
string CTrade::FormatOrderType(string &str,const uint type) const
  {
//--- see the type
   switch(type)
     {
      case ORDER_TYPE_BUY:
         str="buy";
         break;
      case ORDER_TYPE_SELL:
         str="sell";
         break;
      case ORDER_TYPE_BUY_LIMIT:
         str="buy limit";
         break;
      case ORDER_TYPE_SELL_LIMIT:
         str="sell limit";
         break;
      case ORDER_TYPE_BUY_STOP:
         str="buy stop";
         break;
      case ORDER_TYPE_SELL_STOP:
         str="sell stop";
         break;
      case ORDER_TYPE_BUY_STOP_LIMIT:
         str="buy stop limit";
         break;
      case ORDER_TYPE_SELL_STOP_LIMIT:
         str="sell stop limit";
         break;
      default:
         str="unknown order type "+(string)type;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the order filling type to text                          |
//+------------------------------------------------------------------+
string CTrade::FormatOrderTypeFilling(string &str,const uint type) const
  {
//--- see the type
   switch(type)
     {
      case ORDER_FILLING_RETURN:
         str="return remainder";
         break;
      case ORDER_FILLING_IOC:
         str="cancel remainder";
         break;
      case ORDER_FILLING_FOK:
         str="fill or kill";
         break;
      default:
         str="unknown type filling "+(string)type;
         break;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the type of order by expiration to text                 |
//+------------------------------------------------------------------+
string CTrade::FormatOrderTypeTime(string &str,const uint type) const
  {
//--- see the type
   switch(type)
     {
      case ORDER_TIME_GTC:
         str="gtc";
         break;
      case ORDER_TIME_DAY:
         str="day";
         break;
      case ORDER_TIME_SPECIFIED:
         str="specified";
         break;
      case ORDER_TIME_SPECIFIED_DAY:
         str="specified day";
         break;
      default:
         str="unknown type time "+(string)type;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the order prices to text                                |
//+------------------------------------------------------------------+
string CTrade::FormatOrderPrice(string &str,const double price_order,const double price_trigger,const uint digits) const
  {
   string price,trigger;
//--- Is there its trigger price?
   if(price_trigger)
     {
      price  =DoubleToString(price_order,digits);
      trigger=DoubleToString(price_trigger,digits);
      str    =StringFormat("%s (%s)",price,trigger);
     }
   else
      str=DoubleToString(price_order,digits);
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the parameters of a trade request to text               |
//+------------------------------------------------------------------+
string CTrade::FormatRequest(string &str,const MqlTradeRequest &request) const
  {
   string type,price,price_new;
   string tmp_string;
   long   tmp_long;
//--- clean
   str="";
//--- set up
   string symbol_name=(request.symbol==NULL) ? _Symbol : request.symbol;
   int    digits=_Digits;
   ENUM_SYMBOL_TRADE_EXECUTION trade_execution=0;
   if(SymbolInfoInteger(symbol_name,SYMBOL_DIGITS,tmp_long))
      digits=(int)tmp_long;
   if(SymbolInfoInteger(symbol_name,SYMBOL_TRADE_EXEMODE,tmp_long))
      trade_execution=(ENUM_SYMBOL_TRADE_EXECUTION)tmp_long;
//--- see what is wanted
   switch(request.action)
     {
      //--- instant execution of a deal
      case TRADE_ACTION_DEAL:
         switch(trade_execution)
           {
            //--- request execution
            case SYMBOL_TRADE_EXECUTION_REQUEST:
               if(IsHedging() && request.position!=0)
                  str=StringFormat("request %s %s position #%I64u %s at %s",
                                   FormatOrderType(type,request.type),
                                   DoubleToString(request.volume,2),
                                   request.position,
                                   request.symbol,
                                   DoubleToString(request.price,digits));
               else
                  str=StringFormat("request %s %s %s at %s",
                                   FormatOrderType(type,request.type),
                                   DoubleToString(request.volume,2),
                                   request.symbol,
                                   DoubleToString(request.price,digits));
               //--- Is there SL or TP?
               if(request.sl!=0.0)
                 {
                  tmp_string=StringFormat(" sl: %s",DoubleToString(request.sl,digits));
                  str+=tmp_string;
                 }
               if(request.tp!=0.0)
                 {
                  tmp_string=StringFormat(" tp: %s",DoubleToString(request.tp,digits));
                  str+=tmp_string;
                 }
               break;
            //--- instant execution
            case SYMBOL_TRADE_EXECUTION_INSTANT:
               if(IsHedging() && request.position!=0)
                  str=StringFormat("instant %s %s position #%I64u %s at %s",
                                   FormatOrderType(type,request.type),
                                   DoubleToString(request.volume,2),
                                   request.position,
                                   request.symbol,
                                   DoubleToString(request.price,digits));
               else
                  str=StringFormat("instant %s %s %s at %s",
                                   FormatOrderType(type,request.type),
                                   DoubleToString(request.volume,2),
                                   request.symbol,
                                   DoubleToString(request.price,digits));
               //--- Is there SL or TP?
               if(request.sl!=0.0)
                 {
                  tmp_string=StringFormat(" sl: %s",DoubleToString(request.sl,digits));
                  str+=tmp_string;
                 }
               if(request.tp!=0.0)
                 {
                  tmp_string=StringFormat(" tp: %s",DoubleToString(request.tp,digits));
                  str+=tmp_string;
                 }
               break;
            //--- market execution
            case SYMBOL_TRADE_EXECUTION_MARKET:
               if(IsHedging() && request.position!=0)
                  str=StringFormat("market %s %s position #%I64u %s",
                                   FormatOrderType(type,request.type),
                                   DoubleToString(request.volume,2),
                                   request.position,
                                   request.symbol);
               else
                  str=StringFormat("market %s %s %s",
                                   FormatOrderType(type,request.type),
                                   DoubleToString(request.volume,2),
                                   request.symbol);
               //--- Is there SL or TP?
               if(request.sl!=0.0)
                 {
                  tmp_string=StringFormat(" sl: %s",DoubleToString(request.sl,digits));
                  str+=tmp_string;
                 }
               if(request.tp!=0.0)
                 {
                  tmp_string=StringFormat(" tp: %s",DoubleToString(request.tp,digits));
                  str+=tmp_string;
                 }
               break;
            //--- exchange execution
            case SYMBOL_TRADE_EXECUTION_EXCHANGE:
               if(IsHedging() && request.position!=0)
                  str=StringFormat("exchange %s %s position #%I64u %s",
                                   FormatOrderType(type,request.type),
                                   DoubleToString(request.volume,2),
                                   request.position,
                                   request.symbol);
               else
                  str=StringFormat("exchange %s %s %s",
                                   FormatOrderType(type,request.type),
                                   DoubleToString(request.volume,2),
                                   request.symbol);
               //--- Is there SL or TP?
               if(request.sl!=0.0)
                 {
                  tmp_string=StringFormat(" sl: %s",DoubleToString(request.sl,digits));
                  str+=tmp_string;
                 }
               if(request.tp!=0.0)
                 {
                  tmp_string=StringFormat(" tp: %s",DoubleToString(request.tp,digits));
                  str+=tmp_string;
                 }
               break;
           }
         //--- end of TRADE_ACTION_DEAL processing
         break;

      //--- setting a pending order
      case TRADE_ACTION_PENDING:
         str=StringFormat("%s %s %s at %s",
                          FormatOrderType(type,request.type),
                          DoubleToString(request.volume,2),
                          request.symbol,
                          FormatOrderPrice(price,request.price,request.stoplimit,digits));
         //--- Is there SL or TP?
         if(request.sl!=0.0)
           {
            tmp_string=StringFormat(" sl: %s",DoubleToString(request.sl,digits));
            str+=tmp_string;
           }
         if(request.tp!=0.0)
           {
            tmp_string=StringFormat(" tp: %s",DoubleToString(request.tp,digits));
            str+=tmp_string;
           }
         break;

      //--- Setting SL/TP
      case TRADE_ACTION_SLTP:
         if(IsHedging() && request.position!=0)
            str=StringFormat("modify position #%I64u %s (sl: %s, tp: %s)",
                             request.position,
                             request.symbol,
                             DoubleToString(request.sl,digits),
                             DoubleToString(request.tp,digits));
         else
            str=StringFormat("modify %s (sl: %s, tp: %s)",
                             request.symbol,
                             DoubleToString(request.sl,digits),
                             DoubleToString(request.tp,digits));
         break;

      //--- modifying a pending order
      case TRADE_ACTION_MODIFY:
         str=StringFormat("modify #%I64u at %s (sl: %s tp: %s)",
                          request.order,
                          FormatOrderPrice(price_new,request.price,request.stoplimit,digits),
                          DoubleToString(request.sl,digits),
                          DoubleToString(request.tp,digits));
         break;

      //--- deleting a pending order
      case TRADE_ACTION_REMOVE:
         str=StringFormat("cancel #%I64u",request.order);
         break;

      //--- close by
      case TRADE_ACTION_CLOSE_BY:
         if(IsHedging() && request.position!=0)
            str=StringFormat("close position #%I64u by #%I64u",request.position,request.position_by);
         else
            str=StringFormat("wrong action close by (#%I64u by #%I64u)",request.position,request.position_by);
         break;

      default:
         str="unknown action "+(string)request.action;
         break;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//| Converts the result of a request to text                         |
//+------------------------------------------------------------------+
string CTrade::FormatRequestResult(string &str,const MqlTradeRequest &request,const MqlTradeResult &result) const
  {
//--- set up
   string symbol_name=(request.symbol==NULL) ? _Symbol : request.symbol;
   int    digits=_Digits;
   long   tmp_long;
   ENUM_SYMBOL_TRADE_EXECUTION trade_execution=0;
   if(SymbolInfoInteger(symbol_name,SYMBOL_DIGITS,tmp_long))
      digits=(int)tmp_long;
   if(SymbolInfoInteger(symbol_name,SYMBOL_TRADE_EXEMODE,tmp_long))
      trade_execution=(ENUM_SYMBOL_TRADE_EXECUTION)tmp_long;
//--- see the response code
   switch(result.retcode)
     {
      case TRADE_RETCODE_REQUOTE:
         str=StringFormat("requote (%s/%s)",
                          DoubleToString(result.bid,digits),
                          DoubleToString(result.ask,digits));
         break;

      case TRADE_RETCODE_DONE:
         if(request.action==TRADE_ACTION_DEAL &&
            (trade_execution==SYMBOL_TRADE_EXECUTION_REQUEST ||
             trade_execution==SYMBOL_TRADE_EXECUTION_INSTANT ||
             trade_execution==SYMBOL_TRADE_EXECUTION_MARKET))
            str=StringFormat("done at %s",DoubleToString(result.price,digits));
         else
            str="done";
         break;

      case TRADE_RETCODE_DONE_PARTIAL:
         if(request.action==TRADE_ACTION_DEAL &&
            (trade_execution==SYMBOL_TRADE_EXECUTION_REQUEST ||
             trade_execution==SYMBOL_TRADE_EXECUTION_INSTANT ||
             trade_execution==SYMBOL_TRADE_EXECUTION_MARKET))
            str=StringFormat("done partially %s at %s",
                             DoubleToString(result.volume,2),
                             DoubleToString(result.price,digits));
         else
            str=StringFormat("done partially %s",
                             DoubleToString(result.volume,2));
         break;

      case TRADE_RETCODE_REJECT:
         str="rejected";
         break;
      case TRADE_RETCODE_CANCEL:
         str="canceled";
         break;
      case TRADE_RETCODE_PLACED:
         str="placed";
         break;
      case TRADE_RETCODE_ERROR:
         str="common error";
         break;
      case TRADE_RETCODE_TIMEOUT:
         str="timeout";
         break;
      case TRADE_RETCODE_INVALID:
         str="invalid request";
         break;
      case TRADE_RETCODE_INVALID_VOLUME:
         str="invalid volume";
         break;
      case TRADE_RETCODE_INVALID_PRICE:
         str="invalid price";
         break;
      case TRADE_RETCODE_INVALID_STOPS:
         str="invalid stops";
         break;
      case TRADE_RETCODE_TRADE_DISABLED:
         str="trade disabled";
         break;
      case TRADE_RETCODE_MARKET_CLOSED:
         str="market closed";
         break;
      case TRADE_RETCODE_NO_MONEY:
         str="not enough money";
         break;
      case TRADE_RETCODE_PRICE_CHANGED:
         str="price changed";
         break;
      case TRADE_RETCODE_PRICE_OFF:
         str="off quotes";
         break;
      case TRADE_RETCODE_INVALID_EXPIRATION:
         str="invalid expiration";
         break;
      case TRADE_RETCODE_ORDER_CHANGED:
         str="order changed";
         break;
      case TRADE_RETCODE_TOO_MANY_REQUESTS:
         str="too many requests";
         break;
      case TRADE_RETCODE_NO_CHANGES:
         str="no changes";
         break;
      case TRADE_RETCODE_SERVER_DISABLES_AT:
         str="auto trading disabled by server";
         break;
      case TRADE_RETCODE_CLIENT_DISABLES_AT:
         str="auto trading disabled by client";
         break;
      case TRADE_RETCODE_LOCKED:
         str="locked";
         break;
      case TRADE_RETCODE_FROZEN:
         str="frozen";
         break;
      case TRADE_RETCODE_INVALID_FILL:
         str="invalid fill";
         break;
      case TRADE_RETCODE_CONNECTION:
         str="no connection";
         break;
      case TRADE_RETCODE_ONLY_REAL:
         str="only real";
         break;
      case TRADE_RETCODE_LIMIT_ORDERS:
         str="limit orders";
         break;
      case TRADE_RETCODE_LIMIT_VOLUME:
         str="limit volume";
         break;
      case TRADE_RETCODE_POSITION_CLOSED:
         str="position closed";
         break;
      case TRADE_RETCODE_INVALID_ORDER:
         str="invalid order";
         break;
      case TRADE_RETCODE_CLOSE_ORDER_EXIST:
         str="close order already exists";
         break;
      case TRADE_RETCODE_LIMIT_POSITIONS:
         str="limit positions";
         break;
      default:
         str="unknown retcode "+(string)result.retcode;
     }
//--- return the result
   return(str);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CTrade::CheckVolume(const string symbol,double volume,double price,ENUM_ORDER_TYPE order_type)
  {
//--- check
   if(order_type!=ORDER_TYPE_BUY && order_type!=ORDER_TYPE_SELL)
      return(0.0);
   double free_margin=AccountInfoDouble(ENUM_ACCOUNT_INFO_DOUBLE::ACCOUNT_MARGIN_FREE);
   if(free_margin<=0.0)
      return(0.0);
//--- clean
   ClearStructures();
//--- setting request
   m_request.action=TRADE_ACTION_DEAL;
   m_request.symbol=symbol;
   m_request.volume=volume;
   m_request.type  =order_type;
   m_request.price =price;
//--- action and return the result
   if(!::OrderCheck(m_request,m_check_result) && m_check_result.margin_free<0.0)
     {
      double coeff=free_margin/(free_margin-m_check_result.margin_free);
      double lots=NormalizeDouble(volume*coeff,2);
      if(lots<volume)
        {
         //--- normalize and check limits
         double stepvol=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
         if(stepvol>0.0)
            volume=stepvol*(MathFloor(lots/stepvol)-1);
         //---
         double minvol=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
         if(volume<minvol)
            volume=0.0;
        }
     }
   return(volume);
  }
//+------------------------------------------------------------------+
//| Checks if the m_request structure is filled correctly            |
//+------------------------------------------------------------------+
bool CTrade::OrderCheck(const MqlTradeRequest &request,MqlTradeCheckResult &check_result)
  {
//--- action and return the result
   return(::OrderCheck(request,check_result));
  }
//+------------------------------------------------------------------+
//| Set order filling type according to symbol filling mode          |
//+------------------------------------------------------------------+
bool CTrade::SetTypeFillingBySymbol(const string symbol)
  {
//--- get possible filling policy types by symbol
   uint filling=(uint)SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
   if((filling&SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK)
     {
      m_type_filling=ORDER_FILLING_FOK;
      return(true);
     }
   if((filling&SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC)
     {
      m_type_filling=ORDER_FILLING_IOC;
      return(true);
     }
//---
   return(false);
  }
//+------------------------------------------------------------------+
//| Checks and corrects type of filling policy                       |
//+------------------------------------------------------------------+
bool CTrade::FillingCheck(const string symbol)
  {
//--- get execution mode of orders by symbol
   ENUM_SYMBOL_TRADE_EXECUTION exec=(ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(symbol,SYMBOL_TRADE_EXEMODE);
//--- check execution mode
   if(exec==SYMBOL_TRADE_EXECUTION_REQUEST || exec==SYMBOL_TRADE_EXECUTION_INSTANT)
     {
      //--- neccessary filling type will be placed automatically
      return(true);
     }
//--- get possible filling policy types by symbol
   uint filling=(uint)SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
//--- check execution mode again
   if(exec==SYMBOL_TRADE_EXECUTION_MARKET)
     {
      //--- for the MARKET execution mode
      //--- analyze order
      if(m_request.action!=TRADE_ACTION_PENDING)
        {
         //--- in case of instant execution order
         //--- if the required filling policy is supported, add it to the request
         if((filling&SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK)
           {
            m_type_filling=ORDER_FILLING_FOK;
            m_request.type_filling=m_type_filling;
            return(true);
           }
         if((filling&SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC)
           {
            m_type_filling=ORDER_FILLING_IOC;
            m_request.type_filling=m_type_filling;
            return(true);
           }
         //--- wrong filling policy, set error code
         m_result.retcode=TRADE_RETCODE_INVALID_FILL;
         return(false);
        }
      return(true);
     }
//--- EXCHANGE execution mode
   switch(m_type_filling)
     {
      case ORDER_FILLING_FOK:
         //--- analyze order
         if(m_request.action==TRADE_ACTION_PENDING)
           {
            //--- in case of pending order
            //--- add the expiration mode to the request
            if(!ExpirationCheck(symbol))
               m_request.type_time=ORDER_TIME_DAY;
            //--- stop order?
            if(m_request.type==ORDER_TYPE_BUY_STOP || m_request.type==ORDER_TYPE_SELL_STOP ||
               m_request.type==ORDER_TYPE_BUY_LIMIT || m_request.type==ORDER_TYPE_SELL_LIMIT)
              {
               //--- in case of stop order
               //--- add the corresponding filling policy to the request
               m_request.type_filling=ORDER_FILLING_RETURN;
               return(true);
              }
           }
         //--- in case of limit order or instant execution order
         //--- if the required filling policy is supported, add it to the request
         if((filling&SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK)
           {
            m_request.type_filling=m_type_filling;
            return(true);
           }
         //--- wrong filling policy, set error code
         m_result.retcode=TRADE_RETCODE_INVALID_FILL;
         return(false);
      case ORDER_FILLING_IOC:
         //--- analyze order
         if(m_request.action==TRADE_ACTION_PENDING)
           {
            //--- in case of pending order
            //--- add the expiration mode to the request
            if(!ExpirationCheck(symbol))
               m_request.type_time=ORDER_TIME_DAY;
            //--- stop order?
            if(m_request.type==ORDER_TYPE_BUY_STOP || m_request.type==ORDER_TYPE_SELL_STOP ||
               m_request.type==ORDER_TYPE_BUY_LIMIT || m_request.type==ORDER_TYPE_SELL_LIMIT)
              {
               //--- in case of stop order
               //--- add the corresponding filling policy to the request
               m_request.type_filling=ORDER_FILLING_RETURN;
               return(true);
              }
           }
         //--- in case of limit order or instant execution order
         //--- if the required filling policy is supported, add it to the request
         if((filling&SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC)
           {
            m_request.type_filling=m_type_filling;
            return(true);
           }
         //--- wrong filling policy, set error code
         m_result.retcode=TRADE_RETCODE_INVALID_FILL;
         return(false);
      case ORDER_FILLING_RETURN:
         //--- add filling policy to the request
         m_request.type_filling=m_type_filling;
         return(true);
     }
//--- unknown execution mode, set error code
   m_result.retcode=TRADE_RETCODE_ERROR;
   return(false);
  }
//+------------------------------------------------------------------+
//| Check expiration type of pending order                           |
//+------------------------------------------------------------------+
bool CTrade::ExpirationCheck(const string symbol)
  {
//--- check symbol
   string symbol_name=(symbol==NULL) ? _Symbol : symbol;
//--- get flags
   long tmp_long;
   int  flags=0;
   if(SymbolInfoInteger(symbol_name,SYMBOL_EXPIRATION_MODE,tmp_long))
      flags=(int)tmp_long;
//--- check type
   switch(m_request.type_time)
     {
      case ORDER_TIME_GTC:
         if((flags&SYMBOL_EXPIRATION_GTC)!=0)
            return(true);
         break;
      case ORDER_TIME_DAY:
         if((flags&SYMBOL_EXPIRATION_DAY)!=0)
            return(true);
         break;
      case ORDER_TIME_SPECIFIED:
         if((flags&SYMBOL_EXPIRATION_SPECIFIED)!=0)
            return(true);
         break;
      case ORDER_TIME_SPECIFIED_DAY:
         if((flags&SYMBOL_EXPIRATION_SPECIFIED_DAY)!=0)
            return(true);
         break;
      default:
         Print(__FUNCTION__+": Unknown expiration type");
     }
//--- failed
   return(false);
  }
//+------------------------------------------------------------------+
//| Checks order                                                     |
//+------------------------------------------------------------------+
bool CTrade::OrderTypeCheck(const string symbol)
  {
   bool res=false;
//--- check symbol
   string symbol_name=(symbol==NULL) ? _Symbol : symbol;
//--- get flags of allowed trade orders
   long tmp_long;
   int  flags=0;
   if(SymbolInfoInteger(symbol_name,SYMBOL_ORDER_MODE,tmp_long))
      flags=(int)tmp_long;
//--- depending on the type of order in request
   switch(m_request.type)
     {
      case ORDER_TYPE_BUY:
      case ORDER_TYPE_SELL:
         //--- check possibility of execution
         res=((flags&SYMBOL_ORDER_MARKET)!=0);
         break;
      case ORDER_TYPE_BUY_LIMIT:
      case ORDER_TYPE_SELL_LIMIT:
         //--- check possibility of execution
         res=((flags&SYMBOL_ORDER_LIMIT)!=0);
         break;
      case ORDER_TYPE_BUY_STOP:
      case ORDER_TYPE_SELL_STOP:
         //--- check possibility of execution
         res=((flags&SYMBOL_ORDER_STOP)!=0);
         break;
      case ORDER_TYPE_BUY_STOP_LIMIT:
      case ORDER_TYPE_SELL_STOP_LIMIT:
         //--- check possibility of execution
         res=((flags&SYMBOL_ORDER_STOP_LIMIT)!=0);
         break;
     }
//--- check res
   if(res)
     {
      //--- trading order is valid
      //--- check if we need and able to set protective orders
      if(m_request.sl!=0.0 || m_request.tp!=0.0)
        {
         if((flags&SYMBOL_ORDER_SL)==0)
            m_request.sl=0.0;
         if((flags&SYMBOL_ORDER_TP)==0)
            m_request.tp=0.0;
        }
     }
   else
     {
      //--- trading order is not valid
      //--- set error
      m_result.retcode=TRADE_RETCODE_INVALID_ORDER;
      Print(__FUNCTION__+": Invalid order type");
     }
//--- result
   return(res);
  }
//+------------------------------------------------------------------+
//| Send order                                                       |
//+------------------------------------------------------------------+
bool CTrade::OrderSend(const MqlTradeRequest &request,MqlTradeResult &result)
  {
   bool   res;
   string action="";
   string fmt   ="";
//--- action
   if(m_async_mode)
      res=::OrderSendAsync(request,result);
   else
      res=::OrderSend(request,result);
//--- check
   if(res)
     {
      if(m_log_level>LOG_LEVEL_ERRORS)
         PrintFormat(__FUNCTION__+": %s [%s]",FormatRequest(action,request),FormatRequestResult(fmt,request,result));
     }
   else
     {
      if(m_log_level>LOG_LEVEL_NO)
         PrintFormat(__FUNCTION__+": %s [%s]",FormatRequest(action,request),FormatRequestResult(fmt,request,result));
     }
//--- return the result
   return(res);
  }
//+------------------------------------------------------------------+
//| Position select depending on netting or hedging                  |
//+------------------------------------------------------------------+
bool CTrade::SelectPosition(const string symbol)
  {
   bool res=false;
//---
   if(IsHedging())
     {
      uint total=PositionsTotal();
      for(uint i=0; i<total; i++)
        {
         string position_symbol=PositionGetSymbol(i);
         if(position_symbol==symbol && m_magic==PositionGetInteger(POSITION_MAGIC))
           {
            res=true;
            break;
           }
        }
     }
   else
      res=PositionSelect(symbol);
//---
   return(res);
  }
//+------------------------------------------------------------------+

// ===== END MQL5/Include/Trade/Trade.mqh =====

// ===== END INLINED METAQUOTES STANDARD TRADE DEPENDENCIES =====

// Standard headers are inlined below.

CTrade trade;

// Shared quote-integrity gate for broker-facing order submission and position/pending management writes.
bool STB_ScannerQuoteValid(const MqlTick &tick,string &reason);

//==================================================================
// INPUTS
//==================================================================
input group "=== CORE ==="
input ulong   InpMagic                  = 26093001;
input bool    InpAutoTrading            = true;
input int     InpScanSeconds            = 10;
input bool    InpAllowUniversal         = true;
input bool    InpOneSetupPerSymbol      = false;
input string  InpScannerSymbols         = "";   // empty = universal exposure management; explicit list scopes managed symbols
input string  InpScannerExcludedSymbols  = ""; // exact broker symbols excluded from automatic scanner candidates only; manual controls and position protection remain available

input group "=== ADVANCED SCANNER / ARCHITECTURE ==="
input double  InpScannerMinQuality        = 0.0;
input double  InpScannerMinScore          = 0.0;
input double  InpScannerMinTopGap         = 0.0;
input int     InpScannerMaxWatchlist      = 50;
input int     InpScannerTopN              = 10;
input int     InpScannerMaxQuoteAgeSec    = 60;   // reject stale scanner quotes after one minute
input double  InpManualPendingGapPips     = 5.0;

input group "=== TESTER REPRODUCIBILITY ==="
input bool    InpTesterForceAutoTrading  = true;  // tester only; prevents stale/missing .set state from disabling order placement
input bool    InpTesterChartSymbolOnly   = true;  // tester only; isolates the test universe to _Symbol

input group "=== RSI + CCI COMPOSITE ==="
input bool    InpOscillatorConfirmation    = true;
input ENUM_TIMEFRAMES InpOscTF              = PERIOD_M15;
input int     InpRSIPeriod                  = 14;
input int     InpCCIPeriod                  = 20;
input double  InpRSIBuyLevel                = 55.0;
input double  InpRSISellLevel               = 45.0;
input double  InpCCIBuyLevel                = 50.0;
input double  InpCCISellLevel               = -50.0;
input double  InpRSIWeight                  = 7.0;
input double  InpCCIWeight                  = 8.0;
input bool    InpOscillatorHardFilter       = false;
input double  InpMaxSpreadPips         = 0.0;   // 0 = disabled; optional absolute symbol-specific cap
input double  InpMaxRelativeSpreadPct   = 0.0;  // hard scanner gate: spread as % of M15 ATR; 0 disables
input int     InpSetupCooldownMinutes  = 0;
input int     InpMaxSetupAgeBars       = 0;     // maximum age of the M15 structure break before entry; 0 disables
input bool    InpUseRiskSizing         = true;  // default to bounded equity-risk sizing; requires valid SL geometry
input double  InpRiskPercent           = 0.25;  // target equity risk per setup; validation hard-caps at 1.0%
input double  InpMaxRiskVolume         = 0.0;   // 0 = broker max only
input double  InpMaxDailyLossPercent   = 2.0;   // block new setups after daily equity drawdown reaches this %; 0 disables

input group "=== ADAPTIVE LEARNING ==="
input bool    InpAdaptiveLearning       = true;
input double  InpAdaptiveBaseScore      = 50.0;
input double  InpAdaptiveMinScore       = 45.0;
input double  InpAdaptiveMaxScore       = 75.0;
input double  InpAdaptiveStep           = 5.0;
input double  InpAdaptiveWeakWinRate    = 0.40;
input double  InpAdaptiveStrongWinRate  = 0.65;
input int     InpAdaptiveMinSamples     = 20;
input double  InpAdaptiveHalfLifeDays  = 30.0;
input string  InpAdaptiveLogFile        = "SmartTradingBot_Learning.csv";
input bool    InpAdaptiveParameterLearning = true;
input int     InpAdaptiveWarmupPerProfile  = 2;
input double  InpAdaptiveUCBExploration    = 0.35;

input group "=== LOOKBACK ==="
input int     InpLookbackH4             = 180;
input int     InpLookbackM15            = 240;
input int     InpStructureWindowBars    = 30;

input group "=== SWING ==="
input int     InpSwingLeft              = 2;
input int     InpSwingRight             = 2;

input group "=== ENTRY ==="
input double  InpBaseLots               = 0.01;
input double  InpTrendLotMultiplier     = 2.0;
input double  InpUniversalLotMultiplier = 1.0;
input double  InpEntryBufferPips        = 1.0;
input double  InpPendingTrailMaxRiskExpansion = 1.0;  // Pending-trail risk ratio; hard-capped at 1.0 (no risk expansion)
input double  InpPipPointsOverride      = 0.0;  // 0 = automatic; >0 = points per pip
input double  InpSLBufferPips           = 1.0;
input double  InpInitialSLBufferPips    = 2.0;  // automatic SL: distance beyond nearest confirmed swing
input double  InpMaxInitialSLPips        = 0.0;  // 0 = disabled; strategy cap on Entry->SL distance (scalping)
input double  InpMinimumRR              = 1.0;
input int     InpMaxPendingBars         = 4;

input group "=== FVG / OB ==="
input bool    InpRequireFVG             = false;   // hard gate: missing local M15 FVG rejects the setup
input bool    InpRequireOB              = false;   // hard gate: missing local M15 Order Block rejects the setup
input bool    InpStrictPatternFilters   = false;  // legacy compatibility; true forces both local pattern gates
input int     InpPatternWindowBars      = 12;
input bool    InpRequireH4TrendAlignment = false;  // reject missing/contrary H4 directional context
input bool    InpRequireHTFConfluence   = false;   // require valid higher-timeframe FVG + Order Block confluence
input ENUM_TIMEFRAMES InpHTFPatternTF   = PERIOD_H1;
input int     InpHTFLookbackBars        = 120;
input int     InpHTFMaxZoneAgeBars      = 48;
input double  InpHTFZoneMaxGapATR       = 0.50;   // allowed zone gap as a multiple of HTF ATR
input double  InpHTFMinFVGWidthATR      = 0.05;   // reject near-zero-width HTF imbalances

input group "=== PROFIT PROTECTION ==="
input double  InpManualSaveStepPips     = 20.0;

input group "=== TRADE MANAGEMENT ==="
// SIMPLIFIED: per-magic / per-origin management flags removed (ownership scope = allowed symbol only).


input bool    InpAllowOneClickHedge      = true;

input group "=== TRENDLINE ==="
input double  InpTrendlineTolerancePips = 10.0;

input group "=== ADAPTIVE POSITION PROTECTION ==="
input ENUM_TIMEFRAMES InpProtectionTF             = PERIOD_M5;   // faster closed-candle ATR for break-even and ATR trailing
input bool            InpEnableAdaptiveProtection = true;
input double          InpBreakEvenTriggerATR      = 0.45;         // start protection after a favourable move of 0.45 ATR
input double          InpBreakEvenMinOffsetPips   = 1.5;          // never target exact entry; add a cost/slippage buffer
input double          InpBreakEvenCostMultiplier  = 1.50;         // scale observed commission/swap costs conservatively
input double          InpAdaptiveLockTriggerATR   = 0.85;         // advance from break-even to a meaningful profit lock
input double          InpAdaptiveLockATR          = 0.20;         // lock at least 0.20 ATR when available
input double          InpAdaptiveTrailStartATR    = 0.75;         // activate ATR trail after the position has room to breathe
input double          InpAdaptiveTrailDistanceATR = 0.55;         // keep stop behind executable close-side price
input double          InpAdaptiveTrailStepATR     = 0.08;         // suppress tiny modifications/noisy stop churn

input group "=== TRAILING ==="
input ENUM_TIMEFRAMES InpTrailTF        = PERIOD_M15;
input bool    InpUseStructuralTrailing  = true;  // use confirmed swing structure instead of live-price distance
input double  InpStructuralTrailStartATR = 1.0;  // favorable move required before structural trailing starts
input double  InpStructuralTrailBufferATR = 0.15; // SL buffer outside a confirmed swing
input double  InpTrailStartPips         = 150.0;  // used only when structural trailing is disabled
input double  InpLiveTrailDistancePips   = 30.0;  // legacy live-distance trail when structural mode is disabled
input double  InpTrailStepPips             = 5.0;   // minimum SL improvement before a new trailing modification

//+------------------------------------------------------------------+
//| Inline diagnostics-only helpers (A-C). No order behavior changes. |
//+------------------------------------------------------------------+
struct STBVolumeDiag
  {
   string stage;
   string setupType;
   bool   riskMode;
   double equity;
   double riskPct;
   double riskBudget;
   bool   calcProfitCall;
   bool   calcProfitOk;
   int    calcProfitErr;
   double lossForOneLot;
   double rawVolume;
   double cappedVolume;
   double minVolume;
   double volumeStep;
   bool   minVolumeReadOk;
   bool   volumeStepReadOk;
   bool   volumeMetadataValid;
   double maxRiskVolume;
   double finalVolume;
   string rejectCause;
  };
STBVolumeDiag g_stbVolumeDiag;

void STB_VolumeDiagReset(const string stage,const string setupType)
  {
   g_stbVolumeDiag.stage=stage;
   g_stbVolumeDiag.setupType=setupType;
   g_stbVolumeDiag.riskMode=false;
   g_stbVolumeDiag.equity=0.0;
   g_stbVolumeDiag.riskPct=0.0;
   g_stbVolumeDiag.riskBudget=0.0;
   g_stbVolumeDiag.calcProfitCall=false;
   g_stbVolumeDiag.calcProfitOk=false;
   g_stbVolumeDiag.calcProfitErr=0;
   g_stbVolumeDiag.lossForOneLot=0.0;
   g_stbVolumeDiag.rawVolume=0.0;
   g_stbVolumeDiag.cappedVolume=0.0;
   g_stbVolumeDiag.minVolume=0.0;
   g_stbVolumeDiag.volumeStep=0.0;
   g_stbVolumeDiag.minVolumeReadOk=false;
   g_stbVolumeDiag.volumeStepReadOk=false;
   g_stbVolumeDiag.volumeMetadataValid=false;
   g_stbVolumeDiag.maxRiskVolume=0.0;
   g_stbVolumeDiag.finalVolume=0.0;
   g_stbVolumeDiag.rejectCause="UNSET";
  }

bool STB_VolumeDiagReadMetadata(const string symbol)
  {
   double minCheck=0.0,stepCheck=0.0;
   g_stbVolumeDiag.minVolume=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   g_stbVolumeDiag.volumeStep=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
   g_stbVolumeDiag.minVolumeReadOk=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN,minCheck);
   g_stbVolumeDiag.volumeStepReadOk=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP,stepCheck);
   g_stbVolumeDiag.volumeMetadataValid=
      g_stbVolumeDiag.minVolumeReadOk &&
      g_stbVolumeDiag.volumeStepReadOk &&
      g_stbVolumeDiag.minVolume>0.0 &&
      g_stbVolumeDiag.volumeStep>0.0 &&
      MathIsValidNumber(g_stbVolumeDiag.minVolume) &&
      MathIsValidNumber(g_stbVolumeDiag.volumeStep);
   return g_stbVolumeDiag.volumeMetadataValid;
  }

string STB_VolumeDiagFormat(const string symbol,const int direction,
                            const double entry,const double sl)
  {
   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   return " stage="+g_stbVolumeDiag.stage+
          " setupType="+g_stbVolumeDiag.setupType+
          " symbol="+symbol+
          " dir="+(direction>0 ? "BUY":"SELL")+
          " sizing="+(g_stbVolumeDiag.riskMode ? "RISK":"FIXED")+
          " equity="+DoubleToString(g_stbVolumeDiag.equity,2)+
          " riskPct="+DoubleToString(g_stbVolumeDiag.riskPct,4)+
          " riskBudget="+DoubleToString(g_stbVolumeDiag.riskBudget,4)+
          " entry="+DoubleToString(entry,digits)+
          " sl="+DoubleToString(sl,digits)+
          " slDistance="+DoubleToString(MathAbs(entry-sl),digits)+
          " calcProfitCalled="+(g_stbVolumeDiag.calcProfitCall ? "YES":"NO")+
          " calcProfitOk="+(g_stbVolumeDiag.calcProfitOk ? "YES":"NO")+
          " calcProfitErr="+IntegerToString(g_stbVolumeDiag.calcProfitErr)+
          " lossForOneLot="+DoubleToString(g_stbVolumeDiag.lossForOneLot,4)+
          " rawVolume="+DoubleToString(g_stbVolumeDiag.rawVolume,6)+
          " cappedVolume="+DoubleToString(g_stbVolumeDiag.cappedVolume,6)+
          " minVolume="+DoubleToString(g_stbVolumeDiag.minVolume,4)+
          " volumeStep="+DoubleToString(g_stbVolumeDiag.volumeStep,4)+
          " minVolumeReadOk="+(g_stbVolumeDiag.minVolumeReadOk ? "YES":"NO")+
          " volumeStepReadOk="+(g_stbVolumeDiag.volumeStepReadOk ? "YES":"NO")+
          " volumeMetadataValid="+(g_stbVolumeDiag.volumeMetadataValid ? "YES":"NO")+
          " maxRiskVolume="+DoubleToString(g_stbVolumeDiag.maxRiskVolume,4)+
          " finalVolume="+DoubleToString(g_stbVolumeDiag.finalVolume,4)+
          " cause="+g_stbVolumeDiag.rejectCause;
  }

void STB_LogVolumeReject(const string symbol,const int direction,
                         const double entry,const double sl)
  {
   Print("STB VOLUME REJECT",STB_VolumeDiagFormat(symbol,direction,entry,sl));
  }

void STB_LogFixedVolumeReject(const string stage,const string setupType,
                              const string symbol,const int direction,
                              const double entry,const double sl,
                              const double requestedVolume)
  {
   STB_VolumeDiagReset(stage,setupType);
   g_stbVolumeDiag.riskMode=false;
   g_stbVolumeDiag.equity=AccountInfoDouble(ACCOUNT_EQUITY);
   g_stbVolumeDiag.riskPct=InpRiskPercent;
   g_stbVolumeDiag.maxRiskVolume=InpMaxRiskVolume;
   g_stbVolumeDiag.rawVolume=requestedVolume;
   STB_VolumeDiagReadMetadata(symbol);
   g_stbVolumeDiag.cappedVolume=0.0;
   g_stbVolumeDiag.finalVolume=0.0;
   g_stbVolumeDiag.rejectCause=(g_stbVolumeDiag.volumeMetadataValid ?
                                "FIXED_LOT_NORMALIZE_FAILED" :
                                "SYMBOL_VOLUME_METADATA_INVALID");
   STB_LogVolumeReject(symbol,direction,entry,sl);
  }

void STB_LogSizingConfig()
  {
   Print("STB INIT SIZING",
         " useRiskSizing=",(InpUseRiskSizing ? "ON":"OFF"),
         " riskPercent=",DoubleToString(InpRiskPercent,4),
         " baseLots=",DoubleToString(InpBaseLots,4),
         " trendLotMultiplier=",DoubleToString(InpTrendLotMultiplier,4),
         " universalLotMultiplier=",DoubleToString(InpUniversalLotMultiplier,4),
         " maxRiskVolume=",DoubleToString(InpMaxRiskVolume,4),
         " maxDailyLossPercent=",DoubleToString(InpMaxDailyLossPercent,4),
         " chartMinVolume=",DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),4),
         " chartVolumeStep=",DoubleToString(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),4),
         " equity=",DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),2),
         " accountCurrency=",AccountInfoString(ACCOUNT_CURRENCY));
  }

void STB_TallyAdd(string &tally,const string reason)
  {
   tally+="|"+(reason=="" ? "UNSPECIFIED":reason);
  }

string STB_TallyReport(const string tally)
  {
   if(tally=="")
      return "none";
   string parts[];
   int n=StringSplit(tally,StringGetCharacter("|",0),parts);
   string out="";
   for(int i=0;i<n;i++)
     {
      if(parts[i]=="")
         continue;
      if(StringFind(out,parts[i]+"=")>=0)
         continue;
      int count=0;
      for(int j=0;j<n;j++)
         if(parts[j]==parts[i])
            count++;
      out+=(out=="" ? "" : ",")+parts[i]+"="+IntegerToString(count);
     }
   return (out=="" ? "none":out);
  }

// End inline diagnostics-only helpers.

bool g_modifyWasNoChanges=false;

// Daily equity guard state. Tester runs use an isolated run token; terminal
// runtime uses a stable account+magic namespace so daily baseline survives
// chart reinitialization and is shared by instances using the same magic.
double g_stbDailyStartEquity=0.0;
int    g_stbDailyKey=0;
bool   g_stbDailyLimitLogged=false;
bool   g_stbDailyLossThresholdReached=false;
string g_stbRunNamespace="";

// Tester runs use a persisted per-run token. Live/demo runtime uses a stable
// account+magic namespace for the daily-risk baseline; this avoids resetting
// the guard when the EA is detached/reattached or MT5 is restarted.
string STB_RunNamespaceKey()
  {
   return "STB_RUN_"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"_"+
          (string)InpMagic+"_"+(string)ChartID();
  }

bool STB_InitRunNamespace()
  {
   if(!MQLInfoInteger(MQL_TESTER))
     {
      long login=(long)AccountInfoInteger(ACCOUNT_LOGIN);
      if(login<=0)
        {
         Print("STB INIT FAILED: valid account login unavailable for live risk namespace.");
         return false;
        }

      g_stbRunNamespace="LIVE_"+(string)login+"_"+(string)InpMagic;
      return (StringLen(g_stbRunNamespace)>0);
     }

   string runKey=STB_RunNamespaceKey();
   if(GlobalVariableCheck(runKey))
     {
      double stored=GlobalVariableGet(runKey);
      if(MathIsValidNumber(stored) && stored>=1.0 && stored<=4294967295.0)
         g_stbRunNamespace=(string)(uint)stored;
     }

   if(g_stbRunNamespace=="")
     {
      uint runToken=(uint)TimeLocal() ^ GetTickCount() ^
                    (uint)AccountInfoInteger(ACCOUNT_LOGIN) ^
                    (uint)InpMagic ^ (uint)ChartID();
      if(runToken==0)
         runToken=1;
      g_stbRunNamespace=(string)runToken;
      if(GlobalVariableSet(runKey,(double)runToken)<=0)
        {
         Print("STB INIT FAILED: cannot persist tester run namespace.");
         g_stbRunNamespace="";
         return false;
        }
      GlobalVariablesFlush();
     }

   return (StringLen(g_stbRunNamespace)>0);
  }

string STB_DailyRiskStateName(const string suffix)
  {
   return "STB_DLY_"+suffix+"_"+g_stbRunNamespace;
  }

bool STB_DailyRiskPersist(const int dayKey,const double startEquity,
                          const bool limitLogged)
  {
   string dayName=STB_DailyRiskStateName("DAY");
   string equityName=STB_DailyRiskStateName("EQ");
   string loggedName=STB_DailyRiskStateName("LOG");
   if(GlobalVariableSet(equityName,startEquity)<=0 ||
      GlobalVariableSet(loggedName,(limitLogged ? 1.0:0.0))<=0 ||
      GlobalVariableSet(dayName,(double)dayKey)<=0)
     {
      Print("STB DAILY RISK STATE PERSIST FAILED; entries will remain blocked.");
      return false;
     }

   // Force the terminal-global snapshot to disk after a baseline rollover or
   // a verified daily-loss breach. Without a flush, an abrupt terminal/OS
   // failure could lose the in-memory guard state and make a later attach
   // treat the same day as a fresh baseline.
   GlobalVariablesFlush();
   return true;
  }

void STB_DailyRiskClearState()
  {
   GlobalVariableDel(STB_DailyRiskStateName("DAY"));
   GlobalVariableDel(STB_DailyRiskStateName("EQ"));
   GlobalVariableDel(STB_DailyRiskStateName("LOG"));
   GlobalVariableDel(STB_RunNamespaceKey());
   GlobalVariablesFlush();
   g_stbDailyKey=0;
   g_stbDailyStartEquity=0.0;
   g_stbDailyLimitLogged=false;
   g_stbDailyLossThresholdReached=false;
  }

// Return true only for realized deals attributable to this EA or its UI-manual
// commands. Unrelated terminal trades must not contribute to the EA daily guard.
bool STB_DailyGuardDealIsEAOwned(const ulong dealTicket)
  {
   if(dealTicket==0)
      return false;

   long magic=HistoryDealGetInteger(dealTicket,DEAL_MAGIC);
   if(magic==(long)InpMagic)
      return true;

   string comment=HistoryDealGetString(dealTicket,DEAL_COMMENT);
   return (StringFind(comment,"STB|M|")==0);
  }

bool STB_DailyLossLimitHit()
  {
   g_stbDailyLossThresholdReached=false;
   MqlDateTime nowParts;
   datetime now=TimeCurrent();
   if(now<=0 || !TimeToStruct(now,nowParts))
      return true; // fail closed when the test clock is invalid

   int dayKey=nowParts.year*10000+nowParts.mon*100+nowParts.day;
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(!MathIsValidNumber(equity) || equity<=0.0)
      return true; // fail closed on invalid equity

   string dayName=STB_DailyRiskStateName("DAY");
   string equityName=STB_DailyRiskStateName("EQ");
   string loggedName=STB_DailyRiskStateName("LOG");
   bool persistedStateValid=false;

   if(GlobalVariableCheck(dayName) && GlobalVariableCheck(equityName))
     {
      double storedDay=GlobalVariableGet(dayName);
      double storedEquity=GlobalVariableGet(equityName);
      if(MathIsValidNumber(storedDay) &&
         storedDay==(double)dayKey &&
         MathIsValidNumber(storedEquity) && storedEquity>0.0)
        {
         g_stbDailyKey=dayKey;
         g_stbDailyStartEquity=storedEquity;
         g_stbDailyLimitLogged=(GlobalVariableCheck(loggedName) &&
                                GlobalVariableGet(loggedName)>=1.0);
         persistedStateValid=true;
        }
     }

   if(!persistedStateValid)
     {
      // Do not silently reset a damaged same-day baseline to current equity:
      // that could erase already-incurred daily drawdown. A missing/invalid
      // state is allowed to initialize only when no prior state exists.
      bool anyStatePresent=(GlobalVariableCheck(dayName) ||
                            GlobalVariableCheck(equityName) ||
                            GlobalVariableCheck(loggedName));
      if(anyStatePresent)
        {
         if(!GlobalVariableCheck(dayName))
           {
            Print("STB DAILY RISK STATE CORRUPT: day key missing; entries blocked.");
            return true;
           }

         double storedDay=GlobalVariableGet(dayName);
         if(!MathIsValidNumber(storedDay) ||
            storedDay<20000101.0 || storedDay>99991231.0)
           {
            Print("STB DAILY RISK STATE CORRUPT: invalid day key; entries blocked.");
            return true;
           }

         // Same-day partial/corrupt state must fail closed. A future stored
         // day indicates a clock rollback or test-time regression and also
         // fails closed. Only a genuine forward day transition resets baseline.
         if(storedDay>=(double)dayKey)
           {
            Print("STB DAILY RISK STATE CORRUPT/DATE REGRESSION: entries blocked.",
                  " storedDay=",DoubleToString(storedDay,0),
                  " currentDay=",dayKey);
            return true;
           }
        }

      // Fresh installation or confirmed forward server-day rollover.
      g_stbDailyKey=dayKey;
      g_stbDailyStartEquity=equity;
      g_stbDailyLimitLogged=false;
      Print("STB DAILY RISK BASELINE day=",dayKey,
            " accountEquityReference=",DoubleToString(equity,2),
            " maxLossPct=",DoubleToString(InpMaxDailyLossPercent,2),
            " scope=ACCOUNT_EQUITY");
      if(!STB_DailyRiskPersist(dayKey,equity,false))
         return true;
      return false;
     }

   if(InpMaxDailyLossPercent<=0.0)
      return false;

   // Once the daily loss limit has been breached, keep entries blocked until
   // the next valid server-day baseline. An equity recovery later in the day
   // must not silently re-arm new entries after the guard has tripped.
   if(g_stbDailyLimitLogged)
     {
      g_stbDailyLossThresholdReached=true;
      return true;
     }

   // Use the persisted start-of-day account-equity baseline and current
   // account equity. Summing today's closed deals with the FULL floating P/L
   // of open positions double-counts or misattributes overnight exposure:
   // an overnight position's entire floating loss is not necessarily today's
   // loss. Equity delta is internally consistent and fails conservatively:
   // losses from any account activity can block new EA entries, but cannot
   // be omitted merely because a deal/position ownership tag is missing.
   if(!MathIsValidNumber(g_stbDailyStartEquity) ||
      g_stbDailyStartEquity<=0.0 ||
      !MathIsValidNumber(equity) || equity<=0.0)
     {
      Print("STB DAILY RISK EQUITY BASELINE INVALID; entries remain blocked.");
      return true;
     }

   double accountEquityChange=equity-g_stbDailyStartEquity;
   double lossMoney=MathMax(0.0,-accountEquityChange);
   double lossPct=lossMoney/g_stbDailyStartEquity*100.0;

   if(lossPct+1e-9>=InpMaxDailyLossPercent)
     {
      g_stbDailyLossThresholdReached=true;
      if(!g_stbDailyLimitLogged)
        {
         g_stbDailyLimitLogged=true;
         if(!STB_DailyRiskPersist(dayKey,g_stbDailyStartEquity,true))
            return true;
         Print("STB DAILY LOSS LIMIT HIT day=",dayKey,
            " startEquityReference=",DoubleToString(g_stbDailyStartEquity,2),
            " currentAccountEquity=",DoubleToString(equity,2),
            " accountEquityChange=",DoubleToString(accountEquityChange,2),
            " lossPct=",DoubleToString(lossPct,2),
            " limitPct=",DoubleToString(InpMaxDailyLossPercent,2),
            " scope=ACCOUNT_EQUITY action=BLOCK_NEW_SETUPS");
        }
      return true;
     }

   return false;
  }

//==================================================================
// UNIVERSAL PROFIT LOCK POLICY
// Mandatory and identical for EVERY managed position regardless of origin:
// EA / manual / mobile / magic==InpMagic / magic==0 / foreign magic /
// chart-key / HEDGE / pending-trigger / pre-existing / restart-recovered.
//
//   profit <  +50 pip  ->  no auto profit lock
//   profit >= +50 pip  ->  lock at least +20 pip
//        BUY : Locked SL = Entry + 20 pip
//        SELL: Locked SL = Entry - 20 pip
//
// Single central chain (no side paths):
//   Universal Position Intake -> STB_ProfitProtectionOne -> ApplyProfitLock
//   -> STB_SubmitPositionSL -> STB_ResolvePositionSL -> ModifyPositionSL
//==================================================================
#define STB_PROFIT_LOCK_TRIGGER_PIPS 50.0   // mandatory trigger: profit below this -> no lock
#define STB_PROFIT_LOCK_MIN_PIPS     20.0   // mandatory minimum lock once triggered

double STB_ProfitLockTriggerPips()
  {
   return STB_PROFIT_LOCK_TRIGGER_PIPS;
  }

double STB_ProfitLockLockPips()
  {
   // Mandatory policy value; stray .set / chart inputs must never change it.
   double configured=STB_PROFIT_LOCK_MIN_PIPS;
   if(configured<STB_PROFIT_LOCK_MIN_PIPS)
      configured=STB_PROFIT_LOCK_MIN_PIPS;
   return configured;
  }

//==================================================================
// STRUCTURES
//==================================================================

struct SwingPoint
  {
   int               shift;
   datetime          time;
   double            price;
   bool              isHigh;
  };

struct TrendInfo
  {
   string            bias;
   bool              valid;
   int               touches;
   datetime          t1;
   datetime          t2;
   double            p1;
   double            p2;
  };

struct OscillatorState
  {
   double            rsi1;
   double            rsi2;
   double            cci1;
   double            cci2;
   bool              buyConfirmed;
   bool              sellConfirmed;
   bool              valid;
  };

struct STBIndicatorCache
  {
   string            symbol;
   int               rsiHandle;
   int               cciHandle;
  };


struct Setup
  {
   bool              valid;
   string            symbol;
   int               direction;
   bool              trendAligned;

   int               chochShift;
   int               bosShift;
   int               originShift;
   int               fvgShift;

   double            originHigh;
   double            originLow;

   double            swingHigh;
   double            swingLow;

   double            entry;
   double            sl;
   double            tp;
   double            rr;

   double            score;
   int               adaptiveProfile;

   double            entryBufferPips;

   datetime          setupTime;
  };


/*==================================================================
  IN-EA ADAPTIVE PARAMETER LEARNING
  ---------------------------------------------------------------
  Five bounded strategy profiles are selected with a deterministic
  decayed UCB policy. Only closed trade outcomes update the profile
  statistics. No future-bar or future-trade information is used.
==================================================================*/

#define STB_ADAPTIVE_PROFILE_COUNT 5

struct STBAdaptiveProfile
  {
   int               id;
   int               swingLeft;
   int               swingRight;
   int               maxSetupAgeBars;
   int               patternWindowBars;
   int               maxPendingBars;
   double            entryBufferPips;
   double            slBufferPips;
   double            minimumRR;
   double            rsiBuyLevel;
   double            rsiSellLevel;
   double            cciBuyLevel;
   double            cciSellLevel;
   double            rsiWeight;
   double            cciWeight;
  };

struct STBDiagnosticState
  {
   string            symbol;
   int               direction;
   datetime          lastBar;
   string            lastReason;
   datetime          lastReadyBar;
  };

STBAdaptiveProfile g_activeAdaptiveProfile;
bool               g_activeAdaptiveProfileValid=false;
int                g_activeAdaptiveProfileId=0;
string             g_lastBuildRejectReason="UNKNOWN";
STBDiagnosticState g_diagnosticStates[];
string             g_controlLastAction="EA INITIALIZED";
datetime           g_lastSignalScanBar=0;
int                g_panelScanSymbols=0;
int                g_panelScanTradable=0;
int                g_panelScanBuyReady=0;
int                g_panelScanSellReady=0;
int                g_panelScanPlacements=0;
datetime           g_panelLastScanTime=0;
bool               g_panelChartBuyReady=false;
bool               g_panelChartSellReady=false;
double             g_panelChartBuyScore=0.0;
double             g_panelChartSellScore=0.0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong STB_AP_Hash(const string raw)
  {
   ulong h=1469598103934665603ULL;

   for(int i=0;i<StringLen(raw);i++)
     {
      h^=(ulong)StringGetCharacter(raw,i);
      h*=1099511628211ULL;
     }

   return h;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string STB_AP_Key(const string symbol,
                  const int direction,
                  const string scope,
                  const int profile=-1)
  {
   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
              (string)InpMagic+"|AP3|"+symbol+"|"+
              (direction>0 ? "B":"S")+"|"+
              scope+"|"+(string)profile;

   // Do not read or mutate live adaptive statistics from Strategy Tester.
   if(MQLInfoInteger(MQL_TESTER))
      raw+="|TESTER|RUN|"+g_stbRunNamespace;

   return "STB_AP3_"+(string)STB_AP_Hash(raw);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_AP_Read(const string symbol,
                   const int direction,
                   const string scope,
                   const int profile,
                   const double fallback)
  {
   string key=STB_AP_Key(symbol,direction,scope,profile);

   if(!GlobalVariableCheck(key))
      return fallback;

   double value=GlobalVariableGet(key);

   return MathIsValidNumber(value) ? value:fallback;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AP_Write(const string symbol,
                  const int direction,
                  const string scope,
                  const int profile,
                  const double value)
  {
   GlobalVariableSet(STB_AP_Key(symbol,direction,scope,profile),value);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_AP_Decay(const string symbol,
                    const int direction,
                    const int profile)
  {
   double halfLife=MathMax(0.1,InpAdaptiveHalfLifeDays);
   datetime last=(datetime)STB_AP_Read(symbol,direction,"T",profile,0.0);

   if(last<=0)
      return 1.0;

   long elapsed=(long)MathMax(0.0,(double)(TimeCurrent()-last));

   if(elapsed<=0)
      return 1.0;

   return MathPow(0.5,(double)elapsed/(halfLife*86400.0));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AP_ReadProfileStats(const string symbol,
                             const int direction,
                             const int profile,
                             double &wins,
                             double &losses)
  {
   double decay=STB_AP_Decay(symbol,direction,profile);

   wins=MathMax(0.0,STB_AP_Read(symbol,direction,"W",profile,0.0)*decay);
   losses=MathMax(0.0,STB_AP_Read(symbol,direction,"L",profile,0.0)*decay);
  }

// Profile attempts are tracked separately from closed-trade outcomes.
// This prevents a parameter profile that produces no executable setup
// from remaining the least-sampled arm forever.
double STB_AP_ReadAttempts(const string symbol,
                           const int direction,
                           const int profile)
  {
   return MathMax(0.0,
                  STB_AP_Read(symbol,direction,"A",profile,0.0));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AP_RecordAttempt(const string symbol,
                          const int direction,
                          const int profile)
  {
   if(profile<0 || profile>=STB_ADAPTIVE_PROFILE_COUNT)
      return;

// Scanner calls can happen repeatedly during one M15 bar. Count a
// profile probe at most once per closed signal bar so the learner
// measures genuine exploration rather than timer frequency.
   datetime closedBar=iTime(symbol,PERIOD_M15,1);

   if(closedBar<=0)
      return;

   datetime lastProbe=(datetime)STB_AP_Read(
                         symbol,direction,"ABAR",profile,0.0);

   if(lastProbe==closedBar)
      return;

   STB_AP_Write(symbol,direction,"ABAR",profile,(double)closedBar);

   double attempts=STB_AP_ReadAttempts(symbol,direction,profile);
   STB_AP_Write(symbol,direction,"A",profile,attempts+1.0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AP_LoadProfile(const int id,STBAdaptiveProfile &p)
  {
   p.id=0;
   p.swingLeft=InpSwingLeft;
   p.swingRight=InpSwingRight;
   p.maxSetupAgeBars=InpMaxSetupAgeBars;
   p.patternWindowBars=InpPatternWindowBars;
   p.maxPendingBars=InpMaxPendingBars;
   p.entryBufferPips=InpEntryBufferPips;
   p.slBufferPips=InpSLBufferPips;
   p.minimumRR=InpMinimumRR;
   p.rsiBuyLevel=InpRSIBuyLevel;
   p.rsiSellLevel=InpRSISellLevel;
   p.cciBuyLevel=InpCCIBuyLevel;
   p.cciSellLevel=InpCCISellLevel;
   p.rsiWeight=InpRSIWeight;
   p.cciWeight=InpCCIWeight;

   int safeId=MathMax(0,MathMin(STB_ADAPTIVE_PROFILE_COUNT-1,id));

   switch(safeId)
     {
      case 0:
         break;

      case 1:
         p.id=1;
         p.maxSetupAgeBars=2;
         p.patternWindowBars=8;
         p.maxPendingBars=3;
         p.entryBufferPips=0.75;
         p.slBufferPips=1.00;
         p.minimumRR=1.20;
         p.rsiBuyLevel=56.0;
         p.rsiSellLevel=44.0;
         p.cciBuyLevel=60.0;
         p.cciSellLevel=-60.0;
         break;

      case 2:
         p.id=2;
         p.swingLeft=3;
         p.swingRight=3;
         p.maxSetupAgeBars=3;
         p.patternWindowBars=10;
         p.maxPendingBars=2;
         p.entryBufferPips=1.25;
         p.slBufferPips=1.50;
         p.minimumRR=1.50;
         p.rsiBuyLevel=57.0;
         p.rsiSellLevel=43.0;
         p.cciBuyLevel=75.0;
         p.cciSellLevel=-75.0;
         p.rsiWeight=6.0;
         p.cciWeight=9.0;
         break;

      case 3:
         p.id=3;
         p.swingLeft=1;
         p.swingRight=1;
         p.maxSetupAgeBars=1;
         p.patternWindowBars=8;
         p.maxPendingBars=2;
         p.entryBufferPips=0.50;
         p.slBufferPips=0.75;
         p.minimumRR=1.00;
         p.rsiBuyLevel=53.0;
         p.rsiSellLevel=47.0;
         p.cciBuyLevel=30.0;
         p.cciSellLevel=-30.0;
         p.rsiWeight=8.0;
         p.cciWeight=7.0;
         break;

      case 4:
         p.id=4;
         p.swingLeft=2;
         p.swingRight=2;
         p.maxSetupAgeBars=4;
         p.patternWindowBars=16;
         p.maxPendingBars=5;
         p.entryBufferPips=1.00;
         p.slBufferPips=1.25;
         p.minimumRR=1.30;
         p.rsiBuyLevel=54.0;
         p.rsiSellLevel=46.0;
         p.cciBuyLevel=40.0;
         p.cciSellLevel=-40.0;
         break;
     }

   p.swingLeft=MathMax(1,p.swingLeft);
   p.swingRight=MathMax(1,p.swingRight);
   p.maxSetupAgeBars=MathMax(0,p.maxSetupAgeBars);
   p.patternWindowBars=MathMax(1,p.patternWindowBars);
   p.maxPendingBars=MathMax(0,p.maxPendingBars);
   p.entryBufferPips=MathMax(0.0,p.entryBufferPips);
   p.slBufferPips=MathMax(0.0,p.slBufferPips);
   p.minimumRR=MathMax(0.10,p.minimumRR);
   p.rsiBuyLevel=MathMax(50.01,MathMin(100.0,p.rsiBuyLevel));
   p.rsiSellLevel=MathMax(0.0,MathMin(49.99,p.rsiSellLevel));
   p.cciBuyLevel=MathMax(0.01,p.cciBuyLevel);
   p.cciSellLevel=MathMin(-0.01,p.cciSellLevel);
   p.rsiWeight=MathMax(0.0,p.rsiWeight);
   p.cciWeight=MathMax(0.0,p.cciWeight);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_AP_FindLeastSampled(const string symbol,
                            const int direction)
  {
   int best=0;
   double bestAttempts=DBL_MAX;

   ulong tieSeed=STB_AP_Hash(symbol+"|"+
                             (direction>0 ? "B":"S")+"|"+
                             (string)((long)(TimeCurrent()/900)));

   for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
     {
      double attempts=STB_AP_ReadAttempts(symbol,direction,p);

      if(attempts+1e-9<bestAttempts)
        {
         bestAttempts=attempts;
         best=p;
        }
      else
         if(MathAbs(attempts-bestAttempts)<=1e-9)
           {
            if((int)(tieSeed%STB_ADAPTIVE_PROFILE_COUNT)==p)
               best=p;
           }
     }

   return best;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_AP_SelectProfile(const string symbol,
                         const int direction)
  {
   if(!InpAdaptiveLearning || !InpAdaptiveParameterLearning)
      return 0;

// The first exploration gate is based on profile probes, not closed
// trades. A fresh tester/account must be able to leave Profile 0 even
// before the first position has closed.
   double totalStartupAttempts=0.0;

   for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
      totalStartupAttempts+=STB_AP_ReadAttempts(symbol,direction,p);

   if(totalStartupAttempts<=0.0)
      return 0;

   if(InpAdaptiveWarmupPerProfile>0)
     {
      for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
        {
         double attempts=STB_AP_ReadAttempts(symbol,direction,p);

         if(attempts+1e-9 < (double)InpAdaptiveWarmupPerProfile)
            return STB_AP_FindLeastSampled(symbol,direction);
        }
     }

   double totalOutcomeSamples=0.0;
   double totalAttempts=0.0;

   for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
     {
      double wins=0.0;
      double losses=0.0;
      STB_AP_ReadProfileStats(symbol,direction,p,wins,losses);
      totalOutcomeSamples+=wins+losses;
      totalAttempts+=STB_AP_ReadAttempts(symbol,direction,p);
     }

   int best=0;
   double bestValue=-DBL_MAX;
   double logOutcome=MathLog(1.0+totalOutcomeSamples);
   double logAttempts=MathLog(1.0+totalAttempts);

   for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
     {
      double wins=0.0;
      double losses=0.0;
      STB_AP_ReadProfileStats(symbol,direction,p,wins,losses);

      double outcomeSamples=wins+losses;
      double attempts=STB_AP_ReadAttempts(symbol,direction,p);

      double smoothedWinRate=(wins+1.0)/(outcomeSamples+2.0);

      double observations=0.0;
      double averageR=STB_AdaptiveReadProfileR(symbol,direction,p,observations);
      double rSignal=MathMax(-1.0,MathMin(2.0,averageR));

      // Two uncertainty channels are kept separate:
      // 1) trade-outcome uncertainty, based only on closed trades;
      // 2) exploration scarcity, based on profile probes.
      // Thus rejected/non-executable profiles are still explored, while
      // their lack of a trade is never misclassified as a win or loss.
      double outcomeExploration=
         MathMax(0.0,InpAdaptiveUCBExploration)*
         MathSqrt(logOutcome/(outcomeSamples+1.0));

      double probeExploration=
         0.50*MathMax(0.0,InpAdaptiveUCBExploration)*
         MathSqrt(logAttempts/(attempts+1.0));

      double value=
         0.45*smoothedWinRate+
         0.25*(rSignal/2.0+0.5)+
         0.15*outcomeExploration+
         0.15*probeExploration;

      if(value>bestValue)
        {
         bestValue=value;
         best=p;
        }
     }

   return best;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AP_SetActive(const int profileId)
  {
   STB_AP_LoadProfile(profileId,g_activeAdaptiveProfile);
   g_activeAdaptiveProfileValid=true;
   g_activeAdaptiveProfileId=g_activeAdaptiveProfile.id;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AP_SelectActive(const string symbol,
                         const int direction)
  {
   STB_AP_SetActive(STB_AP_SelectProfile(symbol,direction));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AP_ClearActive()
  {
   g_activeAdaptiveProfileValid=false;
   g_activeAdaptiveProfileId=0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_EffectiveSwingLeft(const ENUM_TIMEFRAMES tf)
  {
   if(tf==PERIOD_M15 && g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.swingLeft;

   return InpSwingLeft;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_EffectiveSwingRight(const ENUM_TIMEFRAMES tf)
  {
   if(tf==PERIOD_M15 && g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.swingRight;

   return InpSwingRight;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_EffectivePatternWindow()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.patternWindowBars;

   return InpPatternWindowBars;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_EffectiveMaxSetupAgeBars()
  {
   // An explicit zero disables the setup-age gate globally, including adaptive profiles.
   if(InpMaxSetupAgeBars<=0)
      return 0;

   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.maxSetupAgeBars;

   return InpMaxSetupAgeBars;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_EffectiveMaxPendingBars()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.maxPendingBars;

   return InpMaxPendingBars;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveEntryBuffer()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.entryBufferPips;

   return InpEntryBufferPips;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveSLBuffer()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.slBufferPips;

   return InpSLBufferPips;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveMinimumRR()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.minimumRR;

   return InpMinimumRR;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveRSIBuy()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.rsiBuyLevel;

   return InpRSIBuyLevel;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveRSISell()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.rsiSellLevel;

   return InpRSISellLevel;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveCCIBuy()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.cciBuyLevel;

   return InpCCIBuyLevel;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveCCISell()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.cciSellLevel;

   return InpCCISellLevel;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveRSIWeight()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.rsiWeight;

   return InpRSIWeight;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_EffectiveCCIWeight()
  {
   if(g_activeAdaptiveProfileValid)
      return g_activeAdaptiveProfile.cciWeight;

   return InpCCIWeight;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_AdaptiveScoreFloor(const string symbol,
                              const int direction)
  {
   if(!InpAdaptiveLearning)
      return InpAdaptiveBaseScore;

   double wins=0.0;
   double losses=0.0;

   for(int p=0;p<STB_ADAPTIVE_PROFILE_COUNT;p++)
     {
      double pw=0.0;
      double pl=0.0;
      STB_AP_ReadProfileStats(symbol,direction,p,pw,pl);
      wins+=pw;
      losses+=pl;
     }

   double samples=wins+losses;

   if(samples<InpAdaptiveMinSamples)
      return MathMax(InpAdaptiveMinScore,
                     MathMin(InpAdaptiveMaxScore,
                             InpAdaptiveBaseScore));

   double winRate=wins/samples;
   double floor=InpAdaptiveBaseScore;

   if(winRate<InpAdaptiveWeakWinRate)
      floor+=MathAbs(InpAdaptiveStep);
   else
      if(winRate>InpAdaptiveStrongWinRate)
         floor-=MathAbs(InpAdaptiveStep);

   return MathMax(InpAdaptiveMinScore,
                  MathMin(InpAdaptiveMaxScore,floor));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveLog(const string eventName,
                     const string symbol,
                     const int direction,
                     const double score,
                     const double rr,
                     const double outcome,
                     const int profileId)
  {
   if(!InpAdaptiveLearning)
      return;

   int h=FileOpen(InpAdaptiveLogFile,
                  FILE_READ|FILE_WRITE|FILE_CSV|
                  FILE_SHARE_READ|FILE_SHARE_WRITE,
                  ',');

   if(h==INVALID_HANDLE)
     {
      Print("STB ADAPTIVE: FileOpen failed err=",GetLastError());
      return;
     }

   FileSeek(h,0,SEEK_END);

   if(FileTell(h)==0)
      FileWrite(h,"time","event","account","magic","symbol",
                "direction","profile","score","rr","outcome","scoreFloor");

   FileWrite(h,
             TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
             eventName,
             (string)AccountInfoInteger(ACCOUNT_LOGIN),
             (string)InpMagic,
             symbol,
             direction>0 ? "BUY":"SELL",
             (string)profileId,
             DoubleToString(score,2),
             DoubleToString(rr,3),
             DoubleToString(outcome,2),
             DoubleToString(STB_AdaptiveScoreFloor(symbol,direction),2));

   FileFlush(h);
   FileClose(h);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveRecordSetup(const Setup &s,const bool accepted)
  {
   if(!InpAdaptiveLearning || s.setupTime<=0)
      return;

   string suffix=(accepted ? "DECISION_A":"DECISION_R");

   double lastLogged=STB_AP_Read(s.symbol,s.direction,
                                 suffix,s.adaptiveProfile,0.0);

   if((datetime)lastLogged==s.setupTime)
      return;

   STB_AP_Write(s.symbol,s.direction,
                suffix,s.adaptiveProfile,(double)s.setupTime);

   STB_AdaptiveLog(accepted ? "SETUP_PLACED":"SETUP_REJECTED",
                   s.symbol,s.direction,s.score,s.rr,
                   accepted ? 1.0:0.0,s.adaptiveProfile);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveRememberLastProfile(const string symbol,
                                     const int direction,
                                     const int profileId)
  {
   if(profileId<0 || profileId>=STB_ADAPTIVE_PROFILE_COUNT)
      return;

   STB_AP_Write(symbol,direction,"LASTP",0,profileId);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveRememberPositionProfile(const ulong positionId,
      const int profileId)
  {
   if(positionId==0 ||
      profileId<0 ||
      profileId>=STB_ADAPTIVE_PROFILE_COUNT)
      return;

   STB_AP_Write("POSITION",1,
                STB_AdaptivePositionRaw(positionId),
                0,profileId);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string STB_AdaptiveOrderRaw(const ulong orderTicket)
  {
   return (string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
          (string)InpMagic+"|AP3|ORDER|"+(string)orderTicket;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveRememberOrderProfile(const ulong orderTicket,
                                      const int profileId)
  {
   if(orderTicket==0 ||
      profileId<0 ||
      profileId>=STB_ADAPTIVE_PROFILE_COUNT)
      return;

   STB_AP_Write("ORDER_PROFILE",1,
                STB_AdaptiveOrderRaw(orderTicket),
                0,profileId);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_AdaptiveReadOrderProfile(const ulong orderTicket)
  {
   if(orderTicket==0)
      return -1;

   int profile=(int)MathRound(
                  STB_AP_Read("ORDER_PROFILE",1,
                              STB_AdaptiveOrderRaw(orderTicket),
                              0,-1.0));

   return (profile>=0 && profile<STB_ADAPTIVE_PROFILE_COUNT) ?
          profile:-1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveRememberOrderRisk(const ulong orderTicket,
                                   const double riskMoney)
  {
   if(orderTicket==0 || riskMoney<=0.0 || !MathIsValidNumber(riskMoney))
      return;

   STB_AP_Write("ORDER_RISK",1,
                STB_AdaptiveOrderRaw(orderTicket),
                0,riskMoney);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_AdaptiveReadOrderRisk(const ulong orderTicket)
  {
   if(orderTicket==0)
      return 0.0;

   return MathMax(0.0,
                  STB_AP_Read("ORDER_RISK",1,
                              STB_AdaptiveOrderRaw(orderTicket),
                              0,0.0));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveDeleteOrderState(const ulong orderTicket)
  {
   if(orderTicket==0)
      return;

   GlobalVariableDel(STB_AP_Key("ORDER_PROFILE",1,
                                STB_AdaptiveOrderRaw(orderTicket),0));
   GlobalVariableDel(STB_AP_Key("ORDER_RISK",1,
                                STB_AdaptiveOrderRaw(orderTicket),0));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string STB_AdaptivePositionRaw(const ulong positionId)
  {
   return (string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
          (string)InpMagic+"|AP3|POS|"+(string)positionId;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveRememberPositionRisk(const ulong positionId,
                                      const double riskMoney)
  {
   if(positionId==0 || riskMoney<=0.0 || !MathIsValidNumber(riskMoney))
      return;

   STB_AP_Write("POSITION_RISK",1,
                STB_AdaptivePositionRaw(positionId),
                0,riskMoney);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_AdaptiveReadPositionRisk(const ulong positionId)
  {
   if(positionId==0)
      return 0.0;

   return MathMax(0.0,
                  STB_AP_Read("POSITION_RISK",1,
                              STB_AdaptivePositionRaw(positionId),
                              0,0.0));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveDeletePositionRisk(const ulong positionId)
  {
   if(positionId==0)
      return;

   GlobalVariableDel(
      STB_AP_Key("POSITION_RISK",1,
                 STB_AdaptivePositionRaw(positionId),0));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_AdaptiveReadProfileR(const string symbol,
                                const int direction,
                                const int profile,
                                double &observations)
  {
   double decay=STB_AP_Decay(symbol,direction,profile);
   double sumR=STB_AP_Read(symbol,direction,"RSUM",profile,0.0)*decay;
   double rObservations=STB_AP_Read(symbol,direction,"RCOUNT",profile,0.0)*decay;

   // R expectancy is averaged only over closed trades whose initial
   // monetary risk was captured reliably. Missing risk must not dilute the
   // average toward zero through the win/loss denominator.
   observations=MathMax(0.0,rObservations);
   if(observations<=0.0)
      return 0.0;

   return sumR/observations;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_AdaptiveReadPositionProfile(const ulong positionId)
  {
   if(positionId==0)
      return -1;

   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
              (string)InpMagic+"|AP3|POS|"+(string)positionId;

   int profile=(int)MathRound(
                  STB_AP_Read("POSITION",1,raw,0,-1.0));

   return (profile>=0 && profile<STB_ADAPTIVE_PROFILE_COUNT) ?
          profile:-1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveDeletePositionProfile(const ulong positionId)
  {
   if(positionId==0)
      return;

   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
              (string)InpMagic+"|AP3|POS|"+(string)positionId;

   GlobalVariableDel(STB_AP_Key("POSITION",1,raw,0));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_AdaptiveParseProfileFromComment(const string comment)
  {
   int pos=StringFind(comment,"|P");
   if(pos<0)
      return -1;

   int id=(int)StringToInteger(StringSubstr(comment,pos+2));

   return (id>=0 && id<STB_ADAPTIVE_PROFILE_COUNT) ? id:-1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_AdaptiveIsHedgeComment(const string comment)
  {
   return StringFind(comment,"HEDGE")>=0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_AdaptiveRecordClosedDeal(const string symbol,
                                  const int direction,
                                  const double profit,
                                  const int profileId,
                                  const double rMultiple,
                                  const bool hasValidRiskSample)
  {
   if(!InpAdaptiveLearning || direction==0 ||
      !MathIsValidNumber(profit))
      return;

   if(profileId>=0 && profileId<STB_ADAPTIVE_PROFILE_COUNT)
     {
      double wins=0.0;
      double losses=0.0;
      STB_AP_ReadProfileStats(symbol,direction,profileId,wins,losses);

      // A genuine break-even lifecycle is one neutral observation, not a
      // missing sample: split it equally between wins and losses so it moves
      // the smoothed win rate toward 50% without inventing an edge.
      if(profit>0.0)
         wins+=1.0;
      else if(profit<0.0)
         losses+=1.0;
      else
        {
         wins+=0.5;
         losses+=0.5;
        }

      STB_AP_Write(symbol,direction,"W",profileId,wins);
      STB_AP_Write(symbol,direction,"L",profileId,losses);

      double decay=STB_AP_Decay(symbol,direction,profileId);
      double oldRSum=STB_AP_Read(symbol,direction,
                                 "RSUM",profileId,0.0)*decay;
      double oldRCount=STB_AP_Read(symbol,direction,
                                   "RCOUNT",profileId,0.0)*decay;

      // Keep expectancy in R separate from the win/loss sample count. Only
      // trades with a known positive initial-risk denominator enter this mean.
      if(hasValidRiskSample && MathIsValidNumber(rMultiple))
        {
         oldRSum+=rMultiple;
         oldRCount+=1.0;
        }

      STB_AP_Write(symbol,direction,"RSUM",profileId,oldRSum);
      STB_AP_Write(symbol,direction,"RCOUNT",profileId,oldRCount);
      STB_AP_Write(symbol,direction,"T",profileId,(double)TimeCurrent());
     }

   Print("STB ADAPTIVE outcome symbol=",symbol,
         " dir=",(direction>0 ? "BUY":"SELL"),
         " profile=",IntegerToString(profileId),
         " outcome=",DoubleToString(profit,2),
         " R=",hasValidRiskSample ? DoubleToString(rMultiple,2):"UNAVAILABLE",
         " floor=",DoubleToString(STB_AdaptiveScoreFloor(symbol,direction),1));

   STB_AdaptiveLog("TRADE_CLOSED",symbol,direction,
                   0.0,0.0,profit,profileId);

   GlobalVariablesFlush();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_BuildReject(const string symbol,
                     const int direction,
                     const string reason)
  {
   g_lastBuildRejectReason=reason;
   STB_LogBuildReject(symbol,direction,reason);
   STB_AP_ClearActive();
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_LogBuildReject(const string symbol,
                        const int direction,
                        const string reason)
  {
   datetime bar=iTime(symbol,PERIOD_M15,0);
   if(bar<=0)
      bar=TimeCurrent();

   int idx=-1;

   for(int i=0;i<ArraySize(g_diagnosticStates);i++)
     {
      if(g_diagnosticStates[i].symbol==symbol &&
         g_diagnosticStates[i].direction==direction)
        {
         idx=i;
         break;
        }
     }

   if(idx<0)
     {
      idx=ArraySize(g_diagnosticStates);
      if(ArrayResize(g_diagnosticStates,idx+1)!=idx+1)
        {
         Print("STB diagnostic state allocation failed symbol=",symbol,
               " direction=",direction);
         return;
        }
      g_diagnosticStates[idx].symbol=symbol;
      g_diagnosticStates[idx].direction=direction;
      g_diagnosticStates[idx].lastBar=0;
      g_diagnosticStates[idx].lastReason="";
      g_diagnosticStates[idx].lastReadyBar=0;
     }

   if(bar!=g_diagnosticStates[idx].lastBar ||
      reason!=g_diagnosticStates[idx].lastReason)
     {
      Print("STB SETUP REJECT symbol=",symbol,
            " dir=",(direction>0 ? "BUY":"SELL"),
            " reason=",reason,
            " profile=",IntegerToString(g_activeAdaptiveProfileId));

      g_diagnosticStates[idx].lastBar=bar;
      g_diagnosticStates[idx].lastReason=reason;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_LogSetupReady(const Setup &s)
  {
   if(!s.valid)
      return;

   int idx=-1;

   for(int i=0;i<ArraySize(g_diagnosticStates);i++)
     {
      if(g_diagnosticStates[i].symbol==s.symbol &&
         g_diagnosticStates[i].direction==s.direction)
        {
         idx=i;
         break;
        }
     }

   if(idx<0)
     {
      idx=ArraySize(g_diagnosticStates);
      if(ArrayResize(g_diagnosticStates,idx+1)!=idx+1)
        {
         Print("STB ready-state diagnostic allocation failed symbol=",s.symbol,
               " direction=",s.direction);
         return;
        }
      g_diagnosticStates[idx].symbol=s.symbol;
      g_diagnosticStates[idx].direction=s.direction;
      g_diagnosticStates[idx].lastBar=0;
      g_diagnosticStates[idx].lastReason="";
      g_diagnosticStates[idx].lastReadyBar=0;
     }

   if(g_diagnosticStates[idx].lastReadyBar==s.setupTime)
      return;

   g_diagnosticStates[idx].lastReadyBar=s.setupTime;

   Print("STB SETUP READY symbol=",s.symbol,
         " dir=",(s.direction>0 ? "BUY":"SELL"),
         " profile=",IntegerToString(s.adaptiveProfile),
         " score=",DoubleToString(s.score,1),
         " RR=",DoubleToString(s.rr,2),
         " trend=",s.trendAligned ? "ALIGNED":"UNIVERSAL");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_AdaptiveTesterCriterion()
  {
   if(!MQLInfoInteger(MQL_TESTER))
      return 0.0;

   double profit=TesterStatistics(STAT_PROFIT);
   double pf=TesterStatistics(STAT_PROFIT_FACTOR);
   double dd=TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double sharpe=TesterStatistics(STAT_SHARPE_RATIO);
   double trades=TesterStatistics(STAT_TRADES);
   double expected=TesterStatistics(STAT_EXPECTED_PAYOFF);
   double recovery=TesterStatistics(STAT_RECOVERY_FACTOR);
   double deposit=TesterStatistics(STAT_INITIAL_DEPOSIT);

   if(!MathIsValidNumber(profit) || !MathIsValidNumber(pf) ||
      !MathIsValidNumber(dd) || !MathIsValidNumber(sharpe) ||
      !MathIsValidNumber(trades) || !MathIsValidNumber(expected) ||
      !MathIsValidNumber(recovery) || !MathIsValidNumber(deposit) ||
      deposit<=0.0)
      return -1.0e12;

   if(pf==DBL_MAX)
      pf=10.0;
   if(recovery==DBL_MAX)
      recovery=0.0;

   // Do not let a low-trade-count or losing optimization pass outrank a
   // candidate with a real positive edge. The previous multiplicative score
   // could reward a negative-return pass when its stability multiplier was
   // smaller (less negative score), which is the wrong optimization ordering.
   if(trades<30.0)
      return -1.0e9+trades;

   double returnPct=(profit/deposit)*100.0;
   if(!MathIsValidNumber(returnPct))
      return -1.0e12;

   // Require both positive net profit and PF > 1 before applying secondary
   // quality metrics. This is an optimizer ranking guard, not a live-trading
   // filter and does not guarantee out-of-sample profitability.
   if(profit<=0.0 || pf<=1.0 || expected<=0.0)
      return -1.0e6+MathMax(-100.0,MathMin(0.0,returnPct));

   pf=MathMax(0.0,MathMin(5.0,pf));
   sharpe=MathMax(-5.0,MathMin(5.0,sharpe));
   dd=MathMax(0.0,dd);
   recovery=MathMax(-10.0,MathMin(10.0,recovery));

   double payoffPct=(expected/deposit)*100.0;
   if(!MathIsValidNumber(payoffPct))
      return -1.0e12;

   returnPct=MathMax(-100.0,MathMin(100.0,returnPct));
   payoffPct=MathMax(-10.0,MathMin(10.0,payoffPct));

   // Keep profit as the primary objective; PF, Sharpe, payoff, recovery and
   // equity drawdown are bounded secondary modifiers. All candidates passing
   // the positive-edge gate therefore rank above rejected losing candidates.
   double quality=
      1.0+
      pf*0.12+
      MathMax(-5.0,MathMin(5.0,sharpe))*0.06+
      MathMax(-1.0,MathMin(1.0,payoffPct*0.10))*0.08+
      MathMax(-1.0,MathMin(1.0,recovery*0.10))*0.06;

   quality=MathMax(0.25,quality);
   double confidence=MathMin(1.0,trades/50.0);
   double score=returnPct*quality*confidence/(1.0+dd*0.10);

   return MathIsValidNumber(score) ? score:-1.0e12;
  }


//==================================================================
// GLOBALS
//==================================================================

string g_prefix = "STB_";
string g_autoStateName = "";
bool   g_autoTrading = false;
bool   g_stbOriginalMouseMoveEvents = false;
bool   g_stbMouseMoveEventsCaptured = false;
datetime g_lastM15Bar = 0;
STBIndicatorCache g_indicatorCache[];
datetime g_lastChartBar = 0;
bool g_stbManagementCycleActive = false;
bool g_stbManagementCyclePending = false;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//==================================================================
// GENERAL UTILITY
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string Upper(const string value)
  {
   string s = value;
   StringToUpper(s);
   return s;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double PipSize(const string symbol)
  {
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

   if(point<=0.0)
      return 0.0;

   if(InpPipPointsOverride>0.0)
      return point*InpPipPointsOverride;

   if(digits==3 || digits==5)
      return point*10.0;

   string s=Upper(symbol);
   if(StringFind(s,"XAU")>=0 ||
      StringFind(s,"GOLD")>=0 ||
      StringFind(s,"XAG")>=0 ||
      StringFind(s,"SILVER")>=0)
      return point*10.0;

   return point;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizePrice(const string symbol,const double price)
  {
   if(price<=0.0)
      return 0.0;

   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);

   if(tickSize<=0.0)
      return NormalizeDouble(price,digits);

   double normalized=MathRound(price/tickSize)*tickSize;

   return NormalizeDouble(normalized,digits);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizeVolume(const string symbol,double volume)
  {
   double minLot = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);

   // Never turn a disabled/zero-volume request or an undersized request into
   // the broker minimum. That can silently turn a 0x multiplier into a trade
   // or increase the exposure beyond the configured fixed/risk volume.
   if(!MathIsValidNumber(volume) || volume<=0.0 ||
      minLot<=0.0 || maxLot<minLot || step<=0.0)
      return 0.0;

   if(volume+1e-9<minLot)
      return 0.0;

   volume=MathMin(maxLot,volume);
   volume=MathFloor(volume/step+1e-9)*step;

   // Floating point flooring can dip just below a valid minimum. Use the
   // broker minimum only when the original request already met that minimum.
   if(volume<minLot)
      volume=minLot;

   // Derive decimal precision from the broker's actual volume step.
   // Fixed thresholds (0.01/0.001) break valid grids such as 0.125.
   int digits=-1;
   for(int d=0;d<=8;d++)
     {
      double scaledStep=step*MathPow(10.0,d);
      if(MathAbs(scaledStep-MathRound(scaledStep))<=1e-8)
        {
         digits=d;
         break;
        }
     }

   if(digits<0)
      return 0.0;

   double normalized=NormalizeDouble(volume,digits);
   if(normalized<minLot-1e-9 || normalized>maxLot+1e-9)
      return 0.0;

   // Fail closed if decimal normalization no longer lies on the broker grid.
   double stepUnits=normalized/step;
   if(!MathIsValidNumber(stepUnits) ||
      MathAbs(stepUnits-MathRound(stepUnits))>1e-7)
      return 0.0;

   return normalized;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool GetRates(const string symbol,
              const ENUM_TIMEFRAMES tf,
              const int count,
              MqlRates &rates[])
  {
   if(count<=0 || !SymbolSelect(symbol,true))
      return false;

   // Do not block the history request on the symbol-wide synchronization flag.
   // CopyRates initiates/continues downloading or building the requested
   // symbol/timeframe series. Keep the full-count requirement so incomplete
   // history is never consumed by the structure and entry calculations.
   ArraySetAsSeries(rates,true);

   int copied=CopyRates(symbol,tf,0,count,rates);

   return copied>=count;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSymbolTradable(const string symbol)
  {
   if(!SymbolInfoInteger(symbol,SYMBOL_SELECT))
      return false;

   long tradeMode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);

   if(tradeMode == SYMBOL_TRADE_MODE_DISABLED ||
      tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
      return false;

   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return false;

   if(tick.bid <= 0.0 || tick.ask <= 0.0)
      return false;

   return true;
  }

// Check direction-specific symbol permissions before building or sending
// a setup. SYMBOL_TRADE_MODE and SYMBOL_ORDER_MODE are broker-side
// permissions and can change during the session.
bool IsDirectionTradable(const string symbol,const int direction)
  {
   if(!IsSymbolTradable(symbol))
      return false;

   long tradeMode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
   if(direction>0 && tradeMode==SYMBOL_TRADE_MODE_SHORTONLY)
      return false;
   if(direction<0 && tradeMode==SYMBOL_TRADE_MODE_LONGONLY)
      return false;

   long orderMode=SymbolInfoInteger(symbol,SYMBOL_ORDER_MODE);

// This EA currently places BUY_STOP / SELL_STOP with SL + TP.
   if((orderMode & SYMBOL_ORDER_STOP)!=SYMBOL_ORDER_STOP)
      return false;
   if((orderMode & SYMBOL_ORDER_SL)!=SYMBOL_ORDER_SL)
      return false;
   if((orderMode & SYMBOL_ORDER_TP)!=SYMBOL_ORDER_TP)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_TradeEnvironmentAllowed()
  {
   bool terminalAllowed=(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)!=0);
   bool programAllowed=(MQLInfoInteger(MQL_TRADE_ALLOWED)!=0);
   bool accountAllowed=(AccountInfoInteger(ACCOUNT_TRADE_EXPERT)!=0);
   bool accountTradeAllowed=(AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)!=0);

   if(!terminalAllowed || !programAllowed ||
      !accountAllowed || !accountTradeAllowed)
     {
      Print("STB TRADE ENV REJECT",
            " terminal=",terminalAllowed ? "ON":"OFF",
            " program=",programAllowed ? "ON":"OFF",
            " expert=",accountAllowed ? "ON":"OFF",
            " accountTrade=",accountTradeAllowed ? "ON":"OFF",
            " tester=",MQLInfoInteger(MQL_TESTER) ? "YES":"NO");
      return false;
     }

   return true;
  }

void STB_LogControlReject(const string action,
                          const string reason,
                          const string detail="")
  {
   Print("STB CONTROL REJECT action=",action,
         " symbol=",_Symbol,
         " reason=",reason,
         (detail=="" ? "" : " detail="),detail);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSpreadAcceptable(const string symbol)
  {
   if(InpMaxSpreadPips<=0.0)
      return true;

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return false;

   double pip=PipSize(symbol);
   if(pip<=0.0 || tick.ask<=tick.bid)
      return false;

   double spreadPips=(tick.ask-tick.bid)/pip;

   return spreadPips<=InpMaxSpreadPips+1e-9;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool TradeRetcodeModifySucceeded()
  {
   uint ret=trade.ResultRetcode();

   // A modify request changes order geometry; partial execution is not
   // a valid success signal for that operation.
   return ret==TRADE_RETCODE_DONE ||
          ret==TRADE_RETCODE_NO_CHANGES ||
          ret==TRADE_RETCODE_ORDER_CHANGED;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool TradeRetcodePlacementSucceeded()
  {
   uint ret=trade.ResultRetcode();

   // Pending-order placement is accepted only when the server confirms
   // completion or placement. PARTIAL is a deal/execution result, not proof
   // that a pending order was placed; NO_CHANGES applies to existing objects.
   return ret==TRADE_RETCODE_DONE ||
          ret==TRADE_RETCODE_PLACED;
  }

// Minimum distance required by the broker for pending price, SL and TP.
// Uses both STOP and FREEZE levels because some symbols expose a valid
// STOP level while still rejecting a pending order inside the FREEZE zone.
double TradeMinDistance(const string symbol)
  {
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);

   if(point<=0.0)
      return 0.0;

   long stops=(long)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   long freeze=(long)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);

   long level=MathMax(stops,freeze);

// One extra point avoids equality/rounding rejection at the broker boundary.
   return ((double)level+1.0)*point;
  }
//==================================================================
// CENTRALIZED PENDING GEOMETRY CONTRACT
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_ValidatePendingGeometry(const string symbol,
                                 const int direction,
                                 const double entry,
                                 const double sl,
                                 const double tp,
                                 const bool requireTP,
                                 const double minimumRR,
                                 string &reason)
  {
   reason="OK";

   if(direction!=1 && direction!=-1)
     {
      reason="INVALID_DIRECTION";
      return false;
     }

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
     {
      reason="NO_TICK";
      return false;
     }

   double minDist=TradeMinDistance(symbol);
   if(minDist<=0.0 || entry<=0.0 || sl<=0.0)
     {
      reason="INVALID_GEOMETRY";
      return false;
     }

   double risk=0.0;

   if(direction>0)
     {
      if(entry<=tick.ask+minDist)
        {
         reason="BUY_ENTRY_TOO_CLOSE";
         return false;
        }

      if(sl>=entry || tick.bid-sl<minDist)
        {
         reason="BUY_SL_INVALID";
         return false;
        }

      risk=entry-sl;

      if(requireTP && (tp<=entry || tp-entry<minDist))
        {
         reason="BUY_TP_INVALID";
         return false;
        }
     }
   else
     {
      if(entry>=tick.bid-minDist)
        {
         reason="SELL_ENTRY_TOO_CLOSE";
         return false;
        }

      if(sl<=entry || sl-tick.ask<minDist)
        {
         reason="SELL_SL_INVALID";
         return false;
        }

      risk=sl-entry;

      if(requireTP && (tp>=entry || entry-tp<minDist))
        {
         reason="SELL_TP_INVALID";
         return false;
        }
     }

   if(risk<=0.0)
     {
      reason="RISK_INVALID";
      return false;
     }

   if(requireTP)
     {
      double reward=MathAbs(tp-entry);
      double rr=reward/risk;

      if(reward<=0.0 || rr+1e-9<MathMax(0.0,minimumRR))
        {
         reason="RR_BELOW_MINIMUM";
         return false;
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//--- P4: pending geometry policy helpers (single source of truth) ---
// Entry direction is type-specific: +1 means favorable entry moves UP,
// -1 means favorable entry moves DOWN. STOP kinds follow breakouts; LIMIT
// kinds follow pullbacks. This is the final broker-writer monotonic barrier.
int STB_PendingEntryImproveSign(const long orderType)
  {
   ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)orderType;
   bool isBuy=STB_PendingIsBuySide(type);
   bool isSell=STB_PendingIsSellSide(type);

   if(STB_PendingIsStopKind(type))
     {
      if(isBuy)  return 1;  // BUY STOP / BUY STOP-LIMIT: ratchet up
      if(isSell) return -1; // SELL STOP / SELL STOP-LIMIT: ratchet down
     }
   else
     {
      if(isBuy)  return -1; // BUY LIMIT: pullback entry moves down
      if(isSell) return 1;  // SELL LIMIT: pullback entry moves up
     }

   return 0;
  }

bool STB_PendingEntryDirectionOK(const long orderType,const double curEntry,
                                 const double newEntry,const double tolerance)
  {
   if(curEntry<=0.0 || newEntry<=0.0)
      return false;

   int sign=STB_PendingEntryImproveSign(orderType);

   if(sign>0)
      return (newEntry>=curEntry-tolerance);   // favorable direction is UP
   if(sign<0)
      return (newEntry<=curEntry+tolerance);   // favorable direction is DOWN

   return false;
  }

bool STB_PendingRiskFloorOK(const long orderType,const double curEntry,
                            const double curSL,const double newEntry,
                            const double newSL)
  {
   if(curSL<=0.0 || curEntry<=0.0)
      return true;   // no current SL -> initial structural SL may be created

   double origRisk=MathAbs(curEntry-curSL);
   double newRisk=MathAbs(newEntry-newSL);

   if(origRisk<=0.0)
      return true;

   double cap=MathMin(1.0,(InpPendingTrailMaxRiskExpansion>0.0 ? InpPendingTrailMaxRiskExpansion : 1.0)); // P9 HARD CAP: pending-trail risk can never expand beyond 1.0

   return (newRisk<=origRisk*cap);
  }

// Stop-Limit orders activate a child LIMIT at ORDER_PRICE_STOPLIMIT, not at
// the trigger price. Their SL must therefore remain on the protective side of
// the child fill price as well as passing the trigger-price validation.
bool STB_StopLimitSLSideOK(const ENUM_ORDER_TYPE orderType,
                           const double stopLimit,
                           const double sl)
  {
   if(orderType==ORDER_TYPE_BUY_STOP_LIMIT)
      return (stopLimit>0.0 && sl>0.0 && sl<stopLimit);

   if(orderType==ORDER_TYPE_SELL_STOP_LIMIT)
      return (stopLimit>0.0 && sl>stopLimit);

   return true;
  }

bool STB_ModifyPendingOrderGeometry(const ulong ticket,
                                    const double newEntry,
                                    const double newSL,
                                    const double newTP,
                                    string &failureReason,
                                    const bool isUserAction=false)
  {
   failureReason="UNCLASSIFIED_WRITER_FAILURE";
   if(ticket==0 || !OrderSelect(ticket))
     {
      failureReason="INVALID_TICKET_OR_ORDER_MISSING";
      return false;
     }

   string symbol=OrderGetString(ORDER_SYMBOL);
   if(!IsManagedOrder(ticket))
     {
      failureReason="ORDER_NOT_MANAGED";
      return false;
     } // P1 writer safety barrier
   if(STB_ExposureEnsure(ticket,false)<0)
     {
      failureReason="EXPOSURE_REGISTRY_ALLOCATION_FAILED";
      Print("STB PENDING MODIFY DEFERRED ticket=",ticket,
            " reason=",failureReason);
      return false;
     }
   if(!STB_SymbolManagementOwnedVerified(symbol))
     {
      failureReason="SYMBOL_WRITER_OWNERSHIP_NOT_VERIFIED";
      return false;
     } // P6/P10 cross-instance single pending writer

   MqlTick pendingWriteTick;
   string pendingQuoteReason="";
   if(!SymbolInfoTick(symbol,pendingWriteTick) ||
      !STB_ScannerQuoteValid(pendingWriteTick,pendingQuoteReason))
     {
      failureReason=(pendingQuoteReason=="" ? "QUOTE_UNAVAILABLE":pendingQuoteReason);
      Print("STB PENDING MODIFY DEFERRED ticket=",ticket,
            " symbol=",symbol,
            " reason=",failureReason);
      return false;
     }

   //--- P4 central writer: verify symbol, re-read geometry, validate
   //--- broker constraints, monotonic entry direction and risk floor.
   long stbOt=OrderGetInteger(ORDER_TYPE);
   // Manual/mobile/foreign pending orders remain under the universal manager.
   // Override metadata may control local expiry policy, never SL/trailing protection.
   double stbCurEntry=OrderGetDouble(ORDER_PRICE_OPEN);
   double stbCurSL=OrderGetDouble(ORDER_SL);
   double stbCurTP=OrderGetDouble(ORDER_TP);
   double stbPoint=SymbolInfoDouble(symbol,SYMBOL_POINT);

   if(!IsValidSLForPendingOrder(symbol,(ENUM_ORDER_TYPE)stbOt,newEntry,newSL))
     {
      failureReason="SL_INVALID_FOR_PENDING_ORDER";
      return false;
     }

   if(!STB_PendingEntryDirectionOK(stbOt,stbCurEntry,newEntry,stbPoint*0.5))
     {
      failureReason="ENTRY_DIRECTION_POLICY_REJECTED";
      return false;
     }

   if(!STB_PendingRiskFloorOK(stbOt,stbCurEntry,stbCurSL,newEntry,newSL))
     {
      failureReason="RISK_EXPANSION_FLOOR_REJECTED";
      return false;
     }


   if(newEntry<=0.0)
     {
      failureReason="ENTRY_PRICE_NONPOSITIVE";
      return false;
     }

   ENUM_ORDER_TYPE_TIME typeTime=
      (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
   datetime expiration=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
   double stopLimit=OrderGetDouble(ORDER_PRICE_STOPLIMIT);

   // Keep a Stop-Limit's trigger-to-limit offset when trailing its trigger.
   // Leaving stoplimit unchanged would detach the child limit price from the
   // moved stop price and can make a valid order invalid or behave differently.
   if(stbOt==ORDER_TYPE_BUY_STOP_LIMIT ||
      stbOt==ORDER_TYPE_SELL_STOP_LIMIT)
     {
      if(stbCurEntry<=0.0 || stopLimit<=0.0)
        {
         failureReason="STOP_LIMIT_ORIGINAL_GEOMETRY_INVALID";
         return false;
        }

      double stopLimitOffset=stopLimit-stbCurEntry;
      stopLimit=NormalizePrice(symbol,newEntry+stopLimitOffset);

      bool offsetValid=(stopLimit>0.0 &&
                        ((stbOt==ORDER_TYPE_BUY_STOP_LIMIT && stopLimit<newEntry) ||
                         (stbOt==ORDER_TYPE_SELL_STOP_LIMIT && stopLimit>newEntry)));

      if(!offsetValid)
        {
         failureReason="STOP_LIMIT_OFFSET_INVALID";
         Print("STB STOP-LIMIT MODIFY REJECT ticket=",ticket,
               " symbol=",symbol,
               " oldEntry=",DoubleToString(stbCurEntry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
               " newEntry=",DoubleToString(newEntry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
               " newStopLimit=",DoubleToString(stopLimit,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
         return false;
        }

      if(!STB_StopLimitSLSideOK((ENUM_ORDER_TYPE)stbOt,stopLimit,newSL))
        {
         failureReason="STOP_LIMIT_SL_WRONG_SIDE_OF_CHILD_LIMIT";
         Print("STB STOP-LIMIT SL REJECT ticket=",ticket,
               " symbol=",symbol,
               " type=",EnumToString((ENUM_ORDER_TYPE)stbOt),
               " trigger=",DoubleToString(newEntry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
               " childLimit=",DoubleToString(stopLimit,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
               " sl=",DoubleToString(newSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
         return false;
        }
     }

   // One broker geometry write per ticket per management cycle. This also
   // prevents ManagePendingOrders' initial-SL repair and the trailing engine
   // from both modifying the same pending ticket in one cycle.
   if(STB_CycleWriteAlreadyDone(ticket))
     {
      failureReason="CYCLE_WRITE_BUDGET_ALREADY_USED";
      return false;
     }

   MqlTradeRequest req={};
   MqlTradeCheckResult check={};

   req.action=TRADE_ACTION_MODIFY;
   req.order=ticket;
   req.symbol=symbol;
   req.price=newEntry;
   req.sl=newSL;
   req.tp=newTP;
   req.type_time=typeTime;
   req.expiration=expiration;
   req.stoplimit=stopLimit;

   ResetLastError();

   if(!OrderCheck(req,check))
     {
      failureReason="ORDERCHECK_CALL_FAILED";
      Print("STB PENDING MODIFY ORDERCHECK CALL FAILED ticket=",ticket,
            " symbol=",symbol,
            " lastError=",GetLastError());
      return false;
     }

   // OrderCheck success is retcode=0 in this terminal/broker path.
   if(check.retcode!=0)
     {
      failureReason="ORDERCHECK_REJECTED";
      Print("STB PENDING MODIFY ORDERCHECK REJECT ticket=",ticket,
            " symbol=",symbol,
            " ret=",IntegerToString((int)check.retcode),
            " comment=",check.comment);
      return false;
     }

   // OrderCheck can take time. Re-read the ticket and verify that both the
   // symbol-writer lease and the geometry snapshot are still ours to modify.
   if(!OrderSelect(ticket) || !IsManagedOrder(ticket))
     {
      failureReason="ORDER_CHANGED_OR_REMOVED_DURING_ORDERCHECK";
      return false;
     }
   if(OrderGetString(ORDER_SYMBOL)!=symbol ||
      OrderGetInteger(ORDER_TYPE)!=stbOt)
     {
      failureReason="ORDER_SYMBOL_OR_TYPE_CHANGED_DURING_ORDERCHECK";
      return false;
     }
   // Do not re-enable a manual-override pause after OrderCheck: every
   // managed pending order remains eligible for automatic protection/trailing.
   double latestEntry=OrderGetDouble(ORDER_PRICE_OPEN);
   double latestSL=OrderGetDouble(ORDER_SL);
   double latestTP=OrderGetDouble(ORDER_TP);
   double latestPoint=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double latestTickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double latestTolerance=MathMax(latestPoint*0.5,
                                  latestTickSize>0.0 ? latestTickSize*0.5:latestPoint*0.5);
   if(MathAbs(latestEntry-stbCurEntry)>latestTolerance ||
      MathAbs(latestSL-stbCurSL)>latestTolerance ||
      MathAbs(latestTP-stbCurTP)>latestTolerance)
     {
      failureReason="ORDER_GEOMETRY_CHANGED_DURING_ORDERCHECK";
      return false;
     }

   if(!STB_SymbolManagementOwnedVerified(symbol) ||
      !IsValidSLForPendingOrder(symbol,(ENUM_ORDER_TYPE)stbOt,newEntry,newSL) ||
      !STB_StopLimitSLSideOK((ENUM_ORDER_TYPE)stbOt,stopLimit,newSL) ||
      !STB_PendingEntryDirectionOK(stbOt,latestEntry,newEntry,latestTolerance) ||
      !STB_PendingRiskFloorOK(stbOt,latestEntry,latestSL,newEntry,newSL))
     {
      failureReason="FINAL_PRE_SUBMIT_VALIDATION_REJECTED";
      return false;
     }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetAsyncMode(false);
   trade.SetTypeFilling(ORDER_FILLING_RETURN);

   // Consume the ticket's one-write budget before the broker request. A
   // timeout or ambiguous response may still have changed server state; do not
   // issue a second geometry write for this ticket in the same cycle.
   STB_CycleMarkWritten(ticket);

   // Capture a clean terminal error code and the trade result immediately
   // at the broker-call boundary. OrderSelect/geometry-cache operations below
   // may overwrite the terminal's last-error state.
   ResetLastError();
   if(!trade.OrderModify(ticket,newEntry,newSL,newTP,
                         typeTime,expiration,stopLimit))
     {
      int modifyLastError=GetLastError();
      uint modifyRetcode=trade.ResultRetcode();
      string modifyRetcodeDescription=trade.ResultRetcodeDescription();
      string modifyComment=trade.ResultComment();

      failureReason="BROKER_ORDERMODIFY_RETURNED_FALSE";
      if(OrderSelect(ticket))
         STB_GeomStore(ticket,false,
                       OrderGetDouble(ORDER_PRICE_OPEN),
                       OrderGetDouble(ORDER_SL),
                       OrderGetDouble(ORDER_TP));
      Print("STB PENDING MODIFY BROKER CALL FAILED ticket=",ticket,
            " symbol=",symbol,
            " lastError=",modifyLastError,
            " retcode=",modifyRetcode,
            " retcodeDescription=",modifyRetcodeDescription,
            " comment=",modifyComment);
      return false;
     }

   if(!TradeRetcodeModifySucceeded())
     {
      failureReason="BROKER_RETCODE_NOT_SUCCESS";
      Print("STB PENDING MODIFY BROKER REJECTED ticket=",ticket,
            " symbol=",symbol,
            " retcode=",trade.ResultRetcode(),
            " retcodeDescription=",trade.ResultRetcodeDescription(),
            " comment=",trade.ResultComment());
      if(OrderSelect(ticket))
         STB_GeomStore(ticket,false,
                       OrderGetDouble(ORDER_PRICE_OPEN),
                       OrderGetDouble(ORDER_SL),
                       OrderGetDouble(ORDER_TP));
      return false;
     }

   if(!OrderSelect(ticket))
     {
      failureReason="ORDER_NOT_SELECTABLE_AFTER_MODIFY";
      return false;
     }

   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double tolerance=MathMax(point*0.5,
                            tickSize>0.0 ? tickSize*0.5:point*0.5);

   long verifiedType=OrderGetInteger(ORDER_TYPE);
   double ve=OrderGetDouble(ORDER_PRICE_OPEN);
   double vs=OrderGetDouble(ORDER_SL);
   double vt=OrderGetDouble(ORDER_TP);
   double verifiedStopLimit=OrderGetDouble(ORDER_PRICE_STOPLIMIT);
   bool isStopLimit=(stbOt==ORDER_TYPE_BUY_STOP_LIMIT ||
                     stbOt==ORDER_TYPE_SELL_STOP_LIMIT);

   if(verifiedType!=stbOt ||
      MathAbs(ve-newEntry)>tolerance ||
      MathAbs(vs-newSL)>tolerance ||
      MathAbs(vt-newTP)>tolerance ||
      (isStopLimit && MathAbs(verifiedStopLimit-stopLimit)>tolerance))
     {
      // Cache the actual server geometry, never an unconfirmed proposal.
      // Stop-limit tickets also verify the child limit price, not just the
      // trigger Entry/SL/TP. A broker-side mismatch is not a committed trail.
      STB_GeomStore(ticket,false,ve,vs,vt);
      failureReason="POST_MODIFY_GEOMETRY_VERIFICATION_FAILED";
      Print("STB PENDING MODIFY POSTCHECK FAILED ticket=",ticket,
            " symbol=",symbol,
            " expectedType=",EnumToString((ENUM_ORDER_TYPE)stbOt),
            " actualType=",EnumToString((ENUM_ORDER_TYPE)verifiedType),
            " entryExpected=",DoubleToString(newEntry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " entryActual=",DoubleToString(ve,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " stopLimitExpected=",DoubleToString(stopLimit,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " stopLimitActual=",DoubleToString(verifiedStopLimit,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
      return false;
     }

   STB_GeomStore(ticket,false,ve,vs,vt); // MANUAL_OVERRIDE: verified own write only
   STB_CycleMarkWritten(ticket); // one pending geometry write per cycle
   failureReason="VERIFIED_SUCCESS";
   return true;
  }

// Normalize a pending setup against the live market and the broker's
// symbol-specific stop/freeze constraints. Returns false if the resulting
// geometry cannot satisfy the requested RR.
bool PreparePendingSetup(Setup &s,string &failureReason)
  {
   failureReason="UNSPECIFIED";
   MqlTick tick;

   if(!SymbolInfoTick(s.symbol,tick))
     {
      failureReason="SYMBOL_TICK_UNAVAILABLE";
      return false;
     }

   double point=SymbolInfoDouble(s.symbol,SYMBOL_POINT);
   int digits=(int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS);
   double minDist=TradeMinDistance(s.symbol);

   if(point<=0.0)
     {
      failureReason="INVALID_SYMBOL_POINT";
      return false;
     }

   if(minDist<=0.0)
      minDist=point;

   // Keep STOP entries strictly beyond the broker-distance boundary checked below.
   double entryStep=SymbolInfoDouble(s.symbol,SYMBOL_TRADE_TICK_SIZE);
   if(entryStep<=0.0 || entryStep<point)
      entryStep=point;

   double oldEntry=s.entry;
   double oldSL=s.sl;
   double oldTP=s.tp;

   if(s.direction>0)
     {
      // A BUY STOP whose planned trigger is already at/below the live Ask
      // is stale, not merely too close to the broker's stop distance. Reject
      // it instead of chasing price upward and manufacturing a late entry.
      if(s.entry<=tick.ask)
        {
         Print("STB setup rejected: BUY STOP trigger already crossed symbol=",
               s.symbol,
               " planned=",DoubleToString(s.entry,digits),
               " ask=",DoubleToString(tick.ask,digits));
         failureReason="BUY_STOP_TRIGGER_ALREADY_CROSSED";
         return false;
        }

      double minEntry=tick.ask+minDist+entryStep;
      if(s.entry<minEntry)
         s.entry=minEntry;

      double maxSL=tick.bid-minDist;
      double entrySL=s.entry-minDist;

      // If the pattern-derived SL is too close to the live market, do not
      // replace it with a broker-minimum-distance stop. Rebuild from confirmed
      // structure; reject the setup if no valid structural stop exists.
      if(s.sl>maxSL)
        {
         double structuralSL=0.0;

         if(!CalculateInitialProtectionSL(s.symbol,
                                           POSITION_TYPE_BUY,
                                           s.entry,
                                           structuralSL) ||
            structuralSL>maxSL ||
            structuralSL>=entrySL)
           {
            Print("STB setup rejected: BUY structural SL unresolved symbol=",s.symbol);
            failureReason="BUY_STRUCTURAL_SL_UNRESOLVED";
            return false;
           }

         s.sl=structuralSL;
        }

      if(s.sl>=s.entry)
        {
         Print("STB setup rejected: BUY SL is not structurally below entry symbol=",s.symbol);
         failureReason="BUY_SL_NOT_BELOW_ENTRY";
         return false;
        }

      SwingPoint highs[];
      SwingPoint lows[];
      if(CollectSwings(s.symbol,PERIOD_M15,InpLookbackM15,highs,lows)<=0)
        {
         failureReason="BUY_SWING_DATA_UNAVAILABLE";
         return false;
        }

      double risk=s.entry-s.sl;
      double target=DBL_MAX;
      double nearestSwing=DBL_MAX;

      for(int i=0;i<ArraySize(highs);i++)
        {
         double candidate=highs[i].price;
         if(candidate<=s.entry)
            continue;

         if(candidate<nearestSwing)
            nearestSwing=candidate;

         if(candidate-s.entry+1e-12 < risk*STB_EffectiveMinimumRR())
            continue;

         if(candidate<target)
            target=candidate;
        }

      if(target==DBL_MAX || target<=s.entry+minDist)
        {
         double availableReward=(nearestSwing==DBL_MAX ? 0.0 : nearestSwing-s.entry);
         Print("STB setup rejected after broker normalization: BUY TP is too close or no RR target symbol=",s.symbol,
               " entry=",DoubleToString(s.entry,digits),
               " sl=",DoubleToString(s.sl,digits),
               " nearestSwing=",nearestSwing==DBL_MAX ? "NONE" : DoubleToString(nearestSwing,digits),
               " availableReward=",DoubleToString(availableReward,digits),
               " requiredReward=",DoubleToString(risk*STB_EffectiveMinimumRR(),digits),
               " minRR=",DoubleToString(STB_EffectiveMinimumRR(),2));
         failureReason="BUY_NO_VALID_TP_OR_MINIMUM_RR";
         return false;
        }

      s.tp=NormalizePrice(s.symbol,target);
     }
   else
     {
      // A SELL STOP whose planned trigger is already at/above the live Bid
      // has already been crossed. Reject rather than pushing it lower and
      // entering after the original breakdown level has passed.
      if(s.entry>=tick.bid)
        {
         Print("STB setup rejected: SELL STOP trigger already crossed symbol=",
               s.symbol,
               " planned=",DoubleToString(s.entry,digits),
               " bid=",DoubleToString(tick.bid,digits));
         failureReason="SELL_STOP_TRIGGER_ALREADY_CROSSED";
         return false;
        }

      double maxEntry=tick.bid-minDist-entryStep;
      if(s.entry>maxEntry)
         s.entry=maxEntry;

      double minSL=tick.ask+minDist;
      double entrySL=s.entry+minDist;

      // If the pattern-derived SL is too close to the live market, do not
      // replace it with a broker-minimum-distance stop. Rebuild from confirmed
      // structure; reject the setup if no valid structural stop exists.
      if(s.sl<minSL)
        {
         double structuralSL=0.0;

         if(!CalculateInitialProtectionSL(s.symbol,
                                           POSITION_TYPE_SELL,
                                           s.entry,
                                           structuralSL) ||
            structuralSL<minSL ||
            structuralSL<=entrySL)
           {
            Print("STB setup rejected: SELL structural SL unresolved symbol=",s.symbol);
            failureReason="SELL_STRUCTURAL_SL_UNRESOLVED";
            return false;
           }

         s.sl=structuralSL;
        }

      if(s.sl<=s.entry)
        {
         Print("STB setup rejected: SELL SL is not structurally above entry symbol=",s.symbol);
         failureReason="SELL_SL_NOT_ABOVE_ENTRY";
         return false;
        }

      SwingPoint highs[];
      SwingPoint lows[];
      if(CollectSwings(s.symbol,PERIOD_M15,InpLookbackM15,highs,lows)<=0)
        {
         failureReason="SELL_SWING_DATA_UNAVAILABLE";
         return false;
        }

      double risk=s.sl-s.entry;
      double target=-DBL_MAX;
      double nearestSwing=-DBL_MAX;

      for(int i=0;i<ArraySize(lows);i++)
        {
         double candidate=lows[i].price;
         if(candidate>=s.entry)
            continue;

         if(candidate>nearestSwing)
            nearestSwing=candidate;

         if(s.entry-candidate+1e-12 < risk*STB_EffectiveMinimumRR())
            continue;

         if(candidate>target)
            target=candidate;
        }

      if(target==-DBL_MAX || target>=s.entry-minDist)
        {
         double availableReward=(nearestSwing==-DBL_MAX ? 0.0 : s.entry-nearestSwing);
         Print("STB setup rejected after broker normalization: SELL TP is too close or no RR target symbol=",s.symbol,
               " entry=",DoubleToString(s.entry,digits),
               " sl=",DoubleToString(s.sl,digits),
               " nearestSwing=",nearestSwing==-DBL_MAX ? "NONE" : DoubleToString(nearestSwing,digits),
               " availableReward=",DoubleToString(availableReward,digits),
               " requiredReward=",DoubleToString(risk*STB_EffectiveMinimumRR(),digits),
               " minRR=",DoubleToString(STB_EffectiveMinimumRR(),2));
         failureReason="SELL_NO_VALID_TP_OR_MINIMUM_RR";
         return false;
        }

      s.tp=NormalizePrice(s.symbol,target);
     }

   s.entry=NormalizePrice(s.symbol,s.entry);
   s.sl=NormalizePrice(s.symbol,s.sl);
   s.tp=NormalizePrice(s.symbol,s.tp);

   double risk=MathAbs(s.entry-s.sl);
   double reward=MathAbs(s.tp-s.entry);

   if(risk<=0.0 || reward<=0.0)
     {
      failureReason="NONPOSITIVE_NORMALIZED_RISK_OR_REWARD";
      return false;
     }

   if(InpMaxInitialSLPips>0.0 &&
      risk>InpMaxInitialSLPips*PipSize(s.symbol))
     {
      Print("STB setup rejected: structural risk exceeds InpMaxInitialSLPips symbol=",
            s.symbol,
            " riskPips=",DoubleToString(risk/PipSize(s.symbol),1),
            " capPips=",DoubleToString(InpMaxInitialSLPips,1));
      failureReason="INITIAL_STRUCTURAL_SL_EXCEEDS_CAP";
      return false;
     }

   s.rr=reward/risk;

   string geometryReason="OK";
   if(!STB_ValidatePendingGeometry(s.symbol,s.direction,s.entry,s.sl,s.tp,true,STB_EffectiveMinimumRR(),geometryReason))
     {
      Print("STB pending geometry contract rejected symbol=",s.symbol," dir=",(s.direction>0 ? "BUY":"SELL")," reason=",geometryReason);
      failureReason="PENDING_GEOMETRY_"+geometryReason;
      return false;
     }

   if(s.rr+1e-9<STB_EffectiveMinimumRR())
     {
      Print("STB setup rejected after broker-stop normalization symbol=",s.symbol,
            " dir=",(s.direction>0 ? "BUY":"SELL"),
            " RR=",DoubleToString(s.rr,2),
            " minRR=",DoubleToString(STB_EffectiveMinimumRR(),2),
            " entry=",DoubleToString(s.entry,digits),
            " sl=",DoubleToString(s.sl,digits),
            " tp=",DoubleToString(s.tp,digits));
      failureReason="RR_BELOW_MINIMUM_AFTER_NORMALIZATION";
      return false;
     }

   bool changed=
      MathAbs(oldEntry-s.entry)>point*0.5 ||
      MathAbs(oldSL-s.sl)>point*0.5 ||
      MathAbs(oldTP-s.tp)>point*0.5;

   if(changed)
     {
      Print("STB stops normalized symbol=",s.symbol,
            " dir=",(s.direction>0 ? "BUY":"SELL"),
            " minDistPts=",DoubleToString(minDist/point,0),
            " entry ",DoubleToString(oldEntry,digits)," -> ",DoubleToString(s.entry,digits),
            " SL ",DoubleToString(oldSL,digits)," -> ",DoubleToString(s.sl,digits),
            " TP ",DoubleToString(oldTP,digits)," -> ",DoubleToString(s.tp,digits),
            " RR=",DoubleToString(s.rr,2),
            " profile=",IntegerToString(s.adaptiveProfile));
     }

   return true;
  }

//==================================================================
// RSI + CCI COMPOSITE
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int FindIndicatorCache(const string symbol)
  {
   for(int i=0;i<ArraySize(g_indicatorCache);i++)
      if(g_indicatorCache[i].symbol==symbol)
         return i;

   return -1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool EnsureIndicatorHandles(const string symbol,int &rsiHandle,int &cciHandle)
  {
   rsiHandle=INVALID_HANDLE;
   cciHandle=INVALID_HANDLE;

   int idx=FindIndicatorCache(symbol);
   if(idx>=0)
     {
      rsiHandle=g_indicatorCache[idx].rsiHandle;
      cciHandle=g_indicatorCache[idx].cciHandle;

      if(rsiHandle!=INVALID_HANDLE && cciHandle!=INVALID_HANDLE)
         return true;
     }

   int hRsi=iRSI(symbol,InpOscTF,InpRSIPeriod,PRICE_CLOSE);
   if(hRsi==INVALID_HANDLE)
     {
      Print("STB OSC: iRSI handle failed symbol=",symbol,
            " err=",GetLastError());
      return false;
     }

   int hCci=iCCI(symbol,InpOscTF,InpCCIPeriod,PRICE_TYPICAL);
   if(hCci==INVALID_HANDLE)
     {
      IndicatorRelease(hRsi);
      Print("STB OSC: iCCI handle failed symbol=",symbol,
            " err=",GetLastError());
      return false;
     }

   if(idx<0)
     {
      int n=ArraySize(g_indicatorCache);
      if(ArrayResize(g_indicatorCache,n+1)!=n+1)
        {
         IndicatorRelease(hRsi);
         IndicatorRelease(hCci);
         Print("STB indicator cache allocation failed symbol=",symbol,
               " reason=HANDLE_CACHE_UNAVAILABLE");
         return false;
        }
      g_indicatorCache[n].symbol=symbol;
      g_indicatorCache[n].rsiHandle=hRsi;
      g_indicatorCache[n].cciHandle=hCci;
      idx=n;
     }
   else
     {
      if(g_indicatorCache[idx].rsiHandle!=INVALID_HANDLE)
         IndicatorRelease(g_indicatorCache[idx].rsiHandle);
      if(g_indicatorCache[idx].cciHandle!=INVALID_HANDLE)
         IndicatorRelease(g_indicatorCache[idx].cciHandle);

      g_indicatorCache[idx].rsiHandle=hRsi;
      g_indicatorCache[idx].cciHandle=hCci;
     }

   rsiHandle=hRsi;
   cciHandle=hCci;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool GetOscillatorState(const string symbol,OscillatorState &o)
  {
   ZeroMemory(o);

   if(!InpOscillatorConfirmation)
     {
      o.valid=true;
      o.buyConfirmed=true;
      o.sellConfirmed=true;
      return true;
     }

   int rsiHandle=INVALID_HANDLE;
   int cciHandle=INVALID_HANDLE;

   if(!EnsureIndicatorHandles(symbol,rsiHandle,cciHandle))
      return false;

// Copy closed-bar values only: start position 1 avoids the live bar.
   double rsiBuf[2];
   double cciBuf[2];

   ResetLastError();

   if(CopyBuffer(rsiHandle,0,1,2,rsiBuf)!=2)
     {
      Print("STB OSC: RSI CopyBuffer failed symbol=",symbol,
            " err=",GetLastError());
      return false;
     }

   ResetLastError();

   if(CopyBuffer(cciHandle,0,1,2,cciBuf)!=2)
     {
      Print("STB OSC: CCI CopyBuffer failed symbol=",symbol,
            " err=",GetLastError());
      return false;
     }

// CopyBuffer stores the oldest copied value at index 0.
// With start_pos=1,count=2:
//   index 0 = shift 2 (previous closed bar)
//   index 1 = shift 1 (latest closed bar)
   o.rsi2=rsiBuf[0];
   o.rsi1=rsiBuf[1];
   o.cci2=cciBuf[0];
   o.cci1=cciBuf[1];

   if(!MathIsValidNumber(o.rsi1) || !MathIsValidNumber(o.rsi2) ||
      !MathIsValidNumber(o.cci1) || !MathIsValidNumber(o.cci2))
      return false;

   bool rsiBuy=(o.rsi1>=STB_EffectiveRSIBuy());
   bool rsiSell=(o.rsi1<=STB_EffectiveRSISell());

   bool cciBuy=(o.cci1>=STB_EffectiveCCIBuy());
   bool cciSell=(o.cci1<=STB_EffectiveCCISell());

   bool rsiCrossBuy=(o.rsi2<50.0 && o.rsi1>=50.0);
   bool rsiCrossSell=(o.rsi2>50.0 && o.rsi1<=50.0);

   bool cciCrossBuy=(o.cci2<=0.0 && o.cci1>0.0);
   bool cciCrossSell=(o.cci2>=0.0 && o.cci1<0.0);

// Strong confirmation = regime level + momentum confirmation,
// while a zero-line/50 cross is accepted as a fresh transition.
   o.buyConfirmed=(rsiBuy && cciBuy) ||
                  (rsiCrossBuy && o.cci1>=0.0) ||
                  (cciCrossBuy && o.rsi1>=50.0);

   o.sellConfirmed=(rsiSell && cciSell) ||
                   (rsiCrossSell && o.cci1<=0.0) ||
                   (cciCrossSell && o.rsi1<=50.0);

   o.valid=true;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ReleaseIndicatorHandles()
  {
   for(int i=0;i<ArraySize(g_indicatorCache);i++)
     {
      if(g_indicatorCache[i].rsiHandle!=INVALID_HANDLE)
         IndicatorRelease(g_indicatorCache[i].rsiHandle);

      if(g_indicatorCache[i].cciHandle!=INVALID_HANDLE)
         IndicatorRelease(g_indicatorCache[i].cciHandle);

      g_indicatorCache[i].rsiHandle=INVALID_HANDLE;
      g_indicatorCache[i].cciHandle=INVALID_HANDLE;
     }

   ArrayResize(g_indicatorCache,0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//==================================================================
// SWING ENGINE
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CollectSwings(const string symbol,
                  const ENUM_TIMEFRAMES tf,
                  const int maxBars,
                  SwingPoint &highs[],
                  SwingPoint &lows[])
  {
   MqlRates r[];

   if(!GetRates(symbol,tf,maxBars,r))
      return 0;

   if(ArrayResize(highs,0)<0 || ArrayResize(lows,0)<0)
     {
      Print("STB swing buffers reset failed symbol=",symbol,
            " timeframe=",EnumToString(tf));
      return 0;
     }

   int left  = STB_EffectiveSwingLeft(tf);
   int right = STB_EffectiveSwingRight(tf);
   int maxShift=maxBars-left-1;
   int minShift=right+1;

   if(maxShift<minShift)
      return 0;

   for(int s=maxShift; s>=minShift; --s)
     {
      bool isHigh=true;
      bool isLow=true;

      // CopyRates + ArraySetAsSeries(true) means:
      // shift 0 = newest bar, larger shift = older bar.
      // Therefore "left" (older bars) is s+k and
      // "right" (newer bars) is s-k.
      for(int k=1;k<=left;k++)
        {
         if(r[s].high <= r[s+k].high)
            isHigh=false;

         if(r[s].low >= r[s+k].low)
            isLow=false;
        }

      for(int k=1;k<=right;k++)
        {
         if(r[s].high <= r[s-k].high)
            isHigh=false;

         if(r[s].low >= r[s-k].low)
            isLow=false;
        }

      if(isHigh)
        {
         int n=ArraySize(highs);
         if(ArrayResize(highs,n+1)!=n+1)
           {
            Print("STB swing-high allocation failed symbol=",symbol,
                  " timeframe=",EnumToString(tf));
            ArrayFree(highs);
            ArrayFree(lows);
            return 0;
           }

         highs[n].shift=s;
         highs[n].time=r[s].time;
         highs[n].price=r[s].high;
         highs[n].isHigh=true;
        }

      if(isLow)
        {
         int n=ArraySize(lows);
         if(ArrayResize(lows,n+1)!=n+1)
           {
            Print("STB swing-low allocation failed symbol=",symbol,
                  " timeframe=",EnumToString(tf));
            ArrayFree(highs);
            ArrayFree(lows);
            return 0;
           }

         lows[n].shift=s;
         lows[n].time=r[s].time;
         lows[n].price=r[s].low;
         lows[n].isHigh=false;
        }
     }

   return ArraySize(highs)+ArraySize(lows);
  }

//==================================================================
// H4 TREND
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
TrendInfo GetH4Trend(const string symbol)
  {
   TrendInfo result;

   result.bias="NEUTRAL";
   result.valid=false;
   result.touches=0;
   result.t1=0;
   result.t2=0;
   result.p1=0.0;
   result.p2=0.0;

   SwingPoint highs[];
   SwingPoint lows[];

   CollectSwings(symbol,PERIOD_H4,InpLookbackH4,highs,lows);

   int nh=ArraySize(highs);
   int nl=ArraySize(lows);

   if(nh<2 || nl<2)
      return result;

// Determine H4 market structure from the two latest CONFIRMED
// swing pairs. The line itself is then anchored to those exact
// confirmed pivots, never to the current candle/price.
   bool bullish =
      highs[nh-1].price > highs[nh-2].price &&
      lows[nl-1].price  > lows[nl-2].price;

   bool bearish =
      highs[nh-1].price < highs[nh-2].price &&
      lows[nl-1].price  < lows[nl-2].price;

   double lastClose=iClose(symbol,PERIOD_H4,1);
   datetime lastClosedBar=iTime(symbol,PERIOD_H4,1);
   if(lastClose<=0.0 || lastClosedBar<=0)
      return result;

   // Compare the last closed candle with the trendline at that candle's
   // close time. TimeCurrent() projects the line beyond the candle being
   // tested and can create a time mismatch late in the next H4 bar.
   int h4Seconds=PeriodSeconds(PERIOD_H4);
   if(h4Seconds<=0)
      return result;
   datetime evaluationTime=lastClosedBar+h4Seconds;

   double pip=PipSize(symbol);
   double tolerance=(pip>0.0 ? InpTrendlineTolerancePips*pip : 0.0);

   if(bullish)
     {
      // Bullish trendline = support line through the two latest
      // confirmed higher lows.
      SwingPoint a=lows[nl-2];
      SwingPoint b=lows[nl-1];

      if(b.time<=a.time || b.price<=a.price)
         return result;

      result.bias="BULLISH";
      result.t1=a.time;
      result.p1=a.price;
      result.t2=b.time;
      result.p2=b.price;
      result.touches=2;

      double slope=(b.price-a.price)/(double)(b.time-a.time);

      // A valid bullish line must not have a confirmed swing low
      // materially below the line after the first anchor.
      for(int i=nl-1;i>=0;i--)
        {
         if(lows[i].time<=a.time)
            continue;

         double line=lows[i].price;
         double expected=a.price+slope*(double)(lows[i].time-a.time);

         if(lows[i].price < expected-tolerance)
           {
            result.valid=false;
            return result;
           }
        }

      if(nl>=3)
        {
         SwingPoint c=lows[nl-3];

         // c is the older confirmed pivot before anchor a. Test it against
         // the backward extension of the same line to count a third touch.
         if(c.time<a.time)
           {
            double lineAtC=a.price+slope*(double)(c.time-a.time);

            if(MathAbs(c.price-lineAtC)<=tolerance)
               result.touches=3;
           }
        }

      double lineNow=b.price+slope*(double)(evaluationTime-b.time);

      // The line is structurally valid when price has not decisively
      // broken below it. This check affects trading validity only.
      result.valid=(lastClose>=lineNow-tolerance);
     }

   if(bearish)
     {
      // Bearish trendline = resistance line through the two latest
      // confirmed lower highs.
      SwingPoint a=highs[nh-2];
      SwingPoint b=highs[nh-1];

      if(b.time<=a.time || b.price>=a.price)
         return result;

      result.bias="BEARISH";
      result.t1=a.time;
      result.p1=a.price;
      result.t2=b.time;
      result.p2=b.price;
      result.touches=2;

      double slope=(b.price-a.price)/(double)(b.time-a.time);

      // A valid bearish line must not have a confirmed swing high
      // materially above the line after the first anchor.
      for(int i=nh-1;i>=0;i--)
        {
         if(highs[i].time<=a.time)
            continue;

         double expected=a.price+slope*(double)(highs[i].time-a.time);

         if(highs[i].price > expected+tolerance)
           {
            result.valid=false;
            return result;
           }
        }

      if(nh>=3)
        {
         SwingPoint c=highs[nh-3];

         // c is the older confirmed pivot before anchor a. Test it against
         // the backward extension of the same line to count a third touch.
         if(c.time<a.time)
           {
            double lineAtC=a.price+slope*(double)(c.time-a.time);

            if(MathAbs(c.price-lineAtC)<=tolerance)
               result.touches=3;
           }
        }

      double lineNow=b.price+slope*(double)(evaluationTime-b.time);

      // This affects trading validity only; the drawing still shows
      // the confirmed structural line.
      result.valid=(lastClose<=lineNow+tolerance);
     }

   return result;
  }

//==================================================================
// TRENDLINE DRAWING
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//==================================================================
// M15 CHoCH + BOS
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool DetectStructure(const string symbol,
                     const int direction,
                     int &chochShift,
                     int &bosShift,
                     SwingPoint &breakSwing)
  {
   chochShift=-1;
   bosShift=-1;
   ZeroMemory(breakSwing);

   SwingPoint highs[];
   SwingPoint lows[];

   CollectSwings(symbol,PERIOD_M15,InpLookbackM15,highs,lows);

   int nh=ArraySize(highs);
   int nl=ArraySize(lows);

   if(nh<2 || nl<2)
      return false;

   MqlRates r[];

   if(!GetRates(symbol,PERIOD_M15,InpLookbackM15,r))
      return false;

   const int structureWindowBars=MathMax(5,InpStructureWindowBars);
   const int rightBars=MathMax(1,STB_EffectiveSwingRight(PERIOD_M15));

   if(direction>0)
     {
      for(int s=1;s<=structureWindowBars && s+1<ArraySize(r);s++)
        {
         // Find the newest confirmed high that already existed before
         // this closed breakout candle. No same/younger pivot can be used.
         for(int i=nh-1;i>=0;i--)
           {
            int pivotShift=highs[i].shift;

            if(pivotShift<=s)
               continue;

            // The pivot must have been confirmed by its right-side bars.
            if(pivotShift<rightBars)
               continue;

            if(pivotShift-s>structureWindowBars)
               continue;

            if(r[s].close>highs[i].price && r[s+1].close<=highs[i].price)
              {
               chochShift=pivotShift;
               bosShift=s;
               breakSwing=highs[i];
               return true;
              }
           }
        }
     }
   else
     {
      for(int s=1;s<=structureWindowBars && s+1<ArraySize(r);s++)
        {
         for(int i=nl-1;i>=0;i--)
           {
            int pivotShift=lows[i].shift;

            if(pivotShift<=s)
               continue;

            if(pivotShift<rightBars)
               continue;

            if(pivotShift-s>structureWindowBars)
               continue;

            if(r[s].close<lows[i].price && r[s+1].close>=lows[i].price)
              {
               chochShift=pivotShift;
               bosShift=s;
               breakSwing=lows[i];
               return true;
              }
           }
        }
     }


   return false;
  }
//==================================================================
// FVG / DISPLACEMENT ENGINE
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double LocalATR(const MqlRates &r[],const int shift,const int period)
  {
   int size=ArraySize(r);
   if(size<=shift+1)
      return 0.0;

   int count=MathMin(period,size-shift-1);
   if(count<=0)
      return 0.0;

   double sum=0.0;
   for(int i=shift;i<shift+count;i++)
     {
      double prevClose=r[i+1].close;
      double tr1=r[i].high-r[i].low;
      double tr2=MathAbs(r[i].high-prevClose);
      double tr3=MathAbs(r[i].low-prevClose);
      sum+=MathMax(tr1,MathMax(tr2,tr3));
     }

   return sum/(double)count;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsBullishDisplacement(const MqlRates &r[],const int shift)
  {
   double atr=LocalATR(r,shift+1,20);
   if(atr<=0.0)
      return false;

   double range=r[shift].high-r[shift].low;
   double body=MathAbs(r[shift].close-r[shift].open);

   if(range<=0.0)
      return false;

   return r[shift].close>r[shift].open &&
          range>=atr*1.15 &&
          body/range>=0.55 &&
          (r[shift].close-r[shift].low)/range>=0.70;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsBearishDisplacement(const MqlRates &r[],const int shift)
  {
   double atr=LocalATR(r,shift+1,20);
   if(atr<=0.0)
      return false;

   double range=r[shift].high-r[shift].low;
   double body=MathAbs(r[shift].close-r[shift].open);

   if(range<=0.0)
      return false;

   return r[shift].close<r[shift].open &&
          range>=atr*1.15 &&
          body/range>=0.55 &&
          (r[shift].high-r[shift].close)/range>=0.70;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool FindFVG(const string symbol,
             const int direction,
             const int bosShift,
             int &fvgShift)
  {
   fvgShift=-1;

   MqlRates r[];
   if(!GetRates(symbol,PERIOD_M15,InpLookbackM15,r))
      return false;

   int maxScan=MathMin(STB_EffectivePatternWindow(),InpLookbackM15-4);

   for(int s=1;s<=maxScan;s++)
     {
      int impulse=s+1;

      // Tie the imbalance to the detected BOS/CHoCH instead of allowing
      // an unrelated gap anywhere in the scan window.
      if(MathAbs(impulse-bosShift)>2)
         continue;

      if(direction>0 &&
         r[s].low>r[s+2].high &&
         IsBullishDisplacement(r,impulse))
        {
         fvgShift=s;
         return true;
        }

      if(direction<0 &&
         r[s].high<r[s+2].low &&
         IsBearishDisplacement(r,impulse))
        {
         fvgShift=s;
         return true;
        }
     }

   return false;
  }

//==================================================================
// ORDER BLOCK / DISPLACEMENT ORIGIN ENGINE
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool FindOriginCandle(const string symbol,
                      const int direction,
                      const int bosShift,
                      int &originShift,
                      double &originHigh,
                      double &originLow)
  {
   originShift=-1;
   originHigh=0.0;
   originLow=0.0;

   MqlRates r[];
   if(!GetRates(symbol,PERIOD_M15,InpLookbackM15,r))
      return false;

   int start=bosShift+1;
   int end=MathMin(bosShift+STB_EffectivePatternWindow(),
                   InpLookbackM15-3);

// Professionalized OB definition:
// 1) last opposite candle before the displacement,
// 2) immediately followed by directional displacement,
// 3) displacement body/range must be meaningful relative to local ATR,
// 4) the subsequent structure break must be consistent with direction.
   for(int s=start;s<=end;s++)
     {
      int impulse=s-1;
      if(impulse<1)
         continue;

      bool opposite=(direction>0)
                    ? (r[s].close<r[s].open)
                    : (r[s].close>r[s].open);

      if(!opposite)
         continue;

      bool displacement=(direction>0)
                        ? IsBullishDisplacement(r,impulse)
                        : IsBearishDisplacement(r,impulse);

      if(!displacement)
         continue;

      bool broke=(direction>0)
                 ? (r[impulse].close>r[s].high)
                 : (r[impulse].close<r[s].low);

      if(!broke)
         continue;

      originShift=s;
      originHigh=r[s].high;
      originLow=r[s].low;
      return true;
     }

   return false;
  }

//==================================================================
// HIGHER-TIMEFRAME FVG + ORDER-BLOCK CONFLUENCE
// All pattern decisions use closed candles and enforce confirmation time
// against the latest closed M15 decision candle. No forming/future candle
// is allowed to confirm a zone.
//==================================================================

bool STB_HTFPivotAtImpulse(const MqlRates &rates[],
                           const int pivotShift,
                           const bool wantHigh,
                           const int leftBars,
                           const int rightBars,
                           const int impulseShift)
  {
   int n=ArraySize(rates);
   if(pivotShift<1 || leftBars<1 || rightBars<1 ||
      pivotShift+leftBars>=n ||
      pivotShift-rightBars<=impulseShift)
      return false; // pivot confirmation must predate the impulse candle

   double pivot=(wantHigh ? rates[pivotShift].high:rates[pivotShift].low);
   if(pivot<=0.0)
      return false;

   for(int k=1;k<=leftBars;k++)
     {
      if(wantHigh && pivot<=rates[pivotShift+k].high)
         return false;
      if(!wantHigh && pivot>=rates[pivotShift+k].low)
         return false;
     }
   for(int k=1;k<=rightBars;k++)
     {
      if(wantHigh && pivot<=rates[pivotShift-k].high)
         return false;
      if(!wantHigh && pivot>=rates[pivotShift-k].low)
         return false;
     }
   return true;
  }

bool STB_HTFImpulseBrokePriorSwing(const MqlRates &rates[],
                                  const int impulseShift,
                                  const int direction,
                                  const int leftBars,
                                  const int rightBars)
  {
   int n=ArraySize(rates);
   if(impulseShift<1 || (direction!=1 && direction!=-1))
      return false;

   // Smallest eligible shift = most recent prior swing whose right-side
   // confirmation candles had all closed before this impulse opened.
   for(int p=impulseShift+rightBars+1;p+leftBars<n;p++)
     {
      if(direction>0 && STB_HTFPivotAtImpulse(rates,p,true,leftBars,rightBars,impulseShift))
         return rates[impulseShift].close>rates[p].high;
      if(direction<0 && STB_HTFPivotAtImpulse(rates,p,false,leftBars,rightBars,impulseShift))
         return rates[impulseShift].close<rates[p].low;
     }
   return false;
  }

double STB_RangeGap(const double lowA,const double highA,
                    const double lowB,const double highB)
  {
   if(lowA<=0.0 || highA<lowA || lowB<=0.0 || highB<lowB)
      return DBL_MAX;
   if(highA<lowB)
      return lowB-highA;
   if(highB<lowA)
      return lowA-highB;
   return 0.0;
  }

bool STB_CheckHTFConfluence(const string symbol,
                            const int direction,
                            const datetime decisionTime,
                            const double m15OriginLow,
                            const double m15OriginHigh,
                            string &reason)
  {
   reason="HTF_CONFLUENCE_UNAVAILABLE";
   if(symbol=="" || (direction!=1 && direction!=-1) ||
      decisionTime<=0 || m15OriginLow<=0.0 ||
      m15OriginHigh<m15OriginLow)
     {
      reason="HTF_INPUT_INVALID";
      return false;
     }

   int tfSeconds=PeriodSeconds(InpHTFPatternTF);
   if(tfSeconds<PeriodSeconds(PERIOD_H1))
     {
      reason="HTF_TIMEFRAME_MUST_BE_H1_OR_HIGHER";
      return false;
     }

   int requestedBars=(int)MathMax(64,InpHTFLookbackBars+32);
   MqlRates r[];
   if(!GetRates(symbol,InpHTFPatternTF,requestedBars,r))
     {
      reason="HTF_DATA_UNAVAILABLE";
      return false;
     }

   double currentATR=LocalATR(r,1,14);
   if(currentATR<=0.0 || !MathIsValidNumber(currentATR))
     {
      reason="HTF_ATR_UNAVAILABLE";
      return false;
     }

   int maxShift=(int)MathMin(InpHTFLookbackBars,ArraySize(r)-3);
   if(maxShift<3)
     {
      reason="HTF_LOOKBACK_UNAVAILABLE";
      return false;
     }

   double fvgLow=0.0,fvgHigh=0.0;
   datetime fvgConfirmedAt=0;
   bool haveFVG=false;

   // Three-candle FVG: the middle candle must show displacement and the
   // newest candle must be fully closed by decisionTime.
   for(int s=1;s<=maxShift;s++)
     {
      int impulse=s+1;
      datetime confirmedAt=r[s].time+tfSeconds;
      if(r[s].time<=0 || confirmedAt>decisionTime)
         continue;

      int ageBars=(int)((decisionTime-confirmedAt)/tfSeconds);
      if(ageBars<0 || ageBars>InpHTFMaxZoneAgeBars)
         continue;

      double zoneLow=0.0,zoneHigh=0.0,zoneATR=LocalATR(r,s+1,20);
      if(zoneATR<=0.0)
         continue;

      if(direction>0)
        {
         zoneLow=r[s+2].high;
         zoneHigh=r[s].low;
         if(zoneHigh<=zoneLow ||
            zoneHigh-zoneLow+1e-9<zoneATR*InpHTFMinFVGWidthATR ||
            !IsBullishDisplacement(r,impulse))
            continue;
        }
      else
        {
         zoneLow=r[s].high;
         zoneHigh=r[s+2].low;
         if(zoneHigh<=zoneLow ||
            zoneHigh-zoneLow+1e-9<zoneATR*InpHTFMinFVGWidthATR ||
            !IsBearishDisplacement(r,impulse))
            continue;
        }

      bool fullyMitigated=false;
      for(int j=s-1;j>=1;j--)
        {
         if(r[j].time+tfSeconds>decisionTime)
            continue;
         if(direction>0 && r[j].low<=zoneLow)
           {
            fullyMitigated=true;
            break;
           }
         if(direction<0 && r[j].high>=zoneHigh)
           {
            fullyMitigated=true;
            break;
           }
        }
      if(fullyMitigated)
         continue;

      fvgLow=zoneLow;
      fvgHigh=zoneHigh;
      fvgConfirmedAt=confirmedAt;
      haveFVG=true;
      break; // latest valid, unmitigated FVG first
     }

   if(!haveFVG)
     {
      reason="HTF_FVG_MISSING_STALE_OR_MITIGATED";
      return false;
     }

   double obLow=0.0,obHigh=0.0;
   datetime obConfirmedAt=0;
   bool haveOB=false;
   int leftBars=(int)MathMax(1,InpSwingLeft);
   int rightBars=(int)MathMax(1,InpSwingRight);
   int maxOBShift=(int)MathMin(InpHTFLookbackBars,ArraySize(r)-2);

   // Order Block: most recent opposite candle immediately preceding a
   // directional displacement that closes beyond both the block and the
   // most recent *already confirmed* prior swing.
   for(int s=2;s<=maxOBShift;s++)
     {
      int impulse=s-1;
      datetime confirmedAt=r[impulse].time+tfSeconds;
      if(r[s].time<=0 || confirmedAt>decisionTime)
         continue;

      int ageBars=(int)((decisionTime-confirmedAt)/tfSeconds);
      if(ageBars<0 || ageBars>InpHTFMaxZoneAgeBars)
         continue;

      bool opposite=(direction>0)
                    ? (r[s].close<r[s].open)
                    : (r[s].close>r[s].open);
      if(!opposite)
         continue;

      bool displacement=(direction>0)
                        ? IsBullishDisplacement(r,impulse)
                        : IsBearishDisplacement(r,impulse);
      if(!displacement)
         continue;

      bool closesBeyondBlock=(direction>0)
                             ? (r[impulse].close>r[s].high)
                             : (r[impulse].close<r[s].low);
      if(!closesBeyondBlock ||
         !STB_HTFImpulseBrokePriorSwing(r,impulse,direction,leftBars,rightBars))
         continue;

      double zoneLow=r[s].low;
      double zoneHigh=r[s].high;
      bool invalidated=false;
      for(int j=impulse-1;j>=1;j--)
        {
         if(r[j].time+tfSeconds>decisionTime)
            continue;
         if(direction>0 && r[j].close<zoneLow)
           {
            invalidated=true;
            break;
           }
         if(direction<0 && r[j].close>zoneHigh)
           {
            invalidated=true;
            break;
           }
        }
      if(invalidated)
         continue;

      obLow=zoneLow;
      obHigh=zoneHigh;
      obConfirmedAt=confirmedAt;
      haveOB=true;
      break; // latest valid, non-invalidated OB first
     }

   if(!haveOB)
     {
      reason="HTF_ORDER_BLOCK_MISSING_STALE_OR_INVALIDATED";
      return false;
     }

   // The local M15 OB origin must be near both independently validated H1
   // zones; simple score bonuses cannot compensate for absent confluence.
   double allowedGap=currentATR*InpHTFZoneMaxGapATR;
   double fvgGap=STB_RangeGap(m15OriginLow,m15OriginHigh,fvgLow,fvgHigh);
   double obGap=STB_RangeGap(m15OriginLow,m15OriginHigh,obLow,obHigh);
   double zoneGap=STB_RangeGap(fvgLow,fvgHigh,obLow,obHigh);
   if(fvgGap>allowedGap || obGap>allowedGap || zoneGap>allowedGap)
     {
      reason="HTF_FVG_OB_M15_ORIGIN_NOT_CONFLUENT";
      return false;
     }

   // Times are retained in diagnostics so future refinements can inspect
   // the age relationship without relying on chart screenshots.
   Print("STB HTF CONFLUENCE PASS symbol=",symbol,
         " direction=",(direction>0 ? "BUY":"SELL"),
         " tf=",EnumToString(InpHTFPatternTF),
         " fvgFrom=",TimeToString(fvgConfirmedAt,TIME_DATE|TIME_MINUTES),
         " obFrom=",TimeToString(obConfirmedAt,TIME_DATE|TIME_MINUTES),
         " fvgGapATR=",DoubleToString(fvgGap/currentATR,3),
         " obGapATR=",DoubleToString(obGap/currentATR,3),
         " zonesGapATR=",DoubleToString(zoneGap/currentATR,3));
   reason="";
   return true;
  }

//==================================================================
// SETUP BUILDER
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Find the nearest already-confirmed opposite-side swing that predates the
// structure-break candle. This is the fallback stop anchor when no valid OB
// exists; the broken pivot itself is an entry trigger, not a protective stop.
bool FindStructuralStopAnchor(const string symbol,
                              const int direction,
                              const int bosShift,
                              double &anchorPrice)
  {
   anchorPrice=0.0;

   SwingPoint highs[];
   SwingPoint lows[];
   if(CollectSwings(symbol,PERIOD_M15,InpLookbackM15,highs,lows)<=0)
      return false;

   int bestShift=2147483647;

   if(direction>0)
     {
      for(int i=0;i<ArraySize(lows);i++)
        {
         if(lows[i].shift<=bosShift || lows[i].price<=0.0)
            continue;

         if(lows[i].shift<bestShift)
           {
            bestShift=lows[i].shift;
            anchorPrice=lows[i].price;
           }
        }
     }
   else
     if(direction<0)
       {
        for(int i=0;i<ArraySize(highs);i++)
          {
           if(highs[i].shift<=bosShift || highs[i].price<=0.0)
              continue;

           if(highs[i].shift<bestShift)
             {
              bestShift=highs[i].shift;
              anchorPrice=highs[i].price;
             }
          }
       }

   return (anchorPrice>0.0 && bestShift<2147483647);
  }

bool BuildSetup(const string symbol,
                const int direction,
                Setup &s,
                const bool countAdaptiveAttempt)
  {
   ZeroMemory(s);

   s.symbol=symbol;
   s.direction=direction;
   s.adaptiveProfile=0;

   g_lastBuildRejectReason="UNKNOWN";
   STB_AP_SelectActive(symbol,direction);
   s.adaptiveProfile=g_activeAdaptiveProfileId;

// Count a strategy probe only during the scanner's first-pass discovery.
// Candidate revalidation rebuilds the same setup several times; those checks
// must not inflate adaptive sample counts or make profiles appear warmed up.
   if(countAdaptiveAttempt)
      STB_AP_RecordAttempt(symbol,direction,s.adaptiveProfile);

   if(!IsDirectionTradable(symbol,direction))
     {
      long tradeMode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
      long orderMode=SymbolInfoInteger(symbol,SYMBOL_ORDER_MODE);
      long stops=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
      long freeze=SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);
      long expiration=SymbolInfoInteger(symbol,SYMBOL_EXPIRATION_MODE);

      Print("STB CONTRACT REJECT symbol=",symbol,
            " dir=",(direction>0 ? "BUY":"SELL"),
            " tradeMode=",tradeMode,
            " orderMode=",orderMode,
            " stopsPts=",stops,
            " freezePts=",freeze,
            " expirationMode=",expiration);

      return STB_BuildReject(symbol,direction,"DIRECTION_NOT_TRADABLE");
     }

   if(!IsSpreadAcceptable(symbol))
      return STB_BuildReject(symbol,direction,"SPREAD_FILTER");

   OscillatorState osc;
   ZeroMemory(osc);

   bool oscReady=GetOscillatorState(symbol,osc);

   if(!oscReady && InpOscillatorHardFilter)
      return STB_BuildReject(symbol,direction,"OSCILLATOR_DATA_UNAVAILABLE");

   if(oscReady && InpOscillatorHardFilter)
     {
      if(direction>0 && !osc.buyConfirmed)
         return STB_BuildReject(symbol,direction,"OSCILLATOR_BUY_NOT_CONFIRMED");

      if(direction<0 && !osc.sellConfirmed)
         return STB_BuildReject(symbol,direction,"OSCILLATOR_SELL_NOT_CONFIRMED");
     }

   datetime lastSetup=GetLastSetupTime(symbol,direction);

   if(InpSetupCooldownMinutes>0 &&
      lastSetup>0 &&
      TimeCurrent()-(datetime)lastSetup<InpSetupCooldownMinutes*60)
      return STB_BuildReject(symbol,direction,"SETUP_COOLDOWN");

   TrendInfo ti=GetH4Trend(symbol);

   bool aligned=
      ti.valid &&
      ((direction>0 && ti.bias=="BULLISH") ||
       (direction<0 && ti.bias=="BEARISH"));

   if(InpRequireH4TrendAlignment && (!ti.valid || !aligned))
      return STB_BuildReject(symbol,direction,
                             ti.valid ? "H4_DIRECTION_MISMATCH" : "H4_TREND_UNAVAILABLE");

   if(!aligned && !InpAllowUniversal)
      return STB_BuildReject(symbol,direction,"H4_ALIGNMENT_REQUIRED");

   int chochShift=-1;
   int bosShift=-1;
   SwingPoint breakSwing;

   if(!DetectStructure(symbol,direction,chochShift,bosShift,breakSwing))
      return STB_BuildReject(symbol,direction,"NO_VALID_CHOCH_BOS");

   int maxAge=STB_EffectiveMaxSetupAgeBars();

   if(maxAge>0 && bosShift>maxAge)
      return STB_BuildReject(symbol,direction,"BOS_TOO_OLD");

   int fvgShift=-1;
   bool hasFVG=FindFVG(symbol,direction,bosShift,fvgShift);

   if((InpRequireFVG || InpStrictPatternFilters) && !hasFVG)
      return STB_BuildReject(symbol,direction,"M15_FVG_REQUIRED");

   int originShift=-1;
   double originHigh=0.0;
   double originLow=0.0;

   bool hasOB=FindOriginCandle(symbol,direction,
                               bosShift,originShift,
                               originHigh,originLow);

   if((InpRequireOB || InpStrictPatternFilters || InpRequireHTFConfluence) && !hasOB)
      return STB_BuildReject(symbol,direction,"M15_ORDER_BLOCK_REQUIRED");

   if(InpRequireHTFConfluence)
     {
      datetime latestClosedM15=iTime(symbol,PERIOD_M15,1);
      int m15Seconds=PeriodSeconds(PERIOD_M15);
      if(latestClosedM15<=0 || m15Seconds<=0)
         return STB_BuildReject(symbol,direction,"M15_DECISION_TIME_UNAVAILABLE");

      datetime decisionTime=latestClosedM15+m15Seconds;
      string htfReason="";
      if(!STB_CheckHTFConfluence(symbol,direction,decisionTime,
                                  originLow,originHigh,htfReason))
         return STB_BuildReject(symbol,direction,htfReason);
     }

   // If local OBs are explicitly optional and HTF confluence is disabled,
   // retain the historical structural fallback for compatibility.
   if(!hasOB)
     {
      originShift=breakSwing.shift;
      originHigh=iHigh(symbol,PERIOD_M15,originShift);
      originLow=iLow(symbol,PERIOD_M15,originShift);

      if(originShift<0 || originHigh<=0.0 || originLow<=0.0)
         return STB_BuildReject(symbol,direction,"ORIGIN_FALLBACK_INVALID");
     }

   double pip=PipSize(symbol);

   if(pip<=0.0)
      return STB_BuildReject(symbol,direction,"PIP_SIZE_INVALID");

   // Risk belongs beyond the opposite side of the actual Order Block when
   // one is found. If OB is optional and absent, use the nearest confirmed
   // pre-BOS swing on the risk side. Do not place SL just beyond the broken
   // swing that defines the entry trigger; that artificially compresses risk.
   double stopAnchor=(direction>0 ? originLow:originHigh);
   if(!hasOB &&
      !FindStructuralStopAnchor(symbol,direction,bosShift,stopAnchor))
      return STB_BuildReject(symbol,direction,"STRUCTURAL_STOP_ANCHOR_MISSING");

   if(stopAnchor<=0.0 ||
      (direction>0 && stopAnchor>=originHigh) ||
      (direction<0 && stopAnchor<=originLow))
      return STB_BuildReject(symbol,direction,"STRUCTURAL_STOP_ANCHOR_INVALID");

   double entryBuffer=STB_EffectiveEntryBuffer();
   s.entryBufferPips=MathMax(0.0,entryBuffer); // P4 EB contract source
   double slBuffer=STB_EffectiveSLBuffer();
   double minimumRR=STB_EffectiveMinimumRR();

   // Raw structural geometry only.
   // Final broker alignment and Entry/SL/TP/RR validation are centralized
   // in PreparePendingSetup().
   if(direction>0)
     {
      // A BUY STOP is a breakout order, so its trigger must stay above the
      // confirmed swing-high broken by BOS. The OB high can be below that
      // swing; basing a STOP only on the OB may let it trigger prematurely.
      double buyTriggerBase=MathMax(originHigh,breakSwing.price);
      s.entry=NormalizePrice(symbol,buyTriggerBase + entryBuffer*pip);
      s.sl=NormalizePrice(symbol,stopAnchor - slBuffer*pip);
     }
   else
     {
      // Symmetric rule for SELL STOP: trigger below both the OB low and the
      // confirmed broken swing-low. If valid RR no longer exists, reject it.
      double sellTriggerBase=MathMin(originLow,breakSwing.price);
      s.entry=NormalizePrice(symbol,sellTriggerBase - entryBuffer*pip);
      s.sl=NormalizePrice(symbol,stopAnchor + slBuffer*pip);
     }

   string pendingSetupFailure="";
   if(!PreparePendingSetup(s,pendingSetupFailure))
      return STB_BuildReject(symbol,direction,"PENDING_SETUP_"+pendingSetupFailure);

   if(s.rr+1e-9<minimumRR)
      return STB_BuildReject(symbol,direction,"RR_BELOW_PROFILE_MINIMUM");


   s.score=(aligned ? 40.0:25.0);

   if(bosShift<=2)
      s.score+=30.0;
   else
      if(bosShift<=4)
         s.score+=25.0;
      else
         s.score+=20.0;

   if(s.rr>=2.0)
      s.score+=15.0;
   else
      if(s.rr>=1.5)
         s.score+=10.0;
      else
         s.score+=5.0;

   if(hasFVG)
      s.score+=10.0;

   if(hasOB)
      s.score+=10.0;

   if(oscReady)
     {
      double rsiWeight=MathMax(0.0,STB_EffectiveRSIWeight());
      double cciWeight=MathMax(0.0,STB_EffectiveCCIWeight());

      if(direction>0 && osc.buyConfirmed)
         s.score+=rsiWeight*0.5+cciWeight*0.5;
      else
         if(direction<0 && osc.sellConfirmed)
            s.score+=rsiWeight*0.5+cciWeight*0.5;
         else
            if(direction>0)
              {
               if(osc.rsi1>=50.0)
                  s.score+=rsiWeight*0.25;
               if(osc.cci1>=0.0)
                  s.score+=cciWeight*0.25;
              }
            else
              {
               if(osc.rsi1<=50.0)
                  s.score+=rsiWeight*0.25;
               if(osc.cci1<=0.0)
                  s.score+=cciWeight*0.25;
              }
     }

   if(s.score>100.0)
      s.score=100.0;

   s.setupTime=iTime(symbol,PERIOD_M15,bosShift);

   if(s.setupTime<=0)
      return STB_BuildReject(symbol,direction,"BOS_TIME_INVALID");

   double adaptiveFloor=STB_AdaptiveScoreFloor(symbol,direction);

   if(s.score+1e-9<adaptiveFloor)
     {
      g_lastBuildRejectReason="ADAPTIVE_SCORE_FLOOR";

      Print("STB ADAPTIVE REJECT symbol=",symbol,
            " dir=",(direction>0 ? "BUY":"SELL"),
            " profile=",IntegerToString(s.adaptiveProfile),
            " score=",DoubleToString(s.score,1),
            " floor=",DoubleToString(adaptiveFloor,1),
            " RR=",DoubleToString(s.rr,2));

      STB_AdaptiveRecordSetup(s,false);
      STB_LogBuildReject(symbol,direction,g_lastBuildRejectReason);
      STB_AP_ClearActive();
      return false;
     }

   s.valid=true;

// A successfully built setup is still only a probe; profile quality is
// learned from the eventual closed-trade outcome below.
   s.trendAligned=aligned;
   s.chochShift=chochShift;
   s.bosShift=bosShift;
   s.originShift=originShift;
   s.fvgShift=fvgShift;

   s.originHigh=originHigh;
   s.originLow=originLow;

   s.swingHigh=(direction>0 ? s.tp : breakSwing.price);
   s.swingLow =(direction>0 ? breakSwing.price : s.tp);

   STB_LogSetupReady(s);
   STB_AP_ClearActive();

   return true;
  }


//==================================================================
// GLOBAL VARIABLE IDENTIFIERS
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TicketLockName(const ulong ticket)
  {
   return ScopedStateName("LOCK_"+(string)ticket);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string PositionPnlName(const ulong positionId)
  {
   return ScopedStateName("PNL_"+(string)positionId);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetAccumulatedPositionPnl(const ulong positionId)
  {
   if(positionId==0)
      return 0.0;

   string name=PositionPnlName(positionId);
   if(!GlobalVariableCheck(name))
      return 0.0;

   return GlobalVariableGet(name);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetAccumulatedPositionPnl(const ulong positionId,const double value)
  {
   if(positionId==0)
      return;

   GlobalVariableSet(PositionPnlName(positionId),value);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double TakeAccumulatedPositionPnl(const ulong positionId)
  {
   double value=GetAccumulatedPositionPnl(positionId);

   if(positionId>0)
      GlobalVariableDel(PositionPnlName(positionId));

   return value;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_SumClosedLifecyclePnlFromHistory(const ulong positionId,
                                          double &totalPnl)
  {
   totalPnl=0.0;
   if(positionId==0 || !HistorySelectByPosition(positionId))
      return false;

   int deals=HistoryDealsTotal();
   ulong lastReversalDeal=0;
   long lastReversalTimeMsc=0;

   // Position identifiers may span a netting reversal. Only count deals after
   // the latest INOUT boundary; the reversal's realized P/L belongs to the
   // lifecycle it closed and must not leak into the new lifecycle.
   for(int i=0;i<deals;i++)
     {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0 ||
         HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_INOUT)
         continue;

      long timeMsc=HistoryDealGetInteger(deal,DEAL_TIME_MSC);
      if(timeMsc>lastReversalTimeMsc ||
         (timeMsc==lastReversalTimeMsc && deal>lastReversalDeal))
        {
         lastReversalTimeMsc=timeMsc;
         lastReversalDeal=deal;
        }
     }

   bool foundClose=false;
   bool foundEntry=false;
   for(int j=0;j<deals;j++)
     {
      ulong deal=HistoryDealGetTicket(j);
      if(deal==0)
         continue;

      long timeMsc=HistoryDealGetInteger(deal,DEAL_TIME_MSC);
      if(timeMsc<lastReversalTimeMsc ||
         (timeMsc==lastReversalTimeMsc && deal<=lastReversalDeal))
         continue;

      long entry=HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(entry==DEAL_ENTRY_IN)
        {
         // Entry deals commonly have zero gross P/L, but their commission and
         // fee are real costs. Include them when reconstructing after restart.
         double entryCosts=HistoryDealGetDouble(deal,DEAL_COMMISSION)+
                           HistoryDealGetDouble(deal,DEAL_FEE);
         if(!MathIsValidNumber(entryCosts))
            return false;
         totalPnl+=entryCosts;
         foundEntry=true;
         continue;
        }

      if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY)
         continue;

      double exitPnl=HistoryDealGetDouble(deal,DEAL_PROFIT)+
                     HistoryDealGetDouble(deal,DEAL_SWAP)+
                     HistoryDealGetDouble(deal,DEAL_COMMISSION)+
                     HistoryDealGetDouble(deal,DEAL_FEE);
      if(!MathIsValidNumber(exitPnl))
         return false;

      totalPnl+=exitPnl;
      foundClose=true;
     }

   // For a normal lifecycle, require its entry to be present before replacing
   // the accumulated value. After an INOUT reversal, the reversal deal itself
   // is the new lifecycle boundary and is intentionally excluded here.
   bool lifecycleComplete=(lastReversalDeal>0 || foundEntry);
   return foundClose && lifecycleComplete && MathIsValidNumber(totalPnl);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsPositionIdentifierOpen(const ulong positionId)
  {
   if(positionId==0)
      return false;

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;

      ulong identifier=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(identifier==positionId)
         return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetLockedPips(const ulong ticket)
  {
   string name=TicketLockName(ticket);

   if(!GlobalVariableCheck(name))
      return 0.0;

   return GlobalVariableGet(name);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetLockedPips(const ulong ticket,const double value)
  {
   GlobalVariableSet(TicketLockName(ticket),value);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong SymbolHash(const string symbol)
  {
   ulong h=1469598103934665603ULL;

   int len=StringLen(symbol);

   for(int i=0;i<len;i++)
     {
      ushort c=StringGetCharacter(symbol,i);
      h ^= (ulong)c;
      h *= 1099511628211ULL;
     }

   return h;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string ScopedStateName(const string purpose)
  {
   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
              (string)InpMagic+"|"+purpose;
   if(MQLInfoInteger(MQL_TESTER))
      raw+="|TESTER";
   return g_prefix+(string)SymbolHash(raw);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string ScopedSymbolStateName(const string purpose,const string symbol)
  {
   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|"+
              (string)InpMagic+"|"+purpose+"|"+symbol;
   if(MQLInfoInteger(MQL_TESTER))
      raw+="|TESTER";
   return g_prefix+(string)SymbolHash(raw);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string LastSetupName(const string symbol,const int direction)
  {
   return ScopedSymbolStateName("LAST_"+(direction>0 ? "B":"S"),symbol);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime GetLastSetupTime(const string symbol,const int direction)
  {
   string name=LastSetupName(symbol,direction);

   if(!GlobalVariableCheck(name))
      return 0;

   return (datetime)GlobalVariableGet(name);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SetLastSetupTime(const string symbol,const int direction,const datetime t)
  {
   GlobalVariableSet(LastSetupName(symbol,direction),(double)t);
  }

//==================================================================
// OWNERSHIP / ORIGIN + TRADE REGISTRY
//==================================================================


void STB_ReconcileTradeRegistry()
  {


   STB_GeomPrune(); STB_OverridePersistPrune(false); // MANUAL_OVERRIDE: drop geometry memory for closed tickets + purge persisted overrides for tickets that no longer exist

   for(int i=0;i<PositionsTotal();i++)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;
      if(!STB_IsProtectionPosition(ticket))
         continue;

      // Seed recovery state from the actual terminal geometry. Otherwise the
      // registry's initial zero values can misclassify the next routine server
      // POSITION update as an external/manual geometry edit.
      int exposureIdx=STB_ExposureEnsure(ticket,true); // MANUAL_OVERRIDE: restore persisted override on reconcile (no broker write)
      // Reconcile may run before a delayed POSITION transaction is consumed.
      // Seed only an unknown baseline; do not overwrite a known snapshot, or a
      // later intake callback may miss an external/manual geometry change.
      if(exposureIdx>=0 && g_stbExposure[exposureIdx].entry<=0.0)
         STB_GeomStore(ticket,true,
                       PositionGetDouble(POSITION_PRICE_OPEN),
                       PositionGetDouble(POSITION_SL),
                       PositionGetDouble(POSITION_TP));
     }

   for(int i=0;i<OrdersTotal();i++)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !OrderSelect(ticket))
         continue;
      if(!IsManagedOrder(ticket))
         continue;

      // Ensure the exposure baseline registry before registering trail state.
      // If allocation fails, defer this order's reconciliation as a unit so
      // trail processing cannot proceed from a partially initialized intake.
      int exposureIdx=STB_ExposureEnsure(ticket,false); // MANUAL_OVERRIDE: restore persisted override on reconcile (no broker write)
      if(exposureIdx<0)
        {
         Print("STB ORDER RECONCILE DEFERRED ticket=",ticket,
               " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
         continue;
        }

      // Seed recovery state from the actual pending-order geometry only after
      // the exposure registry is available.
      STB_PendingTrailRegister(ticket,"RECONCILE");

      // Preserve a known intake/own-write baseline across periodic Reconcile.
      // This lets ORDER_UPDATE compare the new server geometry with the last
      // observed baseline instead of a snapshot already overwritten here.
      if(g_stbExposure[exposureIdx].entry<=0.0)
         STB_GeomStore(ticket,false,
                       OrderGetDouble(ORDER_PRICE_OPEN),
                       OrderGetDouble(ORDER_SL),
                       OrderGetDouble(ORDER_TP));
     }

   // SIMPLIFIED: origin registry prune loop removed.


  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_ManagePositionImmediately(const ulong ticket)
  {
   if(ticket==0 || !STB_IsProtectionPosition(ticket))
      return;
   string symbol=PositionGetString(POSITION_SYMBOL);
   int exposureIdx=STB_ExposureEnsure(ticket,true);
   if(exposureIdx<0)
     {
      Print("STB POSITION HANDOFF DEFERRED ticket=",ticket,
            " symbol=",symbol,
            " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
      return;
     }
   STB_GeomStore(ticket,true,
                 PositionGetDouble(POSITION_PRICE_OPEN),
                 PositionGetDouble(POSITION_SL),
                 PositionGetDouble(POSITION_TP));
   Print("STB POSITION HANDOFF ACTIVE ticket=",ticket,
         " symbol=",symbol,
         " side=",(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? "BUY":"SELL"),
         " action=IMMEDIATE_MANAGEMENT_CYCLE");
   STB_RunManagementCycle();
  }

void STB_TradeIntakeFromTransaction(const MqlTradeTransaction &trans)
  {
   STB_ManualOverrideIntake(trans); // MANUAL_OVERRIDE: user SL/TP/entry/pending detection
   if(trans.type==TRADE_TRANSACTION_ORDER_ADD && trans.order>0)
     {
      // SIMPLIFIED: origin registry call removed.

      if(OrderSelect(trans.order))
        {
         ENUM_ORDER_TYPE orderType=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

         // Capture terminal-confirmed geometry at first discovery. Without this
         // baseline, an immediate manual entry/SL/TP edit on a newly created
         // pending order could be mistaken for an unknown geometry snapshot.
         if(IsManagedOrder(trans.order))
           {
            int exposureIdx=STB_ExposureEnsure(trans.order,false);
            if(exposureIdx<0)
              {
               Print("STB ORDER INTAKE DEFERRED ticket=",trans.order,
                     " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
               return;
              }
            STB_GeomStore(trans.order,false,
                          OrderGetDouble(ORDER_PRICE_OPEN),
                          OrderGetDouble(ORDER_SL),
                          OrderGetDouble(ORDER_TP));

            if(STB_IsManagedPendingType((long)orderType))
               STB_PendingTrailRegister(trans.order,"TRADE_TRANSACTION");
           }
        }

      return;
     }

   if(trans.type==TRADE_TRANSACTION_DEAL_ADD &&
      trans.deal>0 &&
      HistoryDealSelect(trans.deal))
     {
      // Pending-order override applies only while the order is pending.
// The resulting open position always enters the protection manager.
      if(trans.order>0)
         STB_PendingTrailOnOrderFilled(trans.order);

      if(trans.position>0 && PositionSelectByTicket(trans.position))
        {
         if(STB_IsProtectionPosition(trans.position))
           {
            string positionSymbol=PositionGetString(POSITION_SYMBOL);
            double positionEntry=PositionGetDouble(POSITION_PRICE_OPEN);
            double positionSL=PositionGetDouble(POSITION_SL);
            double positionTP=PositionGetDouble(POSITION_TP);

            int exposureIdx=STB_ExposureEnsure(trans.position,true);
            if(exposureIdx>=0)
              {
               STB_GeomStore(trans.position,true,
                             positionEntry,positionSL,positionTP);

               Print("STB POSITION PROTECTION ACTIVE after fill ticket=",
                      IntegerToString((int)trans.position),
                      " symbol=",positionSymbol,
                      " SL=",DoubleToString(positionSL,(int)SymbolInfoInteger(positionSymbol,SYMBOL_DIGITS)),
                      " TP=",DoubleToString(positionTP,(int)SymbolInfoInteger(positionSymbol,SYMBOL_DIGITS)));
              }
            else
              {
               Print("STB POSITION BASELINE DEFERRED after fill ticket=",
                     trans.position,
                     " symbol=",positionSymbol,
                     " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
              }
           }

         // SIMPLIFIED: origin registry call removed.
         STB_ManagePositionImmediately(trans.position);
        }
     }
  }

//==================================================================
// EXPOSURE MANAGEMENT
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_IsSymbolAllowed(const string s)
  {
   if(s=="")
      return false;

   // Strategy Tester isolation is a hard scope boundary when enabled.
   if(MQLInfoInteger(MQL_TESTER) && InpTesterChartSymbolOnly)
      return s==_Symbol;

   // The chart symbol remains manageable even when the scanner is configured
   // to explore a different explicit symbol universe (manual controls operate
   // on _Symbol). Additional symbols follow the configured universe.
   if(s==_Symbol)
      return true;

   // Universal management scope: an empty list means every symbol that has
   // an account position or pending order, not only selected Market Watch symbols.
   if(StringLen(InpScannerSymbols)==0)
      return true;

   string parts[];
   string cfg=InpScannerSymbols;
   StringReplace(cfg,";",",");
   ushort sep=StringGetCharacter(",",0);
   int n=StringSplit(cfg,sep,parts);

   for(int i=0;i<n;i++)
     {
      string it=parts[i];
      StringTrimLeft(it);
      StringTrimRight(it);
      if(it!="" && it==s)
         return true;
     }

   return false;
  } bool STB_IsManagedPendingType(const long t){ return t==(long)ORDER_TYPE_BUY_STOP||t==(long)ORDER_TYPE_SELL_STOP||t==(long)ORDER_TYPE_BUY_LIMIT||t==(long)ORDER_TYPE_SELL_LIMIT||t==(long)ORDER_TYPE_BUY_STOP_LIMIT||t==(long)ORDER_TYPE_SELL_STOP_LIMIT; } bool STB_IsProtectionPosition(const ulong ticket)
  {
   if(ticket==0 || !PositionSelectByTicket(ticket))
      return false;
   // Live protection covers all account positions regardless of origin/symbol.
   // Respect the explicit chart-only isolation setting in Strategy Tester.
   if(MQLInfoInteger(MQL_TESTER) && InpTesterChartSymbolOnly)
      return PositionGetString(POSITION_SYMBOL)==_Symbol;
   return true;
  }

bool IsManagedPosition(const ulong ticket)
  {
   if(ticket==0 || !PositionSelectByTicket(ticket)) return false;
   return STB_IsSymbolAllowed(PositionGetString(POSITION_SYMBOL)); // SIMPLIFIED: allowed symbol is the only management scope


  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsManagedOrder(const ulong ticket)
  {
   if(ticket==0 || !OrderSelect(ticket)) return false;
   return STB_IsSymbolAllowed(OrderGetString(ORDER_SYMBOL)); // SIMPLIFIED: allowed symbol is the only management scope


  }

// Exposure deduplication is scoped to this EA instance by Magic Number.
// Keep these helpers separate from IsManagedPosition/IsManagedOrder because those
// functions also define the broader scope used by management and trailing code.
bool STB_IsOwnedPosition(const ulong ticket)
  {
   if(ticket==0 || !PositionSelectByTicket(ticket))
      return false;
   return (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagic;
  }

bool STB_IsOwnedPendingOrder(const ulong ticket)
  {
   if(ticket==0 || !OrderSelect(ticket))
      return false;
   if(!STB_IsManagedPendingType(OrderGetInteger(ORDER_TYPE)))
      return false;
   return (ulong)OrderGetInteger(ORDER_MAGIC)==InpMagic;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Entry-policy gate: only this EA's own exposure blocks a new setup.
bool HasManagedExposure(const string symbol)
  {
   if(!InpOneSetupPerSymbol || symbol=="")
      return false;

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=symbol)
         continue;
      if(STB_IsOwnedPosition(ticket))
         return true;
     }

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL)!=symbol)
         continue;
      if(STB_IsOwnedPendingOrder(ticket))
         return true;
     }

   return false;
  }

// Lifecycle gate: preserve quote subscription while any exposure on this
// symbol remains inside the EA's management scope, independent of entry policy.
bool STB_HasSymbolExposureForManagement(const string symbol)
  {
   if(symbol=="")
      return false;

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=symbol)
         continue;
      if(IsManagedPosition(ticket))
         return true;
     }

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL)!=symbol)
         continue;
      if(IsManagedOrder(ticket))
         return true;
     }

   return false;
  }

//==================================================================
// ONE-CLICK HEDGE
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsHedgingAccount()
  {
   long mode=AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   return (mode==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasManagedPositionDirection(const string symbol,const long positionType)
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL)!=symbol)
         continue;

      if(PositionGetInteger(POSITION_TYPE)!=positionType)
         continue;

      if(IsManagedPosition(ticket))
         return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_HasManagedPendingDirection(const string symbol,
                                    const long positionType)
  {
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);

      if(ticket==0 || !OrderSelect(ticket))
         continue;

      if(OrderGetString(ORDER_SYMBOL)!=symbol)
         continue;

      if(!IsManagedOrder(ticket))
         continue;

      ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(positionType==POSITION_TYPE_BUY &&
         STB_PendingIsBuySide(type))
         return true;

      if(positionType==POSITION_TYPE_SELL &&
         !STB_PendingIsBuySide(type) && STB_PendingIsSellSide(type))
         return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_ResolveManualPendingEntry(const string symbol,
                                     const ENUM_ORDER_TYPE orderType,
                                     const double requestedEntry,
                                     const MqlTick &tick,
                                     double &entry)
  {
   entry=0.0;
   if(symbol=="" || requestedEntry<=0.0 ||
      tick.bid<=0.0 || tick.ask<=0.0)
      return false;

   double minDist=TradeMinDistance(symbol);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   if(minDist<=0.0 || point<=0.0)
      return false;

   // Keep one full tradable price increment beyond the broker boundary so
   // tick rounding cannot place the manual order exactly on the rejection edge.
   double safety=MathMax(point,tickSize>0.0 ? tickSize:point);
   double candidate=requestedEntry;

   switch(orderType)
     {
      case ORDER_TYPE_BUY_STOP:
         candidate=MathMax(candidate,tick.ask+minDist+safety);
         break;
      case ORDER_TYPE_SELL_STOP:
         candidate=MathMin(candidate,tick.bid-minDist-safety);
         break;
      case ORDER_TYPE_BUY_LIMIT:
         candidate=MathMin(candidate,tick.bid-minDist-safety);
         break;
      case ORDER_TYPE_SELL_LIMIT:
         candidate=MathMax(candidate,tick.ask+minDist+safety);
         break;
      default:
         return false;
     }

   entry=NormalizePrice(symbol,candidate);
   if(entry<=0.0)
      return false;

   if(orderType==ORDER_TYPE_BUY_STOP)
      return entry>tick.ask+minDist;
   if(orderType==ORDER_TYPE_SELL_STOP)
      return entry<tick.bid-minDist;
   if(orderType==ORDER_TYPE_BUY_LIMIT)
      return entry<tick.bid-minDist;
   if(orderType==ORDER_TYPE_SELL_LIMIT)
      return entry>tick.ask+minDist;

   return false;
  }

bool OneClickHedge()
  {
   // Reject before submitting a hedge if the daily loss guard is active.
   // This prevents the guard from immediately cancelling an accepted hedge order.
   if(STB_DailyLossLimitHit())
     {
      STB_LogControlReject("HEDGE","DAILY_LOSS_LIMIT_ACTIVE",
                           "daily risk guard blocked hedge before order placement");
      return false;
     }

   if(!InpAllowOneClickHedge)
     {
      STB_LogControlReject("HEDGE","INPUT_DISABLED",
                           "InpAllowOneClickHedge is false");
      return false;
     }
   if(!IsHedgingAccount())
     {
      STB_LogControlReject("HEDGE","ACCOUNT_IS_NOT_HEDGING_MODE");
      return false;
     }
   if(!STB_TradeEnvironmentAllowed())
     {
      STB_LogControlReject("HEDGE","TRADE_ENVIRONMENT_BLOCKED");
      return false;
     }

   string symbol=_Symbol;
   if(!STB_SymbolManagementOwnedVerified(symbol))
     {
      Print("STB HEDGE REJECTED: symbol writer lease not owned symbol=",symbol);
      return false;
     }
   ulong sourceTicket=0;
   long sourceType=-1;
   double sourceVolume=0.0;

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL)!=symbol)
         continue;
      if(!IsManagedPosition(ticket))
         continue;

      sourceTicket=ticket;
      sourceType=PositionGetInteger(POSITION_TYPE);
      sourceVolume=PositionGetDouble(POSITION_VOLUME);
      break;
     }

   if(sourceTicket==0 || sourceVolume<=0.0)
     {
      STB_LogControlReject("HEDGE","NO_MANAGED_POSITION_ON_CHART_SYMBOL");
      return false;
     }

   long hedgeType=(sourceType==POSITION_TYPE_BUY) ? POSITION_TYPE_SELL
                                                  : POSITION_TYPE_BUY;

   long tradeMode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
   if(tradeMode==SYMBOL_TRADE_MODE_DISABLED ||
      tradeMode==SYMBOL_TRADE_MODE_CLOSEONLY ||
      (hedgeType==POSITION_TYPE_BUY && tradeMode==SYMBOL_TRADE_MODE_SHORTONLY) ||
      (hedgeType==POSITION_TYPE_SELL && tradeMode==SYMBOL_TRADE_MODE_LONGONLY))
      return false;

   if(HasManagedPositionDirection(symbol,hedgeType) ||
      STB_HasManagedPendingDirection(symbol,hedgeType))
      return false;

   double volume=NormalizeVolume(symbol,sourceVolume);
   if(volume<=0.0 || volume+1e-9<sourceVolume)
     {
      // Do not silently label a max-volume-capped order as a full hedge.
      // One click represents the entire source exposure; otherwise reject.
      Print("STB HEDGE REJECTED: requested hedge exceeds one-order volume capacity",
            " symbol=",symbol,
            " sourceVolume=",DoubleToString(sourceVolume,4),
            " allowedSingleOrderVolume=",DoubleToString(volume,4));
      return false;
     }

   int hedgeDirection=(hedgeType==POSITION_TYPE_BUY ? 1:-1);
   if(!STB_DirectionVolumeWithinLimit(symbol,hedgeDirection,volume,"OneClickHedge"))
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return false;

   double pip=PipSize(symbol);
   double minDist=TradeMinDistance(symbol);
   if(pip<=0.0 || minDist<=0.0)
      return false;

   long orderModes=SymbolInfoInteger(symbol,SYMBOL_ORDER_MODE);
   if((orderModes&SYMBOL_ORDER_STOP)!=SYMBOL_ORDER_STOP ||
      (orderModes&SYMBOL_ORDER_SL)!=SYMBOL_ORDER_SL)
      return false;

   ENUM_ORDER_TYPE orderType=(hedgeType==POSITION_TYPE_BUY)
                              ? ORDER_TYPE_BUY_STOP
                              : ORDER_TYPE_SELL_STOP;
   double requestedEntry=(hedgeType==POSITION_TYPE_BUY)
                         ? tick.ask+InpManualPendingGapPips*pip
                         : tick.bid-InpManualPendingGapPips*pip;
   double entry=0.0;
   if(!STB_ResolveManualPendingEntry(symbol,orderType,requestedEntry,tick,entry))
      return false;
   double sl=0.0;

   if(!CalculateInitialPendingProtectionSL(symbol,orderType,entry,sl))
      return false;

   int expirationModes=(int)SymbolInfoInteger(symbol,SYMBOL_EXPIRATION_MODE);
   ENUM_ORDER_TYPE_TIME typeTime=ORDER_TIME_GTC;
   datetime expiration=0;

   if((expirationModes&SYMBOL_EXPIRATION_GTC)!=SYMBOL_EXPIRATION_GTC)
     {
      if((expirationModes&SYMBOL_EXPIRATION_DAY)==SYMBOL_EXPIRATION_DAY)
         typeTime=ORDER_TIME_DAY;
      else
         return false;
     }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetAsyncMode(false);
   trade.SetTypeFilling(ORDER_FILLING_RETURN);

   double hedgeEntryOffset=MathAbs(entry-(hedgeType==POSITION_TYPE_BUY
                                          ? tick.bid:tick.ask))/pip;
   string comment="STB|HEDGE|"+
                  (hedgeType==POSITION_TYPE_BUY ? "BUY":"SELL")+
                  "|EB"+DoubleToString(hedgeEntryOffset,8);

   // Recheck writer authority and exposure immediately before broker submission.
   if(!STB_SymbolManagementOwnedVerified(symbol) ||
      HasManagedPositionDirection(symbol,hedgeType) ||
      STB_HasManagedPendingDirection(symbol,hedgeType))
     {
      Print("STB HEDGE REJECTED: writer/exposure changed before submit symbol=",symbol);
      return false;
     }

   MqlTick hedgeSubmitTick;
    string hedgeQuoteReason="";
    if(!SymbolInfoTick(symbol,hedgeSubmitTick) ||
       !STB_ScannerQuoteValid(hedgeSubmitTick,hedgeQuoteReason))
      {
       Print("STB HEDGE REJECTED: quote invalid/stale before submit symbol=",symbol,
             " reason=",(hedgeQuoteReason=="" ? "QUOTE_UNAVAILABLE":hedgeQuoteReason));
       return false;
      }

    ENUM_ORDER_TYPE hedgeOrderType=(hedgeType==POSITION_TYPE_BUY)
                                      ? ORDER_TYPE_BUY_STOP:ORDER_TYPE_SELL_STOP;
    if(!STB_CheckPendingOrderRequest(symbol,hedgeOrderType,volume,entry,sl,0.0,
                                     typeTime,expiration,(ulong)InpMagic,
                                     comment,"ONE_CLICK_HEDGE"))
       return false;

    bool ok=(hedgeType==POSITION_TYPE_BUY)
           ? trade.BuyStop(volume,entry,symbol,sl,0.0,typeTime,expiration,comment)
           : trade.SellStop(volume,entry,symbol,sl,0.0,typeTime,expiration,comment);

   if(!ok || !TradeRetcodePlacementSucceeded())
      return false;

   ulong hedgeOrder=trade.ResultOrder();
   if(hedgeOrder==0 || !VerifyPendingInitialSL(hedgeOrder))
     {
      Print("STB HEDGE REJECTED AFTER SERVER ACCEPT: initial SL not confirmed symbol=",
            symbol," order=",IntegerToString((int)hedgeOrder));
      if(hedgeOrder>0 && OrderSelect(hedgeOrder))
         STB_RequestOrderDelete(hedgeOrder,STB_DEL_AUTO_ROLLBACK,"OneClickHedge");
      return false;
     }

   // SIMPLIFIED: origin registry call removed.
   STB_AfterExposureCreated(hedgeOrder,"HEDGE"); // Blueprint 10/11
   Print("STB HEDGE PENDING CREATED symbol=",symbol,
         " sourceTicket=",sourceTicket,
         " direction=",(hedgeType==POSITION_TYPE_BUY ? "BUY":"SELL"),
         " volume=",DoubleToString(volume,3),
         " entry=",DoubleToString(entry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
         " SL=",DoubleToString(sl,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
         " order=",IntegerToString((int)hedgeOrder));
   return true;
  }


//==================================================================
// STOP VALIDATION
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsValidSLForPosition(const string symbol,
                          const long positionType,
                          const double sl)
  {
   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return false;

   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);

   long stopsLevel=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel=SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);

   double minimumDistance=(MathMax((double)stopsLevel,(double)freezeLevel)+1.0)*point;
   if(minimumDistance<=0.0)
      minimumDistance=point;

   if(positionType==POSITION_TYPE_BUY)
     {
      if(sl<=0.0 || sl>=tick.bid)
         return false;

      if((tick.bid-sl)<minimumDistance)
         return false;

      return true;
     }

   if(positionType==POSITION_TYPE_SELL)
     {
      if(sl<=tick.ask)
         return false;

      if((sl-tick.ask)<minimumDistance)
         return false;

      return true;
     }

   return false;
  }

//==================================================================
// POSITION PROFIT
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double PositionProfitPips(const string symbol,
                          const long positionType,
                          const double entry)
  {
   MqlTick tick;

   if(!SymbolInfoTick(symbol,tick))
      return 0.0;

   double pip=PipSize(symbol);

   if(pip<=0.0)
      return 0.0;

   if(positionType==POSITION_TYPE_BUY)
      return (tick.bid-entry)/pip;

   if(positionType==POSITION_TYPE_SELL)
      return (entry-tick.ask)/pip;

   return 0.0;
  }

//==================================================================
// NET PROFIT PIPS
//==================================================================

double PositionPipValue(const string symbol,
                        const long positionType,
                        const double volume,
                        const double entry)
  {
   if(volume<=0.0 || entry<=0.0)
      return 0.0;

   double pip=PipSize(symbol);
   if(pip<=0.0)
      return 0.0;

   double money=0.0;
   ENUM_ORDER_TYPE orderType=(positionType==POSITION_TYPE_BUY ?
                              ORDER_TYPE_BUY:ORDER_TYPE_SELL);

   double price2=(positionType==POSITION_TYPE_BUY ?
                  entry+pip:entry-pip);

   if(!OrderCalcProfit(orderType,symbol,volume,entry,price2,money))
      return 0.0;

   return MathAbs(money);
  }

double PositionCommissionMoney(const ulong ticket)
  {
   if(ticket==0 || !PositionSelectByTicket(ticket))
      return 0.0;

   ulong positionId=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(positionId==0)
      return 0.0;

   double commission=0.0;

   if(!HistorySelectByPosition(positionId))
      return 0.0;

   int deals=HistoryDealsTotal();
   for(int i=0;i<deals;i++)
     {
      ulong deal=HistoryDealGetTicket(i);
      if(deal==0)
         continue;

      long entryType=HistoryDealGetInteger(deal,DEAL_ENTRY);
      if(entryType==DEAL_ENTRY_IN)
         commission+=HistoryDealGetDouble(deal,DEAL_COMMISSION)+
                     HistoryDealGetDouble(deal,DEAL_FEE);
     }

   return commission;
  }

double STB_PositionPriceMovePips(const ulong ticket)
  {
   if(ticket==0 || !STB_IsProtectionPosition(ticket))
      return 0.0;
   string symbol=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double pip=PipSize(symbol);
   if(entry<=0.0 || pip<=0.0)
      return 0.0;
   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return 0.0;
   // Executable close-side quote: Bid for BUY, Ask for SELL.
   double closePrice=(type==POSITION_TYPE_BUY ? tick.bid : tick.ask);
   if(closePrice<=0.0)
      return 0.0;
   if(type==POSITION_TYPE_BUY)
      return (closePrice-entry)/pip;
   if(type==POSITION_TYPE_SELL)
      return (entry-closePrice)/pip;
   return 0.0;
  }

double PositionNetProfitPips(const ulong ticket)
  {
   if(ticket==0 || !PositionSelectByTicket(ticket))
      return 0.0;

   string symbol=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double volume=PositionGetDouble(POSITION_VOLUME);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);

   double pipValue=PositionPipValue(symbol,type,volume,entry);
   // Fail closed if the cash value of one pip cannot be computed. Falling back
   // to gross quote movement can trigger an automatic profit lock while the
   // actual position is still net negative after commission/swap.
   if(pipValue<=0.0 || !MathIsValidNumber(pipValue))
      return 0.0;

   double netMoney=PositionGetDouble(POSITION_PROFIT)+
                   PositionGetDouble(POSITION_SWAP)+
                   PositionCommissionMoney(ticket);

   if(!MathIsValidNumber(netMoney))
      return 0.0;

   double netPips=netMoney/pipValue;
   return MathIsValidNumber(netPips) ? netPips:0.0;
  }

//==================================================================
// MODIFY POSITION
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//==================================================================
// MANUAL_OVERRIDE (minimal per-ticket user authority)
//==================================================================
// Position protection remains active, including after manual SL/TP edits.
// MANUAL_OVERRIDE is retained only for pending-order lifecycle/trailing behavior.
// It never suppresses an open position's initial SL, profit lock, or live trail.
// User-issued modify actions still pass through the same broker validation.


//==================================================================
// UNIFIED EXPOSURE REGISTRY (MASTER BLUEPRINT 14) - ONE STATE PER TICKET
//==================================================================
// Single owner of per-ticket management state for BOTH positions and
// pendings. Specialized modules (Pending Trail, Adaptive, Lease) keep their
// own storage but never override this state and are keyed by the same ticket.
// Blueprint 14/15: no ticket is controlled by two independent registries.
struct STBExposureState
  {
   ulong    ticket;
   bool     isPosition;
   double   entry;
   double   sl;
   double   tp;
   bool     manualOverride;
   string   symbol;
   long     lastWriteCycle;
   datetime lastSeen;
  };

STBExposureState g_stbExposure[];

//--- persistent manual-override storage (Terminal Global Variables) -----
// Storage backing ONLY. The single Runtime owner stays STBExposureState /
// g_stbExposure; this is a key-value mirror of the manualOverride field.
// Scope = EA magic + account + symbol + ticket (one key per ticket).
string STB_ExposureSymbolOf(const ulong ticket)
  {
   if(PositionSelectByTicket(ticket))
      return PositionGetString(POSITION_SYMBOL);
   if(OrderSelect(ticket))
      return OrderGetString(ORDER_SYMBOL);
   return "";
  }

string STB_OverrideLegacyKey(const ulong ticket,const string symbol)
  {
   if(ticket==0 || symbol=="" || MQLInfoInteger(MQL_TESTER))
      return "";
   // Legacy key format retained only for safe migration from older builds.
   return g_prefix+"OVR_"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"_"+
          (string)InpMagic+"_"+symbol+"_"+IntegerToString((int)ticket);
  }

string STB_OverrideKey(const ulong ticket,const string symbol)
  {
   if(ticket==0 || symbol=="")
      return "";

   // Compact account+magic scope keeps the key safely under MT5's 63-char
   // terminal-global-variable limit even with long broker symbols/tickets.
   return ScopedStateName("OVR")+"_"+(string)ticket;
  }

void STB_OverridePersistSet(const ulong ticket,const string symbol)
  {
   string key=STB_OverrideKey(ticket,symbol);
   if(key=="")
      return;

   if(GlobalVariableSet(key,1.0)!=0)
     {
      string legacy=STB_OverrideLegacyKey(ticket,symbol);
      if(legacy!="")
         GlobalVariableDel(legacy);
     }
  }

void STB_OverridePersistDel(const ulong ticket,const string symbol)
  {
   string key=STB_OverrideKey(ticket,symbol);
   if(key!="")
      GlobalVariableDel(key);

   string legacy=STB_OverrideLegacyKey(ticket,symbol);
   if(legacy!="")
      GlobalVariableDel(legacy);
  }

bool STB_OverridePersistOn(const ulong ticket,const string symbol)
  {
   string key=STB_OverrideKey(ticket,symbol);
   if(key=="" )
      return false;

   if(GlobalVariableCheck(key))
      return GlobalVariableGet(key)>0.5;

   // Lazy migration keeps manual authority across an update/recompile.
   string legacy=STB_OverrideLegacyKey(ticket,symbol);
   if(legacy!="" && GlobalVariableCheck(legacy) &&
      GlobalVariableGet(legacy)>0.5)
     {
      if(GlobalVariableSet(key,1.0)!=0)
         GlobalVariableDel(legacy);
      return true;
     }

   return false;
  }

// Keep an absent ticket's state briefly so a delayed DEAL_ADD transaction
// can transfer manual authority from a filled pending ticket to its position.
// Cancelled/orphaned tickets are still pruned once this bounded grace expires.
#define STB_EXPOSURE_ORPHAN_GRACE_SEC 120
bool STB_ExposureOrphanGraceActive(const ulong ticket,const datetime now)
  {
   for(int i=0;i<ArraySize(g_stbExposure);i++)
     {
      if(g_stbExposure[i].ticket!=ticket)
         continue;

      datetime seen=g_stbExposure[i].lastSeen;
      if(seen<=0)
         return false;

      long age=(long)(now-seen);
      return (age>=0 && age<STB_EXPOSURE_ORPHAN_GRACE_SEC);
     }

   return false;
  }

// Purge persisted overrides. all=true removes every stored key (AUTO clear);
// all=false removes only tickets that no longer exist in the terminal.
void STB_OverridePersistPrune(const bool all)
  {
   // Scope cleanup to this account + magic, covering the compact current key
   // and the legacy human-readable key. Other EA-instance records are untouched.
   string compactPref=ScopedStateName("OVR")+"_";
   string legacyPref=g_prefix+"OVR_"+(string)AccountInfoInteger(ACCOUNT_LOGIN)+"_"+
                     (string)InpMagic+"_";

   for(int i=GlobalVariablesTotal()-1;i>=0;i--)
     {
      string name=GlobalVariableName(i);
      bool compact=(StringFind(name,compactPref)==0);
      // Tester may prune its scoped records but never LIVE legacy keys.
      bool legacy=(!MQLInfoInteger(MQL_TESTER) &&
                   StringFind(name,legacyPref)==0);
      if(!compact && !legacy)
         continue;

      if(all)
        {
         GlobalVariableDel(name);
         continue;
        }

      int p=-1;
      for(int k=StringLen(name)-1;k>=0;k--)
         if(StringGetCharacter(name,k)=='_')
           {
            p=k;
            break;
           }

      if(p<0)
         continue;

      ulong ticket=(ulong)StringToInteger(StringSubstr(name,p+1));
      if(ticket==0)
         continue;

      if(!PositionSelectByTicket(ticket) && !OrderSelect(ticket) &&
         !STB_ExposureOrphanGraceActive(ticket,TimeCurrent()))
         GlobalVariableDel(name);
     }
  }

int STB_ExposureFind(const ulong ticket)
  {
   for(int i=0;i<ArraySize(g_stbExposure);i++)
      if(g_stbExposure[i].ticket==ticket)
         return i;
   return -1;
  }

int STB_ExposureEnsure(const ulong ticket,const bool isPosition)
  {
   if(ticket==0)
      return -1;
   int idx=STB_ExposureFind(ticket);
   if(idx<0)
     {
      idx=ArraySize(g_stbExposure);
      if(ArrayResize(g_stbExposure,idx+1)!=idx+1)
        {
         Print("STB exposure registry allocation failed ticket=",ticket,
               " requestedSize=",idx+1);
         return -1;
        }
      g_stbExposure[idx].ticket=ticket;
      g_stbExposure[idx].manualOverride=false;
      g_stbExposure[idx].lastWriteCycle=0;
      g_stbExposure[idx].entry=0.0;
      g_stbExposure[idx].sl=0.0;
      g_stbExposure[idx].tp=0.0;
      g_stbExposure[idx].symbol=STB_ExposureSymbolOf(ticket);
      if(g_stbExposure[idx].symbol!="" &&
         STB_OverridePersistOn(ticket,g_stbExposure[idx].symbol))
        {
         g_stbExposure[idx].manualOverride=true; // MANUAL_OVERRIDE: restored from persistent storage
         Print("STB MANUAL_OVERRIDE RESTORED ticket=",IntegerToString((int)ticket));
        }
     }
   g_stbExposure[idx].isPosition=isPosition;
   g_stbExposure[idx].lastSeen=TimeCurrent();
   return idx;
  }

//--- manual override (Blueprint 15) ---------------------------------
bool STB_ManualOverrideIs(const ulong ticket)
  {
   int idx=STB_ExposureFind(ticket);
   if(idx>=0)
      return g_stbExposure[idx].manualOverride;
   // Persistent override is consulted by pending-order managers only;
   // open-position protection deliberately ignores this flag.
   return STB_OverridePersistOn(ticket,STB_ExposureSymbolOf(ticket));
  }

void STB_ManualOverrideSet(const ulong ticket)
  {
   if(ticket==0)
      return;
   int idx=STB_ExposureFind(ticket);
   if(idx<0)
     {
      bool isPos=PositionSelectByTicket(ticket);
      idx=STB_ExposureEnsure(ticket,isPos);
     }
   if(idx<0 || g_stbExposure[idx].manualOverride)
      return;
   g_stbExposure[idx].manualOverride=true;
   STB_OverridePersistSet(ticket,STB_ExposureSymbolOf(ticket)); // MANUAL_OVERRIDE persistence (storage only)
   Print("STB MANUAL_OVERRIDE ON ticket=",IntegerToString((int)ticket));
  }


void STB_ManualOverrideClearAll()
  {
   for(int i=0;i<ArraySize(g_stbExposure);i++)
      g_stbExposure[i].manualOverride=false;
   STB_OverridePersistPrune(true); // MANUAL_OVERRIDE: AUTO clears the persistent mirror too
   Print("STB MANUAL_OVERRIDE CLEARED (AUTO) - auto management re-enabled");
  }

//--- geometry memory (owns-write baseline + intake baseline) --------
double STB_GeomTolerance(const string symbol)
  {
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double t=MathMax(point*0.5,(tickSize>0.0 ? tickSize*0.5 : point*0.5));
   return (t>0.0 ? t : point);
  }

void STB_GeomStore(const ulong ticket,const bool isPosition,
                   const double entry,const double sl,const double tp)
  {
   int idx=STB_ExposureEnsure(ticket,isPosition);
   if(idx<0)
      return;
   g_stbExposure[idx].entry=entry;
   g_stbExposure[idx].sl=sl;
   g_stbExposure[idx].tp=tp;
  }

bool STB_GeomIsKnown(const ulong ticket,const bool isPosition,
                     const double entry,const double sl,const double tp,
                     const string symbol)
  {
   int idx=STB_ExposureFind(ticket);
   if(idx<0)
     {
      // Do not report geometry as known unless a registry row was actually
      // allocated and seeded. Allocation failure must remain distinguishable
      // from a successful baseline initialization.
      idx=STB_ExposureEnsure(ticket,isPosition);
      if(idx<0)
        {
         Print("STB geometry baseline unavailable ticket=",ticket,
               " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
         return false;
        }
      g_stbExposure[idx].entry=entry;
      g_stbExposure[idx].sl=sl;
      g_stbExposure[idx].tp=tp;
      return true;
     }

   // A registry row may have been allocated by ExposureEnsure before this
   // first geometry comparison. Its zero entry is an unseeded sentinel, not
   // evidence that the current terminal geometry is a manual edit.
   // Seed the first observed snapshot and report it as known; subsequent
   // changes are compared against this baseline normally.
   if(g_stbExposure[idx].entry<=0.0 && entry>0.0)
     {
      g_stbExposure[idx].entry=entry;
      g_stbExposure[idx].sl=sl;
      g_stbExposure[idx].tp=tp;
      Print("STB geometry baseline seeded ticket=",ticket,
            " reason=FIRST_VALID_SNAPSHOT");
      return true;
     }

   double tol=STB_GeomTolerance(symbol);
   return (MathAbs(g_stbExposure[idx].entry-entry)<=tol &&
           MathAbs(g_stbExposure[idx].sl-sl)<=tol &&
           MathAbs(g_stbExposure[idx].tp-tp)<=tol);
  }

void STB_GeomPrune()
  {
   for(int i=ArraySize(g_stbExposure)-1;i>=0;i--)
     {
      bool alive=(g_stbExposure[i].isPosition
                  ? PositionSelectByTicket(g_stbExposure[i].ticket)
                  : OrderSelect(g_stbExposure[i].ticket));
      if(!alive)
        {
         // A pending order may have filled just before its DEAL_ADD callback.
         // Preserve its override record long enough for intake to transfer it.
         if(STB_ExposureOrphanGraceActive(g_stbExposure[i].ticket,TimeCurrent()))
            continue;

         STB_OverridePersistDel(g_stbExposure[i].ticket,g_stbExposure[i].symbol);
         ArrayRemove(g_stbExposure,i,1);
        }
     }
  }

//--- transaction intake (Blueprint 10/28, H-11 safe direction) ------
void STB_ManualOverrideIntake(const MqlTradeTransaction &trans)
  {
   if(trans.type==TRADE_TRANSACTION_POSITION && trans.position>0)
     {
      ulong ticket=trans.position;
      if( !STB_IsProtectionPosition(ticket))
         return;
      string symbol=PositionGetString(POSITION_SYMBOL);
      double e=PositionGetDouble(POSITION_PRICE_OPEN);
      double sl=PositionGetDouble(POSITION_SL);
      double tp=PositionGetDouble(POSITION_TP);
      if(STB_ExposureEnsure(ticket,true)<0)
        {
         Print("STB POSITION GEOMETRY INTAKE DEFERRED ticket=",ticket,
               " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
         return;
        }
      if(!STB_GeomIsKnown(ticket,true,e,sl,tp,symbol))
         Print("STB POSITION GEOMETRY UPDATED ticket=",ticket,
               " symbol=",symbol,
               " SL=",DoubleToString(sl,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
               " TP=",DoubleToString(tp,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
               " automaticProtection=ACTIVE");
      STB_GeomStore(ticket,true,e,sl,tp);
      return;
     }

   if(trans.type==TRADE_TRANSACTION_ORDER_UPDATE && trans.order>0)
     {
      ulong ticket=trans.order;
      if(!OrderSelect(ticket) || !IsManagedOrder(ticket))
         return;
      string symbol=OrderGetString(ORDER_SYMBOL);
      double e=OrderGetDouble(ORDER_PRICE_OPEN);
      double sl=OrderGetDouble(ORDER_SL);
      double tp=OrderGetDouble(ORDER_TP);
      if(STB_ExposureEnsure(ticket,false)<0)
        {
         Print("STB ORDER GEOMETRY INTAKE DEFERRED ticket=",ticket,
               " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
         return;
        }

      if(!STB_GeomIsKnown(ticket,false,e,sl,tp,symbol))
        {
         STB_ManualOverrideSet(ticket);

         // A manual geometry edit becomes the new explicit trail baseline.
         // Otherwise the old EB / SL distance could make the next user-issued
         // PEND TRAIL snap this order back toward its pre-edit geometry.
         long updatedType=OrderGetInteger(ORDER_TYPE);
         if(STB_PendingTrailIsManagedType(updatedType))
           {
            int trailIdx=STB_PendingTrailFind(ticket);
            if(trailIdx<0)
              {
               STB_PendingTrailRegister(ticket,"MANUAL_UPDATE");
               trailIdx=STB_PendingTrailFind(ticket);
              }

            MqlTick updateTick;
            double pip=PipSize(symbol);
            if(trailIdx>=0 && pip>0.0 &&
               SymbolInfoTick(symbol,updateTick))
              {
               int direction=STB_PendingTrailDirection(updatedType);
               int offsetSign=STB_PendingEntryOffsetSign((ENUM_ORDER_TYPE)updatedType);
               double anchor=(direction>0 ? updateTick.bid:updateTick.ask);

               if(anchor>0.0 && offsetSign!=0)
                 {
                  g_stbPendingTrail[trailIdx].entryBufferPips=
                     MathAbs(e-anchor)/pip;
                  g_stbPendingTrail[trailIdx].trackedExtreme=
                     e-offsetSign*g_stbPendingTrail[trailIdx].entryBufferPips*pip;
                  g_stbPendingTrail[trailIdx].lastEntry=e;
                  g_stbPendingTrail[trailIdx].lastSL=sl;

                  if(sl>0.0)
                     g_stbPendingTrail[trailIdx].slBufferPips=
                        MathAbs(e-sl)/pip;

                  g_stbPendingTrail[trailIdx].failureCount=0;
                  g_stbPendingTrail[trailIdx].nextRetryTime=0;
                  g_stbPendingTrail[trailIdx].lastModifyTime=TimeCurrent();
                 }
              }
           }
        }

      STB_GeomStore(ticket,false,e,sl,tp);
      return;
     }
  }

//==================================================================
// ONE MODIFY PER TICKET PER CYCLE + SAME-CYCLE SL ARBITRATION
//==================================================================
enum ENUM_STB_SL_SOURCE{ STB_SL_SRC_INITIAL=0, STB_SL_SRC_PROFIT_PROTECTION=1, STB_SL_SRC_TRAIL=2 };
struct STBSLProposal{ bool valid; bool hasSL; double sl; int source; string reason; };
struct STBQueuedSLProposal
  {
   ulong ticket;
   long cycle;
   bool valid;
   bool hasSL;
   double sl;
   int source;
   string reason;
  };
STBQueuedSLProposal g_stbSLQueue[];
bool g_stbCollectingSLProposals=false;
// Any queue allocation failure makes the automatic SL batch incomplete.
// Fail closed rather than silently resolving a subset of intended candidates.
bool g_stbSLCollectionFaulted=false;
long g_stbCycleId=0;

void STB_BeginCycle()
  {
   g_stbCycleId++;
   ArrayResize(g_stbSLQueue,0);
   g_stbCollectingSLProposals=false;
   g_stbSLCollectionFaulted=false;
  }

bool STB_QueuePositionSL(const ulong ticket,const double candidateSL,const int source,const string reason)
  {
   if(!g_stbCollectingSLProposals || ticket==0 || candidateSL<=0.0 ||
       !STB_IsProtectionPosition(ticket))
      return false;
   int n=ArraySize(g_stbSLQueue);
   if(ArrayResize(g_stbSLQueue,n+1)!=n+1)
     {
      g_stbSLCollectionFaulted=true;
      Print("STB SL arbitration collection failure: queue allocation failed cycle=",
            g_stbCycleId," ticket=",ticket," source=",source," reason=",reason);
      return false;
     }
   g_stbSLQueue[n].ticket=ticket;
   g_stbSLQueue[n].cycle=g_stbCycleId;
   g_stbSLQueue[n].valid=true;
   g_stbSLQueue[n].hasSL=true;
   g_stbSLQueue[n].sl=candidateSL;
   g_stbSLQueue[n].source=source;
   g_stbSLQueue[n].reason=reason;
   return true;
  }

bool STB_CycleWriteAlreadyDone(const ulong ticket)
  {
   if(g_stbCycleId==0)
      return false;
   int idx=STB_ExposureFind(ticket);
   return (idx>=0 && g_stbExposure[idx].lastWriteCycle==g_stbCycleId);
  }

void STB_CycleMarkWritten(const ulong ticket)
  {
   int idx=STB_ExposureFind(ticket);
   if(idx<0)
      idx=STB_ExposureEnsure(ticket,false);
   if(idx>=0)
      g_stbExposure[idx].lastWriteCycle=g_stbCycleId;
  }

// Validate every proposal against one shared price/constraint snapshot.
// IsValidSLForPosition() is still used on the chosen candidate and again by
// the central modify bridge immediately before broker submission.
bool STB_IsValidSLForDecisionSnapshot(const long side,
                                      const double sl,
                                      const MqlTick &tick,
                                      const double point,
                                      const long stopsLevel,
                                      const long freezeLevel)
  {
   if(sl<=0.0 || point<=0.0 || tick.bid<=0.0 || tick.ask<=0.0)
      return false;
   double minimumDistance=(MathMax((double)stopsLevel,(double)freezeLevel)+1.0)*point;
   if(minimumDistance<=0.0)
      minimumDistance=point;
   if(side==POSITION_TYPE_BUY)
      return sl<tick.bid && (tick.bid-sl)>=minimumDistance;
   if(side==POSITION_TYPE_SELL)
      return sl>tick.ask && (sl-tick.ask)>=minimumDistance;
   return false;
  }

bool STB_ResolvePositionSL(const ulong ticket,STBSLProposal &props[],const int count,double &finalSL,int &finalSource)
  {
   finalSL=0.0; finalSource=-1;
   if(ticket==0 || count<=0 || !PositionSelectByTicket(ticket)) return false;
   string symbol=PositionGetString(POSITION_SYMBOL);
   long side=PositionGetInteger(POSITION_TYPE);
   double currentSL=PositionGetDouble(POSITION_SL);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);

   // If net profit has crossed the universal lock trigger, a competing
   // automatic proposal may not replace the required lock with a weaker SL.
   // When the existing position has no SL at all, retain the strongest valid
   // non-profit-lock candidate as a last-resort protection fallback if broker
   // geometry makes the profit-lock target impossible this cycle.
   double decisionPriceMovePips=STB_PositionPriceMovePips(ticket);
   double pip=PipSize(symbol);
   bool enforceProfitLockFloor=
      (decisionPriceMovePips>=STB_ProfitLockTriggerPips() && pip>0.0);
   double profitLockTarget=0.0;
   if(enforceProfitLockFloor)
     {
      profitLockTarget=NormalizePrice(symbol,
         side==POSITION_TYPE_BUY
         ? entry+STB_ProfitLockLockPips()*pip
         : entry-STB_ProfitLockLockPips()*pip);
      if(profitLockTarget<=0.0)
         enforceProfitLockFloor=false;
     }

   // Use one tick and one broker-constraint snapshot for all proposals so
   // array arrival order cannot change which candidates pass geometry checks.
   MqlTick decisionTick;
   if(!SymbolInfoTick(symbol,decisionTick)) return false;
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   long stopsLevel=(long)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel=(long)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double tieTolerance=(tickSize>0.0 ? tickSize*0.25:0.0);

   // Do not let an unplaceable legacy +20-pip floor block a valid, positive
   // adaptive break-even stop. Existing stops are still monotonic: disabling
   // this cycle's floor cannot loosen an SL already installed on the server.
   if(enforceProfitLockFloor &&
      !STB_IsValidSLForDecisionSnapshot(side,profitLockTarget,decisionTick,
                                        point,stopsLevel,freezeLevel))
      enforceProfitLockFloor=false;

   bool found=false;
   bool unprotectedFallbackFound=false;
   double unprotectedFallbackSL=0.0;
   int unprotectedFallbackSource=-1;
   for(int i=0;i<count;i++)
     {
      if(!props[i].valid || !props[i].hasSL || props[i].sl<=0.0) continue;
      double c=NormalizePrice(symbol,props[i].sl);
      if(c<=0.0 ||
         !STB_IsValidSLForDecisionSnapshot(side,c,decisionTick,point,stopsLevel,freezeLevel))
         continue;

      if(side==POSITION_TYPE_BUY)
        {
         if(currentSL>0.0 && c<=currentSL) continue;
        }
      else if(side==POSITION_TYPE_SELL)
        {
         if(currentSL>0.0 && c>=currentSL) continue;
        }
      else
         continue;

      bool meetsProfitLockFloor=!enforceProfitLockFloor ||
         (side==POSITION_TYPE_BUY ? c>=profitLockTarget:c<=profitLockTarget);
      if(!meetsProfitLockFloor)
        {
         // Never downgrade an installed SL below the active lock target.
         // Only a position with no existing SL may use the INITIAL candidate
         // as a fail-safe stop while the broker rejects the requested lock.
         if(currentSL<=0.0 && props[i].source!=STB_SL_SRC_PROFIT_PROTECTION)
           {
            bool strongerFallback=!unprotectedFallbackFound;
            if(unprotectedFallbackFound)
              {
               if(side==POSITION_TYPE_BUY && c>unprotectedFallbackSL)
                  strongerFallback=true;
               else if(side==POSITION_TYPE_SELL && c<unprotectedFallbackSL)
                  strongerFallback=true;
               else if(MathAbs(c-unprotectedFallbackSL)<=tieTolerance &&
                       props[i].source<unprotectedFallbackSource)
                  strongerFallback=true;
              }
            if(strongerFallback)
              {
               unprotectedFallbackSL=c;
               unprotectedFallbackSource=props[i].source;
               unprotectedFallbackFound=true;
              }
           }
         continue;
        }

      if(side==POSITION_TYPE_BUY)
        {
         if(!found || c>finalSL || (MathAbs(c-finalSL)<=tieTolerance && props[i].source<finalSource))
           { finalSL=c; finalSource=props[i].source; found=true; }
        }
      else if(side==POSITION_TYPE_SELL)
        {
         if(!found || c<finalSL || (MathAbs(c-finalSL)<=tieTolerance && props[i].source<finalSource))
           { finalSL=c; finalSource=props[i].source; found=true; }
        }
     }

   // With no installed SL, use the strongest valid non-lock stop if broker
   // geometry prevents the minimum profit-lock target from being placed.
   // This emergency fallback is never used to loosen an existing position.
   if(!found && unprotectedFallbackFound)
     {
      finalSL=unprotectedFallbackSL;
      finalSource=unprotectedFallbackSource;
      found=true;
     }

   // The chosen candidate must still satisfy the live broker constraint check.
   // If the market moved since the decision snapshot, fail closed this cycle.
   if(!found || !IsValidSLForPosition(symbol,side,finalSL))
      return false;
   return true;
  }

bool STB_SubmitPositionSL(const ulong ticket,const double candidateSL,const int source,const string reason,const bool isUserAction=false)
  {
   if(ticket==0 ||  !STB_IsProtectionPosition(ticket))
      return false;

   // Explicit user SAVE remains synchronous and isolated from automatic batches.
   if(isUserAction)
      return ModifyPositionSL(ticket,candidateSL,true);

   if(g_stbCollectingSLProposals)
      return STB_QueuePositionSL(ticket,candidateSL,source,reason);

   // Lifecycle exception: a newly-created position may need its initial
   // protective stop before the next scheduled management cycle. Do not let
   // trailing/profit-protection silently bypass same-cycle arbitration.
   if(source!=STB_SL_SRC_INITIAL)
     {
      Print("STB SL request blocked outside arbitration cycle ticket=",ticket,
            " source=",source," reason=",reason);
      return false;
     }

   return ModifyPositionSL(ticket,candidateSL,false);
  }

void STB_ProfitProtectionOne(const ulong ticket)
  {
   if(ticket==0 || !STB_IsProtectionPosition(ticket))
      return;
   string symbol=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL=PositionGetDouble(POSITION_SL);
   double priceMovePips=STB_PositionPriceMovePips(ticket);
   double locked=GetLockedPips(ticket);
   double triggerPips=STB_ProfitLockTriggerPips();
   double lockPips=STB_ProfitLockLockPips();
   double pip=PipSize(symbol);

   // Trigger from executable price movement, not cash PnL divided by pip value.
   // Net pips are diagnostic because commission and swap can differ.
   bool liveStopSatisfiesPolicy=false;
   if(pip>0.0 && entry>0.0 && currentSL>0.0)
     {
      double policySL=NormalizePrice(symbol,
         type==POSITION_TYPE_BUY ? entry+lockPips*pip : entry-lockPips*pip);
      double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      double tolerance=MathMax(point*0.5,
                               tickSize>0.0 ? tickSize*0.5:point*0.5);
      if(type==POSITION_TYPE_BUY)
         liveStopSatisfiesPolicy=(policySL>0.0 && currentSL+tolerance>=policySL);
      else if(type==POSITION_TYPE_SELL)
         liveStopSatisfiesPolicy=(policySL>0.0 && currentSL-tolerance<=policySL);
     }
   if(priceMovePips>=triggerPips && (locked<lockPips || !liveStopSatisfiesPolicy))
     {
      double netProfitPips=PositionNetProfitPips(ticket);
      Print("STB AUTO PROFIT LOCK TRIGGER ticket=",ticket,
            " symbol=",symbol,
            " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " priceMovePips=",DoubleToString(priceMovePips,1),
            " netProfitPips=",DoubleToString(netProfitPips,1),
            " pipSize=",DoubleToString(pip,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " triggerPips=",DoubleToString(triggerPips,1),
            " lockPips=",DoubleToString(lockPips,1),
            " lockedPips=",DoubleToString(locked,1),
            " liveSL=",DoubleToString(currentSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " liveStopSatisfiesPolicy=",liveStopSatisfiesPolicy);
      ApplyProfitLock(ticket,lockPips);
     }
  }

// The single broker-facing position modification writer for SL and TP.
// Callers validate their own intent; this bridge enforces snapshot ownership,
// single-write-per-cycle, server retcodes, and terminal-state verification.
bool STB_PositionModifyBrokerVerified(const ulong ticket,
                                      const double expectedEntry,
                                      const double expectedSL,
                                      const double expectedTP,
                                      const double newSL,
                                      const double newTP,
                                      const string failureKey,
                                      const string operation)
  {
   g_modifyWasNoChanges=false;
   if(ticket==0 || !PositionSelectByTicket(ticket) ||
      !STB_IsProtectionPosition(ticket))
      return false;

   if(STB_ExposureEnsure(ticket,true)<0)
     {
      Print("STB POSITION MODIFY DEFERRED ticket=",ticket,
            " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
      return false;
     }

   string symbol=PositionGetString(POSITION_SYMBOL);
   if(symbol=="" || !STB_SymbolManagementOwnedVerified(symbol))
      return false;

       MqlTick positionWriteTick;
    string positionQuoteReason="";
    if(!SymbolInfoTick(symbol,positionWriteTick) ||
       !STB_ScannerQuoteValid(positionWriteTick,positionQuoteReason))
      {
       Print("STB POSITION MODIFY DEFERRED ticket=",ticket,
             " operation=",operation,
             " reason=",(positionQuoteReason=="" ? "QUOTE_UNAVAILABLE":positionQuoteReason));
       return false;
      }

if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ||
      !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      return false;

   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   if(point<=0.0)
      return false;
   double tolerance=MathMax(point*0.5,
                            tickSize>0.0 ? tickSize*0.5:point*0.5);

   double liveEntry=PositionGetDouble(POSITION_PRICE_OPEN);
   double liveSL=PositionGetDouble(POSITION_SL);
   double liveTP=PositionGetDouble(POSITION_TP);
   long side=PositionGetInteger(POSITION_TYPE);
   if(MathAbs(liveEntry-expectedEntry)>tolerance ||
      MathAbs(liveSL-expectedSL)>tolerance ||
      MathAbs(liveTP-expectedTP)>tolerance)
     {
      Print("STB POSITION MODIFY ABORTED: snapshot changed ticket=",ticket,
            " operation=",operation,
            " entryExpected=",DoubleToString(expectedEntry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " entryLive=",DoubleToString(liveEntry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " slExpected=",DoubleToString(expectedSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " slLive=",DoubleToString(liveSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " tpExpected=",DoubleToString(expectedTP,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " tpLive=",DoubleToString(liveTP,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
      return false;
     }

   if(newSL<=0.0 || newTP<0.0)
      return false;

   // For a SL change, validate the new level immediately before the request.
   // For a TP-only change, the existing SL is preserved exactly.
   if(MathAbs(newSL-liveSL)>tolerance &&
      !IsValidSLForPosition(symbol,side,newSL))
      return false;

   if(STB_CycleWriteAlreadyDone(ticket))
      return false;

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetAsyncMode(false);
   trade.SetTypeFillingBySymbol(symbol);

   // Cache the intended geometry before submitting so our own transaction is
   // not misclassified as a manual override. Failure paths restore actual state.
   STB_GeomStore(ticket,true,liveEntry,newSL,newTP);

   // Consume the ticket's single-write budget on the attempt, not only on
   // success. An immediate TP fallback must not retry a failed SL+TP request
   // a second time in the same management cycle.
   STB_CycleMarkWritten(ticket);

   ResetLastError();
   bool requestOK=trade.PositionModify(ticket,newSL,newTP);
   uint ret=trade.ResultRetcode();
   if(!requestOK || (ret!=TRADE_RETCODE_NO_CHANGES &&
                     !TradeRetcodeModifySucceeded()))
     {
      if(PositionSelectByTicket(ticket))
         STB_GeomStore(ticket,true,
                       PositionGetDouble(POSITION_PRICE_OPEN),
                       PositionGetDouble(POSITION_SL),
                       PositionGetDouble(POSITION_TP));
      if(failureKey!="")
         GlobalVariableSet(failureKey,(double)TimeCurrent());
      Print("STB POSITION MODIFY FAILED ticket=",ticket,
            " symbol=",symbol,
            " operation=",operation,
            " requestOK=",requestOK,
            " ret=",IntegerToString((int)ret),
            " desc=",trade.ResultRetcodeDescription(),
            " err=",IntegerToString(GetLastError()));
      return false;
     }

   if(!PositionSelectByTicket(ticket))
     {
      if(failureKey!="")
         GlobalVariableSet(failureKey,(double)TimeCurrent());
      return false;
     }

   double verifiedEntry=PositionGetDouble(POSITION_PRICE_OPEN);
   double verifiedSL=PositionGetDouble(POSITION_SL);
   double verifiedTP=PositionGetDouble(POSITION_TP);
   bool verified=(MathAbs(verifiedEntry-expectedEntry)<=tolerance &&
                  MathAbs(verifiedSL-newSL)<=tolerance &&
                  MathAbs(verifiedTP-newTP)<=tolerance);
   if(!verified)
     {
      STB_GeomStore(ticket,true,verifiedEntry,verifiedSL,verifiedTP);
      if(failureKey!="")
         GlobalVariableSet(failureKey,(double)TimeCurrent());
      Print("STB POSITION MODIFY CONFIRM MISMATCH ticket=",ticket,
            " symbol=",symbol,
            " operation=",operation,
            " slExpected=",DoubleToString(newSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " slActual=",DoubleToString(verifiedSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " tpExpected=",DoubleToString(newTP,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " tpActual=",DoubleToString(verifiedTP,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
      return false;
     }

   STB_GeomStore(ticket,true,verifiedEntry,verifiedSL,verifiedTP);
   STB_CycleMarkWritten(ticket);
   if(failureKey!="")
      GlobalVariableDel(failureKey);
   if(ret==TRADE_RETCODE_NO_CHANGES)
      g_modifyWasNoChanges=true;
   Print("STB POSITION MODIFY CONFIRMED ticket=",ticket,
         " symbol=",symbol,
         " operation=",operation,
         " SL=",DoubleToString(verifiedSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
         " TP=",DoubleToString(verifiedTP,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
         " ret=",IntegerToString((int)ret));
   return true;
  }

/* P2 single-writer bridge */ bool ModifyPositionSL(const ulong ticket,
                      const double newSL,
                      const bool isUserAction=false,
                      const double requestedTP=-1.0)
  {
   g_modifyWasNoChanges=false;
   if(ticket==0 || !STB_IsProtectionPosition(ticket))
      return false;

   string symbol=PositionGetString(POSITION_SYMBOL);
   if(!STB_SymbolManagementOwnedVerified(symbol))
     {
      Print("STB MODIFY WAIT: symbol-management lease not owned ticket=",ticket,
            " symbol=",symbol," chart=",ChartID());
      return false;
     }

   long type=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL=PositionGetDouble(POSITION_SL);
   double currentTP=PositionGetDouble(POSITION_TP);

   if(currentSL>0.0)
     {
      if(type==POSITION_TYPE_BUY && newSL<=currentSL)
         return true;
      if(type==POSITION_TYPE_SELL && newSL>=currentSL)
         return true;
     }

   if(!IsValidSLForPosition(symbol,type,newSL))
     {
      MqlTick invalidTick;
      SymbolInfoTick(symbol,invalidTick);
      Print("STB MODIFY WAIT: invalid SL geometry ticket=",ticket,
            " symbol=",symbol,
            " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " candidateSL=",DoubleToString(newSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " bid=",DoubleToString(invalidTick.bid,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " ask=",DoubleToString(invalidTick.ask,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " stopsLevel=",SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL),
            " freezeLevel=",SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL));
      return false;
     }

   if(STB_CycleWriteAlreadyDone(ticket))
      return false;

   string gv=ScopedStateName("MODFAIL_"+IntegerToString((long)ticket));
   if(GlobalVariableCheck(gv))
     {
      double lastFail=GlobalVariableGet(gv);
      if(lastFail>0.0 && (TimeCurrent()-lastFail)<2)
         return false;
     }

   // Snapshot is checked twice: here and again at the shared broker writer.
   if(!PositionSelectByTicket(ticket))
      return false;
   double latestEntry=PositionGetDouble(POSITION_PRICE_OPEN);
   double latestSL=PositionGetDouble(POSITION_SL);
   double latestTP=PositionGetDouble(POSITION_TP);
   long latestType=PositionGetInteger(POSITION_TYPE);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   double tol=MathMax(point*0.5,
                      tickSize>0.0 ? tickSize*0.5:point*0.5);

   if(latestType!=type ||
      MathAbs(latestEntry-entry)>tol ||
      MathAbs(latestSL-currentSL)>tol ||
      MathAbs(latestTP-currentTP)>tol)
     {
      Print("STB MODIFY ABORTED: position state changed before request ticket=",ticket,
            " symbol=",symbol);
      return false;
     }

   if(latestSL>0.0 &&
      ((latestType==POSITION_TYPE_BUY && newSL<=latestSL) ||
       (latestType==POSITION_TYPE_SELL && newSL>=latestSL)))
      return true;
   if(!IsValidSLForPosition(symbol,latestType,newSL) ||
      !STB_SymbolManagementOwnedVerified(symbol))
      return false;

   double targetTP=latestTP;
   if(latestTP<=0.0 && requestedTP>=0.0)
      targetTP=requestedTP; // only fill an absent TP; never replace an explicit one

   return STB_PositionModifyBrokerVerified(ticket,
                                           latestEntry,
                                           latestSL,
                                           latestTP,
                                           newSL,
                                           targetTP,
                                           gv,
                                           (targetTP!=latestTP ? "SL+TP":"SL"));
  }

// Resolve all automatic candidates after the three managers have run.
// The selected write is revalidated by ModifyPositionSL against live terminal state.
bool STB_CalculatePositionTPFromStructure(const string symbol,
                                          const long positionType,
                                          const double entry,
                                          const double sl,
                                          const double minimumRR,
                                          double &tp,
                                          string &source);

void STB_FlushPositionSLProposals()
  {
   g_stbCollectingSLProposals=false;
   bool collectionFault=g_stbSLCollectionFaulted;
   g_stbSLCollectionFaulted=false;
   if(collectionFault)
     {
      Print("STB SL arbitration ABORTED: incomplete proposal queue; no automatic SL writes this cycle=",
            g_stbCycleId," queued=",ArraySize(g_stbSLQueue));
      ArrayResize(g_stbSLQueue,0);
      return;
     }
   for(int i=0;i<ArraySize(g_stbSLQueue);i++)
     {
      ulong ticket=g_stbSLQueue[i].ticket;
      if(ticket==0 || g_stbSLQueue[i].cycle!=g_stbCycleId) continue;
      bool seen=false;
      for(int j=0;j<i;j++)
         if(g_stbSLQueue[j].ticket==ticket && g_stbSLQueue[j].cycle==g_stbCycleId) { seen=true; break; }
      if(seen ||  !STB_IsProtectionPosition(ticket)) continue;
      STBSLProposal props[];
      int count=0;
      for(int j=i;j<ArraySize(g_stbSLQueue);j++)
         if(g_stbSLQueue[j].ticket==ticket && g_stbSLQueue[j].cycle==g_stbCycleId)
            count++;
      if(count<=0) continue;
      if(ArrayResize(props,count)!=count)
        {
         Print("STB SL arbitration ABORTED for ticket=",ticket,
               ": cannot allocate full candidate set cycle=",g_stbCycleId,
               " candidates=",count);
         continue; // never arbitrate a silently truncated candidate set
        }
      int propIndex=0;
      for(int j=i;j<ArraySize(g_stbSLQueue);j++)
        {
         if(g_stbSLQueue[j].ticket!=ticket || g_stbSLQueue[j].cycle!=g_stbCycleId) continue;
         props[propIndex].valid=g_stbSLQueue[j].valid; props[propIndex].hasSL=g_stbSLQueue[j].hasSL;
         props[propIndex].sl=g_stbSLQueue[j].sl; props[propIndex].source=g_stbSLQueue[j].source;
         props[propIndex].reason=g_stbSLQueue[j].reason; propIndex++;
        }
      double chosenSL=0.0; int chosenSource=-1;
      if(count<=0 || !STB_ResolvePositionSL(ticket,props,count,chosenSL,chosenSource))
        {
         Print("STB SL arbitration WAIT: no valid candidate ticket=",ticket,
               " cycle=",g_stbCycleId,
               " candidates=",count);
         continue;
        }
      string symbol=PositionGetString(POSITION_SYMBOL);
      long side=PositionGetInteger(POSITION_TYPE);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      // If no TP exists, calculate a target from the same chosen SL and attach
      // it to this single verified modify request. This prevents a continuously
      // improving trail from starving the missing-TP manager every cycle.
      double currentTP=PositionGetDouble(POSITION_TP);
      double tpForRequest=-1.0; // negative sentinel = preserve the live TP
      if(currentTP<=0.0)
        {
         tpForRequest=0.0;
         double proposedTP=0.0;
         string tpSource="";
         if(STB_CalculatePositionTPFromStructure(symbol,side,entry,chosenSL,
                                                  InpMinimumRR,proposedTP,tpSource))
           {
            tpForRequest=proposedTP;
            Print("STB SL+TP ARBITRATION target ticket=",ticket,
                  " source=",tpSource,
                  " TP=",DoubleToString(proposedTP,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
           }
        }
      if(!ModifyPositionSL(ticket,chosenSL,false,tpForRequest) ||
         !PositionSelectByTicket(ticket)) continue;
      double actualSL=PositionGetDouble(POSITION_SL);
      // A missing SL must never be treated as a confirmed protective stop;
      // this is especially important for SELL-side lock-pips bookkeeping.
      if(actualSL<=0.0)
        {
         Print("STB SL arbitration verification failed: position has no SL ticket=",ticket,
               " cycle=",g_stbCycleId);
         continue;
        }
      double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
      double tolerance=MathMax(point*0.5,tickSize>0.0 ? tickSize*0.5:point*0.5);
      if(side==POSITION_TYPE_BUY && actualSL+tolerance<chosenSL) continue;
      if(side==POSITION_TYPE_SELL && actualSL-tolerance>chosenSL) continue;
      // Persist every broker-confirmed positive lock, including adaptive
      // break-even offsets smaller than the legacy +20-pip lock.
      double pip=PipSize(symbol);
      if(pip>0.0)
        {
         double achieved=(side==POSITION_TYPE_BUY
                          ? (actualSL-entry)/pip
                          : (entry-actualSL)/pip);
         if(achieved>0.0)
            SetLockedPips(ticket,MathMax(GetLockedPips(ticket),achieved));
        }
      Print("STB SL arbitration confirmed ticket=",ticket," source=",chosenSource,
            " SL=",DoubleToString(actualSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " candidates=",count);
     }
   ArrayResize(g_stbSLQueue,0);
  }

//==================================================================
// APPLY PROFIT LOCK//==================================================================
// APPLY PROFIT LOCK
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ApplyProfitLock(const ulong ticket,const double lockPips,const bool isUserAction=false)
{
   if(ticket==0 || !PositionSelectByTicket(ticket))
      return false;

   string symbol=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL=PositionGetDouble(POSITION_SL);

   double pip=PipSize(symbol);

   if(pip<=0.0)
      return false;

   double targetSL=0.0;

   if(type==POSITION_TYPE_BUY)
   {
      targetSL=NormalizePrice(symbol,entry+lockPips*pip);

      if(currentSL>0.0 && targetSL<=currentSL)
      {
         // The observed SL may change outside this EA between the initial read
         // and the bookkeeping update. Re-read terminal state before crediting
         // a lock that is already satisfied without a broker write.
         if(!PositionSelectByTicket(ticket))
            return false;
         long liveType=PositionGetInteger(POSITION_TYPE);
         double liveSL=PositionGetDouble(POSITION_SL);
         double liveEntry=PositionGetDouble(POSITION_PRICE_OPEN);
         double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
         double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
         double tolerance=MathMax(point*0.5,
                                  tickSize>0.0 ? tickSize*0.5:point*0.5);
         if(liveType!=POSITION_TYPE_BUY || liveSL<=0.0 ||
            liveSL+tolerance<targetSL)
            return false;
         double achieved=(liveSL-liveEntry)/pip;
         if(achieved<=0.0)
            return false;
         SetLockedPips(ticket,MathMax(GetLockedPips(ticket),achieved));
         return true;
      }
   }

   if(type==POSITION_TYPE_SELL)
   {
      targetSL=NormalizePrice(symbol,entry-lockPips*pip);

      if(currentSL>0.0 && targetSL>=currentSL)
      {
         // Confirm the live SELL stop still protects at least the requested
         // lock before persisting lock bookkeeping.
         if(!PositionSelectByTicket(ticket))
            return false;
         long liveType=PositionGetInteger(POSITION_TYPE);
         double liveSL=PositionGetDouble(POSITION_SL);
         double liveEntry=PositionGetDouble(POSITION_PRICE_OPEN);
         double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
         double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
         double tolerance=MathMax(point*0.5,
                                  tickSize>0.0 ? tickSize*0.5:point*0.5);
         if(liveType!=POSITION_TYPE_SELL || liveSL<=0.0 ||
            liveSL-tolerance>targetSL)
            return false;
         double achieved=(liveEntry-liveSL)/pip;
         if(achieved<=0.0)
            return false;
         SetLockedPips(ticket,MathMax(GetLockedPips(ticket),achieved));
         return true;
      }
   }

   if(!IsValidSLForPosition(symbol,type,targetSL))
   {
      MqlTick tick;
      SymbolInfoTick(symbol,tick);

      Print("STB PROFIT LOCK WAIT/REJECT ticket=",ticket,
            " symbol=",symbol,
            " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " profitPips=",DoubleToString(PositionProfitPips(symbol,type,entry),1),
            " requestedLockPips=",DoubleToString(lockPips,1),
            " entry=",DoubleToString(entry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " currentSL=",DoubleToString(currentSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " targetSL=",DoubleToString(targetSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " bid=",DoubleToString(tick.bid,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " ask=",DoubleToString(tick.ask,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " stopsLevel=",IntegerToString((int)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL)),
            " freezeLevel=",IntegerToString((int)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL)));
      return false;
   }

   if(!STB_SubmitPositionSL(ticket,targetSL,STB_SL_SRC_PROFIT_PROTECTION,"PROFIT_PROTECTION",isUserAction))
      return false;

   if(!g_stbCollectingSLProposals || isUserAction)
      SetLockedPips(ticket,MathMax(GetLockedPips(ticket),lockPips));

   return true;
}

//==================================================================
// AUTO +50 -> +20 (UNIVERSAL PROFIT LOCK POLICY, all managed positions)
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void AutoProfitProtection()
{
   // One implementation owns the universal trigger and lock policy.
   // Open-position management remains active regardless of manual SL/TP edits.
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !STB_IsProtectionPosition(ticket))
         continue;

      STB_ProfitProtectionOne(ticket);
   }
}

//==================================================================
// MANUAL SAVE +20
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManualSavePlus20()
  {
   STB_BeginCycle(); // Blueprint 26: user SAVE command gets its own decision cycle
   int managed=0;

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !IsManagedPosition(ticket))
         continue;

      managed++;

      string symbol=PositionGetString(POSITION_SYMBOL);
      long type=PositionGetInteger(POSITION_TYPE);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double profit=PositionNetProfitPips(ticket);
      double currentLock=GetLockedPips(ticket);
      double requested=currentLock+InpManualSaveStepPips;

      if(profit>=requested)
          ApplyProfitLock(ticket,requested,true);
     }

   Print("STB SAVE +20 executed for managed positions count=",managed);
  }

// Cache closed-candle ATR per symbol. The value does not change within the
// current protection candle, so several manager stages can safely share it.
struct STBProtectionATRCacheEntry
  {
   string symbol;
   datetime candle;
   double atr;
  };
STBProtectionATRCacheEntry g_stbProtectionATRCache[];

bool STB_GetAdaptiveProtectionATR(const string symbol,double &atrOut)
  {
   atrOut=0.0;
   if(symbol=="" || !SymbolSelect(symbol,true))
      return false;

   datetime candle=iTime(symbol,InpProtectionTF,0);
   if(candle<=0)
      return false;

   for(int i=0;i<ArraySize(g_stbProtectionATRCache);i++)
     {
      if(g_stbProtectionATRCache[i].symbol!=symbol)
         continue;
      if(g_stbProtectionATRCache[i].candle==candle &&
         g_stbProtectionATRCache[i].atr>0.0)
        {
         atrOut=g_stbProtectionATRCache[i].atr;
         return true;
        }
      break;
     }

   MqlRates rates[];
   if(!GetRates(symbol,InpProtectionTF,24,rates))
      return false;
   double atr=LocalATR(rates,1,14);
   if(atr<=0.0 || !MathIsValidNumber(atr))
      return false;

   int idx=-1;
   for(int i=0;i<ArraySize(g_stbProtectionATRCache);i++)
      if(g_stbProtectionATRCache[i].symbol==symbol)
        {
         idx=i;
         break;
        }
   if(idx<0)
     {
      idx=ArraySize(g_stbProtectionATRCache);
      if(ArrayResize(g_stbProtectionATRCache,idx+1)!=idx+1)
         return false;
      g_stbProtectionATRCache[idx].symbol=symbol;
     }
   g_stbProtectionATRCache[idx].candle=candle;
   g_stbProtectionATRCache[idx].atr=atr;
   atrOut=atr;
   return true;
  }

double STB_AdaptiveBreakEvenOffsetPips(const ulong ticket,
                                       const string symbol,
                                       const long side,
                                       const double entry,
                                       const double pip)
  {
   if(ticket==0 || pip<=0.0 || !PositionSelectByTicket(ticket))
      return 0.0;

   double volume=PositionGetDouble(POSITION_VOLUME);
   double pipValue=PositionPipValue(symbol,side,volume,entry);
   if(pipValue<=0.0 || !MathIsValidNumber(pipValue))
      return 0.0;

   double commission=MathAbs(PositionCommissionMoney(ticket));
   double adverseSwap=MathMax(0.0,-PositionGetDouble(POSITION_SWAP));
   double observedCostPips=(commission+adverseSwap)/pipValue;

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick) || tick.bid<=0.0 || tick.ask<=0.0)
      return 0.0;
   double spreadPips=MathMax(0.0,(tick.ask-tick.bid)/pip);
   double costOffset=observedCostPips*MathMax(1.0,InpBreakEvenCostMultiplier)
                     +spreadPips*0.25;
   return MathMax(MathMax(0.1,InpBreakEvenMinOffsetPips),costOffset);
  }

// Early break-even with a cost-aware positive offset. It never replaces the
// initial SL, never loosens an existing SL, and uses the shared SL arbiter.
bool STB_AdaptiveBreakEvenProtection(const ulong ticket)
  {
   if(!InpEnableAdaptiveProtection || ticket==0 ||
      !STB_IsProtectionPosition(ticket) || !PositionSelectByTicket(ticket))
      return false;

   string symbol=PositionGetString(POSITION_SYMBOL);
   long side=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL=PositionGetDouble(POSITION_SL);
   double pip=PipSize(symbol);
   if(entry<=0.0 || currentSL<=0.0 || pip<=0.0)
      return false; // wait until the initial SL is broker-confirmed

   double atr=0.0;
   if(!STB_GetAdaptiveProtectionATR(symbol,atr))
      return false;

   double offsetPips=STB_AdaptiveBreakEvenOffsetPips(ticket,symbol,side,entry,pip);
   if(offsetPips<=0.0)
      return false;

   double movePips=STB_PositionPriceMovePips(ticket);
   double triggerPrice=MathMax(MathMax(0.1,InpBreakEvenTriggerATR)*atr,
                               offsetPips*pip*1.5);
   if(movePips*pip<triggerPrice)
      return false;

   // Net PnL must already cover the protected buffer; otherwise the SL would
   // be labelled break-even while known costs still leave the position net red.
   if(PositionNetProfitPips(ticket)<offsetPips)
      return false;

   double target=NormalizePrice(symbol,
      side==POSITION_TYPE_BUY ? entry+offsetPips*pip : entry-offsetPips*pip);
   if(target<=0.0)
      return false;

   if(side==POSITION_TYPE_BUY && currentSL>=target)
      return false;
   if(side==POSITION_TYPE_SELL && currentSL<=target)
      return false;
   if(!IsValidSLForPosition(symbol,side,target))
      return false;

   bool queued=STB_SubmitPositionSL(ticket,target,STB_SL_SRC_PROFIT_PROTECTION,
                                    "ADAPTIVE_BREAK_EVEN");
   if(queued)
      Print("STB ADAPTIVE BREAK-EVEN QUEUED ticket=",ticket,
            " symbol=",symbol,
            " side=",(side==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " movePips=",DoubleToString(movePips,1),
            " triggerATR=",DoubleToString(InpBreakEvenTriggerATR,2),
            " offsetPips=",DoubleToString(offsetPips,1),
            " targetSL=",DoubleToString(target,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
   return queued;
  }

// The next stage upgrades break-even into an ATR-scaled positive lock. The
// legacy universal +50/+20 policy remains as a second independent floor.
bool STB_AdaptiveProfitLockProtection(const ulong ticket)
  {
   if(!InpEnableAdaptiveProtection || ticket==0 ||
      !STB_IsProtectionPosition(ticket) || !PositionSelectByTicket(ticket))
      return false;

   string symbol=PositionGetString(POSITION_SYMBOL);
   long side=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL=PositionGetDouble(POSITION_SL);
   double pip=PipSize(symbol);
   if(entry<=0.0 || currentSL<=0.0 || pip<=0.0)
      return false;

   double atr=0.0;
   if(!STB_GetAdaptiveProtectionATR(symbol,atr))
      return false;

   double offsetPips=STB_AdaptiveBreakEvenOffsetPips(ticket,symbol,side,entry,pip);
   if(offsetPips<=0.0)
      return false;
   double lockPips=MathMax(offsetPips,
                           MathMax(0.0,InpAdaptiveLockATR)*atr/pip);
   double movePips=STB_PositionPriceMovePips(ticket);
   double triggerPips=MathMax(MathMax(0.1,InpAdaptiveLockTriggerATR)*atr/pip,
                              lockPips+MathMax(0.5,offsetPips*0.25));
   if(movePips<triggerPips || PositionNetProfitPips(ticket)<lockPips)
      return false;

   double target=NormalizePrice(symbol,
      side==POSITION_TYPE_BUY ? entry+lockPips*pip : entry-lockPips*pip);
   if(target<=0.0)
      return false;
   if(side==POSITION_TYPE_BUY && currentSL>=target)
      return false;
   if(side==POSITION_TYPE_SELL && currentSL<=target)
      return false;
   if(!IsValidSLForPosition(symbol,side,target))
      return false;

   bool queued=STB_SubmitPositionSL(ticket,target,STB_SL_SRC_PROFIT_PROTECTION,
                                    "ADAPTIVE_PROFIT_LOCK");
   if(queued)
      Print("STB ADAPTIVE PROFIT LOCK QUEUED ticket=",ticket,
            " symbol=",symbol,
            " side=",(side==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " movePips=",DoubleToString(movePips,1),
            " triggerPips=",DoubleToString(triggerPips,1),
            " lockPips=",DoubleToString(lockPips,1),
            " targetSL=",DoubleToString(target,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
   return queued;
  }

// ATR trailing complements confirmed swing trailing and remains inside the
// one-write-per-ticket arbiter. It only accepts a stop beyond the entry-plus-cost
// buffer, so activating the trail cannot silently move protection back to loss.
bool STB_AdaptiveATRTrail(const ulong ticket)
  {
   if(!InpEnableAdaptiveProtection || ticket==0 ||
      !STB_IsProtectionPosition(ticket) || !PositionSelectByTicket(ticket))
      return false;

   string symbol=PositionGetString(POSITION_SYMBOL);
   long side=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL=PositionGetDouble(POSITION_SL);
   double pip=PipSize(symbol);
   if(entry<=0.0 || currentSL<=0.0 || pip<=0.0)
      return false;

   double atr=0.0;
   if(!STB_GetAdaptiveProtectionATR(symbol,atr))
      return false;

   double movePips=STB_PositionPriceMovePips(ticket);
   if(movePips*pip<MathMax(0.1,InpAdaptiveTrailStartATR)*atr)
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick) || tick.bid<=0.0 || tick.ask<=0.0)
      return false;
   double minDist=TradeMinDistance(symbol);
   if(minDist<=0.0)
      return false;

   double offsetPips=STB_AdaptiveBreakEvenOffsetPips(ticket,symbol,side,entry,pip);
   if(offsetPips<=0.0 || PositionNetProfitPips(ticket)<offsetPips)
      return false;
   double minimumLockedPrice=offsetPips*pip;
   double distance=MathMax(0.1,InpAdaptiveTrailDistanceATR)*atr;
   double candidate=0.0;

   if(side==POSITION_TYPE_BUY)
     {
      candidate=NormalizePrice(symbol,MathMin(tick.bid-distance,tick.bid-minDist));
      if(candidate<=entry+minimumLockedPrice || candidate<=currentSL)
         return false;
      double step=MathMax(MathMax(0.0,InpTrailStepPips)*pip,
                          MathMax(0.01,InpAdaptiveTrailStepATR)*atr);
      if(candidate-currentSL+SymbolInfoDouble(symbol,SYMBOL_POINT)*0.1<step)
         return false;
     }
   else if(side==POSITION_TYPE_SELL)
     {
      candidate=NormalizePrice(symbol,MathMax(tick.ask+distance,tick.ask+minDist));
      if(candidate<=0.0 || candidate>=entry-minimumLockedPrice || candidate>=currentSL)
         return false;
      double step=MathMax(MathMax(0.0,InpTrailStepPips)*pip,
                          MathMax(0.01,InpAdaptiveTrailStepATR)*atr);
      if(currentSL-candidate+SymbolInfoDouble(symbol,SYMBOL_POINT)*0.1<step)
         return false;
     }
   else
      return false;

   if(candidate<=0.0 || !IsValidSLForPosition(symbol,side,candidate))
      return false;

   bool queued=STB_SubmitPositionSL(ticket,candidate,STB_SL_SRC_TRAIL,"ADAPTIVE_ATR_TRAIL");
   if(queued)
      Print("STB ADAPTIVE ATR TRAIL QUEUED ticket=",ticket,
            " symbol=",symbol,
            " side=",(side==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " movePips=",DoubleToString(movePips,1),
            " atr=",DoubleToString(atr,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " distanceATR=",DoubleToString(InpAdaptiveTrailDistanceATR,2),
            " SL=",DoubleToString(candidate,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
   return queued;
  }

// Rate-limit structural-trailing WAIT messages per position.
void STB_StructuralTrailWaitLog(const ulong ticket,
                                const string reason,
                                const double movePips,
                                const double atr)
  {
   if(ticket==0 || reason=="")
      return;
   string key=ScopedStateName("STRUCTTRAIL_WAIT_"+(string)ticket);
   datetime now=TimeCurrent();
   if(GlobalVariableCheck(key) &&
      now-(datetime)GlobalVariableGet(key)<60)
      return;
   GlobalVariableSet(key,(double)now);
   string symbol="";
   long side=-1;
   if(PositionSelectByTicket(ticket))
     {
      symbol=PositionGetString(POSITION_SYMBOL);
      side=PositionGetInteger(POSITION_TYPE);
     }
   Print("STB STRUCTURAL TRAIL WAIT ticket=",ticket,
         " symbol=",symbol,
         " side=",(side==POSITION_TYPE_BUY ? "BUY":
                   side==POSITION_TYPE_SELL ? "SELL":"UNKNOWN"),
         " reason=",reason,
         " movePips=",DoubleToString(movePips,1),
         " atr=",DoubleToString(atr,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
         " tf=",EnumToString(InpTrailTF));
  }

bool STB_CalculateStructuralTrailSL(const ulong ticket,
                                    double &candidate,
                                    string &reason,
                                    double &atrOut)
  {
   candidate=0.0;
   atrOut=0.0;
   reason="STRUCTURAL_TRAIL_UNAVAILABLE";
   if(ticket==0 || !STB_IsProtectionPosition(ticket) ||
      !PositionSelectByTicket(ticket))
     {
      reason="POSITION_NOT_AVAILABLE";
      return false;
     }

   string symbol=PositionGetString(POSITION_SYMBOL);
   long side=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL=PositionGetDouble(POSITION_SL);
   if(entry<=0.0 || currentSL<=0.0)
     {
      reason="NO_INITIAL_SL";
      return false; // initial SL must be confirmed before trailing can run
     }

   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double pip=PipSize(symbol);
   double minDist=TradeMinDistance(symbol);
   if(point<=0.0 || pip<=0.0 || minDist<=0.0)
     {
      reason="BROKER_GEOMETRY_UNAVAILABLE";
      return false;
     }

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick) || tick.bid<=0.0 || tick.ask<=0.0)
     {
      reason="LIVE_QUOTE_UNAVAILABLE";
      return false;
     }

   int lookback=(int)MathMax(80,InpLookbackM15);
   MqlRates rates[];
   if(!GetRates(symbol,InpTrailTF,lookback,rates))
     {
      reason="TRAIL_TIMEFRAME_DATA_UNAVAILABLE";
      return false;
     }

   double atr=LocalATR(rates,1,14);
   atrOut=atr;
   if(atr<=0.0 || !MathIsValidNumber(atr))
     {
      reason="TRAIL_ATR_UNAVAILABLE";
      return false;
     }

   double movePips=STB_PositionPriceMovePips(ticket);
   double movePrice=movePips*pip;
   if(movePrice<atr*InpStructuralTrailStartATR)
     {
      reason="ATR_ACTIVATION_NOT_REACHED";
      return false;
     }

   SwingPoint highs[];
   SwingPoint lows[];
   if(CollectSwings(symbol,InpTrailTF,lookback,highs,lows)<=0)
     {
      reason="CONFIRMED_SWINGS_UNAVAILABLE";
      return false;
     }

   double buffer=MathMax(InpInitialSLBufferPips*pip,
                         atr*InpStructuralTrailBufferATR);
   double step=MathMax(0.0,InpTrailStepPips)*pip;
   double locked=GetLockedPips(ticket);

   if(side==POSITION_TYPE_BUY)
     {
      // CollectSwings returns older-to-newer pivots; inspect newest first.
      for(int i=ArraySize(lows)-1;i>=0;i--)
        {
         double swing=lows[i].price;
         if(swing<=0.0 || swing>=tick.bid)
            continue;
         double next=NormalizePrice(symbol,swing-buffer);
         if(next<=0.0 || next>=tick.bid-minDist)
            continue;
         if(locked>0.0)
            next=MathMax(next,NormalizePrice(symbol,entry+locked*pip));
         if(next<=entry || (currentSL>0.0 && next<=currentSL))
            continue;
         if(currentSL>0.0 && next-currentSL+point*0.1<step)
            continue;
         if(!IsValidSLForPosition(symbol,side,next))
            continue;
         candidate=next;
         reason="";
         return true;
        }
     }
   else if(side==POSITION_TYPE_SELL)
     {
      for(int i=ArraySize(highs)-1;i>=0;i--)
        {
         double swing=highs[i].price;
         if(swing<=tick.ask)
            continue;
         double next=NormalizePrice(symbol,swing+buffer);
         if(next<=tick.ask+minDist)
            continue;
         if(locked>0.0)
            next=MathMin(next,NormalizePrice(symbol,entry-locked*pip));
         if(next>=entry || (currentSL>0.0 && next>=currentSL))
            continue;
         if(currentSL>0.0 && currentSL-next+point*0.1<step)
            continue;
         if(!IsValidSLForPosition(symbol,side,next))
            continue;
         candidate=next;
         reason="";
         return true;
        }
     }
   else
     {
      reason="UNSUPPORTED_POSITION_SIDE";
      return false;
     }

   reason="NO_CONFIRMED_SWING_CAN_IMPROVE_VALID_SL";
   return false;
  }

//==================================================================
// M15 CLOSED-CANDLE / STRUCTURAL TRAILING
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool TrailPositionByLivePrice(const ulong ticket)
{
   if(ticket==0 || !STB_IsProtectionPosition(ticket))
      return false;
   // Manual SL/TP edits do not disable automated protection/trailing.
   string symbol=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double currentSL=PositionGetDouble(POSITION_SL);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);

   double pip=PipSize(symbol);
   if(pip<=0.0)
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return false;

   double profit=STB_PositionPriceMovePips(ticket);

   if(InpUseStructuralTrailing)
     {
      double structuralSL=0.0;
      double trailATR=0.0;
      string waitReason="";
      if(!STB_CalculateStructuralTrailSL(ticket,structuralSL,waitReason,trailATR))
        {
         STB_StructuralTrailWaitLog(ticket,waitReason,profit,trailATR);
         return false;
        }

      // All automatic stop candidates still go through the existing shared
      // proposal queue/resolver; never bypass SL arbitration or its broker checks.
      bool submitted=STB_SubmitPositionSL(ticket,structuralSL,
                                          STB_SL_SRC_TRAIL,"STRUCTURAL_TRAIL");
      if(submitted && !g_stbCollectingSLProposals)
         Print("STB STRUCTURAL TRAIL submitted ticket=",ticket,
               " symbol=",symbol,
               " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
               " movePips=",DoubleToString(profit,1),
               " atr=",DoubleToString(trailATR,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
               " SL=",DoubleToString(structuralSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
      return submitted;
     }

   if(profit < InpTrailStartPips)
      return false;

   double distancePips=MathMax(0.0,InpLiveTrailDistancePips);
   double distance=distancePips*pip;
   double minDist=TradeMinDistance(symbol);

   if(distance<=0.0)
      return false;

   double candidate=0.0;

   if(type==POSITION_TYPE_BUY)
   {
      candidate=MathMin(tick.bid-distance,
                        tick.bid-minDist);
      candidate=NormalizePrice(symbol,candidate);

      // Never loosen the existing SL.
      if(currentSL>0.0 && candidate<=currentSL)
         return false;

      // Preserve the already-earned automatic lock.
      double locked=GetLockedPips(ticket);
      if(locked<=0.0 && candidate<=entry)
         return false;
      if(locked>0.0)
      {
         double lockSL=NormalizePrice(symbol,entry+locked*pip);
         candidate=MathMax(candidate,lockSL);
      }
   }
   else if(type==POSITION_TYPE_SELL)
   {
      candidate=MathMax(tick.ask+distance,
                        tick.ask+minDist);
      candidate=NormalizePrice(symbol,candidate);

      // Never loosen the existing SL.
      if(currentSL>0.0 && candidate>=currentSL)
         return false;

      // Preserve the already-earned automatic lock.
      double locked=GetLockedPips(ticket);
      if(locked<=0.0 && candidate>=entry)
         return false;
      if(locked>0.0)
      {
         double lockSL=NormalizePrice(symbol,entry-locked*pip);
         candidate=MathMin(candidate,lockSL);
      }
   }
   else
      return false;

   if(candidate<=0.0)
      return false;

   double step=MathMax(0.0,InpTrailStepPips)*pip;
   if(currentSL>0.0)
     {
      if(type==POSITION_TYPE_BUY && candidate-currentSL<step)
         return false;
      if(type==POSITION_TYPE_SELL && currentSL-candidate<step)
         return false;
     }

   if(!IsValidSLForPosition(symbol,type,candidate))
   {
      long stopsLevel=(long)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
      long freezeLevel=(long)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);

      Print("STB LIVE TRAIL WAIT/REJECT ticket=",ticket,
            " symbol=",symbol,
            " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " profitPips=",DoubleToString(profit,1),
            " startPips=",DoubleToString(InpTrailStartPips,1),
            " distancePips=",DoubleToString(distancePips,1),
            " entry=",DoubleToString(entry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " bid=",DoubleToString(tick.bid,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " ask=",DoubleToString(tick.ask,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " currentSL=",DoubleToString(currentSL,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " candidateSL=",DoubleToString(candidate,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " stopsLevel=",IntegerToString((int)stopsLevel),
            " freezeLevel=",IntegerToString((int)freezeLevel));
      return false;
   }

   bool result=STB_SubmitPositionSL(ticket,candidate,STB_SL_SRC_TRAIL,"TRAIL");

   if(result && !g_stbCollectingSLProposals)
   {
      Print("STB LIVE TRAIL updated ticket=",ticket,
            " symbol=",symbol,
            " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " profitPips=",DoubleToString(profit,1),
            " distancePips=",DoubleToString(distancePips,1),
            " price=",DoubleToString(type==POSITION_TYPE_BUY ? tick.bid:tick.ask,
                                     (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " SL=",DoubleToString(candidate,
                                  (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
   }

   return result;
}

//==================================================================
// MANAGE POSITIONS
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CalculateNearestStructuralSL(const string symbol,
                                  const long direction,
                                  const double referencePrice,
                                  double &sl)
  {
   sl=0.0;
   SwingPoint highs[];
   SwingPoint lows[];

   if(CollectSwings(symbol,PERIOD_M15,InpLookbackM15,highs,lows)<=0)
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return false;

   double pip=PipSize(symbol);
   double minDist=TradeMinDistance(symbol);
   if(pip<=0.0 || minDist<=0.0 || referencePrice<=0.0)
      return false;

   double buffer=MathMax(0.0,InpInitialSLBufferPips)*pip;
   double strategyCap=(InpMaxInitialSLPips>0.0 ?
                       InpMaxInitialSLPips*pip : DBL_MAX);

   if(direction==POSITION_TYPE_BUY)
     {
      double maxAllowed=MathMin(referencePrice-minDist,
                                tick.bid-minDist);
      double bestLow=-DBL_MAX;
      double bestSL=0.0;

      for(int i=0;i<ArraySize(lows);i++)
        {
         double swingLow=lows[i].price;
         if(swingLow<=0.0 || swingLow>=referencePrice)
            continue;
         if(referencePrice-swingLow>strategyCap)
            continue;

         double candidate=NormalizePrice(symbol,swingLow-buffer);
         if(candidate<=0.0 || candidate>=maxAllowed)
            continue;

         // Cap the final Entry-to-SL distance, including the structural buffer.
         if(strategyCap<DBL_MAX && referencePrice-candidate>strategyCap)
            continue;

         if(swingLow>bestLow)
           {
            bestLow=swingLow;
            bestSL=candidate;
           }
        }

      if(bestSL<=0.0)
         return false;

      sl=bestSL;
      return true;
     }

   if(direction==POSITION_TYPE_SELL)
     {
      double minAllowed=MathMax(referencePrice+minDist,
                                tick.ask+minDist);
      double bestHigh=DBL_MAX;
      double bestSL=0.0;

      for(int i=0;i<ArraySize(highs);i++)
        {
         double swingHigh=highs[i].price;
         if(swingHigh<=referencePrice)
            continue;
         if(swingHigh-referencePrice>strategyCap)
            continue;

         double candidate=NormalizePrice(symbol,swingHigh+buffer);
         if(candidate<=minAllowed)
            continue;

         // Cap the final Entry-to-SL distance, including the structural buffer.
         if(strategyCap<DBL_MAX && candidate-referencePrice>strategyCap)
            continue;

         if(swingHigh<bestHigh)
           {
            bestHigh=swingHigh;
            bestSL=candidate;
           }
        }

      if(bestSL<=0.0)
         return false;

      sl=bestSL;
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CalculateReferenceCandleSL(const string symbol,
                                   const long positionType,
                                   const double referencePrice,
                                   double &sl)
  {
   sl=0.0;
   if(symbol=="" || referencePrice<=0.0)
      return false;

   double pip=PipSize(symbol);
   if(pip<=0.0)
      return false;

   double buffer=MathMax(0.0,InpInitialSLBufferPips)*pip;

   for(int shift=1;shift<=5;shift++)
     {
      double anchor=(positionType==POSITION_TYPE_BUY)
                    ? iLow(symbol,InpTrailTF,shift)
                    : iHigh(symbol,InpTrailTF,shift);

      if(anchor<=0.0)
         continue;

      double candidate=(positionType==POSITION_TYPE_BUY)
                       ? anchor-buffer
                       : anchor+buffer;

      candidate=NormalizePrice(symbol,candidate);

      bool withinStrategyCap=(InpMaxInitialSLPips<=0.0 ||
                              MathAbs(referencePrice-candidate)<=InpMaxInitialSLPips*pip);

      if(candidate>0.0 && withinStrategyCap &&
         IsValidSLForPosition(symbol,positionType,candidate))
        {
         sl=candidate;
         return true;
        }
     }

   return false;
  }

bool IsValidSLForPendingOrder(const string symbol,
                              const ENUM_ORDER_TYPE orderType,
                              const double entry,
                              const double sl)
  {
   if(symbol=="" || entry<=0.0 || sl<=0.0)
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return false;

   double minDist=TradeMinDistance(symbol);
   if(minDist<=0.0)
      return false;

   bool buyOrder=(orderType==ORDER_TYPE_BUY_STOP ||
                  orderType==ORDER_TYPE_BUY_LIMIT ||
                  orderType==ORDER_TYPE_BUY_STOP_LIMIT);

   bool sellOrder=(orderType==ORDER_TYPE_SELL_STOP ||
                   orderType==ORDER_TYPE_SELL_LIMIT ||
                   orderType==ORDER_TYPE_SELL_STOP_LIMIT);

   if(buyOrder)
      return (sl<=entry-minDist && sl<=tick.bid-minDist);

   if(sellOrder)
      return (sl>=entry+minDist && sl>=tick.ask+minDist);

   return false;
  }

bool CalculateInitialPendingProtectionSL(const string symbol,
                                         const ENUM_ORDER_TYPE orderType,
                                         const double entryPrice,
                                         double &sl)
  {
   sl=0.0;

   long direction=(orderType==ORDER_TYPE_BUY_STOP ||
                   orderType==ORDER_TYPE_BUY_LIMIT ||
                   orderType==ORDER_TYPE_BUY_STOP_LIMIT)
                  ? POSITION_TYPE_BUY
                  : (orderType==ORDER_TYPE_SELL_STOP ||
                     orderType==ORDER_TYPE_SELL_LIMIT ||
                     orderType==ORDER_TYPE_SELL_STOP_LIMIT)
                  ? POSITION_TYPE_SELL
                  : -1;

   if(direction<0)
      return false;

   // BUY STOP / SELL STOP initial protection is anchored to the latest CLOSED
   // M5 candle, as requested. If that structural SL cannot satisfy broker
   // constraints, reject the pending order rather than silently substituting
   // a different timeframe/structure.
   if(orderType==ORDER_TYPE_BUY_STOP || orderType==ORDER_TYPE_SELL_STOP)
     {
      double pip=PipSize(symbol);
      double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      double minDistance=TradeMinDistance(symbol);
      if(pip<=0.0 || point<=0.0 || minDistance<=0.0)
         return false;

      bool buyStop=(orderType==ORDER_TYPE_BUY_STOP);
      double anchor=(buyStop ? iLow(symbol,PERIOD_M5,1)
                             : iHigh(symbol,PERIOD_M5,1));
      if(anchor<=0.0)
         return false;

      double buffer=MathMax(MathMax(0.0,InpInitialSLBufferPips)*pip,
                            minDistance+point);
      double candleSL=NormalizePrice(symbol,
                                     buyStop ? anchor-buffer:anchor+buffer);
      if(candleSL<=0.0 ||
         !IsValidSLForPendingOrder(symbol,orderType,entryPrice,candleSL))
         return false;

      sl=candleSL;
      return true;
     }

   // Same protection source as market positions.
   double candidate=0.0;

   if(CalculateInitialProtectionSL(symbol,direction,entryPrice,candidate) &&
      IsValidSLForPendingOrder(symbol,orderType,entryPrice,candidate))
     {
      sl=candidate;
      return true;
     }

   // Last-resort broker fallback; never intentionally use raw minDist.
   if(CalculateBrokerFallbackSL(symbol,direction,entryPrice,candidate) &&
      IsValidSLForPendingOrder(symbol,orderType,entryPrice,candidate))
     {
      sl=candidate;
      return true;
     }

   sl=0.0;
   return false;
  }

bool VerifyPendingInitialSL(const ulong ticket)
  {
   if(ticket==0 || !OrderSelect(ticket))
      return false;

   ENUM_ORDER_TYPE orderType=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   string symbol=OrderGetString(ORDER_SYMBOL);
   double entry=OrderGetDouble(ORDER_PRICE_OPEN);
   double sl=OrderGetDouble(ORDER_SL);

   if(!IsValidSLForPendingOrder(symbol,orderType,entry,sl))
      return false;

   if(orderType==ORDER_TYPE_BUY_STOP_LIMIT ||
      orderType==ORDER_TYPE_SELL_STOP_LIMIT)
      return STB_StopLimitSLSideOK(
         orderType,OrderGetDouble(ORDER_PRICE_STOPLIMIT),sl);

   return true;
  }

bool CalculateInitialProtectionSL(const string symbol,
                                  const long positionType,
                                  const double entryPrice,
                                  double &sl)
  {
   sl=0.0;

   // Unified protection policy for every managed exposure:
   // confirmed structural swing first, recent candle second, broker fallback last.
   // Broker distance is only a validity floor, never the strategy SL target.
   if(CalculateNearestStructuralSL(symbol,positionType,entryPrice,sl) &&
      IsValidSLForPosition(symbol,positionType,sl))
      return true;

   if(CalculateReferenceCandleSL(symbol,positionType,entryPrice,sl))
      return true;

   if(CalculateBrokerFallbackSL(symbol,positionType,entryPrice,sl) &&
      IsValidSLForPosition(symbol,positionType,sl))
      return true;

   sl=0.0;
   return false;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CalculateBrokerFallbackSL(const string symbol,
                               const long positionType,
                               const double entryPrice,
                               double &sl)
  {
   sl=0.0;
   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick) || entryPrice<=0.0)
      return false;

   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double pip=PipSize(symbol);
   long stopsLevel=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel=SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);

   double minimumDistance=(MathMax((double)stopsLevel,
                                   (double)freezeLevel)+1.0)*point;
   if(minimumDistance<=0.0)
      minimumDistance=point;

   double configuredDistance=
      MathMax(3.0,MathMax(1.0,InpInitialSLBufferPips)*2.0)*pip;
   double preferredDistance=MathMax(minimumDistance*3.0,
                                    configuredDistance);

   if(positionType==POSITION_TYPE_BUY)
      sl=MathMin(entryPrice-preferredDistance,
                 tick.bid-minimumDistance);
   else
      if(positionType==POSITION_TYPE_SELL)
         sl=MathMax(entryPrice+preferredDistance,
                    tick.ask+minimumDistance);
      else
         return false;

   sl=NormalizePrice(symbol,sl);

   if(InpMaxInitialSLPips>0.0 &&
      MathAbs(entryPrice-sl)>InpMaxInitialSLPips*pip)
      return false;

   return IsValidSLForPosition(symbol,positionType,sl);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool EnsureInitialSL(const ulong ticket)
  {
   if(ticket==0 || !STB_IsProtectionPosition(ticket))
      return false;
   if(PositionGetDouble(POSITION_SL)>0.0)
      return true;
   // A live position without SL is automatically repaired; manual edits never
   // silently opt an open position out of protection.
   string symbol=PositionGetString(POSITION_SYMBOL);
   long type=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double candidate=0.0;
   if(!CalculateInitialProtectionSL(symbol,type,entry,candidate))
     {
      Print("STB INITIAL SL WAIT: unable to calculate valid stop ticket=",ticket,
            " symbol=",symbol,
            " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
            " entry=",DoubleToString(entry,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " pipSize=",DoubleToString(PipSize(symbol),(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " stopsLevel=",SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL),
            " freezeLevel=",SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL));
      return false;
     }
   if(!STB_SubmitPositionSL(ticket,candidate,STB_SL_SRC_INITIAL,"INITIAL"))
      return false;
   if(!PositionSelectByTicket(ticket) || PositionGetDouble(POSITION_SL)<=0.0)
      return false;
   Print("STB initial SL active ticket=",ticket,
         " symbol=",symbol,
         " side=",(type==POSITION_TYPE_BUY ? "BUY":"SELL"),
         " SL=",DoubleToString(candidate,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
   return true;
  }

void STB_RecordPendingInitialSLFailure(const int stateIdx);

bool EnsureInitialSLForPendingOrder(const ulong ticket)
  {
   if(ticket==0 || !OrderSelect(ticket) || !IsManagedOrder(ticket))
      return false;

   ENUM_ORDER_TYPE orderType=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

   bool supported=(orderType==ORDER_TYPE_BUY_STOP ||
                   orderType==ORDER_TYPE_SELL_STOP ||
                   orderType==ORDER_TYPE_BUY_LIMIT ||
                   orderType==ORDER_TYPE_SELL_LIMIT ||
                   orderType==ORDER_TYPE_BUY_STOP_LIMIT ||
                   orderType==ORDER_TYPE_SELL_STOP_LIMIT);

   if(!supported)
      return false;

   double currentSL=OrderGetDouble(ORDER_SL);

   // Keep a valid existing SL untouched. If a Stop-Limit's SL is on the
   // wrong side of its child limit, attempt a structural repair instead of
   // treating the trigger-price check alone as sufficient.
   if(currentSL>0.0 && VerifyPendingInitialSL(ticket))
      return true;

   string symbol=OrderGetString(ORDER_SYMBOL);

   // Register missing-SL orders so failed protection attempts share the
   // pending engine's bounded 5/15/60-second retry policy.
   int stateIdx=STB_PendingTrailFind(ticket);
   if(stateIdx<0)
     {
      STB_PendingTrailRegister(ticket,"INITIAL_PROTECTION");
      stateIdx=STB_PendingTrailFind(ticket);
     }

   datetime now=TimeCurrent();
   if(stateIdx>=0 &&
      g_stbPendingTrail[stateIdx].nextRetryTime>now)
      return false;

   double entry=OrderGetDouble(ORDER_PRICE_OPEN);
   double candidate=0.0;

   if(!CalculateInitialPendingProtectionSL(symbol,orderType,entry,candidate))
     {
      Print("STB pending initial SL unavailable ticket=",ticket,
            " symbol=",symbol,
            " type=",EnumToString(orderType));
      STB_RecordPendingInitialSLFailure(stateIdx);
      return false;
     }

   string writerFailureReason="";
   if(!STB_ModifyPendingOrderGeometry(ticket,
                                      entry,
                                      candidate,
                                      OrderGetDouble(ORDER_TP),
                                      writerFailureReason) ||
      !VerifyPendingInitialSL(ticket))
     {
      STB_RecordPendingInitialSLFailure(stateIdx);
      return false;
     }

   if(stateIdx>=0 && OrderSelect(ticket))
     {
      double verifiedEntry=OrderGetDouble(ORDER_PRICE_OPEN);
      double verifiedSL=OrderGetDouble(ORDER_SL);
      double pip=PipSize(symbol);

      g_stbPendingTrail[stateIdx].lastEntry=verifiedEntry;
      g_stbPendingTrail[stateIdx].lastSL=verifiedSL;
      if(pip>0.0)
         g_stbPendingTrail[stateIdx].slBufferPips=
            MathAbs(verifiedEntry-verifiedSL)/pip;
      g_stbPendingTrail[stateIdx].failureCount=0;
      g_stbPendingTrail[stateIdx].nextRetryTime=0;
      g_stbPendingTrail[stateIdx].lastModifyTime=TimeCurrent();
     }

   return true;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//==================================================================
// P6 CROSS-INSTANCE MANAGEMENT ARBITRATION (ONE SYMBOL = ONE WRITER)
//==================================================================
#define STB_MGMT_LEASE_SEC 90

// P10: management lease scope is account + symbol ONLY (never magic). Under
// Universal Management every exposure on an allowed symbol has exactly one
// broker writer, regardless of which magic/EA created it.
string g_stbLeaseSymbols[];

bool STB_LeaseTrackSymbol(const string symbol)
  {
   if(symbol=="")
      return false;

   for(int i=0;i<ArraySize(g_stbLeaseSymbols);i++)
      if(g_stbLeaseSymbols[i]==symbol)
         return true;

   int n=ArraySize(g_stbLeaseSymbols);
   if(ArrayResize(g_stbLeaseSymbols,n+1)==n+1)
     {
      g_stbLeaseSymbols[n]=symbol;
      return true;
     }

   Print("STB management lease tracking allocation failed symbol=",symbol,
         " reason=LEASE_CLAIM_WILL_BE_RELEASED");
   return false;
  }

string STB_MgmtScopeKey(const string purpose,const string symbol)
  {
   string raw=(string)AccountInfoInteger(ACCOUNT_LOGIN)+"|MGMT|"+purpose+"|"+symbol;
   // A tester must not claim or release a live chart's per-symbol lease.
   if(MQLInfoInteger(MQL_TESTER))
      raw+="|TESTER";
   return g_prefix+(string)SymbolHash(raw);
  }

string STB_MgmtOwnerKey(const string symbol)
  {
   return STB_MgmtScopeKey("OWNER",symbol);
  }

string STB_MgmtLeaseKey(const string symbol)
  {
   return STB_MgmtScopeKey("LEASE",symbol);
  }

// Central per-symbol management lease. The first instance to reach a symbol
// claims it; the live owner keeps it; a stale owner (no refresh within
// STB_MGMT_LEASE_SEC) may lose it. Only the current owner should pass the
// broker-writer guards. GlobalVariableSetOnCondition provides atomic CAS for
// claiming/reclaiming the lease within this terminal, but the lease check and
// broker request are not one atomic operation. Final pre-submit rechecks reduce
// the race window; this is not a cross-terminal mutex.
bool STB_SymbolManagementOwnedVerified(const string symbol)
  {
   if(!STB_SymbolManagementOwned(symbol))
      return false;

   double me=(double)((long)ChartID());
   string ownerKey=STB_MgmtOwnerKey(symbol);

   return (GlobalVariableCheck(ownerKey) &&
           GlobalVariableGet(ownerKey)==me);
  }

bool STB_SymbolManagementOwned(const string symbol)
  {
   if(symbol=="")
      return false;

   double me=(double)((long)ChartID());
   string ownerKey=STB_MgmtOwnerKey(symbol);
   string leaseKey=STB_MgmtLeaseKey(symbol);
   // Use terminal-local wall-clock time for the lease TTL. Server time may
   // stop advancing when quotes are absent, which can otherwise delay stale
   // owner reclamation or make the TTL measure market-time rather than elapsed time.
   datetime now=TimeLocal();

   // Create the sentinel without overwriting a concurrent claimant. A plain
   // GlobalVariableSet(ownerKey,0) after a missing-key check can race and erase
   // another chart's successful claim. GlobalVariableTemp creates only-if-absent.
   if(!GlobalVariableCheck(ownerKey))
     {
      ResetLastError();
      if(!GlobalVariableTemp(ownerKey) && !GlobalVariableCheck(ownerKey))
        {
         Print("STB lease owner-key creation failed symbol=",symbol,
               " err=",GetLastError());
         return false;
        }
     }

   if(!GlobalVariableCheck(ownerKey))
      return false;

   if(GlobalVariableGet(ownerKey)==0.0)
     {
      if(!GlobalVariableSetOnCondition(ownerKey,me,0.0))
         return false; // P11 atomic claim (CAS 0 -> me)
      GlobalVariableSet(leaseKey,(double)now);
      if(!STB_LeaseTrackSymbol(symbol))
        {
         // Do not keep a writer lease that this instance cannot release
         // promptly during deinitialization. The owner sentinel is authoritative;
         // leave the old lease timestamp untouched to avoid clobbering a new
         // owner's timestamp in a concurrent takeover race.
         GlobalVariableSetOnCondition(ownerKey,0.0,me);
         return false;
        }
      return true;
     }

   double owner=GlobalVariableGet(ownerKey);
   double lease=GlobalVariableCheck(leaseKey) ? GlobalVariableGet(leaseKey) : 0.0;

   if(owner==me)
     {
      GlobalVariableSet(leaseKey,(double)now);
      if(!STB_LeaseTrackSymbol(symbol))
        {
         // Do not keep a writer lease that this instance cannot release
         // promptly during deinitialization. The owner sentinel is authoritative;
         // leave the old lease timestamp untouched to avoid clobbering a new
         // owner's timestamp in a concurrent takeover race.
         GlobalVariableSetOnCondition(ownerKey,0.0,me);
         return false;
        }
      return true;
     }

   if(lease<=0.0 || (now-(datetime)lease)>STB_MGMT_LEASE_SEC)
     {
      if(!GlobalVariableSetOnCondition(ownerKey,me,owner))
         return false; // P11 atomic stale takeover (CAS)
      GlobalVariableSet(leaseKey,(double)now);
      if(!STB_LeaseTrackSymbol(symbol))
        {
         // Do not keep a writer lease that this instance cannot release
         // promptly during deinitialization. The owner sentinel is authoritative;
         // leave the old lease timestamp untouched to avoid clobbering a new
         // owner's timestamp in a concurrent takeover race.
         GlobalVariableSetOnCondition(ownerKey,0.0,me);
         return false;
        }
      return true;
     }

   return false;
  }

// P10: voluntary release so a removed chart does not hold the symbol lease
// until the TTL expires and another instance can take over immediately.
void STB_ReleaseSymbolManagement(const string symbol)
  {
   if(symbol=="")
      return;

   double me=(double)((long)ChartID());
   string ownerKey=STB_MgmtOwnerKey(symbol);

   // Release through CAS. Deleting the key after a separate owner check can
   // erase a new chart's claim in the race window. Zero is an unowned sentinel.
   if(GlobalVariableCheck(ownerKey))
      GlobalVariableSetOnCondition(ownerKey,0.0,me);
  }

void STB_ReleaseAllSymbolManagement()
  {
   for(int i=ArraySize(g_stbLeaseSymbols)-1;i>=0;i--)
      STB_ReleaseSymbolManagement(g_stbLeaseSymbols[i]);

   ArrayResize(g_stbLeaseSymbols,0);
  }

//==================================================================
// STRUCTURAL INITIAL TAKE-PROFIT FOR POSITIONS AND PENDING ORDERS
// Existing user-supplied TP is never overwritten. If TP is absent, choose
// the nearest confirmed M15 swing that satisfies min-RR and broker distance;
// if no such swing exists, use an explicitly logged RR fallback.
//==================================================================

bool STB_CalculatePendingTPFromStructure(const string symbol,
                                         const ENUM_ORDER_TYPE orderType,
                                         const double entry,
                                         const double sl,
                                         const double minimumRR,
                                         double &tp,
                                         string &source)
  {
   tp=0.0;
   source="UNAVAILABLE";
   bool isBuy=(orderType==ORDER_TYPE_BUY_STOP ||
               orderType==ORDER_TYPE_BUY_LIMIT ||
               orderType==ORDER_TYPE_BUY_STOP_LIMIT);
   bool isSell=(orderType==ORDER_TYPE_SELL_STOP ||
                orderType==ORDER_TYPE_SELL_LIMIT ||
                orderType==ORDER_TYPE_SELL_STOP_LIMIT);
   if(symbol=="" || entry<=0.0 || sl<=0.0 || (!isBuy && !isSell))
      return false;

   double risk=MathAbs(entry-sl);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tickSize<=0.0) tickSize=point;
   double minDist=TradeMinDistance(symbol);
   if(risk<=0.0 || point<=0.0 || tickSize<=0.0 || minDist<=0.0)
      return false;

   double requiredReward=MathMax(risk*MathMax(0.1,minimumRR),
                                 minDist+tickSize);
   SwingPoint highs[];
   SwingPoint lows[];
   int swingCount=CollectSwings(symbol,PERIOD_M15,InpLookbackM15,highs,lows);

   if(isBuy)
     {
      double floorTP=entry+requiredReward;
      double best=DBL_MAX;
      for(int i=0;i<ArraySize(highs);i++)
        {
         double candidate=NormalizePrice(symbol,highs[i].price);
         if(candidate<=entry || candidate-entry+point*0.1<risk*minimumRR ||
            candidate-entry<minDist)
            continue;
         if(candidate>=floorTP-point*0.1 && candidate<best)
            best=candidate;
        }
      if(swingCount>0 && best<DBL_MAX)
        {
         tp=best; source="STRUCTURE_SWING"; return true;
        }
      tp=NormalizePrice(symbol,floorTP+tickSize);
      if(tp>entry && tp-entry>=minDist && tp-entry+point*0.1>=risk*minimumRR)
        { source="RR_FALLBACK"; return true; }
     }
   else
     {
      double ceilingTP=entry-requiredReward;
      double best=-DBL_MAX;
      for(int i=0;i<ArraySize(lows);i++)
        {
         double candidate=NormalizePrice(symbol,lows[i].price);
         if(candidate<=0.0 || candidate>=entry ||
            entry-candidate+point*0.1<risk*minimumRR ||
            entry-candidate<minDist)
            continue;
         if(candidate<=ceilingTP+point*0.1 && candidate>best)
            best=candidate;
        }
      if(swingCount>0 && best>0.0)
        { tp=best; source="STRUCTURE_SWING"; return true; }
      tp=NormalizePrice(symbol,ceilingTP-tickSize);
      if(tp>0.0 && tp<entry && entry-tp>=minDist &&
         entry-tp+point*0.1>=risk*minimumRR)
        { source="RR_FALLBACK"; return true; }
     }

   tp=0.0;
   source="NO_VALID_TARGET";
   return false;
  }

bool STB_CalculatePositionTPFromStructure(const string symbol,
                                          const long positionType,
                                          const double entry,
                                          const double sl,
                                          const double minimumRR,
                                          double &tp,
                                          string &source)
  {
   tp=0.0;
   source="UNAVAILABLE";
   bool isBuy=(positionType==POSITION_TYPE_BUY);
   bool isSell=(positionType==POSITION_TYPE_SELL);
   if(symbol=="" || entry<=0.0 || sl<=0.0 || (!isBuy && !isSell))
      return false;

   // A stop that has moved through entry is a profit lock, not a negative risk.
   // Use absolute entry-to-current-stop geometry for a conservative fallback.
   double risk=MathAbs(entry-sl);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tickSize<=0.0) tickSize=point;
   double minDist=TradeMinDistance(symbol);
   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick) || risk<=0.0 ||
      point<=0.0 || tickSize<=0.0 || minDist<=0.0)
      return false;

   double requiredReward=MathMax(risk*MathMax(0.1,minimumRR),
                                 minDist+tickSize);
   double marketBuffer=minDist+MathMax(tickSize,risk*0.25);
   SwingPoint highs[];
   SwingPoint lows[];
   int swingCount=CollectSwings(symbol,PERIOD_M15,InpLookbackM15,highs,lows);

   if(isBuy)
     {
      double floorTP=MathMax(entry+requiredReward,tick.bid+marketBuffer);
      double best=DBL_MAX;
      for(int i=0;i<ArraySize(highs);i++)
        {
         double candidate=NormalizePrice(symbol,highs[i].price);
         if(candidate<=entry || candidate<=tick.bid+minDist ||
            candidate-entry+point*0.1<risk*MathMax(0.1,minimumRR))
            continue;
         if(candidate>=floorTP-point*0.1 && candidate<best)
            best=candidate;
        }
      if(swingCount>0 && best<DBL_MAX)
        { tp=best; source="STRUCTURE_SWING"; return true; }
      tp=NormalizePrice(symbol,floorTP+tickSize);
      if(tp>entry && tp>tick.bid+minDist &&
         tp-entry+point*0.1>=risk*MathMax(0.1,minimumRR))
        { source="RR_FALLBACK"; return true; }
     }
   else
     {
      double ceilingTP=MathMin(entry-requiredReward,tick.ask-marketBuffer);
      double best=-DBL_MAX;
      for(int i=0;i<ArraySize(lows);i++)
        {
         double candidate=NormalizePrice(symbol,lows[i].price);
         if(candidate<=0.0 || candidate>=entry || candidate>=tick.ask-minDist ||
            entry-candidate+point*0.1<risk*MathMax(0.1,minimumRR))
            continue;
         if(candidate<=ceilingTP+point*0.1 && candidate>best)
            best=candidate;
        }
      if(swingCount>0 && best>0.0)
        { tp=best; source="STRUCTURE_SWING"; return true; }
      tp=NormalizePrice(symbol,ceilingTP-tickSize);
      if(tp>0.0 && tp<entry && tp<tick.ask-minDist &&
         entry-tp+point*0.1>=risk*MathMax(0.1,minimumRR))
        { source="RR_FALLBACK"; return true; }
     }

   tp=0.0;
   source="NO_VALID_TARGET";
   return false;
  }

bool STB_ModifyPositionTP(const ulong ticket,const double newTP)
  {
   if(ticket==0 || !PositionSelectByTicket(ticket) ||
      !STB_IsProtectionPosition(ticket))
      return false;
   string symbol=PositionGetString(POSITION_SYMBOL);
   if(symbol=="" || !STB_SymbolManagementOwnedVerified(symbol))
      return false;

   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   double currentTP=PositionGetDouble(POSITION_TP);
   long side=PositionGetInteger(POSITION_TYPE);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tickSize<=0.0) tickSize=point;
   if(sl<=0.0 || point<=0.0 || tickSize<=0.0 || newTP<=0.0)
      return false;
   if(currentTP>0.0)
      return true; // never overwrite explicit user TP
   if(STB_CycleWriteAlreadyDone(ticket))
      return false;

   MqlTick tick;
   double minDist=TradeMinDistance(symbol);
   if(!SymbolInfoTick(symbol,tick) || minDist<=0.0)
      return false;
   if((side==POSITION_TYPE_BUY &&
       (newTP<=entry || newTP<=tick.bid+minDist)) ||
      (side==POSITION_TYPE_SELL &&
       (newTP>=entry || newTP>=tick.ask-minDist)))
      return false;

   string failKey=ScopedStateName("AUTOTP_MODFAIL_"+IntegerToString((long)ticket));
   if(GlobalVariableCheck(failKey))
     {
      double lastFail=GlobalVariableGet(failKey);
      if(lastFail>0.0 && TimeCurrent()-lastFail<30)
         return false;
     }

   bool modified=STB_PositionModifyBrokerVerified(ticket,entry,sl,currentTP,
                                                  sl,newTP,failKey,"TP");
   if(!modified)
      return false;
   return true;
  }

bool EnsureInitialTPForPosition(const ulong ticket)
  {
   if(ticket==0 || !PositionSelectByTicket(ticket) ||
      !STB_IsProtectionPosition(ticket))
      return false;
   if(PositionGetDouble(POSITION_TP)>0.0)
      return true;
   string symbol=PositionGetString(POSITION_SYMBOL);
   if(!STB_SymbolManagementOwnedVerified(symbol))
      return false;
   if(PositionGetDouble(POSITION_SL)<=0.0)
      return false;
   if(STB_CycleWriteAlreadyDone(ticket))
      return false; // avoid throttling a TP because this cycle already wrote its SL

   string retryKey=ScopedStateName("AUTOTP_INITPOS_"+IntegerToString((long)ticket));
   if(GlobalVariableCheck(retryKey))
     {
      double lastFail=GlobalVariableGet(retryKey);
      if(lastFail>0.0 && TimeCurrent()-lastFail<30)
         return false;
     }

   long side=PositionGetInteger(POSITION_TYPE);
   double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   double tp=0.0;
   string source="";
   if(!STB_CalculatePositionTPFromStructure(symbol,side,entry,sl,
                                             InpMinimumRR,tp,source))
     {
      GlobalVariableSet(retryKey,(double)TimeCurrent());
      Print("STB AUTO TP UNAVAILABLE ticket=",ticket,
            " symbol=",symbol," reason=",source);
      return false;
     }
   if(!STB_ModifyPositionTP(ticket,tp))
     {
      if(!STB_CycleWriteAlreadyDone(ticket))
         GlobalVariableSet(retryKey,(double)TimeCurrent());
      return false;
     }

   GlobalVariableDel(retryKey);
   Print("STB AUTO TP SET ticket=",ticket,
         " symbol=",symbol," side=",(side==POSITION_TYPE_BUY ? "BUY":"SELL"),
         " source=",source,
         " TP=",DoubleToString(tp,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
   return true;
  }

bool EnsureInitialTPForPendingOrder(const ulong ticket)
  {
   if(ticket==0 || !OrderSelect(ticket) || !IsManagedOrder(ticket))
      return false;
   if(OrderGetDouble(ORDER_TP)>0.0)
      return true; // do not replace any explicit TP
   if(STB_CycleWriteAlreadyDone(ticket))
      return false; // initial SL used this ticket's single-write budget this cycle

   string symbol=OrderGetString(ORDER_SYMBOL);
   if(!STB_SymbolManagementOwnedVerified(symbol) ||
      OrderGetDouble(ORDER_SL)<=0.0)
      return false;

   string retryKey=ScopedStateName("AUTOTP_INITPEND_"+IntegerToString((long)ticket));
   if(GlobalVariableCheck(retryKey))
     {
      double lastFail=GlobalVariableGet(retryKey);
      if(lastFail>0.0 && TimeCurrent()-lastFail<30)
         return false;
     }

   ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   double entry=OrderGetDouble(ORDER_PRICE_OPEN);
   double sl=OrderGetDouble(ORDER_SL);
   double tp=0.0;
   string source="";
   if(!STB_CalculatePendingTPFromStructure(symbol,type,entry,sl,
                                            InpMinimumRR,tp,source))
     {
      GlobalVariableSet(retryKey,(double)TimeCurrent());
      Print("STB PENDING TP UNAVAILABLE ticket=",ticket,
            " symbol=",symbol," reason=",source);
      return false;
     }

   string writerFailureReason="";
   if(!STB_ModifyPendingOrderGeometry(ticket,entry,sl,tp,writerFailureReason,false))
     {
      if(!STB_CycleWriteAlreadyDone(ticket))
         GlobalVariableSet(retryKey,(double)TimeCurrent());
      return false;
     }
   if(!OrderSelect(ticket) || OrderGetDouble(ORDER_TP)<=0.0)
     {
      GlobalVariableSet(retryKey,(double)TimeCurrent());
      return false;
     }

   GlobalVariableDel(retryKey);
   Print("STB PENDING TP SET ticket=",ticket,
         " symbol=",symbol," type=",EnumToString(type),
         " source=",source,
         " TP=",DoubleToString(OrderGetDouble(ORDER_TP),(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
   return true;
  }

void ManagePositions()
  {
   // Collect all automatic SL candidates before any broker write.
   g_stbCollectingSLProposals=true;
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !STB_IsProtectionPosition(ticket))
         continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      if(symbol=="" || !SymbolSelect(symbol,true) ||
         !STB_SymbolManagementOwnedVerified(symbol))
         continue;
      EnsureInitialSL(ticket);
     }

   // Stage 1: early cost-aware break-even and ATR-scaled profit lock.
   // Both share the existing same-cycle resolver; neither writes directly.
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !STB_IsProtectionPosition(ticket))
         continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      if(symbol=="" || !SymbolSelect(symbol,true) ||
         !STB_SymbolManagementOwnedVerified(symbol))
         continue;
      STB_AdaptiveBreakEvenProtection(ticket);
      STB_AdaptiveProfitLockProtection(ticket);
     }

   AutoProfitProtection();

   // Stage 2: ATR distance trailing runs alongside confirmed structural trail.
   // Arbitration retains the strongest valid stop and permits only one write.
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !STB_IsProtectionPosition(ticket))
         continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      if(symbol=="" || !SymbolSelect(symbol,true) ||
         !STB_SymbolManagementOwnedVerified(symbol))
         continue;
      STB_AdaptiveATRTrail(ticket);
      TrailPositionByLivePrice(ticket);
     }

   // Flush SL arbitration first. A newly repaired SL then becomes visible to
   // the TP manager. If this cycle already changed the position, TP is deferred
   // without failure backoff and retried next management cycle.
   STB_FlushPositionSLProposals();

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !STB_IsProtectionPosition(ticket))
         continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      if(symbol=="" || !SymbolSelect(symbol,true) ||
         !STB_SymbolManagementOwnedVerified(symbol))
         continue;
      if(PositionGetDouble(POSITION_SL)>0.0 &&
         PositionGetDouble(POSITION_TP)<=0.0)
         EnsureInitialTPForPosition(ticket);
     }
  }

//==================================================================
// PENDING ORDER MANAGEMENT
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManagePendingOrders()
  {
   datetime now=TimeCurrent();

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !OrderSelect(ticket))
         continue;
      if(!IsManagedOrder(ticket))
         continue;

      string symbol=OrderGetString(ORDER_SYMBOL);
      if(symbol=="" || !SymbolSelect(symbol,true))
         continue; // subscribe non-Watch symbols before reading their history/quotes
      if(!STB_SymbolManagementOwnedVerified(symbol)) continue; // P6/P10 cross-instance single pending lifecycle owner

      // Protect every managed pending order with no SL, not only orders created
      // by this EA. Also recheck Stop-Limit SL geometry against the child LIMIT
      // price; a trigger-only-valid SL may be on the wrong side of the actual
      // child entry. The helper respects manual overrides and throttles failures.
      ENUM_ORDER_TYPE pendingType=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      bool stopLimitType=(pendingType==ORDER_TYPE_BUY_STOP_LIMIT ||
                          pendingType==ORDER_TYPE_SELL_STOP_LIMIT);
      if(OrderGetDouble(ORDER_SL)<=0.0 ||
         (stopLimitType && !VerifyPendingInitialSL(ticket)))
        {
         EnsureInitialSLForPendingOrder(ticket);
         if(!OrderSelect(ticket))
            continue;
         symbol=OrderGetString(ORDER_SYMBOL);
        }

      // Add TP only when absent. Explicit manual/mobile TP is preserved.
      if(OrderSelect(ticket) &&
         OrderGetDouble(ORDER_SL)>0.0 &&
         OrderGetDouble(ORDER_TP)<=0.0)
        {
         EnsureInitialTPForPendingOrder(ticket);
         if(!OrderSelect(ticket))
            continue;
         symbol=OrderGetString(ORDER_SYMBOL);
        }

      datetime setupTime=(datetime)OrderGetInteger(ORDER_TIME_SETUP);
      int profileId=STB_AdaptiveParseProfileFromComment(OrderGetString(ORDER_COMMENT));
      int maxBars=InpMaxPendingBars;

      if(profileId>=0 && profileId<STB_ADAPTIVE_PROFILE_COUNT)
        {
         STB_AP_SetActive(profileId);
         maxBars=STB_EffectiveMaxPendingBars();
         STB_AP_ClearActive();
        }

      bool expiredByServer=
         OrderGetInteger(ORDER_TYPE_TIME)==ORDER_TIME_SPECIFIED &&
         OrderGetInteger(ORDER_TIME_EXPIRATION)>0 &&
         now>=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);

      // Blueprint 35: only EA-created pendings may expire by local age.
      // Manual / mobile / foreign / user-overridden pendings are never
      // deleted by local age (server-side explicit expiration is honored).
      bool autoCreated=(StringFind(OrderGetString(ORDER_COMMENT),"STB|B|")==0 ||
                        StringFind(OrderGetString(ORDER_COMMENT),"STB|S|")==0);
      bool expiredByLocalAge=
         autoCreated && !STB_ManualOverrideIs(ticket) &&
         maxBars>0 && setupTime>0 &&
         now-setupTime>=maxBars*15*60;

      if(expiredByServer || expiredByLocalAge)
        {
         Print("STB PENDING EXPIRE ticket=",ticket,
               " symbol=",symbol,
               " profile=",IntegerToString(profileId));

         if(!STB_RequestOrderDelete(ticket,STB_DEL_SERVER_EXPIRATION,"ManagePendingOrders"))
      Print("STB pending delete failed ticket=",ticket,
            " ret=",trade.ResultRetcode()," ",
            trade.ResultRetcodeDescription());
   else
      STB_AdaptiveDeleteOrderState(ticket);
        }
     }
  }

//==================================================================
// AUTO ORDER
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double DirectionExposureVolume(const string symbol,const int direction);

// Shared preflight for every EA order-creation path. This is a local
// snapshot check, not an account-wide atomic reservation; OrderCheck and the
// server response remain authoritative if exposure changes concurrently.
bool STB_DirectionVolumeWithinLimit(const string symbol,
                                    const int direction,
                                    const double requestedVolume,
                                    const string source)
  {
   if((direction!=1 && direction!=-1) || requestedVolume<=0.0)
      return false;

   double volumeLimit=SymbolInfoDouble(symbol,SYMBOL_VOLUME_LIMIT);
   if(volumeLimit<=0.0)
      return true;

   double currentVolume=DirectionExposureVolume(symbol,direction);
   if(currentVolume+requestedVolume>volumeLimit+1e-9)
     {
      Print("STB VOLUME LIMIT REJECT source=",source,
            " symbol=",symbol,
            " direction=",(direction>0 ? "BUY":"SELL"),
            " requested=",DoubleToString(requestedVolume,3),
            " currentDirectionVolume=",DoubleToString(currentVolume,3),
            " limit=",DoubleToString(volumeLimit,3));
      return false;
     }
   return true;
  }

double DirectionExposureVolume(const string symbol,const int direction)
  {
   double total=0.0;

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL)!=symbol)
         continue;

      long type=PositionGetInteger(POSITION_TYPE);
      if((direction>0 && type==POSITION_TYPE_BUY) ||
         (direction<0 && type==POSITION_TYPE_SELL))
         total+=PositionGetDouble(POSITION_VOLUME);
     }

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !OrderSelect(ticket))
         continue;

      if(OrderGetString(ORDER_SYMBOL)!=symbol)
         continue;

      ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      bool sameDirection=
         (direction>0 &&
          (type==ORDER_TYPE_BUY_LIMIT ||
           type==ORDER_TYPE_BUY_STOP ||
           type==ORDER_TYPE_BUY_STOP_LIMIT)) ||
         (direction<0 &&
          (type==ORDER_TYPE_SELL_LIMIT ||
           type==ORDER_TYPE_SELL_STOP ||
           type==ORDER_TYPE_SELL_STOP_LIMIT));

      if(sameDirection)
         total+=OrderGetDouble(ORDER_VOLUME_CURRENT);
     }

   return total;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ValidatePendingSetup(const Setup &s)
  {
   MqlTick tick;
   if(!SymbolInfoTick(s.symbol,tick))
      return false;

   double point=SymbolInfoDouble(s.symbol,SYMBOL_POINT);
   double minDist=TradeMinDistance(s.symbol);

   if(point<=0.0 || minDist<=0.0)
      return false;

   if(s.direction>0)
      return s.entry>tick.ask+minDist &&
             s.sl<s.entry-minDist &&
             s.tp>s.entry+minDist;

   return s.entry<tick.bid-minDist &&
          s.sl>s.entry+minDist &&
          s.tp<s.entry-minDist;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_CheckPendingOrderRequest(const string symbol,
                                    const ENUM_ORDER_TYPE orderType,
                                    const double volume,
                                    const double price,
                                    const double sl,
                                    const double tp,
                                    const ENUM_ORDER_TYPE_TIME typeTime,
                                    const datetime expiration,
                                    const ulong magic,
                                    const string comment,
                                    const string context)
  {
   if(symbol=="" || volume<=0.0 || price<=0.0 ||
      !MathIsValidNumber(volume) || !MathIsValidNumber(price) ||
      !MathIsValidNumber(sl) || !MathIsValidNumber(tp))
      return false;

   MqlTradeRequest request={};
   MqlTradeCheckResult check={};
   request.action=TRADE_ACTION_PENDING;
   request.symbol=symbol;
   request.magic=magic;
   request.volume=volume;
   request.type=orderType;
   request.price=price;
   request.sl=sl;
   request.tp=tp;
   request.type_filling=ORDER_FILLING_RETURN;
   request.type_time=typeTime;
   request.expiration=expiration;
   request.comment=comment;

   ResetLastError();
   if(!OrderCheck(request,check))
     {
      Print("STB PENDING ORDERCHECK CALL FAILED context=",context,
            " symbol=",symbol,
            " err=",GetLastError(),
            " ret=",check.retcode," ",check.comment);
      return false;
     }

   // OrderCheck success is retcode=0. Execution retcodes are evaluated only
   // after the actual broker submission.
   if(check.retcode!=0)
     {
      Print("STB PENDING ORDERCHECK REJECT context=",context,
            " symbol=",symbol,
            " type=",EnumToString(orderType),
            " ret=",check.retcode,
            " comment=",check.comment);
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckPendingOrder(const Setup &s,
                       const double volume,
                       const ENUM_ORDER_TYPE_TIME typeTime,
                       const datetime expiration)
  {
   ENUM_ORDER_TYPE orderType=(s.direction>0 ? ORDER_TYPE_BUY_STOP:ORDER_TYPE_SELL_STOP);
   return STB_CheckPendingOrderRequest(s.symbol,orderType,volume,
                                       s.entry,s.sl,s.tp,typeTime,expiration,
                                       (ulong)InpMagic,"STB","SCANNER_SETUP");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool GetPendingLifetime(const string symbol,
                        ENUM_ORDER_TYPE_TIME &typeTime,
                        datetime &expiration)
  {
   typeTime=ORDER_TIME_GTC;
   expiration=0;

   int modes=(int)SymbolInfoInteger(symbol,SYMBOL_EXPIRATION_MODE);

   if(STB_EffectiveMaxPendingBars()<=0)
     {
      if((modes & SYMBOL_EXPIRATION_GTC)==SYMBOL_EXPIRATION_GTC)
         return true;
      if((modes & SYMBOL_EXPIRATION_DAY)==SYMBOL_EXPIRATION_DAY)
        {
         typeTime=ORDER_TIME_DAY;
         return true;
        }
      if((modes & SYMBOL_EXPIRATION_SPECIFIED_DAY)==SYMBOL_EXPIRATION_SPECIFIED_DAY)
        {
         typeTime=ORDER_TIME_SPECIFIED_DAY;
         MqlDateTime dt;
         TimeToStruct(TimeTradeServer(),dt);
         dt.hour=23;
         dt.min=59;
         dt.sec=59;
         expiration=StructToTime(dt);
         return expiration>TimeTradeServer();
        }
      return false;
     }

   datetime target=TimeTradeServer()+(datetime)STB_EffectiveMaxPendingBars()*15*60;

   if((modes & SYMBOL_EXPIRATION_SPECIFIED)==SYMBOL_EXPIRATION_SPECIFIED)
     {
      typeTime=ORDER_TIME_SPECIFIED;
      expiration=target;
      return expiration>TimeTradeServer();
     }

   if((modes & SYMBOL_EXPIRATION_SPECIFIED_DAY)==SYMBOL_EXPIRATION_SPECIFIED_DAY)
     {
      typeTime=ORDER_TIME_SPECIFIED_DAY;

      MqlDateTime dt;
      TimeToStruct(target,dt);
      dt.hour=23;
      dt.min=59;
      dt.sec=59;
      expiration=StructToTime(dt);

      return expiration>TimeTradeServer();
     }

   if((modes & SYMBOL_EXPIRATION_DAY)==SYMBOL_EXPIRATION_DAY)
     {
      typeTime=ORDER_TIME_DAY;
      expiration=0;
      return true;
     }

   if((modes & SYMBOL_EXPIRATION_GTC)==SYMBOL_EXPIRATION_GTC)
     {
      typeTime=ORDER_TIME_GTC;
      expiration=0;
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculateOrderVolumeByRisk(const Setup &s,
                                  const string diagStage="AUTO",
                                  const string diagSetupType="AUTO")
  {
   STB_VolumeDiagReset(diagStage,diagSetupType);
   g_stbVolumeDiag.riskMode=InpUseRiskSizing;
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   g_stbVolumeDiag.equity=equity;
   g_stbVolumeDiag.riskPct=InpRiskPercent;
   g_stbVolumeDiag.maxRiskVolume=InpMaxRiskVolume;

   if(!InpUseRiskSizing || equity<=0.0 || InpRiskPercent<=0.0)
     {
      if(!InpUseRiskSizing)
         g_stbVolumeDiag.rejectCause="RISK_SIZING_DISABLED";
      else if(equity<=0.0)
         g_stbVolumeDiag.rejectCause="EQUITY_NONPOSITIVE";
      else
         g_stbVolumeDiag.rejectCause="RISK_PERCENT_NONPOSITIVE";
      return 0.0;
     }

   double riskMoney=equity*(InpRiskPercent/100.0);
   g_stbVolumeDiag.riskBudget=riskMoney;

   // Fail closed on malformed setup geometry before OrderCalcProfit. Using
   // MathAbs() on a profit-producing SL (wrong side of entry) would otherwise
   // disguise an invalid setup as a valid risk amount and could oversize a trade.
   bool geometryFinite=(MathIsValidNumber(s.entry) &&
                        MathIsValidNumber(s.sl));
   bool geometryPositive=(s.entry>0.0 && s.sl>0.0);
   bool directionValid=(s.direction==1 || s.direction==-1);
   bool stopOnLossSide=(s.direction==1 ? s.sl<s.entry :
                        s.direction==-1 ? s.sl>s.entry : false);
   if(!geometryFinite || !geometryPositive ||
      !directionValid || !stopOnLossSide)
     {
      g_stbVolumeDiag.rejectCause="INVALID_SETUP_GEOMETRY";
      Print("STB risk sizing rejected invalid setup geometry",
            " symbol=",s.symbol,
            " direction=",s.direction,
            " entry=",DoubleToString(s.entry,10),
            " sl=",DoubleToString(s.sl,10),
            " finite=",geometryFinite,
            " positive=",geometryPositive,
            " directionValid=",directionValid,
            " stopOnLossSide=",stopOnLossSide);
      return 0.0;
     }

   ENUM_ORDER_TYPE orderType=(s.direction>0 ? ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   double lossForOneLot=0.0;
   ResetLastError();
   g_stbVolumeDiag.calcProfitCall=true;
   bool pnlOk=OrderCalcProfit(orderType,s.symbol,1.0,s.entry,s.sl,lossForOneLot);
   g_stbVolumeDiag.calcProfitOk=pnlOk;
   g_stbVolumeDiag.calcProfitErr=(pnlOk ? 0:GetLastError());

   if(!pnlOk)
     {
      g_stbVolumeDiag.rejectCause="ORDER_CALC_PROFIT_FAILED";
      Print("STB risk sizing failed OrderCalcProfit symbol=",s.symbol,
            " err=",g_stbVolumeDiag.calcProfitErr);
      return 0.0;
     }

   // OrderCalcProfit must confirm that the configured SL produces a
   // loss for one lot. Never hide an unexpected positive result with fabs().
   if(!MathIsValidNumber(lossForOneLot) || lossForOneLot>=-1e-8)
     {
      g_stbVolumeDiag.lossForOneLot=0.0;
      g_stbVolumeDiag.rejectCause="SL_DOES_NOT_PRODUCE_VALID_LOSS";
      Print("STB risk sizing rejected non-loss SL calculation",
            " symbol=",s.symbol,
            " direction=",s.direction,
            " entry=",DoubleToString(s.entry,10),
            " sl=",DoubleToString(s.sl,10),
            " orderCalcProfit=",DoubleToString(lossForOneLot,8));
      return 0.0;
     }

   lossForOneLot=-lossForOneLot;
   g_stbVolumeDiag.lossForOneLot=lossForOneLot;

   double raw=riskMoney/lossForOneLot;
   g_stbVolumeDiag.rawVolume=raw;
   double minLot=SymbolInfoDouble(s.symbol,SYMBOL_VOLUME_MIN);
   double volumeStep=SymbolInfoDouble(s.symbol,SYMBOL_VOLUME_STEP);
   STB_VolumeDiagReadMetadata(s.symbol);
   g_stbVolumeDiag.minVolume=minLot;
   g_stbVolumeDiag.volumeStep=volumeStep;

   if(InpMaxRiskVolume>0.0)
      raw=MathMin(raw,InpMaxRiskVolume);
   g_stbVolumeDiag.cappedVolume=raw;

   if(raw+1e-9<minLot)
     {
      g_stbVolumeDiag.rejectCause="RAW_BELOW_MIN_VOLUME";
      return 0.0;
     }

   double volume=NormalizeVolume(s.symbol,raw);
   g_stbVolumeDiag.finalVolume=volume;
   if(volume<=0.0 || !MathIsValidNumber(volume))
     {
      g_stbVolumeDiag.finalVolume=0.0;
      g_stbVolumeDiag.rejectCause=(g_stbVolumeDiag.volumeMetadataValid ?
                                   "NORMALIZED_VOLUME_INVALID" :
                                   "SYMBOL_VOLUME_METADATA_INVALID");
      return 0.0;
     }

   if(InpMaxRiskVolume>0.0 && volume>InpMaxRiskVolume+1e-9)
     {
      g_stbVolumeDiag.finalVolume=0.0;
      g_stbVolumeDiag.rejectCause="EXCEEDS_MAX_RISK_VOLUME";
      return 0.0;
     }

   g_stbVolumeDiag.rejectCause="ACCEPTED";
   return volume;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_LogPlaceReject(const Setup &s,const string reason)
  {
   if(!s.valid)
      return false;

   Print("STB PLACE REJECT symbol=",s.symbol,
         " dir=",(s.direction>0 ? "BUY":"SELL"),
         " profile=",IntegerToString(s.adaptiveProfile),
         " reason=",reason,
         " score=",DoubleToString(s.score,1),
         " RR=",DoubleToString(s.rr,2));

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PlaceSetup(Setup &s,const double entryLockToken)
  {
   if(!s.valid)
      return false;

   if(STB_DailyLossLimitHit())
      return STB_LogPlaceReject(s,"DAILY_EQUITY_LOSS_LIMIT");

   if(!STB_EntryLockStillOwned(s.symbol,entryLockToken))
      return STB_LogPlaceReject(s,"ENTRY_LOCK_NOT_OWNED");

   if(!STB_SymbolManagementOwnedVerified(s.symbol))
      return STB_LogPlaceReject(s,"SYMBOL_WRITER_LEASE_NOT_OWNED");

   if(!g_autoTrading)
      return STB_LogPlaceReject(s,"AUTO_TRADING_OFF");

   if(!IsDirectionTradable(s.symbol,s.direction))
      return STB_LogPlaceReject(s,"DIRECTION_NOT_TRADABLE");

   if(!IsSpreadAcceptable(s.symbol))
      return STB_LogPlaceReject(s,"SPREAD_FILTER");

   if(HasManagedExposure(s.symbol))
      return STB_LogPlaceReject(s,"MANAGED_EXPOSURE_EXISTS");

   if(!STB_TradeEnvironmentAllowed())
      return STB_LogPlaceReject(s,"TRADE_PERMISSION");

   long maxOrders=AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);

   if(maxOrders>0 && OrdersTotal()>=maxOrders)
      return STB_LogPlaceReject(s,"ACCOUNT_ORDER_LIMIT");

   if(!ValidatePendingSetup(s))
      return STB_LogPlaceReject(s,"PENDING_GEOMETRY_INVALID");

   datetime lastSetup=GetLastSetupTime(s.symbol,s.direction);

   if(lastSetup==s.setupTime)
      return STB_LogPlaceReject(s,"SETUP_ALREADY_PLACED");

   if(InpSetupCooldownMinutes>0 &&
      lastSetup>0 &&
      TimeCurrent()-(datetime)lastSetup<InpSetupCooldownMinutes*60)
      return STB_LogPlaceReject(s,"SETUP_COOLDOWN");

   double volume=0.0;

   if(InpUseRiskSizing)
     {
      volume=CalculateOrderVolumeByRisk(s,"PlaceSetup","AUTO");

      if(volume<=0.0)
        {
         STB_LogVolumeReject(s.symbol,s.direction,s.entry,s.sl);
         return STB_LogPlaceReject(s,"RISK_VOLUME_INVALID");
        }
     }
   else
     {
      double multiplier=s.trendAligned ? InpTrendLotMultiplier : InpUniversalLotMultiplier;
      double requestedFixedVolume=InpBaseLots*multiplier;
      volume=NormalizeVolume(s.symbol,requestedFixedVolume);

      if(volume<=0.0)
        {
         STB_LogFixedVolumeReject("PlaceSetup","AUTO_FIXED",s.symbol,
                                  s.direction,s.entry,s.sl,requestedFixedVolume);
         return STB_LogPlaceReject(s,"FIXED_VOLUME_INVALID");
        }
     }

   if(!STB_DirectionVolumeWithinLimit(s.symbol,s.direction,volume,"PlaceSetup"))
      return STB_LogPlaceReject(s,"VOLUME_LIMIT");

   ENUM_ORDER_TYPE_TIME typeTime=ORDER_TIME_GTC;
   datetime expiration=0;

// The pending lifetime is a learned strategy parameter, so activate
// the exact profile that produced this immutable setup.
   STB_AP_SetActive(s.adaptiveProfile);
   bool lifetimeOK=GetPendingLifetime(s.symbol,typeTime,expiration);
   STB_AP_ClearActive();

   if(!lifetimeOK)
     {
      Print("STB order rejected: symbol has no supported pending expiration mode symbol=",s.symbol,
            " profile=",IntegerToString(s.adaptiveProfile));
      return STB_LogPlaceReject(s,"PENDING_EXPIRATION_UNSUPPORTED");
     }

   if(!CheckPendingOrder(s,volume,typeTime,expiration))
     {
      Print("STB ORDERCHECK REJECT symbol=",s.symbol,
            " dir=",(s.direction>0 ? "BUY":"SELL"),
            " profile=",IntegerToString(s.adaptiveProfile),
            " score=",DoubleToString(s.score,1),
            " RR=",DoubleToString(s.rr,2));
      return false;
     }

   trade.SetExpertMagicNumber(InpMagic);
// Pending orders use RETURN filling regardless of execution mode.
   trade.SetTypeFilling(ORDER_FILLING_RETURN);
   trade.SetAsyncMode(false);

   double commentPip=PipSize(s.symbol);
   MqlTick commentTick;
   if(!SymbolInfoTick(s.symbol,commentTick) || commentPip<=0.0)
      return STB_LogPlaceReject(s,"NO_TICK_BEFORE_PLACEMENT");

   // EB is the distance from the pending entry to the pending-trail's live
   // anchor at registration: Bid for BUY-side orders, Ask for SELL-side.
   // Storing the pattern-zone distance here can make restart recovery infer an
   // old extreme and cause an immediate unintended entry jump.
   double commentAnchor=(s.direction>0 ? commentTick.bid:commentTick.ask);
   double effectiveEntryBuffer=MathAbs(s.entry-commentAnchor)/commentPip;
   string comment="STB|"+(s.direction>0 ? "B":"S")+"|P"+
                  IntegerToString(s.adaptiveProfile)+"|EB"+
                  DoubleToString(effectiveEntryBuffer,8);

   // Final pre-submit gate: a second instance may have changed exposure while
   // this setup was being validated and sized.
   // Revalidate volatile market, geometry, permission, and volume state at
   // the broker-submit boundary; discovery and earlier OrderCheck can become
   // stale while volume and expiration are being resolved.
   if(!STB_TradeEnvironmentAllowed())
      return STB_LogPlaceReject(s,"TRADE_PERMISSION_CHANGED_BEFORE_SUBMIT");
   if(!IsDirectionTradable(s.symbol,s.direction))
      return STB_LogPlaceReject(s,"DIRECTION_CHANGED_BEFORE_SUBMIT");
   if(!IsSpreadAcceptable(s.symbol))
      return STB_LogPlaceReject(s,"SPREAD_CHANGED_BEFORE_SUBMIT");
   if(!ValidatePendingSetup(s))
      return STB_LogPlaceReject(s,"PENDING_GEOMETRY_CHANGED_BEFORE_SUBMIT");
   if(!STB_DirectionVolumeWithinLimit(s.symbol,s.direction,volume,"PlaceSetupFinal"))
      return STB_LogPlaceReject(s,"VOLUME_LIMIT_CHANGED_BEFORE_SUBMIT");

   // These are the final state/ownership gates immediately before submission.
   if(!STB_EntryLockStillOwned(s.symbol,entryLockToken))
      return STB_LogPlaceReject(s,"ENTRY_LOCK_LOST_BEFORE_SUBMIT");
   if(!STB_SymbolManagementOwnedVerified(s.symbol))
      return STB_LogPlaceReject(s,"SYMBOL_WRITER_LEASE_LOST");
   if(HasManagedExposure(s.symbol))
      return STB_LogPlaceReject(s,"MANAGED_EXPOSURE_CHANGED_BEFORE_SUBMIT");

   MqlTick submitTick;
    string submitQuoteReason="";
    if(!SymbolInfoTick(s.symbol,submitTick) ||
       !STB_ScannerQuoteValid(submitTick,submitQuoteReason))
       return STB_LogPlaceReject(s,
          "QUOTE_INVALID_OR_STALE_BEFORE_SUBMIT:"+
          (submitQuoteReason=="" ? "QUOTE_UNAVAILABLE":submitQuoteReason));

   // Last broker-side preflight uses the exact metadata to be submitted.
   // The earlier discovery check may be stale after the remaining gates.
   ENUM_ORDER_TYPE finalPendingType=(s.direction>0 ? ORDER_TYPE_BUY_STOP
                                                   : ORDER_TYPE_SELL_STOP);
   if(!STB_CheckPendingOrderRequest(s.symbol,finalPendingType,volume,
                                    s.entry,s.sl,s.tp,typeTime,expiration,
                                    (ulong)InpMagic,comment,"SCANNER_FINAL_SUBMIT"))
      return STB_LogPlaceReject(s,"FINAL_ORDERCHECK_REJECT");

    bool ok=false;

   if(s.direction>0)
      ok=trade.BuyStop(volume,s.entry,s.symbol,s.sl,s.tp,typeTime,expiration,comment);
   else
      ok=trade.SellStop(volume,s.entry,s.symbol,s.sl,s.tp,typeTime,expiration,comment);

   if(!ok)
     {
      Print("STB order request failed symbol=",s.symbol,
            " magic=",IntegerToString((int)InpMagic),
            " dir=",(s.direction>0 ? "BUY":"SELL"),
            " lots=",DoubleToString(volume,3),
            " entry=",DoubleToString(s.entry,(int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS)),
            " SL=",DoubleToString(s.sl,(int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS)),
            " TP=",DoubleToString(s.tp,(int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS)),
            " ret=",trade.ResultRetcode()," ",
            trade.ResultRetcodeDescription());
      return false;
     }

   if(!TradeRetcodePlacementSucceeded())
     {
      Print("STB order server rejected symbol=",s.symbol,
            " magic=",IntegerToString((int)InpMagic),
            " dir=",(s.direction>0 ? "BUY":"SELL"),
            " order=",IntegerToString((int)trade.ResultOrder()),
            " ret=",trade.ResultRetcode()," ",
            trade.ResultRetcodeDescription());
      return false;
     }

   ulong placedOrder=trade.ResultOrder();

   if(placedOrder==0 || !VerifyPendingInitialSL(placedOrder))
     {
      Print("STB AUTO PENDING REJECTED AFTER SERVER ACCEPT: initial SL not confirmed symbol=",
            s.symbol,
            " order=",IntegerToString((int)placedOrder));
      if(placedOrder>0 && OrderSelect(placedOrder))
         STB_RequestOrderDelete(placedOrder,STB_DEL_AUTO_ROLLBACK,"PlaceSetup");
      return STB_LogPlaceReject(s,"INITIAL_SL_NOT_CONFIRMED");
     }

   // Commit the setup cooldown only after the accepted order's initial SL
   // has been verified. A failed protection check triggers rollback and must
   // not poison this valid setup with a false "already placed" timestamp.
   SetLastSetupTime(s.symbol,s.direction,s.setupTime);
   STB_AdaptiveRememberLastProfile(s.symbol,s.direction,s.adaptiveProfile);

   if(placedOrder>0)
     {
      STB_AdaptiveRememberOrderProfile(placedOrder,s.adaptiveProfile);
      STB_AfterExposureCreated(placedOrder,"AUTO"); // Blueprint 10/11

      double orderRiskMoney=0.0;
      ENUM_ORDER_TYPE calcType=
         (s.direction>0 ? ORDER_TYPE_BUY:ORDER_TYPE_SELL);

      if(OrderCalcProfit(calcType,s.symbol,volume,
                         s.entry,s.sl,orderRiskMoney))
        {
         orderRiskMoney=MathAbs(orderRiskMoney);
         STB_AdaptiveRememberOrderRisk(placedOrder,orderRiskMoney);
        }
     }

   STB_AdaptiveRecordSetup(s,true);

// Re-activate the same learned profile around order creation;
// immediately after order creation; the setup itself remains immutable.
   STB_AP_SetActive(s.adaptiveProfile);


   STB_AP_ClearActive();

   Print("STB AUTO PENDING CREATED ",s.symbol," ",
         (s.direction>0 ? "BUY":"SELL"),
         " magic=",IntegerToString((int)InpMagic),
         " order=",IntegerToString((int)trade.ResultOrder()),
         " lots=",DoubleToString(volume,3),
         " entry=",DoubleToString(s.entry,(int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS)),
         " SL=",DoubleToString(s.sl,(int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS)),
         " TP=",DoubleToString(s.tp,(int)SymbolInfoInteger(s.symbol,SYMBOL_DIGITS)),
         " RR=",DoubleToString(s.rr,2));

   return true;
  }

// Scanner data types declared before first use (Build 6238 compatibility).

enum ENUM_STB_REGIME
  {
   STB_REGIME_TRENDING=0,
   STB_REGIME_RANGING=1,
   STB_REGIME_TRANSITION=2,
   STB_REGIME_HIGH_VOLATILITY=3,
   STB_REGIME_LOW_VOLATILITY=4,
   STB_REGIME_UNSTABLE=5
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

struct STBMarketQuality
  {
   bool              valid;
   double            spreadPips;
   double            relativeSpread;
   double            volatility;
   double            volatilityRatio;
   double            activityRatio;
   double            freshnessScore;
   double            score;
   string            reason;
  };

struct STBRegimeState
  {
   ENUM_STB_REGIME   regime;
   double            strength;
   int               bias;
   double            volatilityRatio;
   double            efficiency;
   string            reason;
  };

struct STBCandidate
  {
   bool              valid;
   string            symbol;
   int               direction;
   datetime          setupTime;
   Setup             setup;
   double            strategyScore;
   double            marketQualityScore;
   double            regimeScore;
   double            stabilityScore;
   double            opportunityScore;
   ENUM_STB_REGIME   regime;
   double            regimeStrength;
   int               setupAgeBars;
   double            previousScore;
   int               previousRank;
   int               currentRank;
   datetime          lastValidationTime;
   string            rejectReason;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_FinalCandidateRevalidation(STBCandidate &c,Setup &validated)
  {
   if(!c.valid)
      return false;

   string reason="";
   if(!STB_ScannerDataEligible(c.symbol,reason))
     {
      c.rejectReason=reason;
      return false;
     }

   STBMarketQuality q;
   if(!STB_CalcMarketQuality(c.symbol,q))
     {
      c.rejectReason=q.reason;
      return false;
     }

   if(!STB_ScannerDirectionAllowed(c.symbol,c.direction))
     {
      c.rejectReason="REJECT_DIRECTION_NOT_ALLOWED";
      return false;
     }

   if(q.score+1e-9<InpScannerMinQuality)
     {
      c.rejectReason="REJECT_QUALITY_SCORE_BELOW_MINIMUM";
      return false;
     }

   Setup refreshed;
   if(!BuildSetup(c.symbol,c.direction,refreshed,false))
     {
      c.rejectReason=(g_lastBuildRejectReason=="" ?
                      "REJECT_NO_STRATEGY":g_lastBuildRejectReason);
      return false;
     }

   if(refreshed.setupTime!=c.setupTime)
     {
      c.rejectReason="REJECT_STALE_SETUP";
      return false;
     }

   // Re-check setup age at the final scanner-to-execution handoff. The
   // candidate may have aged after discovery/watchlist construction, so the
   // discovery-stage age check alone is not a sufficient execution gate.
   int setupBarShift=iBarShift(c.symbol,PERIOD_M15,refreshed.setupTime,true);
   if(setupBarShift<1)
     {
      c.rejectReason="REJECT_SETUP_AGE_UNAVAILABLE";
      return false;
     }

   c.setupAgeBars=(int)MathMax(0,setupBarShift-1);
   int effectiveMaxAge=STB_EffectiveMaxSetupAgeBars();
   if(effectiveMaxAge>0 && c.setupAgeBars>effectiveMaxAge)
     {
      c.rejectReason="REJECT_SETUP_TOO_OLD";
      return false;
     }

   if(!ValidatePendingSetup(refreshed))
     {
      c.rejectReason="REJECT_INVALID_PENDING_GEOMETRY";
      return false;
     }

   validated=refreshed;
   c.lastValidationTime=TimeCurrent();
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Serialize final scanner revalidation/submission across chart instances.
// The lock is terminal-local and expires automatically if an instance disappears.
string STB_EntryLockKey(const string symbol)
  {
   return STB_MgmtScopeKey("ENTRY_"+(string)InpMagic,symbol);
  }

bool STB_EntryLockAcquire(const string symbol,double &token)
  {
   token=0.0;
   if(symbol=="")
      return false;

   string key=STB_EntryLockKey(symbol);
   if(!GlobalVariableCheck(key))
     {
      ResetLastError();
      if(!GlobalVariableTemp(key) && !GlobalVariableCheck(key))
        {
         Print("STB entry lock creation failed symbol=",symbol,
               " err=",GetLastError());
         return false;
        }
     }

   if(!GlobalVariableCheck(key))
      return false;

   // Use local wall-clock time so a quiet server market does not freeze the
   // lease expiry while other chart instances remain active.
   datetime now=TimeLocal();
   double current=GlobalVariableGet(key);
   if(current!=0.0 && MathFloor(current)>(double)now)
      return false;

   // Integer part is a 120-second lease expiry; fractional part tags the chart.
   token=(double)(now+120)+
         (double)((long)ChartID()%1000000)/1000000.0;
   if(!GlobalVariableSetOnCondition(key,token,current))
     {
      token=0.0;
      return false;
     }

   return true;
  }

bool STB_EntryLockStillOwned(const string symbol,const double token)
  {
   if(symbol=="" || token==0.0)
      return false;

   string key=STB_EntryLockKey(symbol);
   if(!GlobalVariableCheck(key))
      return false;

   return (GlobalVariableGet(key)==token &&
           MathFloor(token)>(double)TimeLocal());
  }

void STB_EntryLockRelease(const string symbol,const double token)
  {
   if(symbol=="" || token==0.0)
      return;

   string key=STB_EntryLockKey(symbol);
   if(GlobalVariableCheck(key))
      GlobalVariableSetOnCondition(key,0.0,token);
  }

bool STB_ExposureAllowsExecution(const Setup &s,string &reason)
  {
   reason="";
   if(HasManagedExposure(s.symbol))
     {
      reason="MANAGED_EXPOSURE_EXISTS";
      return false;
     }
   long maxOrders=AccountInfoInteger(ACCOUNT_LIMIT_ORDERS);
   if(maxOrders>0 && OrdersTotal()>=maxOrders)
     {
      reason="ACCOUNT_ORDER_LIMIT";
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_FinalAutoGate(const Setup &s,string &reason)
  {
   reason="";
   if(!g_autoTrading)
     {
      reason="AUTO_TRADING_OFF";
      return false;
     }
   if(!STB_TradeEnvironmentAllowed())
     {
      reason="TRADE_ENVIRONMENT_REJECT";
      return false;
     }
   if(!STB_ExposureAllowsExecution(s,reason))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_ExecuteTopCandidate()
  {
   // Preflight the daily guard before ranking/dispatching candidates. PlaceSetup
   // retains its own final check to close the race between scan and submission.
   // Throttle this summary so a blocked scanner does not flood the Experts log.
   static datetime lastDailyGuardSkipLog=0;
   if(STB_DailyLossLimitHit())
     {
      datetime now=TimeCurrent();
      if(lastDailyGuardSkipLog<=0 || now<=0 || now-lastDailyGuardSkipLog>=60)
        {
         Print("STB EXECUTION SKIP reason=DAILY_EQUITY_LOSS_LIMIT",
               " thresholdVerified=",g_stbDailyLossThresholdReached ? "YES":"NO",
               " maxDailyLossPct=",DoubleToString(InpMaxDailyLossPercent,2),
               " detail=",g_stbDailyLossThresholdReached ?
                          "daily equity loss threshold reached or latched" :
                          "daily risk state invalid or unavailable; fail-closed");
         lastDailyGuardSkipLog=now;
        }
      return;
     }

   if(g_scannerTop10Count<=0)
      {
       Print("STB EXECUTION SKIP reason=NO_TOP_CANDIDATE",
             " confidence=",g_scannerConfidence,
             " universe=",IntegerToString(g_scannerUniverseCount),
             " eligible=",IntegerToString(g_scannerEligibleCount),
             " quality=",IntegerToString(g_scannerQualityCount),
             " regime=",IntegerToString(g_scannerRegimeCount),
             " candidates=",IntegerToString(g_scannerCandidateCount));
       return;
      }
    if(g_scannerConfidence!="CLEAR")
      {
       double topScore=g_scannerWatchlistCount>0 ?
                       g_scannerWatchlist[0].opportunityScore :
                       g_scannerTop10[0].opportunityScore;
       // Confidence is computed from the full revalidated watchlist, so
       // diagnostics must report the same runner-up even when TopN=1.
       double secondScore=(g_scannerWatchlistCount>1 ?
                           g_scannerWatchlist[1].opportunityScore:0.0);
       Print("STB EXECUTION SKIP reason=CONFIDENCE_NOT_CLEAR",
             " confidence=",g_scannerConfidence,
             " top=",g_scannerTop10[0].symbol,
             " direction=",(g_scannerTop10[0].direction>0 ? "BUY":"SELL"),
             " topScore=",DoubleToString(topScore,1),
             " secondScore=",DoubleToString(secondScore,1),
             " requiredGap=",DoubleToString(InpScannerMinTopGap,1),
             " topCount=",IntegerToString(g_scannerTop10Count));
       return;
      }

   if(!g_autoTrading)
     {
      Print("STB SCANNER SHADOW: Order=BLOCKED_BY_AUTO_OFF",
            " top=",g_scannerTop10[0].symbol,
            " dir=",(g_scannerTop10[0].direction>0 ? "BUY":"SELL"),
            " score=",DoubleToString(g_scannerTop10[0].opportunityScore,1));
      return;
     }

   for(int i=0;i<g_scannerTop10Count;i++)
     {
      STBCandidate c=g_scannerTop10[i];

      // Confidence must remain valid for the candidate actually being tried.
      // If an earlier candidate fails final validation, do not automatically
      // promote a fallback whose own gap to the next valid watchlist entry
      // is below the configured threshold.
      if(i>0)
        {
         int watchRank=-1;
         for(int w=0;w<g_scannerWatchlistCount;w++)
           {
            if(g_scannerWatchlist[w].symbol==c.symbol &&
               g_scannerWatchlist[w].direction==c.direction &&
               g_scannerWatchlist[w].setupTime==c.setupTime)
              {
               watchRank=w;
               break;
              }
           }

         if(watchRank<0)
           {
            Print("STB CANDIDATE REJECT stage=FALLBACK_CONFIDENCE",
                  " symbol=",c.symbol,
                  " reason=CANDIDATE_NOT_IN_REVALIDATED_WATCHLIST");
            break;
           }

         double fallbackScore=g_scannerWatchlist[watchRank].opportunityScore;
         double nextScore=(watchRank+1<g_scannerWatchlistCount ?
                           g_scannerWatchlist[watchRank+1].opportunityScore:0.0);
         bool fallbackClear=(fallbackScore>=InpScannerMinScore);
         if(fallbackClear && watchRank+1<g_scannerWatchlistCount)
            fallbackClear=(fallbackScore-nextScore)>=InpScannerMinTopGap;

         if(!fallbackClear)
           {
            Print("STB EXECUTION SKIP reason=FALLBACK_CONFIDENCE_NOT_CLEAR",
                  " symbol=",c.symbol,
                  " direction=",(c.direction>0 ? "BUY":"SELL"),
                  " score=",DoubleToString(fallbackScore,1),
                  " nextScore=",DoubleToString(nextScore,1),
                  " requiredGap=",DoubleToString(InpScannerMinTopGap,1),
                  " watchRank=",IntegerToString(watchRank+1));
            break;
           }
        }

      string symbol=c.symbol;
      bool wasSelected=(bool)SymbolInfoInteger(symbol,SYMBOL_SELECT);

      // Keep the candidate symbol subscribed through final revalidation and
      // order placement. Retain it afterward only while a managed exposure
      // needs live quotes for stop management/trailing.
      if(!wasSelected && !SymbolSelect(symbol,true))
         {
          Print("STB CANDIDATE REJECT",
                " stage=SYMBOL_SELECT",
                " symbol=",symbol,
                " reason=SYMBOL_SELECT_FAILED",
                " error=",IntegerToString(GetLastError()));
          continue;
         }

      // The lock spans exposure recheck through broker submission so two
      // chart instances cannot both pass the same-symbol gate concurrently.
      double entryLockToken=0.0;
      if(!STB_EntryLockAcquire(symbol,entryLockToken))
        {
         Print("STB CANDIDATE REJECT stage=ENTRY_LOCK",
               " symbol=",symbol,
               " direction=",(c.direction>0 ? "BUY":"SELL"),
               " reason=LOCK_BUSY_OR_UNAVAILABLE",
               " rank=",IntegerToString(c.currentRank));
         if(!wasSelected && !STB_HasSymbolExposureForManagement(symbol))
            SymbolSelect(symbol,false);
         continue;
        }

      Setup validated;
       bool revalidated=STB_FinalCandidateRevalidation(c,validated);
       bool placed=false;
       if(!revalidated)
         {
          Print("STB CANDIDATE REJECT",
                " stage=FINAL_REVALIDATION",
                " symbol=",c.symbol,
                " direction=",(c.direction>0 ? "BUY":"SELL"),
                " reason=",(c.rejectReason=="" ? "UNSPECIFIED":c.rejectReason),
                " rank=",IntegerToString(c.currentRank),
                " score=",DoubleToString(c.opportunityScore,1));
         }
       else
         {
          string finalGateReason="";
          if(!STB_FinalAutoGate(validated,finalGateReason))
            {
             Print("STB CANDIDATE REJECT",
                   " stage=FINAL_AUTO_GATE",
                   " symbol=",c.symbol,
                   " direction=",(c.direction>0 ? "BUY":"SELL"),
                   " reason=",(finalGateReason=="" ? "UNSPECIFIED":finalGateReason),
                   " rank=",IntegerToString(c.currentRank),
                   " score=",DoubleToString(c.opportunityScore,1));
            }
          else
             placed=PlaceSetup(validated,entryLockToken);
         }
       STB_EntryLockRelease(symbol,entryLockToken);

      if(!wasSelected && !STB_HasSymbolExposureForManagement(symbol))
         SymbolSelect(symbol,false);

      if(placed)
        {
         g_panelScanPlacements++;
         return;
        }
     }
  }

//==================================================================
// MANUAL PENDING COMMANDS
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PlaceManualPendingDirection(const int direction)
  {
   // Explicit manual pending orders bypass the automatic-entry daily loss gate.
   // All other trade-environment, volume, price, stop, and broker checks remain active.
   Print("STB MANUAL PENDING: daily loss entry gate bypassed by explicit user action.");

   if(direction!=1 && direction!=-1)
     {
      STB_LogControlReject("BUY_STOP/SELL_STOP","INVALID_DIRECTION");
      return false;
     }
   if(!STB_TradeEnvironmentAllowed())
     {
      STB_LogControlReject("BUY_STOP/SELL_STOP","TRADE_ENVIRONMENT_BLOCKED");
      return false;
     }

   if(!STB_SymbolManagementOwnedVerified(_Symbol))
     {
      Print("STB MANUAL PENDING REJECTED: symbol writer lease not owned symbol=",_Symbol);
      return false;
     }

   long tradeMode=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   if(tradeMode==SYMBOL_TRADE_MODE_DISABLED ||
      tradeMode==SYMBOL_TRADE_MODE_CLOSEONLY ||
      (direction>0 && tradeMode==SYMBOL_TRADE_MODE_SHORTONLY) ||
      (direction<0 && tradeMode==SYMBOL_TRADE_MODE_LONGONLY))
     {
      STB_LogControlReject("BUY_STOP/SELL_STOP","SYMBOL_TRADE_MODE_BLOCK",
                           "tradeMode="+IntegerToString((int)tradeMode));
      return false;
     }

   MqlTick tick;
   ResetLastError();
   if(!SymbolInfoTick(_Symbol,tick))
     {
      STB_LogControlReject("BUY_STOP/SELL_STOP","TICK_UNAVAILABLE",
                           "err="+IntegerToString(GetLastError()));
      return false;
     }
   double pip=PipSize(_Symbol);
   if(pip<=0.0)
     {
      STB_LogControlReject("BUY_STOP/SELL_STOP","INVALID_PIP_SIZE",
                           "pip="+DoubleToString(pip,10));
      return false;
     }

   int orderModes=(int)SymbolInfoInteger(_Symbol,SYMBOL_ORDER_MODE);
   if((orderModes&SYMBOL_ORDER_STOP)!=SYMBOL_ORDER_STOP ||
      (orderModes&SYMBOL_ORDER_SL)!=SYMBOL_ORDER_SL)
     {
      STB_LogControlReject("BUY_STOP/SELL_STOP","BROKER_ORDER_MODE_BLOCK",
                           "orderModes="+IntegerToString(orderModes));
      return false;
     }

   int expirationModes=(int)SymbolInfoInteger(_Symbol,SYMBOL_EXPIRATION_MODE);
   ENUM_ORDER_TYPE_TIME typeTime=ORDER_TIME_GTC;
   datetime expiration=0;

   if((expirationModes&SYMBOL_EXPIRATION_GTC)!=SYMBOL_EXPIRATION_GTC)
      {
       if((expirationModes&SYMBOL_EXPIRATION_DAY)==SYMBOL_EXPIRATION_DAY)
          typeTime=ORDER_TIME_DAY;
       else
         {
          STB_LogControlReject("BUY_STOP/SELL_STOP","NO_SUPPORTED_EXPIRATION",
                               "expirationModes="+IntegerToString(expirationModes));
          return false;
         }
      }

   ENUM_ORDER_TYPE orderType=(direction>0 ? ORDER_TYPE_BUY_STOP
                                          : ORDER_TYPE_SELL_STOP);
   double requestedEntry=(direction>0 ? tick.ask+InpManualPendingGapPips*pip
                                      : tick.bid-InpManualPendingGapPips*pip);
   double entry=0.0;
   if(!STB_ResolveManualPendingEntry(_Symbol,orderType,requestedEntry,tick,entry))
     {
      STB_LogControlReject("BUY_STOP/SELL_STOP","ENTRY_GEOMETRY_REJECT",
                           "requested="+DoubleToString(requestedEntry,_Digits));
      return false;
     }

   double sl=0.0;
   if(!CalculateInitialPendingProtectionSL(_Symbol,orderType,entry,sl))
     {
      STB_LogControlReject("BUY_STOP/SELL_STOP","INITIAL_SL_CALCULATION_FAILED",
                           "entry="+DoubleToString(entry,_Digits));
      return false;
     }

   // Manual pending entries obey the same equity-risk sizing policy as scanner setups.
   double volume=0.0;
   if(InpUseRiskSizing)
     {
      Setup manualRiskSetup={};
      manualRiskSetup.symbol=_Symbol;
      manualRiskSetup.direction=direction;
      manualRiskSetup.entry=entry;
      manualRiskSetup.sl=sl;
      volume=CalculateOrderVolumeByRisk(manualRiskSetup,"PlaceManualPendingDirection","MANUAL_PENDING");
     }
   else
      volume=NormalizeVolume(_Symbol,InpBaseLots);

   if(volume<=0.0 || !MathIsValidNumber(volume))
     {
      if(InpUseRiskSizing)
         STB_LogVolumeReject(_Symbol,direction,entry,sl);
      else
         STB_LogFixedVolumeReject("PlaceManualPendingDirection","MANUAL_PENDING_FIXED",
                                  _Symbol,direction,entry,sl,InpBaseLots);
      Print("STB MANUAL PENDING REJECTED: ",
            InpUseRiskSizing ? "risk volume invalid" : "fixed volume invalid",
            " symbol=",_Symbol);
      return false;
     }
   if(!STB_DirectionVolumeWithinLimit(_Symbol,direction,volume,"PlaceManualPendingDirection"))
      return false;

   trade.SetExpertMagicNumber(0);
   trade.SetAsyncMode(false);
   trade.SetTypeFilling(ORDER_FILLING_RETURN);

   double effectiveManualOffset=MathAbs(entry-(direction>0 ? tick.bid:tick.ask))/pip;
   string comment="STB|M|"+(direction>0 ? "BUY":"SELL")+"|EB"+DoubleToString(effectiveManualOffset,8);
   if(!STB_SymbolManagementOwnedVerified(_Symbol))
      return false;
   MqlTick manualSubmitTick;
    string manualQuoteReason="";
    if(!SymbolInfoTick(_Symbol,manualSubmitTick) ||
       !STB_ScannerQuoteValid(manualSubmitTick,manualQuoteReason))
      {
       Print("STB MANUAL PENDING REJECTED: quote invalid/stale symbol=",_Symbol,
             " reason=",(manualQuoteReason=="" ? "QUOTE_UNAVAILABLE":manualQuoteReason));
       return false;
      }
    ENUM_ORDER_TYPE manualStopType=(direction>0 ? ORDER_TYPE_BUY_STOP:ORDER_TYPE_SELL_STOP);
    if(!STB_CheckPendingOrderRequest(_Symbol,manualStopType,volume,entry,sl,0.0,
                                     typeTime,expiration,0,comment,"MANUAL_STOP"))
       return false;

    ResetLastError();
    bool ok=(direction>0)
           ? trade.BuyStop(volume,entry,_Symbol,sl,0.0,typeTime,expiration,comment)
           : trade.SellStop(volume,entry,_Symbol,sl,0.0,typeTime,expiration,comment);

    uint sendRetcode=trade.ResultRetcode();
    string sendDescription=trade.ResultRetcodeDescription();
    int sendError=GetLastError();
    if(!ok || !TradeRetcodePlacementSucceeded())
      {
       Print("STB MANUAL STOP SEND REJECTED direction=",
             (direction>0 ? "BUY":"SELL"),
             " symbol=",_Symbol,
             " requestOK=",ok ? "YES":"NO",
             " retcode=",IntegerToString((int)sendRetcode),
             " description=",sendDescription,
             " error=",IntegerToString(sendError),
             " volume=",DoubleToString(volume,3),
             " entry=",DoubleToString(entry,_Digits),
             " SL=",DoubleToString(sl,_Digits));
       return false;
      }

   ulong ticket=trade.ResultOrder();
   if(ticket==0 || !VerifyPendingInitialSL(ticket))
     {
      Print("STB MANUAL PENDING REJECTED AFTER SERVER ACCEPT: initial SL not confirmed symbol=",
            _Symbol," order=",IntegerToString((int)ticket));
      if(ticket>0 && OrderSelect(ticket))
         STB_RequestOrderDelete(ticket,STB_DEL_AUTO_ROLLBACK,"PlaceManual");
      return false;
     }

   // SIMPLIFIED: origin registry call removed.
   STB_AfterExposureCreated(ticket,"UI_MANUAL"); // Blueprint 10/11
   STB_ManualOverrideSet(ticket); // MANUAL_OVERRIDE: user-placed pending is final

   Print("STB MANUAL PENDING ",
         (direction>0 ? "BUY_STOP":"SELL_STOP"),
         " SUCCESS symbol=",_Symbol,
         " entry=",DoubleToString(entry,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)),
         " SL=",DoubleToString(sl,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)),
         " order=",IntegerToString((int)ticket));
   return true;
  }


//==================================================================
// SCANNER ARCHITECTURE — UNIVERSE -> TOP10 CANDIDATES
//==================================================================


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PlaceManualLimitDirection(const int direction)
  {
   // Explicit manual limit orders bypass the automatic-entry daily loss gate.
   // All other trade-environment, volume, price, stop, and broker checks remain active.
   Print("STB MANUAL LIMIT: daily loss entry gate bypassed by explicit user action.");

   if(direction!=1 && direction!=-1)
     {
      STB_LogControlReject("BUY_LIMIT/SELL_LIMIT","INVALID_DIRECTION");
      return false;
     }
   if(!STB_TradeEnvironmentAllowed())
     {
      STB_LogControlReject("BUY_LIMIT/SELL_LIMIT","TRADE_ENVIRONMENT_BLOCKED");
      return false;
     }

   if(!STB_SymbolManagementOwnedVerified(_Symbol))
     {
      Print("STB MANUAL LIMIT REJECTED: symbol writer lease not owned symbol=",_Symbol);
      return false;
     }

   long tradeMode=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE);
   if(tradeMode==SYMBOL_TRADE_MODE_DISABLED ||
      tradeMode==SYMBOL_TRADE_MODE_CLOSEONLY ||
      (direction>0 && tradeMode==SYMBOL_TRADE_MODE_SHORTONLY) ||
      (direction<0 && tradeMode==SYMBOL_TRADE_MODE_LONGONLY))
     {
      STB_LogControlReject("BUY_LIMIT/SELL_LIMIT","SYMBOL_TRADE_MODE_BLOCK",
                           "tradeMode="+IntegerToString((int)tradeMode));
      return false;
     }

   MqlTick tick;
   ResetLastError();
   if(!SymbolInfoTick(_Symbol,tick))
     {
      STB_LogControlReject("BUY_LIMIT/SELL_LIMIT","TICK_UNAVAILABLE",
                           "err="+IntegerToString(GetLastError()));
      return false;
     }
   double pip=PipSize(_Symbol);
   if(pip<=0.0)
     {
      STB_LogControlReject("BUY_LIMIT/SELL_LIMIT","INVALID_PIP_SIZE",
                           "pip="+DoubleToString(pip,10));
      return false;
     }

   int orderModes=(int)SymbolInfoInteger(_Symbol,SYMBOL_ORDER_MODE);
   if((orderModes&SYMBOL_ORDER_LIMIT)!=SYMBOL_ORDER_LIMIT ||
      (orderModes&SYMBOL_ORDER_SL)!=SYMBOL_ORDER_SL)
     {
      STB_LogControlReject("BUY_LIMIT/SELL_LIMIT","BROKER_ORDER_MODE_BLOCK",
                           "orderModes="+IntegerToString(orderModes));
      return false;
     }

   int expirationModes=(int)SymbolInfoInteger(_Symbol,SYMBOL_EXPIRATION_MODE);
   ENUM_ORDER_TYPE_TIME typeTime=ORDER_TIME_GTC;
   datetime expiration=0;

   if((expirationModes&SYMBOL_EXPIRATION_GTC)!=SYMBOL_EXPIRATION_GTC)
      {
       if((expirationModes&SYMBOL_EXPIRATION_DAY)==SYMBOL_EXPIRATION_DAY)
          typeTime=ORDER_TIME_DAY;
       else
         {
          STB_LogControlReject("BUY_LIMIT/SELL_LIMIT","NO_SUPPORTED_EXPIRATION",
                               "expirationModes="+IntegerToString(expirationModes));
          return false;
         }
      }

   ENUM_ORDER_TYPE orderType=(direction>0 ? ORDER_TYPE_BUY_LIMIT
                                          : ORDER_TYPE_SELL_LIMIT);
   double requestedEntry=(direction>0 ? tick.bid-InpManualPendingGapPips*pip
                                      : tick.ask+InpManualPendingGapPips*pip);
   double entry=0.0;
   if(!STB_ResolveManualPendingEntry(_Symbol,orderType,requestedEntry,tick,entry))
     {
      STB_LogControlReject("BUY_LIMIT/SELL_LIMIT","ENTRY_GEOMETRY_REJECT",
                           "requested="+DoubleToString(requestedEntry,_Digits));
      return false;
     }
   double sl=0.0;

   if(!CalculateInitialPendingProtectionSL(_Symbol,orderType,entry,sl))
     {
      STB_LogControlReject("BUY_LIMIT/SELL_LIMIT","INITIAL_SL_CALCULATION_FAILED",
                           "entry="+DoubleToString(entry,_Digits));
      return false;
     }

   // Manual limit entries obey the same equity-risk sizing policy as scanner setups.
   double volume=0.0;
   if(InpUseRiskSizing)
     {
      Setup manualRiskSetup={};
      manualRiskSetup.symbol=_Symbol;
      manualRiskSetup.direction=direction;
      manualRiskSetup.entry=entry;
      manualRiskSetup.sl=sl;
      volume=CalculateOrderVolumeByRisk(manualRiskSetup,"PlaceManualLimitDirection","MANUAL_LIMIT");
     }
   else
      volume=NormalizeVolume(_Symbol,InpBaseLots);

   if(volume<=0.0 || !MathIsValidNumber(volume))
     {
      if(InpUseRiskSizing)
         STB_LogVolumeReject(_Symbol,direction,entry,sl);
      else
         STB_LogFixedVolumeReject("PlaceManualLimitDirection","MANUAL_LIMIT_FIXED",
                                  _Symbol,direction,entry,sl,InpBaseLots);
      Print("STB MANUAL LIMIT REJECTED: ",
            InpUseRiskSizing ? "risk volume invalid" : "fixed volume invalid",
            " symbol=",_Symbol);
      return false;
     }
   if(!STB_DirectionVolumeWithinLimit(_Symbol,direction,volume,"PlaceManualLimitDirection"))
      return false;

   trade.SetExpertMagicNumber(0);
   trade.SetAsyncMode(false);
   trade.SetTypeFilling(ORDER_FILLING_RETURN);

   double effectiveManualOffset=MathAbs(entry-(direction>0 ? tick.bid:tick.ask))/pip;
   string comment="STB|M|"+(direction>0 ? "BUY_LIMIT":"SELL_LIMIT")+
                  "|EB"+DoubleToString(effectiveManualOffset,8);
   if(!STB_SymbolManagementOwnedVerified(_Symbol))
      return false;
   MqlTick manualLimitSubmitTick;
    string manualLimitQuoteReason="";
    if(!SymbolInfoTick(_Symbol,manualLimitSubmitTick) ||
       !STB_ScannerQuoteValid(manualLimitSubmitTick,manualLimitQuoteReason))
      {
       Print("STB MANUAL LIMIT REJECTED: quote invalid/stale symbol=",_Symbol,
             " reason=",(manualLimitQuoteReason=="" ? "QUOTE_UNAVAILABLE":manualLimitQuoteReason));
       return false;
      }
    ENUM_ORDER_TYPE manualLimitType=(direction>0 ? ORDER_TYPE_BUY_LIMIT:ORDER_TYPE_SELL_LIMIT);
    if(!STB_CheckPendingOrderRequest(_Symbol,manualLimitType,volume,entry,sl,0.0,
                                     typeTime,expiration,0,comment,"MANUAL_LIMIT"))
       return false;

    ResetLastError();
   bool ok=(direction>0)
          ? trade.BuyLimit(volume,entry,_Symbol,sl,0.0,typeTime,expiration,comment)
          : trade.SellLimit(volume,entry,_Symbol,sl,0.0,typeTime,expiration,comment);

   uint sendRetcode=trade.ResultRetcode();
   string sendDescription=trade.ResultRetcodeDescription();
   int sendError=GetLastError();
   if(!ok || !TradeRetcodePlacementSucceeded())
     {
      Print("STB MANUAL LIMIT SEND REJECTED direction=",
            (direction>0 ? "BUY":"SELL"),
            " symbol=",_Symbol,
            " requestOK=",ok ? "YES":"NO",
            " retcode=",IntegerToString((int)sendRetcode),
            " description=",sendDescription,
            " error=",IntegerToString(sendError),
            " volume=",DoubleToString(volume,3),
            " entry=",DoubleToString(entry,_Digits),
            " SL=",DoubleToString(sl,_Digits));
      return false;
     }

   ulong ticket=trade.ResultOrder();
   if(ticket==0 || !VerifyPendingInitialSL(ticket))
     {
      Print("STB MANUAL LIMIT REJECTED AFTER SERVER ACCEPT: initial SL not confirmed symbol=",
            _Symbol," order=",IntegerToString((int)ticket));
      if(ticket>0 && OrderSelect(ticket))
         STB_RequestOrderDelete(ticket,STB_DEL_AUTO_ROLLBACK,"PlaceManual");
      return false;
     }

   // SIMPLIFIED: origin registry call removed.
   STB_AfterExposureCreated(ticket,"UI_MANUAL"); // Blueprint 10/11
   STB_ManualOverrideSet(ticket); // MANUAL_OVERRIDE: user-placed pending is final

   Print("STB MANUAL PENDING ",
         (direction>0 ? "BUY_LIMIT":"SELL_LIMIT"),
         " SUCCESS symbol=",_Symbol,
         " entry=",DoubleToString(entry,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)),
         " SL=",DoubleToString(sl,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS)),
         " order=",IntegerToString((int)ticket));
   return true;
  }

STBCandidate g_scannerCurrent[];
STBCandidate g_scannerPrevious[];
STBCandidate g_scannerWatchlist[];
STBCandidate g_scannerTop10[];

datetime g_scannerLastCycleBar=0;
datetime g_scannerLastRun=0;
ulong    g_scannerCycle=0;

string g_scannerStatus="NOT_RUN";
string g_scannerConfidence="NO_CLEAR_WINNER";

int g_scannerUniverseCount=0;
int g_scannerEligibleCount=0;
int g_scannerQualityCount=0;
int g_scannerRegimeCount=0;
int g_scannerBuyCount=0;
int g_scannerSellCount=0;
int g_scannerCandidateCount=0;
int g_scannerWatchlistCount=0;
int g_scannerTop10Count=0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_ScannerSessionOpen(const string symbol)
  {
   datetime serverNow=TimeTradeServer();
   if(serverNow<=0)
      serverNow=TimeCurrent();
   if(serverNow<=0)
      return false;

   MqlDateTime dt;
   if(!TimeToStruct(serverNow,dt))
      return false;

   int nowSec=dt.hour*3600+dt.min*60+dt.sec;

   // Check today's sessions and the previous weekday's overnight sessions.
   // A session such as 22:00-02:00 belongs to its start day, so checking
   // only today's weekday incorrectly rejects the 00:00-02:00 segment.
   for(int dayOffset=0;dayOffset<=1;dayOffset++)
     {
      int sessionDay=(dt.day_of_week-dayOffset+7)%7;

      for(uint session=0;session<32;session++)
        {
         datetime from=0;
         datetime to=0;

         if(!SymbolInfoSessionTrade(symbol,
                                    (ENUM_DAY_OF_WEEK)sessionDay,
                                    session,
                                    from,to))
            break;

         MqlDateTime fd,td;
         if(!TimeToStruct(from,fd) || !TimeToStruct(to,td))
            continue;

         int fromSec=fd.hour*3600+fd.min*60+fd.sec;
         int toSec=td.hour*3600+td.min*60+td.sec;

         if(fromSec==toSec)
           {
            // Equal endpoints represent a full-day session only for the
            // weekday on which that session is declared.
            if(dayOffset==0)
               return true;
            continue;
           }

         if(fromSec<toSec)
           {
            if(dayOffset==0 && nowSec>=fromSec && nowSec<=toSec)
               return true;
           }
         else
           {
            // Before midnight: today's overnight session.
            if(dayOffset==0 && nowSec>=fromSec)
               return true;

            // After midnight: previous weekday's overnight session.
            if(dayOffset==1 && nowSec<=toSec)
               return true;
           }
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Reject invalid market quotes before they can influence scanner eligibility or ranking.
bool STB_ScannerQuoteValid(const MqlTick &tick,string &reason)
  {
   reason="";

   if(tick.time<=0 ||
      !MathIsValidNumber(tick.bid) ||
      !MathIsValidNumber(tick.ask) ||
      tick.bid<=0.0 ||
      tick.ask<=0.0 ||
      tick.ask<tick.bid)
     {
      reason="REJECT_INVALID_QUOTE";
      return false;
     }

   // TimeTradeServer is a server-time estimate in live operation and follows
   // simulated time in Strategy Tester. Permit only a tiny timestamp skew;
   // never turn a materially future-dated quote into a fresh quote via clamping.
   datetime clockNow=TimeTradeServer();
   if(clockNow<=0)
      clockNow=TimeCurrent();

   if(clockNow<=0)
     {
      reason="REJECT_CLOCK_UNAVAILABLE";
      return false;
     }

   long ageSeconds=(long)clockNow-(long)tick.time;
   if(ageSeconds < -2)
     {
      reason="REJECT_FUTURE_QUOTE";
      return false;
     }

   if(ageSeconds<0)
      ageSeconds=0;

   if(ageSeconds>(long)InpScannerMaxQuoteAgeSec)
     {
      reason="REJECT_STALE_DATA";
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_ScannerDataEligible(const string symbol,string &reason)
  {
   reason="";

   bool custom=false;
   if(symbol=="" || !SymbolExist(symbol,custom))
     {
      reason="REJECT_SYMBOL_NOT_FOUND";
      return false;
     }

   bool selected=(bool)SymbolInfoInteger(symbol,SYMBOL_SELECT);
   if(!selected && !SymbolSelect(symbol,true))
     {
      reason="REJECT_SYMBOL_SELECT_FAILED";
      return false;
     }

   // A newly selected symbol can be temporarily unsynchronized while its
   // M15/H4 history is still being downloaded or built. Do not reject it
   // before requesting that history: otherwise the scanner can repeatedly
   // skip the symbol without ever starting the series request.
   int needM15=MathMax(InpLookbackM15,40);
   int needH4=MathMax(InpLookbackH4,40);
   if(!SymbolIsSynchronized(symbol) ||
      Bars(symbol,PERIOD_M15)<needM15 ||
      Bars(symbol,PERIOD_H4)<needH4)
     {
      MqlRates warmM15[];
      MqlRates warmH4[];
      bool m15Ready=GetRates(symbol,PERIOD_M15,needM15,warmM15);
      bool h4Ready=GetRates(symbol,PERIOD_H4,needH4,warmH4);
      if(!m15Ready || !h4Ready)
        {
         reason="REJECT_DATA_UNAVAILABLE";
         return false;
        }
     }

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
     {
      reason="REJECT_DATA_UNAVAILABLE";
      return false;
     }

   if(!STB_ScannerQuoteValid(tick,reason))
      return false;

   if(Bars(symbol,PERIOD_M15)<MathMax(InpLookbackM15,40) ||
      Bars(symbol,PERIOD_H4)<MathMax(InpLookbackH4,40))
     {
      reason="REJECT_DATA_UNAVAILABLE";
      return false;
     }

   if(!STB_ScannerSessionOpen(symbol))
     {
      reason="REJECT_SESSION";
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_ScannerDirectionAllowed(const string symbol,const int direction)
  {
   long tradeMode=SymbolInfoInteger(symbol,SYMBOL_TRADE_MODE);
   long orderMode=SymbolInfoInteger(symbol,SYMBOL_ORDER_MODE);

   if(tradeMode==SYMBOL_TRADE_MODE_DISABLED ||
      tradeMode==SYMBOL_TRADE_MODE_CLOSEONLY)
      return false;

   if((orderMode&SYMBOL_ORDER_STOP)!=SYMBOL_ORDER_STOP ||
      (orderMode&SYMBOL_ORDER_SL)!=SYMBOL_ORDER_SL ||
      (orderMode&SYMBOL_ORDER_TP)!=SYMBOL_ORDER_TP)
      return false;

   if(direction>0 && tradeMode==SYMBOL_TRADE_MODE_SHORTONLY)
      return false;

   if(direction<0 && tradeMode==SYMBOL_TRADE_MODE_LONGONLY)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_CalcMarketQuality(const string symbol,STBMarketQuality &q)
  {
   q.valid=false;
   q.spreadPips=0.0;
   q.relativeSpread=0.0;
   q.volatility=0.0;
   q.volatilityRatio=1.0;
   q.activityRatio=1.0;
   q.freshnessScore=0.0;
   q.score=0.0;
   q.reason="REJECT_DATA_UNAVAILABLE";

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
      return false;

   string quoteReason="";
   if(!STB_ScannerQuoteValid(tick,quoteReason))
     {
      q.reason=quoteReason;
      return false;
     }
   q.reason="REJECT_DATA_UNAVAILABLE";

   double pip=PipSize(symbol);
   if(pip<=0.0)
      return false;

   MqlRates rates[];
   if(!GetRates(symbol,PERIOD_M15,48,rates))
      return false;

   double atrNow=LocalATR(rates,1,14);
   double atrBase=LocalATR(rates,20,14);

   if(!MathIsValidNumber(atrNow) ||
      !MathIsValidNumber(atrBase) ||
      atrNow<=0.0 || atrBase<=0.0)
     {
      q.reason="REJECT_INVALID_MARKET_DATA";
      return false;
     }

   q.spreadPips=(tick.ask-tick.bid)/pip;
   q.relativeSpread=(tick.ask-tick.bid)/atrNow*100.0;
   q.volatility=atrNow;
   q.volatilityRatio=atrNow/atrBase;

   double avgVol=0.0;
   int volCount=0;

   for(int i=5;i<25 && i<ArraySize(rates);i++)
     {
      avgVol+=(double)rates[i].tick_volume;
      volCount++;
     }

   if(volCount<=0)
      return false;

   avgVol/=volCount;
   q.activityRatio=(avgVol>0.0 ?
                    (double)rates[1].tick_volume/avgVol : 0.0);

   datetime qualityClock=TimeTradeServer();
   if(qualityClock<=0)
      qualityClock=TimeCurrent();
   if(qualityClock<=0)
     {
      q.reason="REJECT_CLOCK_UNAVAILABLE";
      return false;
     }

   long age=(long)qualityClock-(long)tick.time;
   if(age<0)
      age=0; // The shared validator already rejected future skew beyond two seconds.
   if(age>(long)InpScannerMaxQuoteAgeSec)
     {
      q.reason="REJECT_STALE_DATA";
      return false;
     }

   q.freshnessScore=100.0-
                    MathMin(100.0,
                            (double)age/(double)InpScannerMaxQuoteAgeSec*100.0);

   if(!MathIsValidNumber(q.spreadPips) ||
      !MathIsValidNumber(q.relativeSpread) ||
      !MathIsValidNumber(q.volatilityRatio) ||
      !MathIsValidNumber(q.activityRatio) ||
      !MathIsValidNumber(q.freshnessScore) ||
      q.spreadPips<0.0 ||
      q.relativeSpread<0.0 ||
      q.volatilityRatio<=0.0 ||
      q.activityRatio<0.0 ||
      q.freshnessScore<0.0 || q.freshnessScore>100.0)
     {
      q.reason="REJECT_INVALID_MARKET_METRICS";
      return false;
     }

   double score=100.0;
   score-=MathMin(35.0,q.relativeSpread*3.0);

   if(q.volatilityRatio>3.0)
      score-=25.0;
   else
      if(q.volatilityRatio<0.35)
         score-=20.0;

   if(q.activityRatio<0.20)
      score-=25.0;
   else
      if(q.activityRatio<0.40)
         score-=12.0;

   score*=MathMax(0.0,q.freshnessScore)/100.0;
   q.score=MathMax(0.0,MathMin(100.0,score));

   if(InpMaxSpreadPips>0.0 && q.spreadPips>InpMaxSpreadPips)
     {
      q.reason="REJECT_SPREAD";
      return false;
     }

   // High technical scores do not override excessive transaction friction.
   // The ATR-relative cap adapts to each symbol's current M15 volatility.
   if(InpMaxRelativeSpreadPct>0.0 &&
      q.relativeSpread>InpMaxRelativeSpreadPct)
     {
      q.reason="REJECT_RELATIVE_SPREAD";
      return false;
     }

   if(q.activityRatio<0.10)
     {
      q.reason="REJECT_ACTIVITY";
      return false;
     }

   if(q.volatilityRatio>4.0)
     {
      q.reason="REJECT_VOLATILITY";
      return false;
     }

   if(q.score+1e-9<InpScannerMinQuality)
     {
      q.reason="REJECT_QUALITY_SCORE";
      return false;
     }

   q.valid=true;
   q.reason="";
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_EvaluateRegime(const string symbol,STBRegimeState &r)
  {
   r.regime=STB_REGIME_UNSTABLE;
   r.strength=0.0;
   r.bias=0;
   r.volatilityRatio=1.0;
   r.efficiency=0.0;
   r.reason="REJECT_UNSTABLE_REGIME";

   TrendInfo trend=GetH4Trend(symbol);

   MqlRates m15[];
   if(!GetRates(symbol,PERIOD_M15,64,m15))
      return false;

   double atrNow=LocalATR(m15,1,14);
   double atrBase=LocalATR(m15,30,14);

   if(atrNow<=0.0 || atrBase<=0.0)
      return false;

   r.volatilityRatio=atrNow/atrBase;

   double net=MathAbs(m15[1].close-m15[21].close);
   double path=0.0;

   for(int i=1;i<21;i++)
      path+=MathAbs(m15[i].close-m15[i+1].close);

   r.efficiency=(path>0.0 ? net/path:0.0);

   if(trend.valid)
      r.bias=(trend.bias=="BULLISH" ? 1 :
              trend.bias=="BEARISH" ? -1 : 0);

   if(r.volatilityRatio>=2.50)
     {
      r.regime=STB_REGIME_HIGH_VOLATILITY;
      r.strength=MathMin(100.0,50.0+(r.volatilityRatio-2.50)*25.0);
      r.reason="HIGH_RELATIVE_VOLATILITY";
      return true;
     }

   if(r.volatilityRatio<=0.40)
     {
      r.regime=STB_REGIME_LOW_VOLATILITY;
      r.strength=MathMin(100.0,50.0+(0.40-r.volatilityRatio)*100.0);
      r.reason="LOW_RELATIVE_VOLATILITY";
      return true;
     }

   if(trend.valid && r.efficiency>=0.55)
     {
      r.regime=STB_REGIME_TRENDING;
      r.strength=MathMin(100.0,55.0+r.efficiency*45.0);
      r.reason="H4_TREND_PLUS_M15_EFFICIENCY";
      return true;
     }

   if(!trend.valid && r.efficiency<=0.25)
     {
      r.regime=STB_REGIME_RANGING;
      r.strength=MathMin(100.0,55.0+(0.25-r.efficiency)*180.0);
      r.reason="LOW_DIRECTIONAL_EFFICIENCY";
      return true;
     }

   if(r.efficiency>=0.20)
     {
      r.regime=STB_REGIME_TRANSITION;
      r.strength=55.0;
      r.reason="MIXED_STRUCTURE";
      return true;
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_RegimeFitScore(const STBCandidate &c,const STBRegimeState &r)
  {
   if(r.regime==STB_REGIME_UNSTABLE)
      return 0.0;

   if(r.regime==STB_REGIME_TRENDING)
     {
      if((c.direction>0 && r.bias>0) ||
         (c.direction<0 && r.bias<0))
         return 100.0;
      return 35.0;
     }

   if(r.regime==STB_REGIME_RANGING)
      return 45.0;

   if(r.regime==STB_REGIME_TRANSITION)
      return 65.0;

   if(r.regime==STB_REGIME_HIGH_VOLATILITY)
      return 45.0;

   if(r.regime==STB_REGIME_LOW_VOLATILITY)
      return 60.0;

   return 0.0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int STB_FindPreviousCandidate(const string symbol,
                              const int direction,
                              const datetime setupTime)
  {
   for(int i=0;i<ArraySize(g_scannerPrevious);i++)
      if(g_scannerPrevious[i].symbol==symbol &&
         g_scannerPrevious[i].direction==direction &&
         g_scannerPrevious[i].setupTime==setupTime)
         return i;

   return -1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double STB_CandidateStability(const string symbol,
                              const int direction,
                              const datetime setupTime,
                              const double score,
                              double &previousScore,
                              int &previousRank)
  {
   previousScore=0.0;
   previousRank=0;

   int idx=STB_FindPreviousCandidate(symbol,direction,setupTime);

   if(idx<0)
      return 55.0;

   previousScore=g_scannerPrevious[idx].opportunityScore;
   previousRank=g_scannerPrevious[idx].currentRank;

   double delta=MathAbs(score-previousScore);
   return MathMax(0.0,100.0-MathMin(100.0,delta*4.0));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool STB_CandidateGreater(const STBCandidate &a,
                          const STBCandidate &b)
  {
   if(MathAbs(a.opportunityScore-b.opportunityScore)>1e-9)
      return a.opportunityScore>b.opportunityScore;

   if(MathAbs(a.marketQualityScore-b.marketQualityScore)>1e-9)
      return a.marketQualityScore>b.marketQualityScore;

   if(MathAbs(a.strategyScore-b.strategyScore)>1e-9)
      return a.strategyScore>b.strategyScore;

   if(MathAbs(a.setup.rr-b.setup.rr)>1e-9)
      return a.setup.rr>b.setup.rr;

   if(a.setupTime!=b.setupTime)
      return a.setupTime>b.setupTime;

   if(a.symbol!=b.symbol)
      return a.symbol<b.symbol;

   return a.direction>b.direction;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_SortCandidates(STBCandidate &arr[])
  {
   int n=ArraySize(arr);

   for(int i=0;i<n-1;i++)
     {
      int best=i;

      for(int j=i+1;j<n;j++)
         if(STB_CandidateGreater(arr[j],arr[best]))
            best=j;

      if(best!=i)
        {
         STBCandidate tmp=arr[i];
         arr[i]=arr[best];
         arr[best]=tmp;
        }
     }

   for(int i=0;i<n;i++)
      arr[i].currentRank=i+1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_ScannerAllocationAbort(const string stage,string &symbols[],bool &wasSelected[])
  {
   Print("STB SCANNER ABORT stage=",stage,
         " reason=ARRAY_ALLOCATION_FAILED; no candidate may be executed");

   for(int i=0;i<ArraySize(symbols) && i<ArraySize(wasSelected);i++)
      if(!wasSelected[i] && !STB_HasSymbolExposureForManagement(symbols[i]))
         SymbolSelect(symbols[i],false);

   ArrayFree(g_scannerCurrent);
   ArrayFree(g_scannerWatchlist);
   ArrayFree(g_scannerTop10);

   g_scannerUniverseCount=0;
   g_scannerEligibleCount=0;
   g_scannerQualityCount=0;
   g_scannerRegimeCount=0;
   g_scannerBuyCount=0;
   g_scannerSellCount=0;
   g_scannerCandidateCount=0;
   g_scannerWatchlistCount=0;
   g_scannerTop10Count=0;
   g_scannerConfidence="NO_CLEAR_WINNER";
   g_scannerStatus="ALLOCATION_FAILED";
   g_panelScanSymbols=0;
   g_panelScanTradable=0;
   g_panelScanBuyReady=0;
   g_panelScanSellReady=0;
   g_panelScanPlacements=0;
   g_panelLastScanTime=TimeCurrent();
   g_panelChartBuyReady=false;
   g_panelChartSellReady=false;
   g_panelChartBuyScore=0.0;
   g_panelChartSellScore=0.0;
   g_scannerLastRun=TimeCurrent();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Match configured scanner exclusions by exact broker symbol name, case-insensitively.
bool STB_ScannerSymbolExcluded(const string symbol)
  {
   if(symbol=="" || StringLen(InpScannerExcludedSymbols)==0)
      return false;

   string cfg=InpScannerExcludedSymbols;
   StringReplace(cfg,";",",");
   string parts[];
   ushort separator=StringGetCharacter(",",0);
   int count=StringSplit(cfg,separator,parts);

   string candidate=symbol;
   StringToUpper(candidate);

   for(int i=0;i<count;i++)
     {
      string excluded=parts[i];
      StringTrimLeft(excluded);
      StringTrimRight(excluded);
      if(excluded=="")
         continue;

      StringToUpper(excluded);
      if(excluded==candidate)
         return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_ScannerRun()
  {
   datetime cycleBar=iTime(_Symbol,PERIOD_M15,1);
   bool newChartBar=(cycleBar>0 && cycleBar!=g_scannerLastCycleBar);
   int scanInterval=MathMax(1,InpScanSeconds);
   bool intervalElapsed=(g_scannerLastRun<=0 ||
                         TimeCurrent()-g_scannerLastRun>=scanInterval);
   if(!newChartBar && !intervalElapsed)
      return;

   ulong started=(ulong)GetTickCount();

   string symbols[];
   bool wasSelected[];

   ArrayFree(g_scannerPrevious);
   int prevCount=ArraySize(g_scannerCurrent);

   if(prevCount>0)
     {
      if(ArrayResize(g_scannerPrevious,prevCount)!=prevCount)
        {
         STB_ScannerAllocationAbort("PREVIOUS_SNAPSHOT",symbols,wasSelected);
         return;
        }
      for(int p=0;p<prevCount;p++)
         g_scannerPrevious[p]=g_scannerCurrent[p];
     }

   ArrayFree(g_scannerCurrent);
   ArrayFree(g_scannerWatchlist);
   ArrayFree(g_scannerTop10);

   g_scannerUniverseCount=0;
   g_scannerEligibleCount=0;
   g_scannerQualityCount=0;
   g_scannerRegimeCount=0;
   g_scannerBuyCount=0;
   g_scannerSellCount=0;
   g_scannerCandidateCount=0;
   g_scannerWatchlistCount=0;
   g_scannerTop10Count=0;
   g_scannerConfidence="NO_CLEAR_WINNER";
   g_scannerStatus="RUNNING";

   ArrayResize(symbols,0);
   bool universeAllocationFailed=false;

   if(MQLInfoInteger(MQL_TESTER) && InpTesterChartSymbolOnly)
     {
      if(ArrayResize(symbols,1)!=1)
        {
         STB_ScannerAllocationAbort("TESTER_UNIVERSE",symbols,wasSelected);
         return;
        }
      symbols[0]=_Symbol;
     }
   else if(StringLen(InpScannerSymbols)>0)
     {
      // Parse only configured symbols instead of iterating the broker's full
      // symbol catalog. This keeps explicit-universe scans bounded and fast.
      string configured=InpScannerSymbols;
      StringReplace(configured,";",",");
      string parts[];
      ushort separator=StringGetCharacter(",",0);
      int count=StringSplit(configured,separator,parts);

      for(int i=0;i<count;i++)
        {
         string symbol=parts[i];
         StringTrimLeft(symbol);
         StringTrimRight(symbol);
         if(symbol=="")
            continue;

         bool duplicate=false;
         for(int j=0;j<ArraySize(symbols);j++)
            if(symbols[j]==symbol)
              {
               duplicate=true;
               break;
              }

         if(duplicate)
            continue;

         int n=ArraySize(symbols);
         if(ArrayResize(symbols,n+1)!=n+1)
           {
            Print("STB SCANNER UNIVERSE ALLOCATION FAILED symbol=",symbol);
            universeAllocationFailed=true;
            break;
           }
         symbols[n]=symbol;
        }
     }
   else
     {
      // Empty InpScannerSymbols means selected Market Watch symbols only.
      int total=SymbolsTotal(true);

      for(int i=0;i<total;i++)
        {
         string symbol=SymbolName(i,true);
         if(symbol=="")
            continue;

         int n=ArraySize(symbols);
         if(ArrayResize(symbols,n+1)!=n+1)
           {
            Print("STB SCANNER UNIVERSE ALLOCATION FAILED symbol=",symbol);
            universeAllocationFailed=true;
            break;
           }
         symbols[n]=symbol;
        }
     }

   if(universeAllocationFailed)
     {
      STB_ScannerAllocationAbort("UNIVERSE_LIST",symbols,wasSelected);
      return;
     }

   g_scannerUniverseCount=ArraySize(symbols);

   if(ArrayResize(wasSelected,g_scannerUniverseCount)!=g_scannerUniverseCount)
     {
      // Symbol selection has not started yet; discard any partial snapshot so
      // the abort handler cannot mistake default-false entries for symbols
      // that were originally unselected and deselect user-selected symbols.
      ArrayFree(wasSelected);
      STB_ScannerAllocationAbort("SYMBOL_SELECTION_SNAPSHOT",symbols,wasSelected);
      return;
     }

   for(int i=0;i<g_scannerUniverseCount;i++)
     {
      wasSelected[i]=(bool)SymbolInfoInteger(symbols[i],SYMBOL_SELECT);
      if(!wasSelected[i])
         SymbolSelect(symbols[i],true);
     }

   bool candidateAllocationFailed=false;
   // Per-cycle counters expose silent discovery-stage exits in the summary.
   int scanDataRejects=0;
   int scanExcludedSymbols=0;
   int scanQualityRejects=0;
   int scanRegimeEvalRejects=0;
   int scanUnstableRegimeRejects=0;
   string scanQualityReasonTally="";
   string scanBuildSetupReasonTally="";
   int scanDirectionGateRejects=0;
   int scanBuildSetupRejects=0;
   int scanSetupAgeRejects=0;
   int scanScoreRejects=0;

   for(int i=0;i<ArraySize(symbols);i++)
     {
      string symbol=symbols[i];

      if(STB_ScannerSymbolExcluded(symbol))
        {
         scanExcludedSymbols++;
         Print("STB SCANNER EXCLUDED symbol=",symbol,
               " input=InpScannerExcludedSymbols");
         continue;
        }

      string reason="";
       if(!STB_ScannerDataEligible(symbol,reason))
         {
          scanDataRejects++;
          Print("STB SCANNER REJECT stage=DATA_ELIGIBILITY symbol=",symbol,
                " reason=",(reason=="" ? "UNSPECIFIED":reason));
          continue;
         }
      g_scannerEligibleCount++;
      STBMarketQuality quality;
       if(!STB_CalcMarketQuality(symbol,quality))
         {
          scanQualityRejects++;
          STB_TallyAdd(scanQualityReasonTally,quality.reason);
          Print("STB SCANNER REJECT stage=MARKET_QUALITY symbol=",symbol,
                " reason=",(quality.reason=="" ? "UNSPECIFIED":quality.reason),
                " score=",DoubleToString(quality.score,1),
                " spreadPips=",DoubleToString(quality.spreadPips,2),
                " activityRatio=",DoubleToString(quality.activityRatio,2),
                " volatilityRatio=",DoubleToString(quality.volatilityRatio,2));
          continue;
         }
      g_scannerQualityCount++;
      STBRegimeState regime;
       if(!STB_EvaluateRegime(symbol,regime))
         {
          scanRegimeEvalRejects++;
          Print("STB SCANNER REJECT stage=REGIME_EVALUATION symbol=",symbol,
                " reason=",(regime.reason=="" ? "UNSPECIFIED":regime.reason));
          continue;
         }
       if(regime.regime==STB_REGIME_UNSTABLE)
         {
          scanUnstableRegimeRejects++;
          Print("STB SCANNER REJECT stage=REGIME_FILTER symbol=",symbol,
                " reason=",(regime.reason=="" ? "UNSTABLE_REGIME":regime.reason),
                " volatilityRatio=",DoubleToString(regime.volatilityRatio,2),
                " efficiency=",DoubleToString(regime.efficiency,2));
          continue;
         }

      g_scannerRegimeCount++;

      for(int direction=1;direction>=-1;direction-=2)
        {
         if(!STB_ScannerDirectionAllowed(symbol,direction))
           {
            scanDirectionGateRejects++;
            continue;
           }

         Setup setup;
         if(!BuildSetup(symbol,direction,setup,true))
           {
            scanBuildSetupRejects++;
            string buildRejectReason=(g_lastBuildRejectReason=="" ?
                                      "UNKNOWN":g_lastBuildRejectReason);
            string buildRejectKey=(direction>0 ? "BUY:":"SELL:")+
                                  buildRejectReason;
            STB_TallyAdd(scanBuildSetupReasonTally,buildRejectKey);
            continue;
           }

         STBCandidate candidate;
         ZeroMemory(candidate);

         candidate.valid=true;
         candidate.symbol=symbol;
         candidate.direction=direction;
         candidate.setupTime=setup.setupTime;
         candidate.setup=setup;
         candidate.strategyScore=MathMax(0.0,MathMin(100.0,setup.score));
         candidate.marketQualityScore=quality.score;
         candidate.regime=regime.regime;
         candidate.regimeStrength=regime.strength;
         candidate.regimeScore=STB_RegimeFitScore(candidate,regime);
         int setupBarShift=iBarShift(symbol,PERIOD_M15,setup.setupTime,true);
         if(setupBarShift<1)
           {
            scanSetupAgeRejects++;
            Print("STB SCANNER REJECT stage=DISCOVERY_AGE symbol=",symbol,
                  " reason=SETUP_BAR_SHIFT_UNAVAILABLE",
                  " setupTime=",(string)setup.setupTime);
            continue;
           }

         // Count actual M15 bars, not elapsed wall-clock seconds. A BOS on
         // the most recently closed bar has age 0; weekends/session gaps do
         // not artificially age a setup.
         candidate.setupAgeBars=(int)MathMax(0,setupBarShift-1);

         double preliminary=0.65*candidate.strategyScore+
                            0.20*candidate.marketQualityScore+
                            0.10*candidate.regimeScore+
                            0.05*55.0;

         candidate.stabilityScore=
            STB_CandidateStability(symbol,direction,setup.setupTime,
                                   preliminary,
                                   candidate.previousScore,
                                   candidate.previousRank);

         candidate.opportunityScore=
            0.65*candidate.strategyScore+
            0.20*candidate.marketQualityScore+
            0.10*candidate.regimeScore+
            0.05*candidate.stabilityScore;

         candidate.opportunityScore=
            MathMax(0.0,MathMin(100.0,candidate.opportunityScore));

         if(candidate.opportunityScore+1e-9<InpScannerMinScore)
           {
            scanScoreRejects++;
            continue;
           }

         int idx=ArraySize(g_scannerCurrent);
         if(ArrayResize(g_scannerCurrent,idx+1)!=idx+1)
           {
            Print("STB SCANNER CANDIDATE ALLOCATION FAILED symbol=",symbol,
                  " direction=",direction);
            candidateAllocationFailed=true;
            break;
           }
         g_scannerCurrent[idx]=candidate;

         if(direction>0)
            g_scannerBuyCount++;
         else
            g_scannerSellCount++;
        }

      if(candidateAllocationFailed)
         break;
     }

   if(candidateAllocationFailed)
     {
      STB_ScannerAllocationAbort("CANDIDATE_LIST",symbols,wasSelected);
      return;
     }

   g_scannerCandidateCount=ArraySize(g_scannerCurrent);
   STB_SortCandidates(g_scannerCurrent);

   int watchLimit=MathMax(1,MathMin(InpScannerMaxWatchlist,50));
   int watchCount=MathMin(watchLimit,ArraySize(g_scannerCurrent));

   if(ArrayResize(g_scannerWatchlist,watchCount)!=watchCount)
     {
      STB_ScannerAllocationAbort("INITIAL_WATCHLIST",symbols,wasSelected);
      return;
     }

   for(int i=0;i<watchCount;i++)
      g_scannerWatchlist[i]=g_scannerCurrent[i];

   int validWatch=0;

   for(int i=0;i<watchCount;i++)
     {
      STBCandidate c=g_scannerWatchlist[i];

      Setup validated;
      if(!STB_FinalCandidateRevalidation(c,validated))
        {
         Print("STB SCANNER REJECT stage=FINAL_REVALIDATION symbol=",c.symbol,
               " direction=",(c.direction>0 ? "BUY":"SELL"),
               " reason=",(c.rejectReason=="" ? "UNSPECIFIED":c.rejectReason));
         continue;
        }

      c.setup=validated;

      STBMarketQuality q;
       if(!STB_CalcMarketQuality(c.symbol,q))
         {
          Print("STB SCANNER REJECT stage=WATCHLIST_QUALITY symbol=",c.symbol,
                " reason=",(q.reason=="" ? "UNSPECIFIED":q.reason));
          continue;
         }
       c.marketQualityScore=q.score;
       STBRegimeState rr;
       if(!STB_EvaluateRegime(c.symbol,rr))
         {
          Print("STB SCANNER REJECT stage=WATCHLIST_REGIME symbol=",c.symbol,
                " reason=",(rr.reason=="" ? "UNSPECIFIED":rr.reason));
          continue;
         }
       if(rr.regime==STB_REGIME_UNSTABLE)
         {
          Print("STB SCANNER REJECT stage=WATCHLIST_REGIME symbol=",c.symbol,
                " reason=",(rr.reason=="" ? "UNSTABLE_REGIME":rr.reason));
          continue;
         }

      c.regime=rr.regime;
      c.regimeStrength=rr.strength;
      c.regimeScore=STB_RegimeFitScore(c,rr);

      int setupBarShift=iBarShift(c.symbol,PERIOD_M15,c.setup.setupTime,true);
      if(setupBarShift<1)
        {
         Print("STB SCANNER REJECT stage=WATCHLIST_AGE symbol=",c.symbol,
               " reason=SETUP_BAR_SHIFT_UNAVAILABLE",
               " setupTime=",(string)c.setup.setupTime);
         continue;
        }

      // Use the same bar-based age contract during final watchlist ranking.
      c.setupAgeBars=(int)MathMax(0,setupBarShift-1);

      // Use the same effective age limit as discovery and final handoff.
      // Adaptive profiles may override InpMaxSetupAgeBars; using the raw input
      // here could reject a valid candidate early or admit one only to reject
      // it again during final revalidation.
      int watchlistMaxAge=STB_EffectiveMaxSetupAgeBars();
      if(watchlistMaxAge>0 && c.setupAgeBars>watchlistMaxAge)
        {
         Print("STB SCANNER REJECT stage=WATCHLIST_AGE symbol=",c.symbol,
               " direction=",(c.direction>0 ? "BUY":"SELL"),
               " ageBars=",IntegerToString(c.setupAgeBars),
               " maxAgeBars=",IntegerToString(watchlistMaxAge));
         continue;
        }

      // Recompute stability from the refreshed watchlist inputs. The
      // stability component compares the current preliminary score with the
      // previous scan's score for this exact symbol/direction/setup identity.
      // Carrying the discovery-stage value here would mix stale and refreshed
      // market/regime components in the final ranking.
      double refreshedStrategyScore=
         MathMax(0.0,MathMin(100.0,c.setup.score));
      double refreshedPreliminary=
         0.65*refreshedStrategyScore+
         0.20*c.marketQualityScore+
         0.10*c.regimeScore+
         0.05*55.0;

      c.stabilityScore=
         STB_CandidateStability(c.symbol,c.direction,c.setup.setupTime,
                                refreshedPreliminary,
                                c.previousScore,c.previousRank);

      c.strategyScore=refreshedStrategyScore;

      c.opportunityScore=
         0.65*c.strategyScore+
         0.20*c.marketQualityScore+
         0.10*c.regimeScore+
         0.05*c.stabilityScore;

      c.opportunityScore=
         MathMax(0.0,MathMin(100.0,c.opportunityScore));

      if(c.opportunityScore+1e-9<InpScannerMinScore)
        {
         Print("STB SCANNER REJECT stage=WATCHLIST_SCORE symbol=",c.symbol,
               " direction=",(c.direction>0 ? "BUY":"SELL"),
               " score=",DoubleToString(c.opportunityScore,1),
               " minScore=",DoubleToString(InpScannerMinScore,1));
         continue;
        }

      g_scannerWatchlist[validWatch]=c;
      validWatch++;
     }

   if(ArrayResize(g_scannerWatchlist,validWatch)!=validWatch)
     {
      STB_ScannerAllocationAbort("FINAL_WATCHLIST",symbols,wasSelected);
      return;
     }
   STB_SortCandidates(g_scannerWatchlist);
   g_scannerWatchlistCount=ArraySize(g_scannerWatchlist);

   int topCount=MathMin(MathMax(1,InpScannerTopN),10);
   topCount=MathMin(topCount,g_scannerWatchlistCount);

   if(ArrayResize(g_scannerTop10,topCount)!=topCount)
     {
      STB_ScannerAllocationAbort("EXECUTION_TOPN",symbols,wasSelected);
      return;
     }

   for(int i=0;i<topCount;i++)
      g_scannerTop10[i]=g_scannerWatchlist[i];

   STB_SortCandidates(g_scannerTop10);
   g_scannerTop10Count=ArraySize(g_scannerTop10);

   // Confidence is based on the complete revalidated/reranked watchlist, not
   // the truncated execution Top-N. In particular, TopN=1 must not bypass
   // the configured runner-up gap when a second valid candidate exists.
   if(g_scannerWatchlistCount<=0)
      g_scannerConfidence="NO_CLEAR_WINNER";
   else
     {
      double topScore=g_scannerWatchlist[0].opportunityScore;
      bool clear=(topScore>=InpScannerMinScore);

      if(clear && g_scannerWatchlistCount>1)
         clear=(topScore-g_scannerWatchlist[1].opportunityScore)>=InpScannerMinTopGap;

      g_scannerConfidence=(clear ? "CLEAR":"WEAK");
     }

   // Dashboard "ready" counts must reflect the final revalidated watchlist,
   // not discovery-stage candidates that may have become stale or failed a
   // final quality/regime/age gate.
   int finalBuyReady=0;
   int finalSellReady=0;
   for(int i=0;i<g_scannerWatchlistCount;i++)
     {
      if(g_scannerWatchlist[i].direction>0)
         finalBuyReady++;
      else if(g_scannerWatchlist[i].direction<0)
         finalSellReady++;
     }

   g_panelScanSymbols=g_scannerUniverseCount;
   g_panelScanTradable=g_scannerEligibleCount;
   g_panelScanBuyReady=finalBuyReady;
   g_panelScanSellReady=finalSellReady;
   g_panelScanPlacements=0;
   g_panelLastScanTime=TimeCurrent();

   g_panelChartBuyReady=false;
   g_panelChartSellReady=false;
   g_panelChartBuyScore=0.0;
   g_panelChartSellScore=0.0;

   for(int i=0;i<g_scannerWatchlistCount;i++)
     {
      if(g_scannerWatchlist[i].symbol!=_Symbol)
         continue;

      if(g_scannerWatchlist[i].direction>0)
        {
         g_panelChartBuyReady=true;
         g_panelChartBuyScore=g_scannerWatchlist[i].opportunityScore;
        }
      else
        {
         g_panelChartSellReady=true;
         g_panelChartSellScore=g_scannerWatchlist[i].opportunityScore;
        }
     }

   for(int i=0;i<ArraySize(symbols) && i<ArraySize(wasSelected);i++)
      if(!wasSelected[i] && !STB_HasSymbolExposureForManagement(symbols[i]))
         SymbolSelect(symbols[i],false);

   if(cycleBar>0)

      g_scannerLastCycleBar=cycleBar;

   g_scannerLastRun=TimeCurrent();
   g_scannerCycle++;
   g_scannerStatus="PASS";

   ulong elapsed=(ulong)GetTickCount()-(ulong)started;

   Print("STB SCANNER SUMMARY",
         " universe=",IntegerToString(g_scannerUniverseCount),
         " excluded=",IntegerToString(scanExcludedSymbols),
         " eligible=",IntegerToString(g_scannerEligibleCount),
         " quality=",IntegerToString(g_scannerQualityCount),
         " regime=",IntegerToString(g_scannerRegimeCount),
         " buyCandidates=",IntegerToString(g_scannerBuyCount),
         " sellCandidates=",IntegerToString(g_scannerSellCount),
         " candidates=",IntegerToString(g_scannerCandidateCount),
         " directionGateRejects=",IntegerToString(scanDirectionGateRejects),
         " buildSetupRejects=",IntegerToString(scanBuildSetupRejects),
         " buildSetupReasons=",STB_TallyReport(scanBuildSetupReasonTally),
         " setupAgeRejects=",IntegerToString(scanSetupAgeRejects),
         " scoreRejects=",IntegerToString(scanScoreRejects),
         " minScore=",DoubleToString(InpScannerMinScore,1),
         " watchlist=",IntegerToString(g_scannerWatchlistCount),
         " top10=",IntegerToString(g_scannerTop10Count),
         " confidence=",g_scannerConfidence,
         " durationMs=",IntegerToString((int)elapsed));

    Print("STB SCANNER DISCOVERY REJECT BREAKDOWN",
          " dataRejects=",IntegerToString(scanDataRejects),
          " qualityRejects=",IntegerToString(scanQualityRejects),
          " qualityReasons=",STB_TallyReport(scanQualityReasonTally),
          " regimeEvalRejects=",IntegerToString(scanRegimeEvalRejects),
          " unstableRegimeRejects=",IntegerToString(scanUnstableRegimeRejects),
          " directionGateRejects=",IntegerToString(scanDirectionGateRejects),
          " buildSetupRejects=",IntegerToString(scanBuildSetupRejects),
          " buildSetupReasons=",STB_TallyReport(scanBuildSetupReasonTally),
          " setupAgeRejects=",IntegerToString(scanSetupAgeRejects),
          " scoreRejects=",IntegerToString(scanScoreRejects),
          " check=discovery_stage_only; universe=excluded+dataRejects+eligible;",
          " eligible=qualityRejects+quality; quality=regimeEval+unstable+regime",
          " countsPerDirection=direction/build/age/score");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//==================================================================
// LEGACY DASHBOARD CLEANUP
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_DashDeleteAll()
  {
   int total=ObjectsTotal(0,-1,-1);

   for(int i=total-1;i>=0;i--)
     {
      string name=ObjectName(0,i,-1,-1);

      if(StringFind(name,g_prefix+"DASH_")==0)
         ObjectDelete(0,name);
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//--- P19 lightweight TRADING-SIGNAL markers (managed exposure levels) ------
// Marker taxonomy in FINAL:
//   TRADING SIGNAL : entry / SL / TP lines for the chart symbol's MANAGED
//                    exposures -> restored here (this function).
//   DECORATIVE     : oscillator panel -> not rendered.
//   DEBUG          : none active.
//   LEGACY         : the old professional visual engine has 0 callers.
// Only this EA's own objects (prefix TM_) are touched. This is a handful of
// HLINEs, refreshed on the panel cadence (timer / new bar / button) and is
// NEVER invoked from CHARTEVENT_CHART_CHANGE. No forced ChartRedraw.
void STB_DrawTradingLevels()
  {
   string pref=g_prefix+"TM_";

   // Remove only previously drawn STB trading markers.
   for(int i=ObjectsTotal(0,-1,-1)-1;i>=0;i--)
     {
      string name=ObjectName(0,i,-1,-1);
      if(StringFind(name,pref)==0)
         ObjectDelete(0,name);
     }

   string sym=_Symbol;

   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);

      if(ticket==0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL)!=sym || !IsManagedPosition(ticket))
         continue;

      string tag=pref+"POS_"+(string)ticket+"_";
      DrawHLine(tag+"E",PositionGetDouble(POSITION_PRICE_OPEN),clrGray);
      DrawHLine(tag+"S",PositionGetDouble(POSITION_SL),clrSilver);
      DrawHLine(tag+"T",PositionGetDouble(POSITION_TP),clrDeepSkyBlue);
     }

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);

      if(ticket==0 || !OrderSelect(ticket))
         continue;

      if(OrderGetString(ORDER_SYMBOL)!=sym || !IsManagedOrder(ticket))
         continue;

      string tag=pref+"PND_"+(string)ticket+"_";
      DrawHLine(tag+"E",OrderGetDouble(ORDER_PRICE_OPEN),clrGray);
      DrawHLine(tag+"S",OrderGetDouble(ORDER_SL),clrSilver);
      DrawHLine(tag+"T",OrderGetDouble(ORDER_TP),clrDeepSkyBlue);
     }
  }

void UpdatePanel()
  {
// Keep the chart clean by removing any stale dashboard objects left by older builds.
   STB_DashDeleteAll();
   STB_DrawTradingLevels();
  }

//==================================================================
// BUTTONS
//==================================================================


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateButton(const string name,
                  const string text,
                  const int x,
                  const int y,
                  const int width,
                  const int height,
                  const color bgColor)
  {
   ObjectDelete(0,name);
   ResetLastError();

   if(!ObjectCreate(0,name,OBJ_BUTTON,0,0,0))
     {
      Print("STB UI BUTTON CREATE FAILED name=",name,
            " err=",GetLastError());
      return;
     }

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_LOWER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,text);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bgColor);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrDimGray);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_STATE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
   // Keep actionable buttons above the non-interactive status panel.
   ObjectSetInteger(0,name,OBJPROP_ZORDER,200000);
  }

// Repair stale control objects without treating drag-selectability as click readiness.
// OBJPROP_SELECTABLE controls object selection/movement; button clicks are routed by OnChartEvent.
bool STB_ControlButtonNeedsRepair(const string name)
  {
   if(ObjectFind(0,name)<0)
      return true;

   long type=ObjectGetInteger(0,name,OBJPROP_TYPE);
   if(type!=(long)OBJ_BUTTON)
     {
      Print("STB UI CONTROL REPAIR name=",name,
            " reason=WRONG_OBJECT_TYPE",
            " type=",IntegerToString((int)type));
      ObjectDelete(0,name);
      return true;
     }

   long width=ObjectGetInteger(0,name,OBJPROP_XSIZE);
   long height=ObjectGetInteger(0,name,OBJPROP_YSIZE);
   if(width<=0 || height<=0)
     {
      Print("STB UI CONTROL REPAIR name=",name,
            " reason=UNRECOVERABLE_GEOMETRY",
            " width=",IntegerToString((int)width),
            " height=",IntegerToString((int)height));
      ObjectDelete(0,name);
      return true;
     }

   ResetLastError();
   bool normalized=true;
   if(!ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false))
      normalized=false;
   if(!ObjectSetInteger(0,name,OBJPROP_SELECTED,false))
      normalized=false;
   if(!ObjectSetInteger(0,name,OBJPROP_STATE,false))
      normalized=false;
   if(!ObjectSetInteger(0,name,OBJPROP_HIDDEN,false))
      normalized=false;
   if(!normalized)
      Print("STB UI CONTROL NORMALIZE FAILED name=",name,
            " err=",GetLastError());

   return false;
  }

void STB_LogControlButtonHealth()
  {
   string names[8]=
     {
      g_prefix+"BUY_STOP",g_prefix+"SELL_STOP",g_prefix+"AUTO",
      g_prefix+"SAVE20",g_prefix+"HEDGE",g_prefix+"SELL_LIMIT",
      g_prefix+"BUY_LIMIT",g_prefix+"PEND_TRAIL"
     };

   int ready=0;
   for(int i=0;i<ArraySize(names);i++)
     {
      string name=names[i];
      if(ObjectFind(0,name)<0)
        {
         Print("STB UI BUTTON HEALTH name=",name," state=MISSING");
         continue;
        }

      long type=ObjectGetInteger(0,name,OBJPROP_TYPE);
      long x=ObjectGetInteger(0,name,OBJPROP_XDISTANCE);
      long y=ObjectGetInteger(0,name,OBJPROP_YDISTANCE);
      long width=ObjectGetInteger(0,name,OBJPROP_XSIZE);
      long height=ObjectGetInteger(0,name,OBJPROP_YSIZE);
      long zorder=ObjectGetInteger(0,name,OBJPROP_ZORDER);
      bool selectable=(ObjectGetInteger(0,name,OBJPROP_SELECTABLE)!=0);
      bool selected=(ObjectGetInteger(0,name,OBJPROP_SELECTED)!=0);
      bool pressed=(ObjectGetInteger(0,name,OBJPROP_STATE)!=0);
      bool hidden=(ObjectGetInteger(0,name,OBJPROP_HIDDEN)!=0);
      bool valid=(type==(long)OBJ_BUTTON && !selected && !pressed && !hidden &&
                  width>0 && height>0);
      if(valid)
         ready++;

      Print("STB UI BUTTON HEALTH name=",name,
            " state=",valid ? "READY":"INVALID",
            " type=",IntegerToString((int)type),
            " x=",IntegerToString((int)x),
            " y=",IntegerToString((int)y),
            " width=",IntegerToString((int)width),
            " height=",IntegerToString((int)height),
            " zorder=",IntegerToString((int)zorder),
            " selectable=",selectable ? "YES":"NO",
            " selected=",selected ? "YES":"NO",
            " pressed=",pressed ? "YES":"NO",
            " hidden=",hidden ? "YES":"NO");
     }

   Print("STB UI BUTTONS SUMMARY ready=",IntegerToString(ready),
         " expected=",IntegerToString(ArraySize(names)),
         " chart=",(string)ChartID());
  }

void STB_EnsureControlButtons()
  {
   if(STB_ControlButtonNeedsRepair(g_prefix+"BUY_STOP"))
      CreateButton(g_prefix+"BUY_STOP","BUY STOP",7,28,82,19,clrSeaGreen);
   if(STB_ControlButtonNeedsRepair(g_prefix+"SELL_STOP"))
      CreateButton(g_prefix+"SELL_STOP","SELL STOP",94,28,82,19,clrTomato);
   if(STB_ControlButtonNeedsRepair(g_prefix+"AUTO"))
      CreateButton(g_prefix+"AUTO","AUTO",181,28,82,19,clrFireBrick);
   if(STB_ControlButtonNeedsRepair(g_prefix+"SAVE20"))
      CreateButton(g_prefix+"SAVE20","SAVE +20",268,28,82,19,clrRoyalBlue);
   if(STB_ControlButtonNeedsRepair(g_prefix+"HEDGE"))
      CreateButton(g_prefix+"HEDGE","HEDGE",355,28,82,19,clrDarkOrange);
   if(STB_ControlButtonNeedsRepair(g_prefix+"SELL_LIMIT"))
      CreateButton(g_prefix+"SELL_LIMIT","SELL LIMIT",442,28,82,19,clrTomato);
   if(STB_ControlButtonNeedsRepair(g_prefix+"BUY_LIMIT"))
      CreateButton(g_prefix+"BUY_LIMIT","BUY LIMIT",529,28,82,19,clrSeaGreen);
   if(STB_ControlButtonNeedsRepair(g_prefix+"PEND_TRAIL"))
      CreateButton(g_prefix+"PEND_TRAIL","PEND TRAIL",616,28,82,19,clrSlateBlue);
  }

void STB_RenderControlStatus()
  {
   string name=g_prefix+"CONTROL_STATUS";
   if(ObjectFind(0,name)<0)
     {
      ResetLastError();
      if(!ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0))
        {
         Print("STB UI STATUS CREATE FAILED err=",GetLastError());
         return;
        }
     }
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,8);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,22);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,570);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,22);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,clrBlack);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrYellow);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrDimGray);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
   // Status must never win click priority over the trading-control buttons.
   ObjectSetInteger(0,name,OBJPROP_ZORDER,1);
   ObjectSetString(0,name,OBJPROP_TEXT,g_controlLastAction);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,
                   "Latest SmartTradingBot control result. See Experts log for details.");
  }

void STB_SetControlStatus(const string message)
  {
   g_controlLastAction=message;
   Print("STB UI STATUS: ",message);
   STB_RenderControlStatus();
   ChartRedraw(0);
  }

string STB_ControlRejectSuffix()
  {
   if(g_stbDailyLossThresholdReached)
      return " - DAILY_LOSS_LIMIT_ACTIVE; risk guard blocked this action";
   return " - see Experts log for the exact rejection reason";
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountManagedPendingOrders()
  {
   int count=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);

      if(ticket==0 || !OrderSelect(ticket))
         continue;

      if(!IsManagedOrder(ticket))
         continue;

      ENUM_ORDER_TYPE type=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      if(STB_IsManagedPendingType((long)type))
         count++;
     }

   return count;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int TrailAllPendingOrdersNow()
  {
   STB_BeginCycle(); // Blueprint 26: user PEND_TRAIL command gets its own decision cycle
   int before=CountManagedPendingOrders();
   int moved=STB_PendingTrailProcess(true); // count only confirmed broker geometry changes
   Print("STB PEND_TRAIL COMMAND complete managedPending=",before,
         " confirmedMoved=",moved,
         " remainingManagedPending=",CountManagedPendingOrders());
   if(before>0 && moved==0)
      Print("STB PEND_TRAIL DIAGNOSTIC: no broker-confirmed geometry change; inspect PENDING_TRAIL_* and STB PENDING MODIFY logs for the per-ticket rejection reason.");
   return moved;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STB_UpdateControlBarLayout()
  {
// EA control keys.
// bottom-left anchored vertical stack.
// Order from bottom to top.
   const int left=7;
   const int bottom=28;
   const int width=82;
   const int height=19;
   const int gap=2;

   string names[8]=
     {
      g_prefix+"SAVE20",
      g_prefix+"SELL_STOP",
      g_prefix+"BUY_STOP",
      g_prefix+"PEND_TRAIL",
      g_prefix+"HEDGE",
      g_prefix+"SELL_LIMIT",
      g_prefix+"BUY_LIMIT",
      g_prefix+"AUTO"
     };

   for(int i=0;i<8;i++)
     {
      if(ObjectFind(0,names[i])<0)
         continue;

      ObjectSetInteger(0,names[i],OBJPROP_CORNER,CORNER_LEFT_LOWER);
      ObjectSetInteger(0,names[i],OBJPROP_XDISTANCE,left);
      ObjectSetInteger(0,names[i],OBJPROP_YDISTANCE,bottom+i*(height+gap));
      ObjectSetInteger(0,names[i],OBJPROP_XSIZE,width);
      ObjectSetInteger(0,names[i],OBJPROP_YSIZE,height);
      ObjectSetInteger(0,names[i],OBJPROP_FONTSIZE,7);
      ObjectSetInteger(0,names[i],OBJPROP_ZORDER,100000);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateButtons()
  {
   STB_EnsureControlButtons();
   STB_UpdateControlBarLayout();

   string buyName=g_prefix+"BUY_STOP";
   string sellName=g_prefix+"SELL_STOP";
   string autoName=g_prefix+"AUTO";
   string saveName=g_prefix+"SAVE20";
   string hedgeName=g_prefix+"HEDGE";
   string trailName=g_prefix+"PEND_TRAIL";

   ObjectSetString(0,buyName,OBJPROP_TEXT,"BUY STOP");
   ObjectSetInteger(0,buyName,OBJPROP_BGCOLOR,clrSeaGreen);
   ObjectSetInteger(0,buyName,OBJPROP_COLOR,clrWhite);

   ObjectSetString(0,sellName,OBJPROP_TEXT,"SELL STOP");
   ObjectSetInteger(0,sellName,OBJPROP_BGCOLOR,clrTomato);
   ObjectSetInteger(0,sellName,OBJPROP_COLOR,clrWhite);

   ObjectSetString(0,autoName,OBJPROP_TEXT,g_autoTrading ? "AUTO  ON":"AUTO  OFF");
   ObjectSetInteger(0,autoName,OBJPROP_BGCOLOR,
                    g_autoTrading ? clrSeaGreen : clrFireBrick);
   ObjectSetInteger(0,autoName,OBJPROP_COLOR,clrWhite);

   ObjectSetString(0,saveName,OBJPROP_TEXT,"SAVE +20");
   ObjectSetInteger(0,saveName,OBJPROP_BGCOLOR,clrRoyalBlue);
   ObjectSetInteger(0,saveName,OBJPROP_COLOR,clrWhite);

   ObjectSetString(0,hedgeName,OBJPROP_TEXT,"HEDGE");
   ObjectSetInteger(0,hedgeName,OBJPROP_BGCOLOR,clrDarkOrange);
   ObjectSetInteger(0,hedgeName,OBJPROP_COLOR,clrWhite);

   ObjectSetString(0,trailName,OBJPROP_TEXT,
                   "PEND TRAIL "+
                   IntegerToString(CountManagedPendingOrders()));
   ObjectSetInteger(0,trailName,OBJPROP_BGCOLOR,clrSlateBlue);
   ObjectSetInteger(0,trailName,OBJPROP_COLOR,clrWhite);
   STB_RenderControlStatus();
   ChartRedraw(0);
  }

//==================================================================
// VISUAL MARKERS
//==================================================================


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteVisuals()
  {
   int total=ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;i--)
     {
      string name=ObjectName(0,i,-1,-1);
      if(StringFind(name,g_prefix+"VIS_")==0 ||
         StringFind(name,g_prefix+"SIG_")==0 ||
         StringFind(name,g_prefix+"TM_")==0)
         ObjectDelete(0,name);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawHLine(const string name,const double price,const color clr)
  {
   ObjectDelete(0,name);
   if(price<=0.0)
      return;

   if(!ObjectCreate(0,name,OBJ_HLINE,0,0,price))
      return;

   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//==================================================================
// BAR DETECTION
//==================================================================


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool NewM15Bar()
  {
   datetime current=iTime(_Symbol,PERIOD_M15,0);

   if(current==0)
      return false;

   if(current!=g_lastM15Bar)
     {
      g_lastM15Bar=current;
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//==================================================================
// INIT
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ValidateInputs()
  {
   if(InpMagic==0)
      return false;
   if(StringLen(InpScannerSymbols)>1024)
      return false;
   if(InpScanSeconds<1 || InpScannerMaxQuoteAgeSec<1 ||
      InpScannerMaxQuoteAgeSec>3600)
      return false;
   if(InpAdaptiveMinScore<0.0 ||
      InpAdaptiveMaxScore>100.0 ||
      InpAdaptiveMinScore>InpAdaptiveMaxScore ||
      InpAdaptiveBaseScore<InpAdaptiveMinScore ||
      InpAdaptiveBaseScore>InpAdaptiveMaxScore ||
      InpAdaptiveStep<0.0 ||
      InpAdaptiveWeakWinRate<0.0 ||
      InpAdaptiveWeakWinRate>1.0 ||
      InpAdaptiveStrongWinRate<0.0 ||
      InpAdaptiveStrongWinRate>1.0 ||
      InpAdaptiveWeakWinRate>=InpAdaptiveStrongWinRate ||
      InpAdaptiveMinSamples<1 ||
      InpAdaptiveHalfLifeDays<=0.0 ||
      InpAdaptiveWarmupPerProfile<0 ||
      InpAdaptiveUCBExploration<0.0)
      return false;
   if(InpLookbackH4<30 || InpLookbackM15<30 ||
      InpStructureWindowBars<5)
      return false;
   if(InpSwingLeft<1 || InpSwingRight<1)
      return false;
   if(InpBaseLots<=0.0 ||
      InpTrendLotMultiplier<0.0 ||
      InpUniversalLotMultiplier<0.0 ||
      InpEntryBufferPips<0.0 ||
      InpSLBufferPips<0.0 ||
      InpInitialSLBufferPips<0.0 || InpMaxInitialSLPips<0.0 ||
      InpMinimumRR<=0.0 ||
      InpMaxPendingBars<0)
      return false;
   if(InpPatternWindowBars<1 ||
      InpHTFLookbackBars<60 || InpHTFLookbackBars>1000 ||
      InpHTFMaxZoneAgeBars<1 ||
      InpHTFMaxZoneAgeBars>InpHTFLookbackBars ||
      PeriodSeconds(InpHTFPatternTF)<PeriodSeconds(PERIOD_H1) ||
      InpHTFZoneMaxGapATR<0.0 || InpHTFZoneMaxGapATR>3.0 ||
      InpHTFMinFVGWidthATR<0.0 || InpHTFMinFVGWidthATR>1.0)
      return false;
   if(InpManualSaveStepPips<0.0)
      return false;
   if(InpTrendlineTolerancePips<0.0 ||
       InpTrailStartPips<0.0 ||
       InpLiveTrailDistancePips<0.0 ||
       InpTrailStepPips<0.0 ||
       InpStructuralTrailStartATR<=0.0 ||
       InpStructuralTrailStartATR>10.0 ||
       InpStructuralTrailBufferATR<0.0 ||
       InpStructuralTrailBufferATR>2.0)
      return false;
   if(InpMaxSpreadPips<0.0 ||
      InpMaxRelativeSpreadPct<0.0 ||
      InpMaxRelativeSpreadPct>100.0 ||
      InpSetupCooldownMinutes<0 ||
      InpMaxSetupAgeBars<0 ||
      InpPendingTrailMaxRiskExpansion<0.0 ||
      InpPipPointsOverride<0.0 ||
      InpRiskPercent<0.0 ||
      InpMaxRiskVolume<0.0 ||
      InpMaxDailyLossPercent<0.0 || InpMaxDailyLossPercent>10.0)
      return false;

   // Risk-sizing mode must not silently become a no-trade mode because a
   // stale .set file supplies zero risk.
   if(InpUseRiskSizing && (InpRiskPercent<=0.0 || InpRiskPercent>1.0))
      return false;

   // Reject NaN/Infinity for every floating-point input before range checks.
   if(
      !MathIsValidNumber(InpScannerMinQuality) ||
      !MathIsValidNumber(InpScannerMinScore) ||
      !MathIsValidNumber(InpScannerMinTopGap) ||
      !MathIsValidNumber(InpManualPendingGapPips) ||
      !MathIsValidNumber(InpRSIBuyLevel) ||
      !MathIsValidNumber(InpRSISellLevel) ||
      !MathIsValidNumber(InpCCIBuyLevel) ||
      !MathIsValidNumber(InpCCISellLevel) ||
      !MathIsValidNumber(InpRSIWeight) ||
      !MathIsValidNumber(InpCCIWeight) ||
      !MathIsValidNumber(InpMaxSpreadPips) ||
      !MathIsValidNumber(InpMaxRelativeSpreadPct) ||
      !MathIsValidNumber(InpAdaptiveBaseScore) ||
      !MathIsValidNumber(InpAdaptiveMinScore) ||
      !MathIsValidNumber(InpAdaptiveMaxScore) ||
      !MathIsValidNumber(InpAdaptiveStep) ||
      !MathIsValidNumber(InpAdaptiveWeakWinRate) ||
      !MathIsValidNumber(InpAdaptiveStrongWinRate) ||
      !MathIsValidNumber(InpAdaptiveHalfLifeDays) ||
      !MathIsValidNumber(InpAdaptiveUCBExploration) ||
      !MathIsValidNumber(InpEntryBufferPips) ||
      !MathIsValidNumber(InpPendingTrailMaxRiskExpansion) ||
      !MathIsValidNumber(InpPipPointsOverride) ||
      !MathIsValidNumber(InpSLBufferPips) ||
      !MathIsValidNumber(InpInitialSLBufferPips) ||
      !MathIsValidNumber(InpMaxInitialSLPips) ||
      !MathIsValidNumber(InpMinimumRR) ||
      !MathIsValidNumber(InpManualSaveStepPips) ||
      !MathIsValidNumber(InpTrendlineTolerancePips) ||
      !MathIsValidNumber(InpHTFZoneMaxGapATR) ||
      !MathIsValidNumber(InpHTFMinFVGWidthATR) ||
      !MathIsValidNumber(InpTrailStartPips) ||
      !MathIsValidNumber(InpLiveTrailDistancePips) ||
      !MathIsValidNumber(InpTrailStepPips) ||
      !MathIsValidNumber(InpStructuralTrailStartATR) ||
      !MathIsValidNumber(InpStructuralTrailBufferATR) ||
      !MathIsValidNumber(InpBreakEvenTriggerATR) ||
      !MathIsValidNumber(InpBreakEvenMinOffsetPips) ||
      !MathIsValidNumber(InpBreakEvenCostMultiplier) ||
      !MathIsValidNumber(InpAdaptiveLockTriggerATR) ||
      !MathIsValidNumber(InpAdaptiveLockATR) ||
      !MathIsValidNumber(InpAdaptiveTrailStartATR) ||
      !MathIsValidNumber(InpAdaptiveTrailDistanceATR) ||
      !MathIsValidNumber(InpAdaptiveTrailStepATR) ||
      !MathIsValidNumber(InpRiskPercent) ||
      !MathIsValidNumber(InpMaxRiskVolume) ||
      !MathIsValidNumber(InpMaxDailyLossPercent) ||
      !MathIsValidNumber(InpBaseLots) ||
      !MathIsValidNumber(InpTrendLotMultiplier) ||
      !MathIsValidNumber(InpUniversalLotMultiplier)
     )
      return false;

   if(InpBreakEvenTriggerATR<0.1 || InpBreakEvenTriggerATR>3.0 ||
      InpBreakEvenMinOffsetPips<0.0 || InpBreakEvenMinOffsetPips>1000.0 ||
      InpBreakEvenCostMultiplier<1.0 || InpBreakEvenCostMultiplier>5.0 ||
      InpAdaptiveLockTriggerATR<0.1 || InpAdaptiveLockTriggerATR>5.0 ||
      InpAdaptiveLockATR<0.0 || InpAdaptiveLockATR>3.0 ||
      InpAdaptiveTrailStartATR<0.1 || InpAdaptiveTrailStartATR>5.0 ||
      InpAdaptiveTrailDistanceATR<0.1 || InpAdaptiveTrailDistanceATR>5.0 ||
      InpAdaptiveTrailStepATR<0.01 || InpAdaptiveTrailStepATR>2.0)
      return false;

   if(InpScannerMinQuality<0.0 ||
      InpScannerMinQuality>100.0 ||
      InpScannerMinScore<0.0 ||
      InpScannerMinScore>100.0 ||
      InpScannerMinTopGap<0.0 ||
      InpScannerMaxWatchlist<1 ||
      InpScannerTopN<1 ||
      InpScannerTopN>10 ||
      InpScannerMaxQuoteAgeSec<30 ||
      InpManualPendingGapPips<=0.0)
      return false;

   if(InpRSIPeriod<2 ||
      InpCCIPeriod<2 ||
      InpRSIBuyLevel<=50.0 ||
      InpRSIBuyLevel>100.0 ||
      InpRSISellLevel<0.0 ||
      InpRSISellLevel>=50.0 ||
      InpCCIBuyLevel<=0.0 ||
      InpCCISellLevel>=0.0 ||
      InpRSIWeight<0.0 ||
      InpCCIWeight<0.0 ||
      InpRSIWeight+InpCCIWeight>30.0)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


int OnInit()
  {
   if(!STB_InitRunNamespace())
     {
      Print("STB INIT FAILED: risk namespace unavailable; refusing initialization.");
      return INIT_FAILED;
     }

   g_autoStateName=ScopedStateName("AUTO");

   if(!ValidateInputs())
     {
      Print("STB INIT FAILED: invalid input configuration.");
      return INIT_PARAMETERS_INCORRECT;
     }

   // Mouse-move events let the UI release a selected line that would otherwise
   // capture a drag gesture over a button in MT5.
   g_stbOriginalMouseMoveEvents=(ChartGetInteger(0,CHART_EVENT_MOUSE_MOVE)!=0);
   g_stbMouseMoveEventsCaptured=true;
   if(!ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,true))
      Print("STB UI WARNING: unable to enable mouse-move event fallback err=",GetLastError());

   // Establish the initial daily equity baseline; it rolls over on server-date changes.
   if(STB_DailyLossLimitHit())
      Print("STB INIT WARNING: daily risk guard initialized in fail-closed state.");

// Tester AUTO override is opt-in through InpTesterForceAutoTrading.
   // When it is OFF, honor InpAutoTrading just as the normal terminal does.
   // Trade permission, quote validation, exposure checks, and daily-risk guards
   // remain unchanged; the on-chart AUTO button remains available in both modes.
   if(MQLInfoInteger(MQL_TESTER) && InpTesterForceAutoTrading)
     {
      g_autoTrading=true;
      ResetLastError();
      if(GlobalVariableSet(g_autoStateName,1.0)<=0)
         Print("STB INIT WARNING: unable to persist forced tester AUTO state err=",GetLastError());
      else
         GlobalVariablesFlush();
      STB_ManualOverrideClearAll();
      if(!InpAutoTrading)
         Print("STB INIT AUTO OVERRIDE: forced ON because InpTesterForceAutoTrading=ON despite autoInput=OFF");
     }
   else if(!InpAutoTrading)
     {
      // Respect the explicit AUTO=OFF setting in both tester and terminal runtime.
      // The AUTO button remains available for deliberate manual activation.
      g_autoTrading=false;
      ResetLastError();
      if(GlobalVariableSet(g_autoStateName,0.0)<=0)
         Print("STB INIT WARNING: unable to persist AUTO=OFF state err=",GetLastError());
      else
         GlobalVariablesFlush();
      Print("STB INIT AUTO POLICY: AUTO starts OFF because InpAutoTrading=OFF.");
     }
   else
     {
      g_autoTrading=true;
      ResetLastError();
      if(GlobalVariableSet(g_autoStateName,1.0)<=0)
         Print("STB INIT WARNING: unable to persist explicit AUTO state err=",GetLastError());
      else
         GlobalVariablesFlush();
      if(MQLInfoInteger(MQL_TESTER))
         STB_ManualOverrideClearAll();
     }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetAsyncMode(false);

   if(!SymbolSelect(_Symbol,true))
      Print("STB INIT: current chart SymbolSelect failed symbol=",_Symbol,
            " err=",GetLastError());

   Print("STB TRADE ENV terminal=",
         TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) ? "ON":"OFF",
         " program=",MQLInfoInteger(MQL_TRADE_ALLOWED) ? "ON":"OFF",
         " accountExpert=",AccountInfoInteger(ACCOUNT_TRADE_EXPERT) ? "ON":"OFF",
          " accountTrade=",AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) ? "ON":"OFF",
         " tester=",MQLInfoInteger(MQL_TESTER) ? "YES":"NO");

   Print("STB INIT symbol=",_Symbol,
         " chartTF=",EnumToString((ENUM_TIMEFRAMES)_Period),
         " magic=",IntegerToString((int)InpMagic),
         " auto=",g_autoTrading ? "ON":"OFF",
         " autoInput=",InpAutoTrading ? "ON":"OFF",
         " testerForceAuto=",InpTesterForceAutoTrading ? "ON":"OFF",
         " testerSymbolOnly=",InpTesterChartSymbolOnly ? "ON":"OFF",
         " universal=",InpAllowUniversal ? "ON":"OFF",
         " strictFVGOB=",InpStrictPatternFilters ? "ON":"OFF",
         " requireFVG=",InpRequireFVG ? "ON":"OFF",
         " requireOB=",InpRequireOB ? "ON":"OFF",
         " requireH4Align=",InpRequireH4TrendAlignment ? "ON":"OFF",
         " requireHTFConfluence=",InpRequireHTFConfluence ? "ON":"OFF",
         " htfTF=",EnumToString(InpHTFPatternTF),
         " htfLookback=",IntegerToString(InpHTFLookbackBars),
         " htfMaxAge=",IntegerToString(InpHTFMaxZoneAgeBars),
         " structuralTrail=",InpUseStructuralTrailing ? "ON":"OFF",
         " structuralTrailStartATR=",DoubleToString(InpStructuralTrailStartATR,2),
         " structuralTrailBufferATR=",DoubleToString(InpStructuralTrailBufferATR,2),
         " maxSpreadPips=",DoubleToString(InpMaxSpreadPips,1),
         " maxRelativeSpreadPct=",DoubleToString(InpMaxRelativeSpreadPct,1),
         " adaptiveHalfLifeDays=",DoubleToString(InpAdaptiveHalfLifeDays,1),
         " RSIperiod=",IntegerToString(InpRSIPeriod),
         " CCIperiod=",IntegerToString(InpCCIPeriod),
         " oscHardFilter=",InpOscillatorHardFilter ? "ON":"OFF",
         " adaptiveParams=",InpAdaptiveParameterLearning ? "ON":"OFF",
         " warmup=",IntegerToString(InpAdaptiveWarmupPerProfile),
         " UCB=",DoubleToString(InpAdaptiveUCBExploration,2));
   STB_LogSizingConfig();
   if(InpMaxRelativeSpreadPct>0.0)
      Print("STB CONFIG HARD GATE relativeSpreadPct=",
            DoubleToString(InpMaxRelativeSpreadPct,1),
            "% formula=(ask-bid)/M15_ATR14*100. Symbols above this cap are rejected before candidate ranking; inspect STB SCANNER DISCOVERY REJECT BREAKDOWN for qualityReasons=REJECT_RELATIVE_SPREAD.");
   Print("STB UNIVERSAL PROFIT LOCK POLICY ENFORCED: triggerPips=",DoubleToString(STB_ProfitLockTriggerPips(),1)," lockPips=",DoubleToString(STB_ProfitLockLockPips(),1));

// Keep the eight dedicated EA controls in a non-overlapping vertical stack at the lower-left,
// away from the native MT5 one-click panel. Button handlers dispatch to dedicated
// strategy/trade-management functions.
   CreateButton(g_prefix+"BUY_STOP","BUY STOP",8,8,88,26,clrSeaGreen);
   CreateButton(g_prefix+"SELL_STOP","SELL STOP",100,8,88,26,clrTomato);
   CreateButton(g_prefix+"AUTO","AUTO",192,8,80,26,clrFireBrick);
   CreateButton(g_prefix+"SAVE20","SAVE +20",276,8,88,26,clrRoyalBlue);
   CreateButton(g_prefix+"HEDGE","HEDGE",368,8,84,26,clrDarkOrange);
   CreateButton(g_prefix+"SELL_LIMIT","SELL LIMIT",456,8,88,26,clrTomato);
   CreateButton(g_prefix+"BUY_LIMIT","BUY LIMIT",548,8,88,26,clrSeaGreen);
   CreateButton(g_prefix+"PEND_TRAIL","PEND TRAIL",640,8,96,26,clrSlateBlue);

   g_controlLastAction="CONTROL BAR READY - click results appear here; rejection details are in Experts.";
   UpdateButtons();
   STB_LogControlButtonHealth();
   ResetLastError();
    if(!EventSetTimer(MathMax(1,InpScanSeconds)))
      {
       Print("STB INIT FAILED: EventSetTimer failed err=",GetLastError());
       return INIT_FAILED;
      }
   g_lastChartBar=iTime(_Symbol,(ENUM_TIMEFRAMES)_Period,0);
   g_lastM15Bar=iTime(_Symbol,PERIOD_M15,0);


// P9 restart/reinitialize recovery: rebuild pending-trail state for EVERY
// managed pending type before the first management cycle. This prevents the
// first cycle from registering/trailing recovered orders before a clean rebuild.
   STB_PendingTrailRebuildFromTerminal();

// Seed the per-ticket geometry/override registry before any write is attempted.
// This closes the attach/restart window in which a manual SL/TP edit could be
// mistaken for an unknown baseline because the first timer reconciliation had
// not yet run.
   STB_ReconcileTradeRegistry();

// Harden restart/reattach protection: do not wait for the first Tick/Timer.
// Every currently open position is checked immediately through the one cycle.
   STB_RunManagementCycle(); // Protection takes priority during startup/recovery.

   // Scanner discovery is independent of account-wide exposure. Execution
   // still checks managed exposure for the candidate's own symbol.
   STB_ScannerRun();
   g_lastSignalScanBar=iTime(_Symbol,PERIOD_M15,1);

   UpdatePanel();
   return INIT_SUCCEEDED;
  }

//==================================================================
// DEINIT
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
   double profit=TesterStatistics(STAT_PROFIT);
   double pf=TesterStatistics(STAT_PROFIT_FACTOR);
   double expected=TesterStatistics(STAT_EXPECTED_PAYOFF);
   double trades=TesterStatistics(STAT_TRADES);
   double ddAbs=TesterStatistics(STAT_EQUITY_DD);
   double ddMax=TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
   double sharpe=TesterStatistics(STAT_SHARPE_RATIO);
   double recovery=TesterStatistics(STAT_RECOVERY_FACTOR);
   double initial=TesterStatistics(STAT_INITIAL_DEPOSIT);

// The canonical FILE_COMMON snapshot is consumed by the single-run
// regression harness. During optimization, multiple tester agents can write
// the same filename concurrently and silently associate another pass's
// statistics with this pass. Keep the stable filename for ordinary single
// tests; optimization statistics remain available in each pass's tester log
// and through this function's returned criterion.
   if(!MQLInfoInteger(MQL_OPTIMIZATION))
     {
      int mh=FileOpen("SmartTradingBot_TesterMetrics.csv",
                      FILE_WRITE|FILE_CSV|FILE_COMMON,
                      ',');
      if(mh!=INVALID_HANDLE)
        {
         FileWrite(mh,
                   "profit","trades","profit_factor","expected_payoff",
                   "equity_dd","equity_dd_percent","sharpe",
                   "recovery_factor","initial_deposit");
         FileWrite(mh,
                   DoubleToString(profit,10),
                   DoubleToString(trades,0),
                   DoubleToString(pf,10),
                   DoubleToString(expected,10),
                   DoubleToString(ddAbs,10),
                   DoubleToString(ddMax,10),
                   DoubleToString(sharpe,10),
                   DoubleToString(recovery,10),
                   DoubleToString(initial,10));
         FileFlush(mh);
         FileClose(mh);
        }
      else
        {
         Print("STB TESTER METRICS CSV OPEN FAILED err=",GetLastError());
        }
     }
   else
     {
      Print("STB TESTER METRICS CSV SKIPPED during optimization to prevent shared FILE_COMMON collisions; use per-pass tester log/criterion.");
     }

   Print("STB TESTER METRICS",
         " profit=",DoubleToString(profit,2),
         " trades=",DoubleToString(trades,0),
         " pf=",DoubleToString(pf,4),
         " expected=",DoubleToString(expected,4),
         " equityDD=",DoubleToString(ddAbs,2),
         " equityDDPct=",DoubleToString(ddMax,4),
         " sharpe=",DoubleToString(sharpe,4),
         " recovery=",DoubleToString(recovery,4),
         " initial=",DoubleToString(initial,2));

   double criterion=STB_AdaptiveTesterCriterion();
   Print("STB TESTER adaptive criterion=",DoubleToString(criterion,6));
   return criterion;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();

   if(g_stbMouseMoveEventsCaptured)
     {
      if(!ChartSetInteger(0,CHART_EVENT_MOUSE_MOVE,g_stbOriginalMouseMoveEvents))
         Print("STB UI WARNING: unable to restore mouse-move event setting err=",GetLastError());
      g_stbMouseMoveEventsCaptured=false;
     }

   // Keep the daily baseline through ordinary EA reinitializations, but clear
   // tester-agent state when this instance is finally unloaded. This prevents
   // a completed test's baseline from contaminating a later test on the same agent.
   if(MQLInfoInteger(MQL_TESTER) &&
      (reason==REASON_PROGRAM || reason==REASON_REMOVE ||
       reason==REASON_CHARTCLOSE || reason==REASON_CLOSE ||
       reason==REASON_INITFAILED))
      STB_DailyRiskClearState();

   STB_ReleaseAllSymbolManagement(); // P10 release every symbol lease owned by this chart

   ObjectDelete(0,g_prefix+"BUY_STOP");
   ObjectDelete(0,g_prefix+"SELL_STOP");
   ObjectDelete(0,g_prefix+"AUTO");
   ObjectDelete(0,g_prefix+"SAVE20");
   ObjectDelete(0,g_prefix+"HEDGE");
   ObjectDelete(0,g_prefix+"SELL_LIMIT");
   ObjectDelete(0,g_prefix+"BUY_LIMIT");
   ObjectDelete(0,g_prefix+"PEND_TRAIL");
   ObjectDelete(0,g_prefix+"CONTROL_STATUS");
   ObjectDelete(0,g_prefix+"H4_TRENDLINE");
   ObjectDelete(0,g_prefix+"TF_TREND_BASE");
   ObjectDelete(0,g_prefix+"TF_TREND_EXT");
   ObjectDelete(0,g_prefix+"TF_TREND_HIGH");
   ObjectDelete(0,g_prefix+"TF_TREND_HIGH_EXT");
   ObjectDelete(0,g_prefix+"TF_TREND_LOW");
   ObjectDelete(0,g_prefix+"TF_TREND_LOW_EXT");

   STB_DashDeleteAll();
   DeleteVisuals();
   ObjectDelete(0,g_prefix+"OSC_PANEL");
   ObjectDelete(0,g_prefix+"OSC_SIG_B");
   ObjectDelete(0,g_prefix+"OSC_SIG_S");
   ReleaseIndicatorHandles();

   Comment("");
  }

//==================================================================
// TICK
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/* ==============================================================
   STB PENDING TRAIL SERVICES
   Included after the EA's global declarations and before events.
   ============================================================== */

// LRN-04 record codec was removed: it had no call sites in the EA.


// ===== INLINED FROM MQL5/Include/STB/STB_PendingDistanceResolver.mqh; standalone source integration =====
//+------------------------------------------------------------------+
//| STB_PendingDistanceResolver.mqh                                  |
//| Safe-integration distance service for SmartTradingBot.           |
//|                                                                  |
//| NOT an EA. NOT an Adaptive Engine.                               |
//| This module is a SPECIALIZED SERVICE: it consumes the EXISTING   |
//| STB adaptive context (STB_EffectiveEntryBuffer /                 |
//| STB_EffectiveSLBuffer) and EXISTING broker helpers               |
//| (TradeMinDistance, NormalizePrice) and produces broker-validated |
//| Entry / SL geometry for EVERY supported pending type:            |
//|   BUY STOP / SELL STOP / BUY LIMIT / SELL LIMIT /                |
//|   BUY STOP-LIMIT / SELL STOP-LIMIT.                              |
//|                                                                  |
//| Responsibilities:                                                |
//|   EntryOffset, SLBuffer, Broker validation, Tick alignment,      |
//|   Final Entry, Final SL                                          |
//| The broker minimum distance is only a VALIDITY FLOOR, never the  |
//| strategy SL target.                                              |
//+------------------------------------------------------------------+
#ifndef _STB_PENDING_DISTANCE_RESOLVER_MQH
#define _STB_PENDING_DISTANCE_RESOLVER_MQH

//--- Broker symbol limits snapshot ---------------------------------
struct STBBrokerLimits
{
   string symbol;
   double point;          // SYMBOL_POINT
   int    digits;         // SYMBOL_DIGITS
   double tickSize;       // SYMBOL_TRADE_TICK_SIZE
   long   stopsLevel;     // SYMBOL_TRADE_STOPS_LEVEL
   long   freezeLevel;    // SYMBOL_TRADE_FREEZE_LEVEL
   double minDistance;    // existing STB broker minimum distance
   bool   valid;
};

//--- Resolver output -------------------------------------------------
struct STBPendingResolution
{
   bool   valid;
   string reason;
   double entry;             // validated entry (tick aligned)
   double sl;                // validated SL (tick aligned)
   double entryOffset;       // applied entry offset (price units)
   double slBuffer;          // applied SL buffer (price units)
   double brokerMinDistance; // broker minimum distance (price units)
};

//--- Read symbol broker constraints --------------------------------
bool STB_ReadBrokerLimits(const string symbol, STBBrokerLimits &bl)
{
   ZeroMemory(bl);

   bl.symbol=      symbol;
   bl.point=       SymbolInfoDouble(symbol,SYMBOL_POINT);
   bl.digits=      (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   bl.tickSize=    SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   bl.stopsLevel=  (long)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   bl.freezeLevel= (long)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   bl.minDistance= TradeMinDistance(symbol);

   bl.valid=(bl.point>0.0 && bl.minDistance>0.0);
   return bl.valid;
}

//--- Tick-size alignment (NormalizeDouble alone is NOT sufficient) ----
double STB_TickAlignPrice(const string symbol,const double price)
{
   if(price<=0.0)
      return 0.0;

   STBBrokerLimits bl;
   if(!STB_ReadBrokerLimits(symbol,bl))
      return NormalizePrice(symbol,price);

   if(bl.tickSize<=0.0)
      return NormalizePrice(symbol,price);

   double aligned=MathRound(price/bl.tickSize)*bl.tickSize;

   return NormalizePrice(symbol,aligned);
}

//--- Directional tick alignment for broker-bound prices -------------
// Entry prices are rounded AWAY from the market-facing invalid boundary:
// BUY_STOP/BUY_STOP_LIMIT and SELL_LIMIT round up; SELL_STOP/SELL_STOP_LIMIT
// and BUY_LIMIT round down. SL rounds down for BUY risk and up for SELL risk.
// Nearest-tick rounding can still put a price inside the broker stop/freeze zone.
double STB_TickAlignPriceDirectional(const string symbol,
                                     const double price,
                                     const bool roundUp)
{
   if(price<=0.0)
      return 0.0;

   STBBrokerLimits bl;
   if(!STB_ReadBrokerLimits(symbol,bl))
      return NormalizePrice(symbol,price);

   // Prefer exchange tick size; fall back to point if the symbol omits it.
   double tickSize=(bl.tickSize>0.0 ? bl.tickSize:bl.point);
   if(tickSize<=0.0)
      return NormalizePrice(symbol,price);

   double units=price/tickSize;
   double alignedUnits=(roundUp ? MathCeil(units-1e-10)
                                : MathFloor(units+1e-10));
   return NormalizePrice(symbol,alignedUnits*tickSize);
}

//--- Pending classification (single source of truth) ---------------
bool STB_PendingIsBuySide(const ENUM_ORDER_TYPE orderType)
{
   return orderType==ORDER_TYPE_BUY_STOP       ||
          orderType==ORDER_TYPE_BUY_LIMIT      ||
          orderType==ORDER_TYPE_BUY_STOP_LIMIT;
}

bool STB_PendingIsSellSide(const ENUM_ORDER_TYPE orderType)
{
   return orderType==ORDER_TYPE_SELL_STOP      ||
          orderType==ORDER_TYPE_SELL_LIMIT     ||
          orderType==ORDER_TYPE_SELL_STOP_LIMIT;
}

// STOP-kind orders enter on a breakout; LIMIT-kind orders enter on a pullback.
bool STB_PendingIsStopKind(const ENUM_ORDER_TYPE orderType)
{
   return orderType==ORDER_TYPE_BUY_STOP       ||
          orderType==ORDER_TYPE_SELL_STOP      ||
          orderType==ORDER_TYPE_BUY_STOP_LIMIT ||
          orderType==ORDER_TYPE_SELL_STOP_LIMIT;
}

//--- Entry offset sign relative to the tracked anchor extreme ------
//   +1 => entry sits ABOVE the anchor
//         (BUY STOP, BUY STOP-LIMIT, SELL LIMIT)
//   -1 => entry sits BELOW the anchor
//         (SELL STOP, SELL STOP-LIMIT, BUY LIMIT)
int STB_PendingEntryOffsetSign(const ENUM_ORDER_TYPE orderType)
{
   if(orderType==ORDER_TYPE_BUY_STOP       ||
      orderType==ORDER_TYPE_BUY_STOP_LIMIT ||
      orderType==ORDER_TYPE_SELL_LIMIT)
      return 1;

   if(orderType==ORDER_TYPE_SELL_STOP      ||
      orderType==ORDER_TYPE_SELL_STOP_LIMIT ||
      orderType==ORDER_TYPE_BUY_LIMIT)
      return -1;

   return 0;
}

//--- Resolve Entry / SL for any supported pending type -------------
// Inputs:
//   symbol                  - target symbol
//   orderType               - BUY/SELL STOP, BUY/SELL LIMIT, STOP-LIMIT
//   extreme                 - tracked anchor extreme
//                             (live Bid for BUY side, live Ask for SELL side)
//   configuredBaseDistance  - caller override in pips; <=0 means use the
//                             EXISTING STB adaptive entry/SL buffers
// Outputs (validated):
//   entry, sl, entryOffset, slBuffer, brokerMinDistance
bool STB_ResolvePendingDistance(const string symbol,
                                const ENUM_ORDER_TYPE orderType,
                                const double extreme,
                                const double configuredBaseDistance,
                                STBPendingResolution &r,
                                const double configuredSLBufferPips=-1.0,
                                const double currentEntry=0.0)
{
   ZeroMemory(r);
   r.valid=false;
   r.reason="UNRESOLVED";

   if(symbol=="" || extreme<=0.0)
   {
      r.reason="IDENTITY_INVALID";
      return false;
   }

   bool isBuy =STB_PendingIsBuySide(orderType);
   bool isSell=STB_PendingIsSellSide(orderType);
   bool isStop=STB_PendingIsStopKind(orderType);
   int  offSign=STB_PendingEntryOffsetSign(orderType);

   if((!isBuy && !isSell) || offSign==0)
   {
      r.reason="IDENTITY_INVALID";
      return false;
   }

   STBBrokerLimits bl;
   if(!STB_ReadBrokerLimits(symbol,bl))
   {
      r.reason="BROKER_LIMITS_UNAVAILABLE";
      return false;
   }

   // Adaptive context remains available for Strategy-owned callers. Lifecycle
   // managers can pass immutable stored buffers and therefore do not need
   // Adaptive access.
   double entryOffsetPips=STB_EffectiveEntryBuffer();
   double slBufferPips   =STB_EffectiveSLBuffer();

   if(configuredBaseDistance>0.0)
      entryOffsetPips=configuredBaseDistance;

   if(configuredSLBufferPips>=0.0)
      slBufferPips=configuredSLBufferPips;
   else if(configuredBaseDistance>0.0)
      slBufferPips=configuredBaseDistance;

   // STB configuration values are expressed in pips, not raw broker points.
   // Use the EA's canonical PipSize() so XAU/XAG/3-5 digit symbols receive
   // the intended price distance.
   double pip=PipSize(symbol);
   if(pip<=0.0)
   {
      r.reason="PIP_SIZE_INVALID";
      return false;
   }

   MqlTick tick;
   if(!SymbolInfoTick(symbol,tick))
   {
      r.reason="NO_TICK";
      return false;
   }

   // Broker validity floor for the entry offset. STOP trails can be anchored
   // to a CLOSED M5 extreme, which may be well behind the current quote.
   // Therefore calculate the minimum offset from the ACTUAL anchor to the
   // current legal trigger boundary, not merely from the spread.
   double priceStep=MathMax(bl.point,
                            bl.tickSize>0.0 ? bl.tickSize:bl.point);
   double minOffset=bl.minDistance+priceStep;

   if(orderType==ORDER_TYPE_BUY_STOP ||
      orderType==ORDER_TYPE_BUY_STOP_LIMIT)
     {
      double minimumBuyEntry=tick.ask+bl.minDistance+priceStep;
      minOffset=MathMax(minOffset,minimumBuyEntry-extreme);
     }
   else if(orderType==ORDER_TYPE_SELL_STOP ||
           orderType==ORDER_TYPE_SELL_STOP_LIMIT)
     {
      double maximumSellEntry=tick.bid-bl.minDistance-priceStep;
      minOffset=MathMax(minOffset,extreme-maximumSellEntry);
     }

   minOffset=MathMax(0.0,minOffset);
   double effectiveOffset=MathMax(entryOffsetPips*pip,minOffset);

   // The entry keeps a fixed offset from the tracked anchor extreme; the offset
   // sign encodes stop (breakout) vs limit (pullback) geometry per side.
   double rawEntry=extreme+offSign*effectiveOffset;

   // Enforce the broker-valid boundary after applying the anchor offset. If a
   // STOP order would have to move in the wrong direction to become valid,
   // defer it rather than submitting an invalid or non-improving proposal.
   double entryTolerance=MathMax(bl.point*0.5,
                                 bl.tickSize>0.0 ? bl.tickSize*0.5:bl.point*0.5);

   if(orderType==ORDER_TYPE_BUY_STOP ||
      orderType==ORDER_TYPE_BUY_STOP_LIMIT)
     {
      double minimumBuyEntry=tick.ask+bl.minDistance+priceStep;
      if(rawEntry<minimumBuyEntry)
        {
         rawEntry=minimumBuyEntry;
         effectiveOffset=rawEntry-extreme;
        }
     }
   else if(orderType==ORDER_TYPE_SELL_STOP ||
           orderType==ORDER_TYPE_SELL_STOP_LIMIT)
     {
      double maximumSellEntry=tick.bid-bl.minDistance-priceStep;
      if(rawEntry>maximumSellEntry)
        {
         rawEntry=maximumSellEntry;
         effectiveOffset=extreme-rawEntry;
        }
     }

   // Round each entry away from the invalid market boundary.
   bool entryRoundUp=
      (orderType==ORDER_TYPE_BUY_STOP ||
       orderType==ORDER_TYPE_BUY_STOP_LIMIT ||
       orderType==ORDER_TYPE_SELL_LIMIT);

   double entry=STB_TickAlignPriceDirectional(symbol,rawEntry,entryRoundUp);
   if(entry<=0.0)
     {
      r.reason="PRICE_INVALID";
      return false;
     }

   // Test the FINAL tick-aligned price. A STOP trigger must improve in the
   // breakout direction: BUY STOP rises; SELL STOP falls. STOP-LIMIT triggers
   // obey the same monotonic direction. Tick alignment can erase small moves.
   if((orderType==ORDER_TYPE_BUY_STOP ||
       orderType==ORDER_TYPE_BUY_STOP_LIMIT) &&
      currentEntry>0.0 && entry<=currentEntry+entryTolerance)
     {
      r.reason="BUY_STOP_NO_FAVORABLE_VALID_ENTRY";
      return false;
     }

   if((orderType==ORDER_TYPE_SELL_STOP ||
       orderType==ORDER_TYPE_SELL_STOP_LIMIT) &&
      currentEntry>0.0 && entry>=currentEntry-entryTolerance)
     {
      r.reason="SELL_STOP_NO_FAVORABLE_VALID_ENTRY";
      return false;
     }

   // SL distance is measured from the FINAL aligned Entry. Align away from
   // risk: down for BUY, up for SELL.
   double rawSL=(isBuy ? entry-slBufferPips*pip
                       : entry+slBufferPips*pip);
   double sl=STB_TickAlignPriceDirectional(symbol,rawSL,isSell);

   if(sl<=0.0)
     {
      r.reason="PRICE_INVALID";
      return false;
     }

   effectiveOffset=MathAbs(entry-extreme);

   // Broker validation, per pending geometry:
   //   BUY  STOP      : sl < bid < ask < entry          (breakout above)
   //   BUY  LIMIT     : sl < entry < bid                (pullback below)
   //   SELL STOP      : entry < bid < ask < sl          (breakout below)
   //   SELL LIMIT     : bid < ask < entry < sl          (pullback above)
   if(isBuy)
   {
      if(sl>=entry-bl.minDistance)
      {
         r.reason="BUY_SL_TOO_CLOSE_TO_ENTRY";
         return false;
      }

      if(sl>tick.bid-bl.minDistance)
      {
         r.reason="BUY_SL_INSIDE_BROKER_ZONE";
         return false;
      }

      if(isStop)
      {
         if(entry<=tick.ask+bl.minDistance)
         {
            r.reason="BUY_ENTRY_INSIDE_BROKER_ZONE";
            return false;
         }
      }
      else
      {
         if(entry>=tick.bid-bl.minDistance)
         {
            r.reason="BUY_ENTRY_INSIDE_BROKER_ZONE";
            return false;
         }
      }
   }
   else
   {
      if(sl<=entry+bl.minDistance)
      {
         r.reason="SELL_SL_TOO_CLOSE_TO_ENTRY";
         return false;
      }

      if(sl<tick.ask+bl.minDistance)
      {
         r.reason="SELL_SL_INSIDE_BROKER_ZONE";
         return false;
      }

      if(isStop)
      {
         if(entry>=tick.bid-bl.minDistance)
         {
            r.reason="SELL_ENTRY_INSIDE_BROKER_ZONE";
            return false;
         }
      }
      else
      {
         if(entry<=tick.ask+bl.minDistance)
         {
            r.reason="SELL_ENTRY_INSIDE_BROKER_ZONE";
            return false;
         }
      }
   }

   r.entry=entry;
   r.sl=sl;
   r.entryOffset=effectiveOffset;
   r.slBuffer=MathAbs(entry-sl); // Actual aligned SL distance, in price units.
   r.brokerMinDistance=bl.minDistance;
   r.valid=true;
   r.reason="OK";
   return true;
}

#endif

// ===== END INLINED MODULE =====


// ===== INLINED FROM MQL5/Include/STB/STB_PendingTrail.mqh; standalone source integration =====
double STB_ParsePendingEntryBufferPips(const string comment,const double fallback)
{
   int pos=StringFind(comment,"|EB");
   if(pos<0) return fallback;
   int start=pos+3;
   int end=StringFind(comment,"|",start);
   string raw=(end>=0 ? StringSubstr(comment,start,end-start)
                      : StringSubstr(comment,start));
   double value=StringToDouble(raw);
   return (MathIsValidNumber(value) && value>=0.0) ? value:fallback;
}

//+------------------------------------------------------------------+
//| STB_PendingTrail.mqh                                             |
//| Safe-integration Pending Trail service for SmartTradingBot.      |
//|                                                                  |
//| NOT an EA. NOT a Trade Manager.                                  |
//| This module OWNS the pre-trigger lifecycle of EVERY supported    |
//| pending type through ONE engine:                                 |
//|   BUY STOP / SELL STOP / BUY LIMIT / SELL LIMIT /                |
//|   BUY STOP-LIMIT / SELL STOP-LIMIT.                              |
//|   - ticket-based state (never symbol-only state)                 |
//|   - BUY STOP / BUY STOP-LIMIT: closed M5 highs ratchet entries up|
//|   - SELL STOP / SELL STOP-LIMIT: closed M5 lows ratchet entries down|
//|   - LIMIT orders retain live Bid/Ask pullback-style trailing      |
//|   - broker validation via STB_PendingDistanceResolver            |
//|   - restart recovery (state rebuilt from terminal orders)        |
//|   - multi-ticket isolation                                       |
//|   - P4: this module only PROPOSES geometry. The single pending   |
//|     geometry writer is STB_ModifyPendingOrderGeometry() (EA).    |
//|   - P4: bounded time throttle + failure backoff per ticket.      |
//|   - P4: entry Step + monotonic trackedExtreme.                   |
//|   - trigger handoff: PENDING_TRIGGERED then                      |
//|     PENDING_TRAIL_STOPPED handoff=TRADE_MANAGEMENT               |
//|                                                                  |
//| After trigger this module MUST NOT touch the resulting position. |
//+------------------------------------------------------------------+
#ifndef _STB_PENDING_TRAIL_MQH
#define _STB_PENDING_TRAIL_MQH

//--- P4: proposal source + modify result classification -------------
enum ENUM_STB_PENDING_SRC
{
   STB_PEND_SRC_INITIAL=0,
   STB_PEND_SRC_TRAIL=1
};

enum ENUM_STB_PENDING_RESULT
{
   STB_PEND_RES_SUCCESS=0,
   STB_PEND_RES_NO_CHANGE=1,
   STB_PEND_RES_TEMPORARY_FAILURE=2,
   STB_PEND_RES_INVALID_STOPS=3,
   STB_PEND_RES_INVALID_PRICE=4,
   STB_PEND_RES_FREEZE_LEVEL=5,
   STB_PEND_RES_TOO_MANY_REQUESTS=6,
   STB_PEND_RES_ORDER_GONE=7,
   STB_PEND_RES_OTHER_FAILURE=8
};

//--- P4: bounded retry policy (never retry every tick) --------------
#define STB_PEND_TRAIL_COOLDOWN_SEC   2
#define STB_PEND_BACKOFF_1_SEC        5
#define STB_PEND_BACKOFF_2_SEC        15
#define STB_PEND_BACKOFF_3_SEC        60

//--- P4: pending geometry proposal (Entry and SL resolved apart) ----
struct STBPendingGeometryProposal
{
   bool   valid;
   double entry;
   double sl;
   double tp;
   int    source;
   string reason;
};

//--- Ticket-based pending trail state --------------------------------
struct STBPendingTrailState
{
   ulong    ticket;
   string   symbol;
   long     orderType;   // BUY/SELL STOP, BUY/SELL LIMIT, STOP-LIMIT
   string   source;      // AUTO | UI_MANUAL | HEDGE | TERMINAL_SCAN | RESTART_RECOVERY
   double   trackedExtreme;
   double   lastEntry;
   double   lastSL;
   datetime lastModifyTime;
   datetime lastNoNewExtremeLogBar;
   datetime lastProcessedM5Bar; // latest closed M5 candle considered for STOP-order trailing
   datetime lastFailLogBar;
   int      lastProcessedCycle;
   double   entryBufferPips;
   double   slBufferPips;
   int      failureCount;   // P4 failure backoff counter
   datetime nextRetryTime;  // P4 earliest next modify attempt
   bool     active;
};

//--- Single central instance -----------------------------------------
STBPendingTrailState g_stbPendingTrail[];
int g_stbPendingTrailCycle=0;

int STB_PendingTrailFind(const ulong ticket)
{
   for(int i=0;i<ArraySize(g_stbPendingTrail);i++)
      if(g_stbPendingTrail[i].ticket==ticket)
         return i;

   return -1;
}

// Distinguish a filled order from cancelled/expired/rejected orders when it
// disappears from the live order pool. A missing live ticket alone is not proof
// that the pending order was triggered.
string STB_PendingTrailMissingOrderReason(const ulong ticket)
{
   if(!HistoryOrderSelect(ticket))
      return "ORDER_HISTORY_UNAVAILABLE";

   ENUM_ORDER_STATE state=
      (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket,ORDER_STATE);

   if(state==ORDER_STATE_FILLED)
      return "ORDER_FILLED";
   if(state==ORDER_STATE_CANCELED)
      return "ORDER_CANCELED";
   if(state==ORDER_STATE_EXPIRED)
      return "ORDER_EXPIRED";
   if(state==ORDER_STATE_REJECTED)
      return "ORDER_REJECTED";

   return "ORDER_STATE_"+EnumToString(state);
}

void STB_PendingTrailClear()
{
   ArrayResize(g_stbPendingTrail,0);
   g_stbPendingTrailCycle=0;
}

// Drop completed/cancelled order records. Without compaction, every historical
// pending ticket would remain in this per-cycle array for the EA's lifetime.
void STB_PendingTrailPruneInactive()
{
   for(int i=ArraySize(g_stbPendingTrail)-1;i>=0;i--)
      if(!g_stbPendingTrail[i].active)
         ArrayRemove(g_stbPendingTrail,i,1);
}

// Every supported pending geometry is managed by the same trail engine:
// BUY/SELL STOP, BUY/SELL LIMIT and BUY/SELL STOP-LIMIT.
bool STB_PendingTrailIsManagedType(const long orderType)
{
   return orderType==(long)ORDER_TYPE_BUY_STOP       ||
          orderType==(long)ORDER_TYPE_SELL_STOP      ||
          orderType==(long)ORDER_TYPE_BUY_LIMIT      ||
          orderType==(long)ORDER_TYPE_SELL_LIMIT     ||
          orderType==(long)ORDER_TYPE_BUY_STOP_LIMIT ||
          orderType==(long)ORDER_TYPE_SELL_STOP_LIMIT;
}

// +1 => BUY side, -1 => SELL side. STOP-kind orders use breakout-direction
// comparisons on closed M5 highs/lows; LIMIT orders retain pullback semantics.
int STB_PendingTrailDirection(const long orderType)
{
   ENUM_ORDER_TYPE t=(ENUM_ORDER_TYPE)orderType;

   if(STB_PendingIsBuySide(t))
      return 1;

   if(STB_PendingIsSellSide(t))
      return -1;

   return 0;
}

string STB_PendingTrailTypeName(const long orderType)
{
   if(orderType==(long)ORDER_TYPE_BUY_STOP)
      return "BUY_STOP";

   if(orderType==(long)ORDER_TYPE_SELL_STOP)
      return "SELL_STOP";

   if(orderType==(long)ORDER_TYPE_BUY_LIMIT)
      return "BUY_LIMIT";

   if(orderType==(long)ORDER_TYPE_SELL_LIMIT)
      return "SELL_LIMIT";

   if(orderType==(long)ORDER_TYPE_BUY_STOP_LIMIT)
      return "BUY_STOP_LIMIT";

   if(orderType==(long)ORDER_TYPE_SELL_STOP_LIMIT)
      return "SELL_STOP_LIMIT";

   return "UNKNOWN";
}

//--- P4: classify the last modify outcome (policy only, no new logs) -
int STB_PendingClassifyResult(const bool ok)
{
   if(ok)
      return STB_PEND_RES_SUCCESS;

   uint ret=(uint)trade.ResultRetcode();

   switch(ret)
   {
      case TRADE_RETCODE_DONE:
         return STB_PEND_RES_SUCCESS;
      case TRADE_RETCODE_NO_CHANGES:
         return STB_PEND_RES_NO_CHANGE;
      case TRADE_RETCODE_INVALID_STOPS:
         return STB_PEND_RES_INVALID_STOPS;
      case TRADE_RETCODE_INVALID_PRICE:
         return STB_PEND_RES_INVALID_PRICE;
      case TRADE_RETCODE_TOO_MANY_REQUESTS:
         return STB_PEND_RES_TOO_MANY_REQUESTS;
      case TRADE_RETCODE_MARKET_CLOSED:
         return STB_PEND_RES_TEMPORARY_FAILURE;
   }

   return STB_PEND_RES_OTHER_FAILURE;
}

//--- Register a real terminal pending order --------------------------
// Called ONLY after the terminal confirmed the ticket. Initial trackedExtreme
// is reconstructed from actual order geometry and its stored entry offset.
// Management uses closed M5 highs/lows for STOP-kind orders and live Bid/Ask
// extremes for LIMIT orders.
// Universal intake: EA-created, manual/mobile, other-EA and restart-recovered
// tickets all register through this single entry point.
bool STB_PendingTrailRegister(const ulong ticket,const string source)
{
   if(ticket==0 || !OrderSelect(ticket) || !IsManagedOrder(ticket))
      return false;

   // Do not create partial Pending Trail state unless the shared exposure
   // registry can represent this terminal order. Later scan/reconcile passes
   // will retry registration if allocation is temporarily unavailable.
   if(STB_ExposureEnsure(ticket,false)<0)
     {
      Print("STB PENDING TRAIL REGISTER DEFERRED ticket=",ticket,
            " source=",source,
            " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
      return false;
     }

   long orderType=OrderGetInteger(ORDER_TYPE);
   if(!STB_PendingTrailIsManagedType(orderType))
      return false;

   int existing=STB_PendingTrailFind(ticket);
   if(existing>=0)
   {
      if(!g_stbPendingTrail[existing].active)
      {
         g_stbPendingTrail[existing].active=true;
         g_stbPendingTrail[existing].source=source;
         g_stbPendingTrail[existing].lastProcessedCycle=-1;
      }
      return true;
   }

   string symbol=OrderGetString(ORDER_SYMBOL);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double pip=PipSize(symbol);

   if(symbol=="" || point<=0.0 || pip<=0.0)
      return false;

   string comment=OrderGetString(ORDER_COMMENT);
   double currentEntry=OrderGetDouble(ORDER_PRICE_OPEN);
   double currentSL=OrderGetDouble(ORDER_SL);

   // P4 EB contract: this EA writes the effective offset to the order comment.
   // For older manual/foreign orders without EB, infer a stable offset from
   // their current entry versus the appropriate live quote. This avoids
   // snapping an inherited order toward the EA's tiny default buffer.
   double fallbackEntryBufferPips=MathMax(0.0,InpEntryBufferPips);
   if(StringFind(comment,"|EB")<0 && currentEntry>0.0)
     {
      MqlTick currentTick;
      if(!SymbolInfoTick(symbol,currentTick) || pip<=0.0)
         return false;

      bool buySide=STB_PendingIsBuySide((ENUM_ORDER_TYPE)orderType);
      // The pending trail's canonical anchor is Bid for BUY-side orders and
      // Ask for SELL-side orders, regardless of STOP vs LIMIT geometry.
      double anchorQuote=buySide ? currentTick.bid:currentTick.ask;
      fallbackEntryBufferPips=MathAbs(currentEntry-anchorQuote)/pip;

      double minDistance=TradeMinDistance(symbol);
      if(minDistance>0.0)
         fallbackEntryBufferPips=MathMax(fallbackEntryBufferPips,
                                         minDistance/pip);
     }

   // Persisted manual authority means the user may have changed entry/SL/TP
   // since the original comment was written. On recovery, re-anchor to the
   // current geometry rather than trusting a stale historical EB value.
   double entryBufferPips=0.0;
   if(STB_ManualOverrideIs(ticket) || StringFind(comment,"|EB")<0)
      entryBufferPips=fallbackEntryBufferPips;
   else
      entryBufferPips=STB_ParsePendingEntryBufferPips(comment,
                                                     fallbackEntryBufferPips);

   if(entryBufferPips<0.0 || !MathIsValidNumber(entryBufferPips))
      return false;

   // P4 STB-002: the pending SL distance is the STRUCTURAL risk of the order
   // (|Entry-SL|), never an arbitrary constant. A constant could otherwise
   // expand risk beyond the structural floor. If the order has no SL yet the
   // trail may create the initial structural SL using the configured fallback.
   double structuralRiskPips=(currentEntry>0.0 && currentSL>0.0)
                             ? MathAbs(currentEntry-currentSL)/pip
                             : 0.0;

   // Pending protection is independent from whether live trailing is
   // disabled. If no SL exists yet, reserve a positive structural-buffer
   // fallback; the EA's initial-protection path must install the real SL.
   double slBufferPips=(structuralRiskPips>0.0)
                        ? structuralRiskPips
                        : MathMax(1.0,
                                  MathMax(InpInitialSLBufferPips,
                                          InpSLBufferPips));

   int direction=STB_PendingTrailDirection(orderType);
   int offSign  =STB_PendingEntryOffsetSign((ENUM_ORDER_TYPE)orderType);

   if(direction==0 || offSign==0)
      return false;

   // Recover the anchor extreme from the live pending geometry:
   //   entry = extreme + offSign*offset  =>  extreme = entry - offSign*offset.
   double inferredExtreme=currentEntry-offSign*entryBufferPips*pip;

   // Keep the anchor reconstructed from the CURRENT order geometry and its
   // EB offset. EB is defined against Bid for BUY-side orders and Ask for
   // SELL-side orders at registration/recovery. Unconditionally replacing this
   // anchor with a candle extreme combines an unrelated extreme with the EB
   // offset and can make the first trail proposal jump or fail broker geometry.
   // Actual STOP trailing still evaluates each NEW closed M5 low/high below.

   if(inferredExtreme<=0.0)
      return false;

   STBPendingTrailState st;
   ZeroMemory(st);

   st.ticket=ticket;
   st.symbol=symbol;
   st.orderType=orderType;
   st.source=source;
   st.trackedExtreme=inferredExtreme;
   st.lastEntry=currentEntry;
   st.lastSL=currentSL;
   st.lastModifyTime=0;
   st.lastNoNewExtremeLogBar=0;
   st.lastProcessedM5Bar=iTime(symbol,PERIOD_M5,1);
   st.lastFailLogBar=0;
   st.lastProcessedCycle=-1;
   st.entryBufferPips=entryBufferPips;
   st.slBufferPips=slBufferPips;
   st.failureCount=0;
   st.nextRetryTime=0;
   st.active=true;

   int n=ArraySize(g_stbPendingTrail);
   if(ArrayResize(g_stbPendingTrail,n+1)!=n+1)
     {
      Print("STB PENDING TRAIL STATE ALLOCATION FAILED ticket=",ticket,
            " source=",source,
            " requestedSize=",n+1);
      return false;
     }
   g_stbPendingTrail[n]=st;

   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

   Print("PENDING_CREATED ticket=",IntegerToString((int)ticket),
         " symbol=",symbol,
         " type=",STB_PendingTrailTypeName(orderType),
         " source=",source,
         " trackedExtreme=",DoubleToString(st.trackedExtreme,digits),
         " entryBufferPips=",DoubleToString(st.entryBufferPips,4),
         " structuralRiskPips=",DoubleToString(st.slBufferPips,4),
         " entry=",DoubleToString(st.lastEntry,digits),
         " sl=",DoubleToString(st.lastSL,digits));

   STBPendingResolution res;
   bool distanceOK=
      STB_ResolvePendingDistance(symbol,
                                 (ENUM_ORDER_TYPE)st.orderType,
                                 st.trackedExtreme,
                                 st.entryBufferPips,
                                 res,
                                 st.slBufferPips);

   if(distanceOK && res.valid)
   {
      Print("PENDING_DISTANCE ticket=",IntegerToString((int)ticket),
            " symbol=",symbol,
            " type=",STB_PendingTrailTypeName(orderType),
            " entryOffset=",DoubleToString(res.entryOffset,digits),
            " slBuffer=",DoubleToString(res.slBuffer,digits),
            " brokerMinDistance=",DoubleToString(res.brokerMinDistance,digits));
   }

   return true;
}

//--- Rate-limited NO_NEW_EXTREME log --------------------------------
void STB_PendingTrailLogNoNewExtreme(const ulong ticket,
                                     const string symbol,
                                     const int logIdx)
{
   datetime bar=iTime(symbol,PERIOD_M15,1);

   if(bar<=0)
      bar=TimeCurrent();

   if(logIdx>=0 && g_stbPendingTrail[logIdx].lastNoNewExtremeLogBar==bar)
      return;

   if(logIdx>=0)
      g_stbPendingTrail[logIdx].lastNoNewExtremeLogBar=bar;

   Print("PENDING_TRAIL_NO_NEW_EXTREME ticket=",IntegerToString((int)ticket),
         " symbol=",symbol);
}

//--- P4 central submit gate: throttle + backoff + Step + state --------
// This gate NEVER talks to the broker. It applies the time throttle, the
// failure backoff and the meaningful Step gate, then forwards the proposal
// to the single pending geometry writer STB_ModifyPendingOrderGeometry().
// Returns true only when the writer confirmed the change.
bool STB_SubmitPendingTrailGeometry(const ulong ticket,
                                    const double propEntry,
                                    const double propSL,
                                    const double propTP,
                                    string &gateReason,
                                    const bool manual=false)
{
   gateReason="";
   int idx=STB_PendingTrailFind(ticket);

   if(idx<0 || !g_stbPendingTrail[idx].active)
   {
      gateReason="STATE_INACTIVE";
      return false;
   }

   string symbol=g_stbPendingTrail[idx].symbol;
   double pip=PipSize(symbol);
   datetime now=TimeCurrent();

   // Time throttle: at most one modification per cooldown window.
   if(g_stbPendingTrail[idx].nextRetryTime>0 &&
      now<g_stbPendingTrail[idx].nextRetryTime)
   {
      gateReason="BACKOFF_ACTIVE";
      return false;
   }

   if(g_stbPendingTrail[idx].lastModifyTime>0 &&
      now<g_stbPendingTrail[idx].lastModifyTime+STB_PEND_TRAIL_COOLDOWN_SEC)
   {
      gateReason="COOLDOWN_ACTIVE";
      return false;
   }

   // Step gate: skip a proposal whose protection improvement is below the
   // configured meaningful step (existing input, no new input introduced).
   if(OrderSelect(ticket) && pip>0.0)
   {
      double step=MathMax(0.0,InpTrailStepPips)*pip;
      double curEntry=OrderGetDouble(ORDER_PRICE_OPEN);
      double curSL=OrderGetDouble(ORDER_SL);

      if(step>0.0 &&
         MathAbs(propEntry-curEntry)<step &&
         MathAbs(propSL-curSL)<step)
      {
         gateReason="STEP_GATE";
         return false;
      }
   }

   // Forward to the ONE central pending geometry writer and preserve its
   // precise local/broker rejection reason for the caller's diagnostic log.
   string writerFailureReason="";
   bool ok=STB_ModifyPendingOrderGeometry(ticket,propEntry,propSL,propTP,
                                          writerFailureReason,manual);
   int cls=STB_PendingClassifyResult(ok);

   if(ok)
   {
      gateReason="MODIFY_CONFIRMED";
      if(manual)
         STB_ManualOverrideSet(ticket); // MANUAL_OVERRIDE: user PEND_TRAIL command is final
      // SUCCESS (or broker NO_CHANGE accepted): reset failure backoff.
      g_stbPendingTrail[idx].failureCount=0;
      g_stbPendingTrail[idx].nextRetryTime=0;
      g_stbPendingTrail[idx].lastModifyTime=TimeCurrent();

      if(OrderSelect(ticket))
      {
         g_stbPendingTrail[idx].lastEntry=OrderGetDouble(ORDER_PRICE_OPEN);
         g_stbPendingTrail[idx].lastSL=OrderGetDouble(ORDER_SL);
      }

      return true;
   }

   if(cls==STB_PEND_RES_ORDER_GONE)
   {
      g_stbPendingTrail[idx].active=false;
      gateReason="ORDER_GONE";
      return false;
   }

   // Failure: bounded exponential-ish backoff. Never retry every tick.
   g_stbPendingTrail[idx].failureCount++;

   int fc=g_stbPendingTrail[idx].failureCount;
   int backoffSec=(fc<=1 ? STB_PEND_BACKOFF_1_SEC
                         : (fc==2 ? STB_PEND_BACKOFF_2_SEC
                                  : STB_PEND_BACKOFF_3_SEC));

   g_stbPendingTrail[idx].nextRetryTime=TimeCurrent()+backoffSec;
   gateReason=(writerFailureReason=="" ? "WRITER_REJECTED":writerFailureReason);

   return false;
}

//--- Proposal-only pipeline for ONE ticket ---------------------------
// Reads, verifies ownership, reads geometry, reads the tracked extreme,
// calculates a candidate, validates it and returns a PROPOSAL. It never
// calls the broker itself.
bool STB_PendingTrailManageOne(const ulong ticket,const bool manual=false)
{
   int idx=STB_PendingTrailFind(ticket);

   if(idx<0 || !g_stbPendingTrail[idx].active)
      return false;

   // Resolve terminal lifecycle before requiring the exposure registry.
   // A deleted/filled ticket must be retired even if registry allocation is
   // currently failing; otherwise stale active states can persist indefinitely.
   if(!OrderSelect(g_stbPendingTrail[idx].ticket))
   {
      // Terminal no longer exposes this order: filled (triggered),
      // cancelled or deleted. The trail stops here; the existing
      // STB Trade Manager owns any resulting position.
      Print("PENDING_TRAIL_STOPPED ticket=",IntegerToString((int)ticket),
            " symbol=",g_stbPendingTrail[idx].symbol,
            " reason=",STB_PendingTrailMissingOrderReason(ticket));
      g_stbPendingTrail[idx].active=false;
      return false;
   }

   // If the shared registry becomes unavailable after registration, defer
   // processing before consuming bars or mutating trail state. The next
   // management cycle retries from the still-live terminal order.
   if(STB_ExposureEnsure(ticket,false)<0)
     {
      Print("STB PENDING TRAIL PROCESS DEFERRED ticket=",ticket,
            " reason=EXPOSURE_REGISTRY_ALLOCATION_FAILED");
      return false;
     }

   if(!IsManagedOrder(ticket))
   {
      Print("PENDING_TRAIL_STOPPED ticket=",IntegerToString((int)ticket),
            " symbol=",g_stbPendingTrail[idx].symbol,
            " reason=OWNERSHIP_LOST");
      g_stbPendingTrail[idx].active=false;
      return false;
   }

   // Only the verified terminal-wide symbol lease owner may evaluate/submit
   // this order. Other chart instances defer before proposal calculation so
   // they cannot consume retry budget or emit false writer-failure logs.
   string managedSymbol=OrderGetString(ORDER_SYMBOL);
   if(!STB_SymbolManagementOwnedVerified(managedSymbol))
      return true;

   // After lifecycle/ownership checks, honor per-ticket backoff before
   // rebuilding an actionable-bar proposal.
   if(g_stbPendingTrail[idx].nextRetryTime>TimeCurrent())
      return true;

   long orderType=OrderGetInteger(ORDER_TYPE);

   // Every supported pending type remains under automatic management,
   // including orders created or edited manually/from mobile. Manual-override
   // metadata is not a permanent opt-out from protective trailing.
   bool candleStop=(orderType==(long)ORDER_TYPE_BUY_STOP ||
                    orderType==(long)ORDER_TYPE_SELL_STOP ||
                    orderType==(long)ORDER_TYPE_BUY_STOP_LIMIT ||
                    orderType==(long)ORDER_TYPE_SELL_STOP_LIMIT);

   if(!STB_PendingTrailIsManagedType(orderType))
   {
      Print("PENDING_TRAIL_STOPPED ticket=",IntegerToString((int)ticket),
            " symbol=",g_stbPendingTrail[idx].symbol,
            " reason=ORDER_TYPE_CHANGED");
      g_stbPendingTrail[idx].active=false;
      return false;
   }

   if(OrderGetString(ORDER_SYMBOL)!=g_stbPendingTrail[idx].symbol)
   {
      Print("PENDING_TRAIL_STOPPED ticket=",IntegerToString((int)ticket),
            " symbol=",g_stbPendingTrail[idx].symbol,
            " reason=SYMBOL_CHANGED");
      g_stbPendingTrail[idx].active=false;
      return false;
   }

   // Initial structural protection owns unprotected pending orders. Do not
   // let the trail fallback silently install a generic fixed-distance SL.
   if(OrderGetDouble(ORDER_SL)<=0.0)
     {
      Print("PENDING_TRAIL_WAIT ticket=",ticket,
            " symbol=",g_stbPendingTrail[idx].symbol,
            " type=",STB_PendingTrailTypeName(orderType),
            " reason=SL_NOT_INSTALLED");
      return true;
     }

   g_stbPendingTrail[idx].orderType=orderType;

   string symbol=g_stbPendingTrail[idx].symbol;
   int direction=STB_PendingTrailDirection(orderType);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double pip=PipSize(symbol);

   if(direction==0 || point<=0.0 || pip<=0.0)
     {
      Print("PENDING_TRAIL_WAIT ticket=",ticket," symbol=",symbol,
            " type=",STB_PendingTrailTypeName(orderType),
            " reason=INVALID_SYMBOL_GEOMETRY",
            " direction=",direction,
            " point=",DoubleToString(point,10),
            " pip=",DoubleToString(pip,10));
      return true;
     }

   // 1) STOP-kind orders use closed M5 structure, never the forming candle.
   // BUY STOP evaluates each closed candle's HIGH and ratchets its entry up;
   // SELL STOP evaluates each closed candle's LOW and ratchets its entry down.
   // STOP-LIMIT triggers follow the same direction. Candle color is irrelevant;
   // a wick can create a valid favorable extreme. LIMIT orders use live quotes.
   double extreme=0.0;
   datetime actionableClosedBar=0;
   if(candleStop)
     {
      datetime closedBar=iTime(symbol,PERIOD_M5,1);
      if(closedBar<=0)
        {
         Print("PENDING_TRAIL_WAIT ticket=",ticket," symbol=",symbol,
               " type=",STB_PendingTrailTypeName(orderType),
               " reason=M5_CLOSED_BAR_UNAVAILABLE");
         return true;
        }
      if(closedBar==g_stbPendingTrail[idx].lastProcessedM5Bar)
         return true;

      double barOpen=iOpen(symbol,PERIOD_M5,1);
      double barClose=iClose(symbol,PERIOD_M5,1);
      double barLow=iLow(symbol,PERIOD_M5,1);
      double barHigh=iHigh(symbol,PERIOD_M5,1);
      bool ohlcFinite=(MathIsValidNumber(barOpen) &&
                       MathIsValidNumber(barClose) &&
                       MathIsValidNumber(barLow) &&
                       MathIsValidNumber(barHigh));
      bool ohlcPositive=(barOpen>0.0 && barClose>0.0 &&
                         barLow>0.0 && barHigh>0.0);
      bool ohlcOrdered=(barLow<=barHigh &&
                        barLow<=MathMin(barOpen,barClose) &&
                        barHigh>=MathMax(barOpen,barClose));
      if(!ohlcFinite || !ohlcPositive || !ohlcOrdered)
        {
         Print("PENDING_TRAIL_WAIT ticket=",ticket," symbol=",symbol,
               " type=",STB_PendingTrailTypeName(orderType),
               " reason=M5_OHLC_INVALID",
               " finite=",ohlcFinite,
               " positive=",ohlcPositive,
               " ordered=",ohlcOrdered,
               " open=",DoubleToString(barOpen,10),
               " close=",DoubleToString(barClose,10),
               " low=",DoubleToString(barLow,10),
               " high=",DoubleToString(barHigh,10));
         return true;
        }

      // Candle color is not a trailing criterion: either wick may improve the
      // anchor. BUY-side STOP kinds track highs; SELL-side STOP kinds track lows.
      // Commit this bar only after a no-change decision or confirmed write;
      // resolver/writer failures leave it retryable under bounded backoff.
      actionableClosedBar=closedBar;
      extreme=(STB_PendingIsBuySide((ENUM_ORDER_TYPE)orderType) ? barHigh:barLow);
     }
   else
     {
      MqlTick liveTick;
      if(!SymbolInfoTick(symbol,liveTick))
        {
         Print("PENDING_TRAIL_WAIT ticket=",ticket," symbol=",symbol,
               " type=",STB_PendingTrailTypeName(orderType),
               " reason=LIVE_TICK_UNAVAILABLE");
         return true;
        }
      extreme=(direction>0 ? liveTick.bid:liveTick.ask);
     }

   if(extreme<=0.0)
     {
      Print("PENDING_TRAIL_WAIT ticket=",ticket," symbol=",symbol,
            " type=",STB_PendingTrailTypeName(orderType),
            " reason=EXTREME_INVALID",
            " extreme=",DoubleToString(extreme,10));
      return true;
     }

   // Monotonic anchor policy is type-specific:
   // STOP kinds follow breakout direction (BUY high up, SELL low down).
   // LIMIT kinds retain pullback direction (BUY low down, SELL high up).
   bool isNewExtreme=false;

   if(candleStop)
     {
      if(direction>0)
         isNewExtreme=(extreme > g_stbPendingTrail[idx].trackedExtreme+point*0.5);
      else
         isNewExtreme=(extreme < g_stbPendingTrail[idx].trackedExtreme-point*0.5);
     }
   else if(direction>0)
      isNewExtreme=(extreme < g_stbPendingTrail[idx].trackedExtreme-point*0.5);
   else
      isNewExtreme=(extreme > g_stbPendingTrail[idx].trackedExtreme+point*0.5);

   if(!isNewExtreme)
   {
      // This closed candle produced no favorable new extreme. It is safe to
      // consume; a later candle will provide a new anchor.
      if(candleStop && actionableClosedBar>0)
         g_stbPendingTrail[idx].lastProcessedM5Bar=actionableClosedBar;

      Print("PENDING_TRAIL_WAIT ticket=",ticket," symbol=",symbol,
            " type=",STB_PendingTrailTypeName(orderType),
            " reason=NO_NEW_EXTREME",
            " extreme=",DoubleToString(extreme,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " trackedExtreme=",DoubleToString(g_stbPendingTrail[idx].trackedExtreme,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
      STB_PendingTrailLogNoNewExtreme(ticket,symbol,
                                      STB_PendingTrailFind(ticket));
      return true;
   }

   // 3) Build a PROPOSAL: resolve entry + SL via the immutable metadata.
   STBPendingResolution res;

   bool resolved=
      STB_ResolvePendingDistance(symbol,
                                 (ENUM_ORDER_TYPE)g_stbPendingTrail[idx].orderType,
                                 extreme,
                                 g_stbPendingTrail[idx].entryBufferPips,
                                 res,
                                 g_stbPendingTrail[idx].slBufferPips,
                                 STB_PendingIsStopKind((ENUM_ORDER_TYPE)g_stbPendingTrail[idx].orderType)
                                 ? OrderGetDouble(ORDER_PRICE_OPEN):0.0);

   // Do not fabricate a synthetic candle extreme merely to push a pending
   // STOP beyond the current market. If the true candle-derived geometry is
   // currently invalid, retain the real extreme and retry after bounded
   // backoff; the resolver will re-evaluate it against the latest quote.

   if(!resolved || !res.valid)
   {
      datetime bar=iTime(symbol,PERIOD_M15,1);

      if(bar<=0)
         bar=TimeCurrent();

      bool noFavorableEntry=
         (res.reason=="BUY_STOP_NO_FAVORABLE_VALID_ENTRY" ||
          res.reason=="SELL_STOP_NO_FAVORABLE_VALID_ENTRY");

      if(g_stbPendingTrail[idx].lastFailLogBar!=bar)
      {
         g_stbPendingTrail[idx].lastFailLogBar=bar;

         if(noFavorableEntry)
            Print("PENDING_TRAIL_WAIT ticket=",IntegerToString((int)ticket),
                  " symbol=",symbol,
                  " type=",STB_PendingTrailTypeName(orderType),
                  " reason=",res.reason,
                  " extreme=",DoubleToString(extreme,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
                  " currentEntry=",DoubleToString(OrderGetDouble(ORDER_PRICE_OPEN),
                                                   (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
         else
            Print("PENDING_TRAIL_MODIFY_FAILED ticket=",IntegerToString((int)ticket),
                  " symbol=",symbol,
                  " type=",STB_PendingTrailTypeName(orderType),
                  " stage=RESOLVE",
                  " reason=",res.reason);
      }

      // A no-favorable-entry condition is transient: retry at a short fixed
      // interval without treating it as repeated broker failure. Keep the bar
      // unconsumed so the same structural anchor can be re-evaluated if quotes
      // move back into a valid, monotonic geometry window.
      if(noFavorableEntry)
        {
         g_stbPendingTrail[idx].nextRetryTime=
            TimeCurrent()+STB_PEND_BACKOFF_1_SEC;
         return true;
        }

      // Other resolver failures retain bounded backoff. Retry with the same bounded 5/15/60s policy.
      // The actionable M5 bar remains unconsumed so broker geometry can recover.
      g_stbPendingTrail[idx].failureCount++;
      int fc=g_stbPendingTrail[idx].failureCount;
      int backoffSec=(fc<=1 ? STB_PEND_BACKOFF_1_SEC
                            : (fc==2 ? STB_PEND_BACKOFF_2_SEC
                                     : STB_PEND_BACKOFF_3_SEC));
      g_stbPendingTrail[idx].nextRetryTime=TimeCurrent()+backoffSec;
      return true;
   }

   STBPendingGeometryProposal prop;
   ZeroMemory(prop);
   prop.valid=true;
   prop.entry=res.entry;
   prop.sl=res.sl;
   prop.tp=OrderGetDouble(ORDER_TP);
   prop.source=STB_PEND_SRC_TRAIL;
   prop.reason=res.reason;

   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);

   // Match the central step gate before submitting, so an insignificant
   // proposal consumes its candle instead of being recalculated each tick.
   double currentEntry=OrderGetDouble(ORDER_PRICE_OPEN);
   double currentSL=OrderGetDouble(ORDER_SL);
   double step=MathMax(0.0,InpTrailStepPips)*pip;
   if(candleStop && step>0.0 &&
      MathAbs(prop.entry-currentEntry)<step &&
      MathAbs(prop.sl-currentSL)<step)
     {
      // The proposal is intentionally too small to send, but the candle's
      // favorable extreme is still valid market information. Consume the bar
      // AND advance the anchor together; otherwise the next candle can be
      // resolved from a stale extreme that no longer matches the current
      // pending entry, causing repeated NO_FAVORABLE_VALID_ENTRY deferrals.
      g_stbPendingTrail[idx].lastProcessedM5Bar=actionableClosedBar;
      if(direction>0)
         g_stbPendingTrail[idx].trackedExtreme=
            MathMax(g_stbPendingTrail[idx].trackedExtreme,extreme);
      else
         g_stbPendingTrail[idx].trackedExtreme=
            MathMin(g_stbPendingTrail[idx].trackedExtreme,extreme);
      Print("PENDING_TRAIL_WAIT ticket=",ticket," symbol=",symbol,
            " type=",STB_PendingTrailTypeName(orderType),
            " reason=STEP_GATE",
            " entryDelta=",DoubleToString(MathAbs(prop.entry-currentEntry)/pip,2),
            " slDelta=",DoubleToString(MathAbs(prop.sl-currentSL)/pip,2),
            " trackedExtreme=",DoubleToString(g_stbPendingTrail[idx].trackedExtreme,digits),
            " stepPips=",DoubleToString(InpTrailStepPips,2));
      return true;
     }

   // 4) Forward the proposal to the central submit gate. A failed broker
   //    write leaves the action bar unconsumed, so a later cycle can retry.
   ResetLastError();
   string submitGateReason="";
   bool committed=STB_SubmitPendingTrailGeometry(ticket,
                                                 prop.entry,
                                                 prop.sl,
                                                 prop.tp,
                                                 submitGateReason,
                                                 manual);

   if(!committed)
     {
      int writerIdx=STB_PendingTrailFind(ticket);
      int failures=(writerIdx>=0 ? g_stbPendingTrail[writerIdx].failureCount:0);
      datetime retryAt=(writerIdx>=0 ? g_stbPendingTrail[writerIdx].nextRetryTime:0);

      // A throttle/backoff/step rejection is an intentional local wait, not
      // a broker modification failure. Do not report stale ResultRetcode=0
      // or an unchanged failure counter as if a trade request had failed.
      if(submitGateReason=="BACKOFF_ACTIVE" ||
         submitGateReason=="COOLDOWN_ACTIVE" ||
         submitGateReason=="STEP_GATE" ||
         submitGateReason=="STATE_INACTIVE" ||
         submitGateReason=="ORDER_GONE")
         Print("PENDING_TRAIL_WAIT ticket=",ticket,
               " symbol=",symbol,
               " type=",STB_PendingTrailTypeName(orderType),
               " reason=",submitGateReason,
               " proposedEntry=",DoubleToString(prop.entry,digits),
               " proposedSL=",DoubleToString(prop.sl,digits),
               " currentEntry=",DoubleToString(currentEntry,digits),
               " currentSL=",DoubleToString(currentSL,digits),
               " failureCount=",failures,
               " retryAt=",(string)retryAt);
      else
         Print("PENDING_TRAIL_MODIFY_FAILED ticket=",ticket,
               " symbol=",symbol,
               " type=",STB_PendingTrailTypeName(orderType),
               " stage=SUBMIT",
               " reason=",submitGateReason,
               " proposedEntry=",DoubleToString(prop.entry,digits),
               " proposedSL=",DoubleToString(prop.sl,digits),
               " currentEntry=",DoubleToString(currentEntry,digits),
               " currentSL=",DoubleToString(currentSL,digits),
               " failureCount=",failures,
               " retryAt=",(string)retryAt);
      // Do not print GetLastError()/trade.ResultRetcode() here: this caller
      // cannot know whether a broker request was made, and these values may
      // be stale. The central writer logs broker codes at the request boundary.
     }

   if(committed)
   {
      if(candleStop && actionableClosedBar>0)
         g_stbPendingTrail[idx].lastProcessedM5Bar=actionableClosedBar;

      // Advance the anchor only in the type's favorable direction.
      // STOP-kind: BUY high watermark increases; SELL low watermark decreases.
      // LIMIT-kind: BUY low watermark decreases; SELL high watermark increases.
      if(candleStop)
        {
         if(direction>0)
            g_stbPendingTrail[idx].trackedExtreme=
               MathMax(g_stbPendingTrail[idx].trackedExtreme,extreme);
         else
            g_stbPendingTrail[idx].trackedExtreme=
               MathMin(g_stbPendingTrail[idx].trackedExtreme,extreme);
        }
      else if(direction>0)
         g_stbPendingTrail[idx].trackedExtreme=
            MathMin(g_stbPendingTrail[idx].trackedExtreme,extreme);
      else
         g_stbPendingTrail[idx].trackedExtreme=
            MathMax(g_stbPendingTrail[idx].trackedExtreme,extreme);

      Print("PENDING_TRAIL_UPDATE ticket=",IntegerToString((int)ticket),
            " symbol=",symbol,
            " type=",STB_PendingTrailTypeName(orderType),
            " entry=",DoubleToString(prop.entry,digits),
            " sl=",DoubleToString(prop.sl,digits),
            " trackedExtreme=",DoubleToString(g_stbPendingTrail[idx].trackedExtreme,digits));
   }

   return true;
}

//--- Per-cycle processing (OnTick / OnTimer with cycle dedup) ---------
int STB_PendingTrailProcess(const bool manual=false)
{
   STB_PendingTrailPruneInactive();
   g_stbPendingTrailCycle++;
   int moved=0;

   // Registration pass: TERMINAL-SCAN every managed pending order type that
   // is not yet tracked (multi-ticket + manual/mobile/other-EA discovery).
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);

      if(ticket==0)
         continue;

      if(!OrderSelect(ticket))
         continue;

      if(!STB_PendingTrailIsManagedType(OrderGetInteger(ORDER_TYPE)))
         continue;

      if(!IsManagedOrder(ticket))
         continue;

      if(STB_PendingTrailFind(ticket)>=0)
         continue;

      STB_PendingTrailRegister(ticket,"TERMINAL_SCAN");
   }

   // Manage pass: maximum ONE modify per ticket per cycle.
   for(int i=0;i<ArraySize(g_stbPendingTrail);i++)
   {
      if(!g_stbPendingTrail[i].active)
         continue;

      if(g_stbPendingTrail[i].lastProcessedCycle==g_stbPendingTrailCycle)
         continue;

      ulong ticket=g_stbPendingTrail[i].ticket;

      // Count only a terminal-confirmed geometry change. lastModifyTime has
      // one-second resolution, so timestamp comparisons can miss a successful
      // same-second update and can count a broker-confirmed NO_CHANGE as moved.
      bool hadBefore=OrderSelect(ticket);
      long typeBefore=-1;
      string symbolBefore="";
      double entryBefore=0.0,slBefore=0.0,tpBefore=0.0,stopLimitBefore=0.0;
      if(hadBefore)
      {
         typeBefore=OrderGetInteger(ORDER_TYPE);
         symbolBefore=OrderGetString(ORDER_SYMBOL);
         entryBefore=OrderGetDouble(ORDER_PRICE_OPEN);
         slBefore=OrderGetDouble(ORDER_SL);
         tpBefore=OrderGetDouble(ORDER_TP);
         stopLimitBefore=OrderGetDouble(ORDER_PRICE_STOPLIMIT);
      }

      g_stbPendingTrail[i].lastProcessedCycle=g_stbPendingTrailCycle;
      STB_PendingTrailManageOne(ticket,manual);

      if(hadBefore && OrderSelect(ticket) &&
         OrderGetInteger(ORDER_TYPE)==typeBefore &&
         OrderGetString(ORDER_SYMBOL)==symbolBefore)
      {
         double point=SymbolInfoDouble(symbolBefore,SYMBOL_POINT);
         double tickSize=SymbolInfoDouble(symbolBefore,SYMBOL_TRADE_TICK_SIZE);
         double tolerance=MathMax(point*0.5,
                                  tickSize>0.0 ? tickSize*0.5:point*0.5);
         if(point>0.0 && tolerance>0.0 &&
            (MathAbs(OrderGetDouble(ORDER_PRICE_OPEN)-entryBefore)>tolerance ||
             MathAbs(OrderGetDouble(ORDER_SL)-slBefore)>tolerance ||
             MathAbs(OrderGetDouble(ORDER_TP)-tpBefore)>tolerance ||
             MathAbs(OrderGetDouble(ORDER_PRICE_STOPLIMIT)-stopLimitBefore)>tolerance))
            moved++;
      }
   }

   STB_PendingTrailPruneInactive();
   return moved;
}

//--- Trigger handoff -------------------------------------------------
void STB_PendingTrailOnOrderFilled(const ulong ticket)
{
   if(ticket==0)
      return;

   int idx=STB_PendingTrailFind(ticket);

   if(idx<0 || !g_stbPendingTrail[idx].active)
      return;

   // DEAL_ADD can represent a partial fill. If the original pending ticket
   // still exists in the active-order pool, keep its trail state alive for
   // the unfilled remainder; only hand off after the pending order is gone.
   // Transaction arrival order is not assumed: the next manager pass will
   // also deactivate stale state if the order disappears after this check.
   if(OrderSelect(ticket) &&
      IsManagedOrder(ticket) &&
      STB_PendingTrailIsManagedType(OrderGetInteger(ORDER_TYPE)))
   {
      Print("PENDING_PARTIAL_FILL_REMAINDER ticket=",IntegerToString((int)ticket),
            " symbol=",OrderGetString(ORDER_SYMBOL),
            " remainingVolume=",DoubleToString(OrderGetDouble(ORDER_VOLUME_CURRENT),2),
            " action=KEEP_TRAIL_ACTIVE");
      return;
   }

   Print("PENDING_TRIGGERED ticket=",IntegerToString((int)ticket),
         " symbol=",g_stbPendingTrail[idx].symbol,
         " type=",STB_PendingTrailTypeName(g_stbPendingTrail[idx].orderType));

   Print("PENDING_TRAIL_STOPPED ticket=",IntegerToString((int)ticket),
         " symbol=",g_stbPendingTrail[idx].symbol,
         " handoff=TRADE_MANAGEMENT");

   g_stbPendingTrail[idx].active=false;
}

//--- Restart recovery -------------------------------------------------
// Registers / reconstructs state from terminal orders for every managed
// pending type (EA-created, manual/mobile, other-EA, pre-existing). It NEVER
// modifies an order by itself: a proposal is only produced when the live
// market creates a new favorable extreme (see STB_PendingTrailManageOne).
int STB_PendingTrailRebuildFromTerminal()
{
   STB_PendingTrailClear();

   int recovered=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);

      if(ticket==0)
         continue;

      if(!OrderSelect(ticket))
         continue;

      if(!STB_PendingTrailIsManagedType(OrderGetInteger(ORDER_TYPE)))
         continue;

      if(!IsManagedOrder(ticket))
         continue;

      string symbol=OrderGetString(ORDER_SYMBOL);

      if(STB_PendingTrailRegister(ticket,"RESTART_RECOVERY"))
      {
         recovered++;
         Print("PENDING_RECOVERED ticket=",IntegerToString((int)ticket),
               " symbol=",symbol,
               " type=",STB_PendingTrailTypeName(
                  OrderGetInteger(ORDER_TYPE)));
      }
   }

   return recovered;
}

#endif

// ===== END INLINED MODULE =====

void STB_RecordPendingInitialSLFailure(const int stateIdx)
  {
   if(stateIdx<0 || stateIdx>=ArraySize(g_stbPendingTrail))
      return;

   g_stbPendingTrail[stateIdx].failureCount++;

   int fc=g_stbPendingTrail[stateIdx].failureCount;
   int backoffSec=(fc<=1 ? STB_PEND_BACKOFF_1_SEC
                         : (fc==2 ? STB_PEND_BACKOFF_2_SEC
                                  : STB_PEND_BACKOFF_3_SEC));

   g_stbPendingTrail[stateIdx].nextRetryTime=TimeCurrent()+backoffSec;
  }

//==================================================================
// COMMON POST-CREATION POINT (MASTER BLUEPRINT 10/11)
//==================================================================
// Every creator calls this exactly once after the broker confirmed the
// ticket: Register + Initial Protection. Trade management itself runs ONLY
// inside STB_RunManagementCycle().
//==================================================================
// CENTRAL DELETE PATH (MASTER BLUEPRINT 34) - the ONLY OrderDelete writer
//==================================================================
enum ENUM_STB_DELETE_REASON
  {
   STB_DEL_AUTO_ROLLBACK=0,          // creator rollback (server accept but invalid)
   STB_DEL_SERVER_ACCEPT_INVALID=1,  // accepted then rejected geometry
   STB_DEL_EXPLICIT_USER_COMMAND=2,  // user-issued delete
   STB_DEL_SERVER_EXPIRATION=3,      // server-side explicit expiration
   STB_DEL_EXPLICIT_CLEANUP=4,       // housekeeping cleanup
   STB_DEL_DAILY_RISK_GUARD=5        // daily equity-loss circuit breaker
  };

bool STB_ExecuteOrderDelete(const ulong ticket,
                            const ENUM_STB_DELETE_REASON reason,
                            const string source)
  {
   if(ticket==0 || !OrderSelect(ticket))
      return false;

   ENUM_ORDER_TYPE deleteType=(ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   bool isPending=(deleteType==ORDER_TYPE_BUY_LIMIT ||
                   deleteType==ORDER_TYPE_SELL_LIMIT ||
                   deleteType==ORDER_TYPE_BUY_STOP ||
                   deleteType==ORDER_TYPE_SELL_STOP ||
                   deleteType==ORDER_TYPE_BUY_STOP_LIMIT ||
                   deleteType==ORDER_TYPE_SELL_STOP_LIMIT);
   if(!isPending)
      return false;

   string orderComment=OrderGetString(ORDER_COMMENT);
   datetime setupTime=(datetime)OrderGetInteger(ORDER_TIME_SETUP);
   ENUM_ORDER_TYPE_TIME timeType=(ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
   datetime expiry=(datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
   bool stbComment=(StringFind(orderComment,"STB|")==0);
   bool hedgeCreated=(StringFind(orderComment,"STB|HEDGE|")==0);
   bool autoCreated=(StringFind(orderComment,"STB|B|")==0 ||
                     StringFind(orderComment,"STB|S|")==0);
   bool authorized=false;

   if(reason==STB_DEL_AUTO_ROLLBACK || reason==STB_DEL_SERVER_ACCEPT_INVALID)
     {
      bool knownCreator=(source=="OneClickHedge" ||
                         source=="PlaceSetup" ||
                         source=="PlaceManual");
      // Rollback is narrowly scoped to a fresh STB order. Manual orders may
      // use magic 0, so the explicit STB comment + exact creator source is
      // the authorization signal rather than magic number alone.
      bool creatorCommentMatches=
         (source=="OneClickHedge" && hedgeCreated) ||
         (source=="PlaceSetup" && autoCreated) ||
         (source=="PlaceManual" &&
          StringFind(orderComment,"STB|M|")==0);
      authorized=knownCreator && stbComment && creatorCommentMatches &&
                 setupTime>0 && setupTime<=TimeCurrent()+5 &&
                 TimeCurrent()-setupTime<=120;
     }
   else if(reason==STB_DEL_SERVER_EXPIRATION)
     {
      // Expiry deletion is only valid through the owned pending manager.
      // Recheck scope and lease at the final writer boundary, not only in
      // ManagePendingOrders before it calls this function.
      string symbol=OrderGetString(ORDER_SYMBOL);
      bool expiryAuthority=(source=="ManagePendingOrders" &&
                           IsManagedOrder(ticket) &&
                           STB_SymbolManagementOwnedVerified(symbol));
      if(expiryAuthority)
        {
         bool serverExpired=(timeType==ORDER_TIME_SPECIFIED &&
                             expiry>0 && TimeCurrent()>=expiry);
         bool localAgeExpired=false;
         if(autoCreated && !STB_ManualOverrideIs(ticket) && setupTime>0)
           {
            int maxBars=InpMaxPendingBars;
            int profileId=STB_AdaptiveParseProfileFromComment(orderComment);
            if(profileId>=0 && profileId<STB_ADAPTIVE_PROFILE_COUNT)
              {
               STB_AP_SetActive(profileId);
               maxBars=STB_EffectiveMaxPendingBars();
               STB_AP_ClearActive();
              }
            localAgeExpired=(maxBars>0 &&
                             TimeCurrent()-setupTime>=maxBars*15*60);
           }
         // Server expiry remains honored for allowed managed orders;
         // local-age expiry remains restricted to unoverridden EA creations.
         authorized=serverExpired || localAgeExpired;
        }
     }

   else if(reason==STB_DEL_DAILY_RISK_GUARD)
     {
      // Daily-risk cancellation is not a creator rollback: it must work for
      // aged pending orders and must be re-authorized at the central writer.
      // Include EA-owned magic orders and this EA's UI-manual orders (magic 0,
      // STB|M| comment); never delete unrelated magic-0 terminal orders.
      string symbol=OrderGetString(ORDER_SYMBOL);
      long orderMagic=OrderGetInteger(ORDER_MAGIC);
      bool eaOwned=(orderMagic==(long)InpMagic);
      bool eaUiManual=(orderMagic==0 &&
                       StringFind(orderComment,"STB|M|")==0);
      authorized=(source=="DailyLossGuard" &&
                  (eaOwned || eaUiManual) &&
                  IsManagedOrder(ticket) &&
                  STB_SymbolManagementOwnedVerified(symbol));
     }

   if(!authorized)
     {
      Print("STB DELETE BLOCKED ticket=",IntegerToString((int)ticket),
            " reason=",IntegerToString((int)reason),
            " source=",source,
            " comment=",orderComment,
            " reason=UNAUTHORIZED_OR_UNVERIFIED");
      return false;
     }

   trade.SetAsyncMode(false);
   trade.SetExpertMagicNumber(InpMagic);

   bool requestOK=trade.OrderDelete(ticket);
   uint ret=trade.ResultRetcode();
   string retText=trade.ResultRetcodeDescription();

   // CTrade::OrderDelete returning true only confirms the local request
   // structure. Require both a server-success retcode and disappearance of
   // this active ticket before treating deletion as complete.
   if(!requestOK || ret!=TRADE_RETCODE_DONE)
     {
      Print("STB DELETE REJECTED ticket=",IntegerToString((int)ticket),
            " reason=",IntegerToString((int)reason),
            " source=",source,
            " ret=",ret," ",retText,
            " requestOK=",requestOK ? "YES":"NO");
      return false;
     }

   if(OrderSelect(ticket))
     {
      Print("STB DELETE NOT CONFIRMED ticket=",IntegerToString((int)ticket),
            " reason=",IntegerToString((int)reason),
            " source=",source,
            " ret=",ret," ",retText,
            " reason=ORDER_STILL_ACTIVE");
      return false;
     }

   Print("STB DELETE CONFIRMED ticket=",IntegerToString((int)ticket),
         " reason=",IntegerToString((int)reason),
         " source=",source,
         " ret=",ret);
   return true;
  }

// Single controlled entry used by every permitted pending delete.
bool STB_RequestOrderDelete(const ulong ticket,
                            const ENUM_STB_DELETE_REASON reason,
                            const string source)
  {
   return STB_ExecuteOrderDelete(ticket,reason,source);
  }

void STB_AfterExposureCreated(const ulong ticket,const string source)
  {
   if(ticket==0)
      return;

   if(OrderSelect(ticket) && IsManagedOrder(ticket))
     {
      string symbol=OrderGetString(ORDER_SYMBOL);
      if(symbol=="")
         return;
      SymbolSelect(symbol,true);
      if(!STB_SymbolManagementOwnedVerified(symbol))
         return;
      STB_PendingTrailRegister(ticket,source);
      EnsureInitialSLForPendingOrder(ticket);
      if(OrderSelect(ticket) &&
         OrderGetDouble(ORDER_SL)>0.0 &&
         OrderGetDouble(ORDER_TP)<=0.0)
         EnsureInitialTPForPendingOrder(ticket);
      return;
     }

   if(PositionSelectByTicket(ticket) && STB_IsProtectionPosition(ticket))
     {
      string symbol=PositionGetString(POSITION_SYMBOL);
      if(symbol=="")
         return;
      SymbolSelect(symbol,true);
      if(!STB_SymbolManagementOwnedVerified(symbol))
         return;
      EnsureInitialSL(ticket);
      if(PositionSelectByTicket(ticket) &&
         PositionGetDouble(POSITION_SL)>0.0 &&
         PositionGetDouble(POSITION_TP)<=0.0)
         EnsureInitialTPForPosition(ticket);
      return;
     }
  }

// Enforce the daily equity guard for automatic entries. Explicit UI-manual
// pending orders and manual button actions bypass this entry gate; automatic EA
// pending orders are canceled while normal position protection continues. Broker rejection,
// gaps, and slippage mean this guard is not a guaranteed maximum-loss boundary.
void STB_EnforceDailyRiskGuard()
  {
   bool riskBlocked=STB_DailyLossLimitHit();
   // Missing/corrupt risk state blocks new entries and cancels pending entries,
   // but it must never be treated as a verified loss breach for liquidation.
   if(!riskBlocked)
      return;

   // Preserve historical tester liquidation only for a verified threshold breach.
   // In terminal/demo/live runtime, existing positions remain under normal
   // protection; managed EA pending entries are canceled to avoid new exposure.
   if(MQLInfoInteger(MQL_TESTER) && g_stbDailyLossThresholdReached)
     {
      for(int i=PositionsTotal()-1;i>=0;i--)
        {
         ulong ticket=PositionGetTicket(i);
         if(ticket==0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC)!=(long)InpMagic)
            continue;

         string symbol=PositionGetString(POSITION_SYMBOL);
         if(!STB_SymbolManagementOwnedVerified(symbol))
            continue;

         trade.SetExpertMagicNumber(InpMagic);
         trade.SetAsyncMode(false);
         ResetLastError();
         bool closeOK=trade.PositionClose(ticket);
         uint closeRetcode=trade.ResultRetcode();

         if(!closeOK || closeRetcode!=TRADE_RETCODE_DONE)
           {
            Print("STB DAILY GUARD CLOSE FAILED ticket=",ticket,
                  " symbol=",symbol,
                  " requestOK=",closeOK ? "YES":"NO",
                  " retcode=",IntegerToString((int)closeRetcode),
                  " description=",trade.ResultRetcodeDescription(),
                  " error=",GetLastError());
            continue;
           }

         if(PositionSelectByTicket(ticket))
            Print("STB DAILY GUARD CLOSE UNCONFIRMED ticket=",ticket,
                  " symbol=",symbol,
                  " retcode=",IntegerToString((int)closeRetcode));
         else
            Print("STB DAILY GUARD POSITION CLOSED ticket=",ticket,
                  " symbol=",symbol);
        }
     }

   // In both modes, prevent managed EA pending entries from triggering after
   // the daily risk threshold is reached.
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong ticket=OrderGetTicket(i);
      if(ticket==0 || !OrderSelect(ticket))
         continue;
      long orderMagic=OrderGetInteger(ORDER_MAGIC);
      string orderComment=OrderGetString(ORDER_COMMENT);
      bool eaOwned=(orderMagic==(long)InpMagic);
      bool eaUiManual=(orderMagic==0 &&
                       StringFind(orderComment,"STB|M|")==0);
      // Daily loss guard cancels only automatic EA pending entries.
      // Explicitly placed UI-manual pending orders are left untouched.
      if(!eaOwned || eaUiManual)
         continue;
      if(!IsManagedOrder(ticket))
         continue;

      string symbol=OrderGetString(ORDER_SYMBOL);
      if(!STB_SymbolManagementOwnedVerified(symbol))
         continue;
      if(STB_RequestOrderDelete(ticket,STB_DEL_DAILY_RISK_GUARD,"DailyLossGuard"))
         Print("STB DAILY GUARD cancelled pending order=",ticket,
               " symbol=",symbol);
     }
  }

//==================================================================
// SINGLE MANAGEMENT CYCLE (MASTER BLUEPRINT 31/32/33)
//==================================================================
// The ONLY management decision path. OnTick / OnTimer / OnInit must call
// this and never run a management engine directly.
void STB_RunManagementCycle()
  {
   if(g_stbManagementCycleActive)
     {
      g_stbManagementCyclePending=true;
      return;
     }
   g_stbManagementCycleActive=true;
   int pass=0;
   do
     {
      g_stbManagementCyclePending=false;
      STB_BeginCycle();
      ManagePositions();
      ManagePendingOrders();
      int pendingTrailMoved=STB_PendingTrailProcess();
      // Emit a rate-limited health line when pending orders exist but no broker-
      // confirmed geometry changed. Per-ticket rejection details remain in the
      // PENDING_TRAIL_* / STB PENDING MODIFY messages.
      static datetime lastPendingTrailHealthLog=0;
      int managedPendingCount=CountManagedPendingOrders();
      datetime trailNow=TimeCurrent();
      if(managedPendingCount>0 && pendingTrailMoved==0 &&
         (lastPendingTrailHealthLog<=0 || trailNow<=0 ||
          trailNow-lastPendingTrailHealthLog>=60))
        {
         Print("STB PENDING TRAIL HEALTH",
               " managedPending=",managedPendingCount,
               " confirmedMoved=0",
               " trackedStates=",ArraySize(g_stbPendingTrail),
               " cycle=",IntegerToString((int)g_stbPendingTrailCycle),
               " detail=inspect per-ticket PENDING_TRAIL_WAIT/REJECT/MODIFY logs");
         lastPendingTrailHealthLog=trailNow;
        }
      pass++;
     }
   while(g_stbManagementCyclePending && pass<2);
   g_stbManagementCycleActive=false;
  }

void OnTick()
  {
   STB_EnforceDailyRiskGuard();
   bool m15Bar=NewM15Bar();
   if(m15Bar)
      STB_ReconcileTradeRegistry();
   // Reconcile a newly detected M15-bar exposure before this tick's manager pass.
   STB_RunManagementCycle();
   ulong cycleBefore=g_scannerCycle;
   STB_ScannerRun();
   if(g_scannerCycle!=cycleBefore)
     {
      STB_ExecuteTopCandidate();
      g_lastSignalScanBar=iTime(_Symbol,PERIOD_M15,1);
      UpdatePanel();
     }
  }

//==================================================================
// TIMER
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer()
  {
   STB_EnforceDailyRiskGuard();
   // Recover terminal-visible positions/orders before the manager pass so a
   // missed or delayed transaction handoff can be protected in this timer cycle.
   STB_ReconcileTradeRegistry();
   STB_RunManagementCycle();
   ulong cycleBefore=g_scannerCycle;
   STB_ScannerRun();
   if(g_scannerCycle!=cycleBefore)
     {
      STB_ExecuteTopCandidate();
      g_lastSignalScanBar=iTime(_Symbol,PERIOD_M15,1);
     }
   UpdatePanel();
   UpdateButtons();
  }

//==================================================================
// CHART EVENTS
//==================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
// Trade transaction intake is the single transaction-level protection owner.
   STB_TradeIntakeFromTransaction(trans);

   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD ||
      trans.deal==0 ||
      !HistoryDealSelect(trans.deal))
      return;

   string comment=HistoryDealGetString(trans.deal,DEAL_COMMENT);
   long magic=HistoryDealGetInteger(trans.deal,DEAL_MAGIC);
   long entryType=HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   string symbol=HistoryDealGetString(trans.deal,DEAL_SYMBOL);
   ulong positionId=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);

   // Audit-only realized-result telemetry. Log every exit/partial-exit deal
   // with trading costs so loss analysis can distinguish small wins from
   // oversized losses. This block does not alter trade decisions or controls.
   if(entryType==DEAL_ENTRY_OUT ||
      entryType==DEAL_ENTRY_OUT_BY ||
      entryType==DEAL_ENTRY_INOUT)
     {
      double dealProfit=HistoryDealGetDouble(trans.deal,DEAL_PROFIT);
      double dealCommission=HistoryDealGetDouble(trans.deal,DEAL_COMMISSION);
      double dealSwap=HistoryDealGetDouble(trans.deal,DEAL_SWAP);
      double dealFee=HistoryDealGetDouble(trans.deal,DEAL_FEE);
      double dealNet=dealProfit+dealCommission+dealSwap+dealFee;
      double dealVolume=HistoryDealGetDouble(trans.deal,DEAL_VOLUME);
      double dealPrice=HistoryDealGetDouble(trans.deal,DEAL_PRICE);
      long dealReason=HistoryDealGetInteger(trans.deal,DEAL_REASON);

      // Deal-level net can omit entry-side commission/fees. Also calculate the
      // cumulative net across all currently recorded deals for this position
      // identifier, then restore the original single-deal selection for the
      // remaining transaction handler.
      double positionNetToDate=0.0;
      bool positionNetValid=false;
      if(positionId>0 && HistorySelectByPosition(positionId))
        {
         int positionDeals=HistoryDealsTotal();
         for(int dealIndex=0;dealIndex<positionDeals;dealIndex++)
           {
            ulong historyTicket=HistoryDealGetTicket(dealIndex);
            if(historyTicket==0)
               continue;
            positionNetToDate+=HistoryDealGetDouble(historyTicket,DEAL_PROFIT)
                               +HistoryDealGetDouble(historyTicket,DEAL_COMMISSION)
                               +HistoryDealGetDouble(historyTicket,DEAL_SWAP)
                               +HistoryDealGetDouble(historyTicket,DEAL_FEE);
           }
         positionNetValid=true;
        }
      HistoryDealSelect(trans.deal);

      Print("STB CLOSED DEAL RESULT ticket=",trans.deal,
            " positionId=",positionId,
            " symbol=",symbol,
            " entryType=",EnumToString((ENUM_DEAL_ENTRY)entryType),
            " reason=",EnumToString((ENUM_DEAL_REASON)dealReason),
            " volume=",DoubleToString(dealVolume,8),
            " price=",DoubleToString(dealPrice,(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
            " profit=",DoubleToString(dealProfit,2),
            " commission=",DoubleToString(dealCommission,2),
            " swap=",DoubleToString(dealSwap,2),
            " fee=",DoubleToString(dealFee,2),
            " dealNet=",DoubleToString(dealNet,2),
            " positionNetToDate=",(positionNetValid ? DoubleToString(positionNetToDate,2) : "NA"),
            " magic=",magic);
     }

   // Reconcile per-ticket protection state before filtering by deal magic:
   // a manual/foreign-magic deal can partially or fully close a managed
   // netting position. Preserve state after partial OUT/OUT_BY while the
   // position still exists; clear it on full close or direction reversal.
   if(entryType==DEAL_ENTRY_OUT ||
      entryType==DEAL_ENTRY_OUT_BY ||
      entryType==DEAL_ENTRY_INOUT)
     {
      ulong closedTicket=trans.position;
      if(closedTicket>0)
        {
         bool positionRemains=PositionSelectByTicket(closedTicket);
         bool exposureReversed=(entryType==DEAL_ENTRY_INOUT);
         if(exposureReversed || !positionRemains)
           {
            GlobalVariableDel(TicketLockName(closedTicket));
            GlobalVariableDel(ScopedStateName("MODFAIL_"+(string)closedTicket));
           }
        }
     }

// Hedges use the same magic but are not strategy-profile observations.
   bool isHedge=STB_AdaptiveIsHedgeComment(comment);
   bool isLifecycleClose=(entryType==DEAL_ENTRY_OUT ||
                          entryType==DEAL_ENTRY_OUT_BY ||
                          entryType==DEAL_ENTRY_INOUT);
   bool hasTrackedAdaptiveLifecycle=(positionId>0 &&
                                     STB_AdaptiveReadPositionProfile(positionId)>=0);

   // A manual/foreign-magic partial close still realizes PnL on an existing
   // managed netting lifecycle. Include it only when the position already has
   // an EA adaptive profile; never adopt unrelated foreign trades.
   if(isHedge)
      return;
   if(magic!=(long)InpMagic &&
      !(isLifecycleClose && hasTrackedAdaptiveLifecycle))
      return;

   if(entryType==DEAL_ENTRY_IN && positionId>0)
     {
      long dealType=HistoryDealGetInteger(trans.deal,DEAL_TYPE);
      int direction=(dealType==DEAL_TYPE_BUY ? 1 :
                     dealType==DEAL_TYPE_SELL ? -1 : 0);

      if(direction!=0)
        {
         int profileId=STB_AdaptiveReadOrderProfile(trans.order);

         if(profileId<0)
            profileId=STB_AdaptiveParseProfileFromComment(comment);

         if(profileId<0)
           {
            // Legacy/manual trades without an explicit strategy profile
            // must not contaminate the adaptive learner.
            Print("STB ADAPTIVE skip lifecycle without profile symbol=",
                  symbol," position=",positionId,
                  " order=",trans.order);
            return;
           }

         STB_AdaptiveRememberPositionProfile(positionId,profileId);

         // Start with the planned risk captured when the pending order was
         // created, then prefer risk recalculated from the actual filled position
         // (fill price, filled volume and active initial SL) when it is available.
         double riskMoney=STB_AdaptiveReadOrderRisk(trans.order);
         if(PositionSelectByTicket(trans.position))
           {
            double positionVolume=PositionGetDouble(POSITION_VOLUME);
            double entryPrice=PositionGetDouble(POSITION_PRICE_OPEN);
            double initialSL=PositionGetDouble(POSITION_SL);
            long positionType=PositionGetInteger(POSITION_TYPE);

            if(positionVolume>0.0 && entryPrice>0.0 && initialSL>0.0)
              {
               ENUM_ORDER_TYPE calcType=
                  (positionType==POSITION_TYPE_BUY ?
                   ORDER_TYPE_BUY:ORDER_TYPE_SELL);
               double actualRiskMoney=0.0;

               if(OrderCalcProfit(calcType,symbol,positionVolume,
                                  entryPrice,initialSL,actualRiskMoney))
                 {
                  actualRiskMoney=MathAbs(actualRiskMoney);
                  if(actualRiskMoney>0.0 &&
                     MathIsValidNumber(actualRiskMoney))
                     riskMoney=actualRiskMoney;
                 }
              }
           }

         if(riskMoney>0.0)
            STB_AdaptiveRememberPositionRisk(positionId,riskMoney);

         STB_AdaptiveDeleteOrderState(trans.order);
        }
     }

   if(entryType!=DEAL_ENTRY_OUT &&
      entryType!=DEAL_ENTRY_OUT_BY &&
      entryType!=DEAL_ENTRY_INOUT)
      return;

   double dealPnl=HistoryDealGetDouble(trans.deal,DEAL_PROFIT)+
                  HistoryDealGetDouble(trans.deal,DEAL_SWAP)+
                  HistoryDealGetDouble(trans.deal,DEAL_COMMISSION)+
                  HistoryDealGetDouble(trans.deal,DEAL_FEE);

   int originalDirection=0;
   int profileId=STB_AdaptiveReadPositionProfile(positionId);

   if(entryType==DEAL_ENTRY_INOUT)
     {
      long newType=HistoryDealGetInteger(trans.deal,DEAL_TYPE);

      if(newType==DEAL_TYPE_BUY)
         originalDirection=-1;
      else
         if(newType==DEAL_TYPE_SELL)
            originalDirection=1;

      double priorPnl=GetAccumulatedPositionPnl(positionId);
      TakeAccumulatedPositionPnl(positionId);

      if(originalDirection!=0)
        {
         double lifecyclePnl=priorPnl+dealPnl;
         double riskMoney=STB_AdaptiveReadPositionRisk(positionId);
         double rMultiple=(riskMoney>0.0 ? lifecyclePnl/riskMoney:0.0);

         STB_AdaptiveRecordClosedDeal(symbol,
                                      originalDirection,
                                      lifecyclePnl,
                                      profileId,
                                      rMultiple,
                                      riskMoney>0.0 && MathIsValidNumber(riskMoney));
        }

      // Close the old adaptive lifecycle first. In netting mode an INOUT
      // deal can leave a new position in the opposite direction; that exposure
      // must receive its own profile/risk state rather than inheriting the old
      // lifecycle or remaining untracked.
      int newProfileId=STB_AdaptiveReadOrderProfile(trans.order);
      if(newProfileId<0)
         newProfileId=STB_AdaptiveParseProfileFromComment(comment);
      double newRiskMoney=STB_AdaptiveReadOrderRisk(trans.order);

      STB_AdaptiveDeletePositionProfile(positionId);
      STB_AdaptiveDeletePositionRisk(positionId);

      long incomingDealType=HistoryDealGetInteger(trans.deal,DEAL_TYPE);
      bool activeReversalPosition=false;
      ulong newPositionId=0;
      double newPositionVolume=0.0;
      double newEntryPrice=0.0;
      double newInitialSL=0.0;
      long newPositionType=-1;

      // Position selection by symbol is required because the ticket can change
      // across a netting reversal while the position identifier may persist.
      if(PositionSelect(symbol))
        {
         newPositionId=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
         newPositionVolume=PositionGetDouble(POSITION_VOLUME);
         newEntryPrice=PositionGetDouble(POSITION_PRICE_OPEN);
         newInitialSL=PositionGetDouble(POSITION_SL);
         newPositionType=PositionGetInteger(POSITION_TYPE);

         activeReversalPosition=
            newPositionId>0 &&
            newPositionVolume>0.0 &&
            ((incomingDealType==DEAL_TYPE_BUY &&
              newPositionType==POSITION_TYPE_BUY) ||
             (incomingDealType==DEAL_TYPE_SELL &&
              newPositionType==POSITION_TYPE_SELL));
        }

      if(activeReversalPosition && newProfileId>=0)
        {
         STB_AdaptiveRememberPositionProfile(newPositionId,newProfileId);

         if(newInitialSL>0.0 && newEntryPrice>0.0)
           {
            ENUM_ORDER_TYPE newOrderType=
               (newPositionType==POSITION_TYPE_BUY ?
                ORDER_TYPE_BUY:ORDER_TYPE_SELL);
            double actualRiskMoney=0.0;

            if(OrderCalcProfit(newOrderType,symbol,newPositionVolume,
                               newEntryPrice,newInitialSL,actualRiskMoney))
              {
               actualRiskMoney=MathAbs(actualRiskMoney);
               if(actualRiskMoney>0.0 &&
                  MathIsValidNumber(actualRiskMoney))
                  newRiskMoney=actualRiskMoney;
              }
           }

         if(newRiskMoney>0.0 && MathIsValidNumber(newRiskMoney))
            STB_AdaptiveRememberPositionRisk(newPositionId,newRiskMoney);

         STB_AdaptiveDeleteOrderState(trans.order);
         Print("STB ADAPTIVE reversal lifecycle initialized symbol=",symbol,
               " position=",newPositionId,
               " profile=",newProfileId,
               " riskMoney=",DoubleToString(newRiskMoney,2));
        }
      else
        {
         Print("STB ADAPTIVE reversal lifecycle not initialized symbol=",symbol,
               " oldPosition=",positionId,
               " activePosition=",newPositionId,
               " profile=",newProfileId,
               " active=",activeReversalPosition,
               "; order state retained for reconciliation");
        }
      return;
     }

   double cumulative=dealPnl;

   if(positionId>0)
      cumulative+=GetAccumulatedPositionPnl(positionId);

   if(positionId>0)
      SetAccumulatedPositionPnl(positionId,cumulative);

   bool positionStillOpen=IsPositionIdentifierOpen(positionId);

   if(positionStillOpen)
      return;

   cumulative=TakeAccumulatedPositionPnl(positionId);

   // Terminal-global accumulation can be absent after a restart or a delayed
   // event. When broker history is available, rebuild the closed lifecycle
   // PnL from its OUT/OUT_BY deals rather than trusting volatile aggregation.
   double historyLifecyclePnl=0.0;
   if(STB_SumClosedLifecyclePnlFromHistory(positionId,historyLifecyclePnl))
      cumulative=historyLifecyclePnl;

   if(positionId>0 && HistorySelectByPosition(positionId))
     {
      int deals=HistoryDealsTotal();

      for(int j=0;j<deals;j++)
        {
         ulong d=HistoryDealGetTicket(j);

         if(d==0)
            continue;

         long e=HistoryDealGetInteger(d,DEAL_ENTRY);

         if(e!=DEAL_ENTRY_IN)
            continue;

         long t=HistoryDealGetInteger(d,DEAL_TYPE);

         if(t==DEAL_TYPE_BUY)
           {
            originalDirection=1;
            break;
           }

         if(t==DEAL_TYPE_SELL)
           {
            originalDirection=-1;
            break;
           }
        }
     }

   if(originalDirection==0)
     {
      long closedType=HistoryDealGetInteger(trans.deal,DEAL_TYPE);
      originalDirection=(closedType==DEAL_TYPE_SELL ? 1:-1);
     }

   double riskMoney=STB_AdaptiveReadPositionRisk(positionId);
   double rMultiple=(riskMoney>0.0 ? cumulative/riskMoney:0.0);

   STB_AdaptiveRecordClosedDeal(symbol,
                                originalDirection,
                                cumulative,
                                profileId,
                                rMultiple,
                                riskMoney>0.0 && MathIsValidNumber(riskMoney));

   STB_AdaptiveDeletePositionProfile(positionId);
   STB_AdaptiveDeletePositionRisk(positionId);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Recover a control click when MT5 routes the mouse event to an overlapping chart object
// (for example, a selected line underneath a button). Coordinates are chart-pixel coordinates.
string STB_ControlAtChartXY(const long mouseX,const long mouseY)
  {
   if(mouseX<0 || mouseY<0)
      return "";

   long chartWidth=ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   long chartHeight=ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   if(chartWidth<=0 || chartHeight<=0)
      return "";

   string names[8]=
     {
      g_prefix+"BUY_STOP",g_prefix+"SELL_STOP",g_prefix+"AUTO",
      g_prefix+"SAVE20",g_prefix+"HEDGE",g_prefix+"SELL_LIMIT",
      g_prefix+"BUY_LIMIT",g_prefix+"PEND_TRAIL"
     };

   for(int i=0;i<ArraySize(names);i++)
     {
      string name=names[i];
      if(ObjectFind(0,name)<0)
         continue;
      if(ObjectGetInteger(0,name,OBJPROP_TYPE)!=(long)OBJ_BUTTON)
         continue;

      long xdist=ObjectGetInteger(0,name,OBJPROP_XDISTANCE);
      long ydist=ObjectGetInteger(0,name,OBJPROP_YDISTANCE);
      long width=ObjectGetInteger(0,name,OBJPROP_XSIZE);
      long height=ObjectGetInteger(0,name,OBJPROP_YSIZE);
      long corner=ObjectGetInteger(0,name,OBJPROP_CORNER);
      if(width<=0 || height<=0)
         continue;

      bool fromRight=(corner==CORNER_RIGHT_UPPER || corner==CORNER_RIGHT_LOWER);
      bool fromBottom=(corner==CORNER_LEFT_LOWER || corner==CORNER_RIGHT_LOWER);
      long left=fromRight ? chartWidth-xdist-width : xdist;
      long top=fromBottom ? chartHeight-ydist-height : ydist;

      if(mouseX>=left && mouseX<left+width &&
         mouseY>=top && mouseY<top+height)
         return name;
     }

   return "";
  }

// If a user-selected horizontal/vertical/trend line overlaps a button, MT5 may
// treat a 1-pixel mouse movement as a drag and suppress the button click. Release
// only selected line objects that intersect the cursor while it is over an EA control.
void STB_ReleaseSelectedLineOverControl(const long mouseX,
                                        const long mouseY,
                                        const string controlName)
  {
   int x=(int)mouseX;
   int y=(int)mouseY;
   if(x<0 || y<0 || controlName=="")
      return;

   int subUp=0,subDown=0,subLeft=0,subRight=0;
   datetime timeUp=0,timeDown=0,timeLeft=0,timeRight=0;
   double priceUp=0.0,priceDown=0.0,priceLeft=0.0,priceRight=0.0;
   bool havePriceBand=(y>=3 &&
      ChartXYToTimePrice(0,x,y-3,subUp,timeUp,priceUp) &&
      ChartXYToTimePrice(0,x,y+3,subDown,timeDown,priceDown) &&
      subUp==0 && subDown==0);
   bool haveTimeBand=(x>=3 &&
      ChartXYToTimePrice(0,x-3,y,subLeft,timeLeft,priceLeft) &&
      ChartXYToTimePrice(0,x+3,y,subRight,timeRight,priceRight) &&
      subLeft==0 && subRight==0);

   double lowPrice=MathMin(priceUp,priceDown);
   double highPrice=MathMax(priceUp,priceDown);
   datetime lowTime=(timeLeft<timeRight ? timeLeft:timeRight);
   datetime highTime=(timeLeft>timeRight ? timeLeft:timeRight);
   int released=0;
   int total=ObjectsTotal(0,-1,-1);

   for(int i=total-1;i>=0;i--)
     {
      string name=ObjectName(0,i,-1,-1);
      if(name=="" || name==controlName)
         continue;
      if(ObjectGetInteger(0,name,OBJPROP_SELECTED)==0)
         continue;

      long type=ObjectGetInteger(0,name,OBJPROP_TYPE);
      bool intersects=false;
      if(type==(long)OBJ_HLINE && havePriceBand)
        {
         double linePrice=ObjectGetDouble(0,name,OBJPROP_PRICE,0);
         intersects=(linePrice>=lowPrice && linePrice<=highPrice);
        }
      else if(type==(long)OBJ_VLINE && haveTimeBand)
        {
         datetime lineTime=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,0);
         intersects=(lineTime>=lowTime && lineTime<=highTime);
        }
      else if(type==(long)OBJ_TREND)
        {
         datetime t0=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,0);
         datetime t1=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,1);
         double p0=ObjectGetDouble(0,name,OBJPROP_PRICE,0);
         double p1=ObjectGetDouble(0,name,OBJPROP_PRICE,1);
         int x0=0,y0=0,x1=0,y1=0;
         if(ChartTimePriceToXY(0,0,t0,p0,x0,y0) &&
            ChartTimePriceToXY(0,0,t1,p1,x1,y1))
           {
            double dx=(double)(x1-x0);
            double dy=(double)(y1-y0);
            double len2=dx*dx+dy*dy;
            if(len2>0.0)
              {
               double u=((mouseX-x0)*dx+(mouseY-y0)*dy)/len2;
               if(u<0.0) u=0.0;
               if(u>1.0) u=1.0;
               double px=x0+u*dx;
               double py=y0+u*dy;
               double ex=mouseX-px;
               double ey=mouseY-py;
               intersects=(ex*ex+ey*ey)<=25.0;
              }
           }
        }

      if(intersects)
        {
         if(ObjectSetInteger(0,name,OBJPROP_SELECTED,false))
           {
            released++;
            Print("STB UI OVERLAY LINE RELEASED name=",name,
                  " type=",IntegerToString((int)type),
                  " overControl=",controlName,
                  " x=",IntegerToString(x),
                  " y=",IntegerToString(y));
           }
        }
     }

   if(released>0)
      ChartRedraw(0);
  }

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(id==CHARTEVENT_MOUSE_MOVE)
     {
      string hoveredControl=STB_ControlAtChartXY(lparam,(long)dparam);
      if(hoveredControl!="")
         STB_ReleaseSelectedLineOverControl(lparam,(long)dparam,hoveredControl);
      return;
     }

   // Trace a named control event before name filtering. This separates a UI
   // dispatch defect from a rejected trading request in the Experts log.
   if(id==CHARTEVENT_OBJECT_CLICK && StringFind(sparam,g_prefix)==0)
     {
      long objectType=-1;
      if(ObjectFind(0,sparam)>=0)
         objectType=ObjectGetInteger(0,sparam,OBJPROP_TYPE);

      Print("STB UI OBJECT_CLICK event received name=",sparam,
            " objectType=",IntegerToString((int)objectType),
            " x=",IntegerToString((int)lparam),
            " y=",DoubleToString(dparam,0),
            " chart=",(string)ChartID());
     }

   if(id==CHARTEVENT_CHART_CHANGE) return; // P6 STB-CLEANUP: no rebuild/redraw on chart change


   // Route only named object-click events to avoid dispatching one physical click twice.
   // Keep hit-test rescue below for OBJECT_CLICK events intercepted by another chart object.
   if(id!=CHARTEVENT_OBJECT_CLICK)
      return;

   string clickName=sparam;
   string buyName=g_prefix+"BUY_STOP";
   string sellName=g_prefix+"SELL_STOP";
   string autoName=g_prefix+"AUTO";
   string saveName=g_prefix+"SAVE20";
   string hedgeName=g_prefix+"HEDGE";
   string sellLimitName=g_prefix+"SELL_LIMIT";
   string buyLimitName=g_prefix+"BUY_LIMIT";
   string trailName=g_prefix+"PEND_TRAIL";

   bool recognizedControl=(clickName==buyName || clickName==sellName ||
                           clickName==autoName || clickName==saveName ||
                           clickName==hedgeName || clickName==sellLimitName ||
                           clickName==buyLimitName || clickName==trailName);
   if(!recognizedControl)
     {
      string hitName=STB_ControlAtChartXY(lparam,(long)dparam);
      if(hitName!="")
        {
         Print("STB UI HITTEST FALLBACK eventId=",IntegerToString(id),
               " originalObject=",sparam,
               " mappedControl=",hitName,
               " x=",IntegerToString((int)lparam),
               " y=",DoubleToString(dparam,0),
               " chart=",(string)ChartID());
         clickName=hitName;
         recognizedControl=true;
        }
     }

   if(!recognizedControl)
     {
      if(id==CHARTEVENT_OBJECT_CLICK && StringFind(sparam,g_prefix)==0)
         Print("STB UI CLICK NOT ROUTED name=",sparam,
               " reason=UNRECOGNIZED_CONTROL_NAME",
               " x=",IntegerToString((int)lparam),
               " y=",DoubleToString(dparam,0),
               " expectedPrefix=",g_prefix,
               " chart=",(string)ChartID());
      return;
     }

   if(ObjectFind(0,clickName)>=0)
     {
      ObjectSetInteger(0,clickName,OBJPROP_STATE,false);
      ChartRedraw(0);
     }

   // A single physical click can surface through both event paths on some chart layouts.
   // Suppress only an immediate duplicate for the same control and pixel.
   static ulong lastControlDispatchUs=0;
   static string lastControlDispatchName="";
   static long lastControlDispatchX=-1;
   static long lastControlDispatchY=-1;
   ulong nowUs=GetMicrosecondCount();
   long clickY=(long)dparam;
   if(lastControlDispatchName==clickName &&
      lastControlDispatchX==lparam &&
      lastControlDispatchY==clickY &&
      nowUs>=lastControlDispatchUs &&
      nowUs-lastControlDispatchUs<350000)
     {
      Print("STB UI DUPLICATE CLICK SUPPRESSED object=",clickName,
            " x=",IntegerToString((int)lparam),
            " y=",IntegerToString((int)clickY),
            " chart=",(string)ChartID());
      return;
     }
   lastControlDispatchUs=nowUs;
   lastControlDispatchName=clickName;
   lastControlDispatchX=lparam;
   lastControlDispatchY=clickY;

   Print("STB UI CLICK RECEIVED object=",clickName,
         " sourceEvent=",IntegerToString(id),
         " x=",IntegerToString((int)lparam),
         " y=",IntegerToString((int)clickY),
         " chart=",IntegerToString(ChartID()));
   STB_SetControlStatus("PROCESSING "+clickName+" - see Experts for result.");

   if(clickName==buyName)
     {
      bool ok=PlaceManualPendingDirection(1);
      STB_SetControlStatus(ok ? "BUY STOP ACCEPTED" :
                                 "BUY STOP REJECTED"+STB_ControlRejectSuffix());
      UpdateButtons();
      UpdatePanel();
      ChartRedraw(0);
      return;
     }

   if(clickName==sellName)
     {
      bool ok=PlaceManualPendingDirection(-1);
      STB_SetControlStatus(ok ? "SELL STOP ACCEPTED" :
                                 "SELL STOP REJECTED"+STB_ControlRejectSuffix());
      UpdateButtons();
      UpdatePanel();
      ChartRedraw(0);
      return;
     }

   if(clickName==autoName)
     {
      bool requestedAuto=!g_autoTrading;
      ResetLastError();
      if(GlobalVariableSet(g_autoStateName,requestedAuto ? 1.0 : 0.0)<=0)
        {
         int persistError=GetLastError();
         Print("STB AUTO STATE PERSIST FAILED requested=",requestedAuto ? "ON":"OFF",
               " state unchanged err=",persistError);
         STB_SetControlStatus("AUTO STATE SAVE FAILED - STATE UNCHANGED");
         UpdateButtons();
         UpdatePanel();
         return;
        }
      // Persist the successful AUTO toggle immediately rather than relying on
      // the terminal's eventual shutdown flush.
      GlobalVariablesFlush();
      g_autoTrading=requestedAuto;

      // Manual overrides are released ONLY when AUTO is explicitly enabled.
      // Turning AUTO OFF must not erase a user's persisted per-ticket authority.
      if(g_autoTrading)
         STB_ManualOverrideClearAll();

      STB_SetControlStatus(g_autoTrading ?
                           "AUTO TRADING ENABLED" :
                           "AUTO TRADING DISABLED");

      UpdateButtons();
      UpdatePanel();

      Print("STB AUTO TRADING = ",
            (g_autoTrading ? "ON":"OFF"));
      return;
     }

   if(clickName==saveName)
     {
      ManualSavePlus20();
      STB_SetControlStatus("SAVE +20 PROCESSED - only eligible managed positions change; see Experts log.");
      UpdateButtons();
      UpdatePanel();
      return;
     }

   if(clickName==hedgeName)
     {
      bool ok=OneClickHedge();
      STB_SetControlStatus(ok ? "HEDGE ACCEPTED" :
                                 "HEDGE REJECTED"+STB_ControlRejectSuffix());
      UpdateButtons();
      UpdatePanel();
      return;
     }

   if(clickName==sellLimitName)
     {
      bool ok=PlaceManualLimitDirection(-1);
      STB_SetControlStatus(ok ? "SELL LIMIT ACCEPTED" :
                                 "SELL LIMIT REJECTED"+STB_ControlRejectSuffix());
      UpdateButtons();
      UpdatePanel();
      ChartRedraw(0);
      return;
     }

   if(clickName==buyLimitName)
     {
      bool ok=PlaceManualLimitDirection(1);
      STB_SetControlStatus(ok ? "BUY LIMIT ACCEPTED" :
                                 "BUY LIMIT REJECTED"+STB_ControlRejectSuffix());
      UpdateButtons();
      UpdatePanel();
      ChartRedraw(0);
      return;
     }
   if(clickName==trailName)
     {
      int moved=TrailAllPendingOrdersNow();
      STB_SetControlStatus("PENDING TRAIL MOVED "+
                            IntegerToString(moved)+" ORDER(S)");
      Print("STB PEND TRAIL button moved=",IntegerToString(moved),
            " pending=",IntegerToString(CountManagedPendingOrders()));
      UpdateButtons();
      UpdatePanel();
      ChartRedraw(0);
      return;
     }
  }
//+------------------------------------------------------------------+
