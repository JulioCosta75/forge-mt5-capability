//+------------------------------------------------------------------+
//| ForgeP5Check.mq5                                                 |
//| Synthetic bench test EA for P5: reads ForgeSynthInd by iCustom.  |
//| Records the close and the buffer of each closed bar. No orders.  |
//| Demo Strategy Tester only.                                       |
//+------------------------------------------------------------------+
#property copyright "Forge synthetic bench"
#property version   "1.00"
#property description "P5 check: exports close and ForgeSynthInd buffer per closed bar. No orders."
#property tester_indicator "ForgeSynthInd.ex5"

#define FORGE_FILE "forge_p5_buffers.csv"

int      g_handle   = INVALID_HANDLE;
datetime g_last_bar = 0;
string   g_rows[];

int OnInit()
  {
   g_handle = iCustom(_Symbol, PERIOD_CURRENT, "ForgeSynthInd");
   if(g_handle == INVALID_HANDLE)
      return(INIT_FAILED);
   ArrayResize(g_rows, 0, 1024);
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   if(g_handle != INVALID_HANDLE)
      IndicatorRelease(g_handle);
  }

void OnTick()
  {
   datetime bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(bar == 0 || bar == g_last_bar)
      return;
   g_last_bar = bar;
   double values[];
   if(CopyBuffer(g_handle, 0, 1, 1, values) != 1)
      return;
   double close = iClose(_Symbol, PERIOD_CURRENT, 1);
   datetime closed = iTime(_Symbol, PERIOD_CURRENT, 1);
   if(close <= 0.0 || closed == 0 || values[0] == EMPTY_VALUE)
      return;
   int n = ArraySize(g_rows);
   ArrayResize(g_rows, n + 1, 1024);
   g_rows[n] = StringFormat("%s,%s,%s",
                            TimeToString(closed, TIME_DATE|TIME_MINUTES),
                            DoubleToString(close, _Digits),
                            DoubleToString(values[0], 10));
  }

double OnTester()
  {
   FileDelete(FORGE_FILE);
   int handle = FileOpen(FORGE_FILE, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
      return(0.0);
   FileWriteString(handle, "time,close,sma\r\n");
   for(int i = 0; i < ArraySize(g_rows); i++)
      FileWriteString(handle, g_rows[i] + "\r\n");
   FileClose(handle);
   return((double)ArraySize(g_rows));
  }
//+------------------------------------------------------------------+
