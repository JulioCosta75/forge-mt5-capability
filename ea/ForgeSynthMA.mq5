//+------------------------------------------------------------------+
//| ForgeSynthMA.mq5                                                 |
//| Synthetic bench EA: fixed simple-moving-average crossover.       |
//| No profit claim. Fixed parameters. Minimum lot 0.01.             |
//| Demo Strategy Tester only. No live orders.                       |
//+------------------------------------------------------------------+
#property copyright "Forge synthetic bench"
#property version   "1.00"
#property description "Fixed SMA crossover for the synthetic bench. No profit claim."

#define FORGE_FAST_PERIOD 12
#define FORGE_SLOW_PERIOD 48
#define FORGE_LOT         0.01
#define FORGE_MAGIC       760003
#define FORGE_SLIPPAGE    10

int      g_fast_handle = -1;
int      g_slow_handle = -1;
datetime g_last_bar    = 0;

int OnInit()
  {
   if(FORGE_FAST_PERIOD >= FORGE_SLOW_PERIOD)
      return(INIT_PARAMETERS_INCORRECT);
   if(FORGE_LOT <= 0.0)
      return(INIT_PARAMETERS_INCORRECT);

   g_fast_handle = iMA(_Symbol, PERIOD_CURRENT, FORGE_FAST_PERIOD, 0, MODE_SMA, PRICE_CLOSE);
   g_slow_handle = iMA(_Symbol, PERIOD_CURRENT, FORGE_SLOW_PERIOD, 0, MODE_SMA, PRICE_CLOSE);
   if(g_fast_handle == INVALID_HANDLE || g_slow_handle == INVALID_HANDLE)
      return(INIT_FAILED);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(g_fast_handle != INVALID_HANDLE)
      IndicatorRelease(g_fast_handle);
   if(g_slow_handle != INVALID_HANDLE)
      IndicatorRelease(g_slow_handle);
  }

bool CopyClosedPair(const int handle, double &older, double &newer)
  {
   double values[];
   ArraySetAsSeries(values, false);
   if(CopyBuffer(handle, 0, 1, 2, values) != 2)
      return(false);
   older = values[0];
   newer = values[1];
   return(true);
  }

ENUM_ORDER_TYPE_FILLING FillingMode()
  {
   int mode = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return(ORDER_FILLING_FOK);
   if((mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return(ORDER_FILLING_IOC);
   return(ORDER_FILLING_RETURN);
  }

bool CloseOurs()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != FORGE_MAGIC)
         continue;

      MqlTradeRequest request;
      MqlTradeResult  result;
      ZeroMemory(request);
      ZeroMemory(result);
      request.action    = TRADE_ACTION_DEAL;
      request.position  = ticket;
      request.symbol    = _Symbol;
      request.volume    = PositionGetDouble(POSITION_VOLUME);
      request.magic     = FORGE_MAGIC;
      request.deviation = FORGE_SLIPPAGE;
      request.type_filling = FillingMode();
      long ptype = PositionGetInteger(POSITION_TYPE);
      request.type = (ptype == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price = (request.type == ORDER_TYPE_SELL)
                      ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(!OrderSend(request, result))
         return(false);
      if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_DONE_PARTIAL)
         return(false);
     }
   return(true);
  }

bool OpenDirection(const bool buy)
  {
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);
   request.action       = TRADE_ACTION_DEAL;
   request.symbol       = _Symbol;
   request.volume       = FORGE_LOT;
   request.magic        = FORGE_MAGIC;
   request.deviation    = FORGE_SLIPPAGE;
   request.type         = buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.type_filling = FillingMode();
   request.price        = buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(!OrderSend(request, result))
      return(false);
   return(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_DONE_PARTIAL);
  }

void OnTick()
  {
   datetime bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(bar == 0 || bar == g_last_bar)
      return;
   g_last_bar = bar;

   double fast_older = 0.0;
   double fast_newer = 0.0;
   double slow_older = 0.0;
   double slow_newer = 0.0;
   if(!CopyClosedPair(g_fast_handle, fast_older, fast_newer))
      return;
   if(!CopyClosedPair(g_slow_handle, slow_older, slow_newer))
      return;

   bool cross_up = (fast_older <= slow_older && fast_newer > slow_newer);
   bool cross_down = (fast_older >= slow_older && fast_newer < slow_newer);
   if(cross_up == cross_down)
      return;
   if(!CloseOurs())
      return;
   OpenDirection(cross_up);
  }

// Agent sandbox file (not FILE_COMMON): <data>\Tester\<agent>\MQL5\Files.
double OnTester()
  {
   FileDelete("forge_p3_stats.csv");
   int handle = FileOpen("forge_p3_stats.csv", FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
      return(0.0);
   string body = StringFormat("profit,%s\r\ntrades,%s\r\nequity_dd,%s\r\nbalance_dd,%s\r\n",
                               DoubleToString(TesterStatistics(STAT_PROFIT), 2),
                               DoubleToString(TesterStatistics(STAT_TRADES), 0),
                               DoubleToString(TesterStatistics(STAT_EQUITY_DD), 2),
                               DoubleToString(TesterStatistics(STAT_BALANCE_DD), 2));
   FileWriteString(handle, body);
   FileClose(handle);
   return(0.0);
  }
//+------------------------------------------------------------------+
