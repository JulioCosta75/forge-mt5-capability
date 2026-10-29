//+------------------------------------------------------------------+
//| ForgeSynthInd.mq5                                                |
//| Synthetic bench indicator: simple moving average of the close.  |
//| Fixed period. One buffer. No signal, no trading.                 |
//+------------------------------------------------------------------+
#property copyright "Forge synthetic bench"
#property version   "1.00"
#property description "SMA(12) of the close for the synthetic bench (P5)."
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_label1  "ForgeSynthSMA12"

#define FORGE_PERIOD 12

double g_sma[];

int OnInit()
  {
   SetIndexBuffer(0, g_sma, INDICATOR_DATA);
   ArraySetAsSeries(g_sma, false);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, FORGE_PERIOD - 1);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   return(INIT_SUCCEEDED);
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   if(rates_total < FORGE_PERIOD)
      return(0);
   ArraySetAsSeries(close, false);
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int i = start; i < rates_total; i++)
     {
      if(i < FORGE_PERIOD - 1)
        {
         g_sma[i] = EMPTY_VALUE;
         continue;
        }
      double sum = 0.0;
      for(int k = 0; k < FORGE_PERIOD; k++)
         sum += close[i - k];
      g_sma[i] = sum / FORGE_PERIOD;
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
