//+------------------------------------------------------------------+
//|                                                Impulse-Drive.mq5 |
//|                                     Copyright 2019, nasrudin2458 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

// input parameters
input bool     AllowBuyPositions = false;
input bool     AllowSellPositions= false;
input uchar    MaxPositions      = 3;
input int      MagicNumber       = 2468;
input int      EmaFastPeriod     = 34;
input int      EmaSlowPeriod     = 89;
input int      StopLoss          = 30;
input int      TakeProfit        = 100;

// global declarations
int emafastHandle;                           // handle id of the EmaFast indicator
int emaslowHandle;                           // handle id of the EmaSlow indicotor
double emafastVal[], emaslowVal[];           // Dynamic arrays to hold the values of Moving Averages for each bars
double p_close;                              // Variable to store the close value of a bar
int STP, TKP;                                // To be used for Stop Loss & Take Profit values
int countbuypositions, countsellpositions;   // order counters

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//|   called after activating an expert advisor by dragging on chart |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create Time with an invervall of 60 seconds
   EventSetTimer(60);
   
   // Get handle for indicators
   emafastHandle=iMA(_Symbol, _Period, EmaFastPeriod, 0, MODE_EMA,PRICE_CLOSE);
   emaslowHandle=iMA(_Symbol, _Period, EmaSlowPeriod, 0, MODE_EMA,PRICE_CLOSE);
 
   // error handling invalid handles
   if(emafastHandle<0 || emaslowHandle<0)
      {
      Alert("Error Creating Handles for indicators - error: ",GetLastError(),"!!");
      return(-1);
      }

   // handle asset pairs with 5 or 3 digit prices instead of 4
   STP = StopLoss;
   TKP = TakeProfit;
   if(_Digits==5 || _Digits==3) {
      STP = STP*10;
      TKP = TKP*10;
   }
   return(INIT_SUCCEEDED);
}
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//|   called after deleting an expert advisor from chart             |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //Release indicator handles
   IndicatorRelease(emafastHandle);
   IndicatorRelease(emaslowHandle);
   // Kill timer
   EventKillTimer();   
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//|   recuring call on timer overflow (if timer is defined)          |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Debug message to show timerfunction is working
   //Alert("The time is ",TimeCurrent());
   
}

//+------------------------------------------------------------------+
//| Trade function                                                   |
//|   called on every trade event                                    |
//+------------------------------------------------------------------+
void OnTrade()
{
//---
   
}

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//|   Callback function OrderSend                                    |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
//--- 
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//|   called every time a new price is released on main asset        |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime Old_Time;
   datetime New_Time[1];
   bool IsNewBar=false;

   // copying the last bar time to the element New_Time[0]
   int copied = CopyTime(_Symbol,_Period,0,1,New_Time);
   if(copied > 0) {                    // ok, the data has been copied successfully
      if(Old_Time != New_Time[0]) {    // if old time isn't equal to new bar time
         IsNewBar = true;              // if it isn't a first call, the new bar has appeared
         
         if(MQL5InfoInteger(MQL5_DEBUGGING)) {
            Print("We have new bar here ",New_Time[0]," old time was ",Old_Time);
         }
         Old_Time=New_Time[0];            // saving bar time
      }
   }
   
   else {
      Alert("Error in copying historical times data, error =",GetLastError());
      ResetLastError();
      return;
   }

   // check if new bar is available, quit otherwise
   if(IsNewBar==false) {
      return;
   }

   // Check if enough bars available for correct processing and quit if not
   if(Bars(_Symbol,_Period)<EmaSlowPeriod + 10) {
      Alert("Less bars available than needed for EmaSlow - Exiting.");
      return;
   }
   
   // Define MQL5 Structures used for trade processing
   MqlTick latest_price;      // To be used for getting recent/latest price quotes
   MqlTradeRequest mrequest;  // To be used for sending our trade requests
   MqlTradeResult mresult;    // To be used to get our trade results
   MqlRates mrate[];          // To be used to store the prices, volumes and spread of each bar
   ZeroMemory(mrequest);      // Initialization of mrequest structure

   // Assure that bar and ema values are stored serially similar to timeseries array
   ArraySetAsSeries(mrate,true);
   ArraySetAsSeries(emafastVal,true);
   ArraySetAsSeries(emaslowVal,true);
   
   // Get the last price quote using the MQL5 MqlTick Structure
   if(!SymbolInfoTick(_Symbol,latest_price)) {
      Alert("Error getting the latest price quote - error:",GetLastError(),"!!");
      return;
   }
   
   // Copy new EMA-fast values into buffer 
   if(CopyBuffer(emafastHandle,0,0,3,emafastVal)<0){
      Alert("Error copying EMA fast indicator buffer - error:",GetLastError());
      ResetLastError();
      return;
   }
   // Copy new EMA-slow values into buffer 
   if(CopyBuffer(emaslowHandle,0,0,3,emaslowVal)<0){
      Alert("Error copying EMA losw indicator buffer - error:",GetLastError());
      ResetLastError();
      return;
   }
   
   // check for open positions
   bool Buy_opened=false;  // variable to hold the result of Buy opened position
   bool Sell_opened=false; // variables to hold the result of Sell opened position

   if(PositionSelect(_Symbol)==true) { // we have an opened position
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) {
         Buy_opened=true;  //It is a Buy
      }
      else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL) {
         Sell_opened=true; // It is a Sell
      }
   }
   
   // Copy the bar close price for the previous bar prior to the current bar, that is Bar 1
   p_close=mrate[1].close;  // bar 1 close price

   
}




//+------------------------------------------------------------------+
// functions below are not needed for this EA
//+------------------------------------------------------------------+








//+------------------------------------------------------------------+
//| Tester function                                                  |
//|   Callbackfunction Tester (end of a test series)                 |
//+------------------------------------------------------------------+
double OnTester()
{
//---
   double ret=0.0;
//---
   return(ret);
}

//+------------------------------------------------------------------+
//| TesterInit function                                              |
//+------------------------------------------------------------------+
void OnTesterInit()
{
//---
}

//+------------------------------------------------------------------+
//| TesterPass function                                              |
//+------------------------------------------------------------------+
void OnTesterPass()
{
//---  
}

//+------------------------------------------------------------------+
//| TesterDeinit function                                            |
//+------------------------------------------------------------------+
void OnTesterDeinit()
{
//---  
}

//+------------------------------------------------------------------+
//| ChartEvent                                                       |
//|   Callback ChartEvent, triggered on user input in active chart   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
//--- 
}

//+------------------------------------------------------------------+
//| BookEvent function                                               |
//|   Callback Bookevent - change of market depth                    |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
{
//---  
}


