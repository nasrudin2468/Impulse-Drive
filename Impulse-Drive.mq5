//+------------------------------------------------------------------+
//|                                                Impulse-Drive.mq5 |
//|                                     Copyright 2019, nasrudin2458 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

// input parameters

//input bool     AllowBuyPositions    = true;
//input bool     AllowSellPositions   = true;
//input uchar    MaxPositions         = 3;
input int      EmaFastPeriod        = 34;
input int      EmaSlowPeriod        = 89;
input int      StopLoss             = 30;
input int      TakeProfit           = 100;
input double   TralingSLfactor      = 0.5;      
input double   Lot                  = 0.1;   // Lots to Trade
input int      deviation            = 100;
input int      MagicNumber          = 2468;

// global defines (replace magic numbers)
#define PCLOSED   0                          // no position open 
#define POPEN     10                         // position opened
#define PTRAILING 20                         // position is in trailing stop modus
#define PUNKNOWN  90                         // unknown status, possible malfunction
#define PHALT     100                        // Force-stop EA state machine from further changes - debugging only

// global declarations
int emafastHandle;                           // handle id of the EmaFast indicator
int emaslowHandle;                           // handle id of the EmaSlow indicotor
double emafastVal[], emaslowVal[];           // Dynamic arrays to hold the values of Moving Averages for each bars
double p_close;                              // Variable to store the close value of a bar
double emadifference[2];                     // Stores substraction result of both emas over acual and last value. 
int STP, TKP;                                // To be used for Stop Loss & Take Profit values
int countbuypositions, countsellpositions;   // order counters
double orderprice       = 0;                 // confirmed position order price
double positionticket   = 0;                 // ticket number of position
double ordertakeprofit  = 0;                 // tp value from open order, needs to be given on sl changes
int pstatus = PUNKNOWN;                      // indicates status of trades
                                             //     0: no position open 
                                             //    10: position opened
                                             //    20: position is in trailing stop modus
                                             //    90: unknown status, possible malfunction
bool debughalt = false;   
                                          

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//|   called after activating an expert advisor by dragging on chart |
//+------------------------------------------------------------------+
int OnInit()
{
   // Create Time with an invervall of 60 seconds
   EventSetTimer(60);
   
   // Get handles for indicators
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
   //Alert("DEBUG: OnBookTrade() was called");
}

//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//|   Callback function OrderSendAsync                               |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   //Alert("DEBUG: OnTradeTransaction() was called");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//|   called every time a new price is released on main asset        |
//+------------------------------------------------------------------+
void OnTick()
{
   if (debughalt == true){ return;}
   
   static datetime Old_Time;
   datetime New_Time[1];
   bool IsNewBar = false;

   // copying the last bar time to the element New_Time[0]
   int copied = CopyTime(_Symbol, _Period, 0, 1, New_Time);
   if(copied > 0) {                    // ok, the data has been copied successfully
      if(Old_Time != New_Time[0]) {    // if old time isn't equal to new bar time
         IsNewBar = true;              // if it isn't a first call, the new bar has appeared
         
         if(MQL5InfoInteger(MQL5_DEBUGGING)) {
            Print("We have new bar here ", New_Time[0]," old time was ", Old_Time);
         }
         Old_Time=New_Time[0];            // saving bar time
      }
   }
   
   else {
      Alert("Error in copying historical times data, error =",GetLastError());
      ResetLastError();
      return;
   }

   // Check if enough bars available for correct processing and quit if not
   if(Bars(_Symbol,_Period) < EmaSlowPeriod + 10){
      Alert("Less bars available than needed for EmaSlow - Exiting.");
      return;
   }
   
   if (IsNewBar == false){
   // check if new bar is available, otherwise return
   // reduces advisor call to once/bar. deactivate if calculation should be done per tick
      return;
   }
   
   // Define MQL5 Structures used for trade processing
   MqlTick latest_price;      // To be used for getting recent/latest price quotes
   MqlTradeRequest mrequest;  // To be used for sending our trade requests
   MqlTradeResult mresult;    // To be used to get our trade results
   MqlRates mrate[];          // To be used to store the prices, volumes and spread of each bar
   ZeroMemory(mrequest);      // Initialization of mrequest structure

   // Assure that bar and ema values are stored serially similar to timeseries array
   ArraySetAsSeries(mrate, true);
   ArraySetAsSeries(emafastVal, true);
   ArraySetAsSeries(emaslowVal, true);
   
   // Get the last price quote using the MQL5 MqlTick Structure
   if (!SymbolInfoTick(_Symbol, latest_price)){
      Alert("Error getting the latest price quote - error:",GetLastError(),"!!");
      return;
   }
   // Get the details of the latest 3 bars
   if(CopyRates(_Symbol,_Period, 0, 3, mrate) < 0){
      Alert("Error copying rates/history data - error:",GetLastError(),"!!");
      ResetLastError();
      return;
   }
   // Copy new EMA-fast values into buffer 
   if(CopyBuffer(emafastHandle, 0, 0, 3, emafastVal) < 0){
      Alert("Error copying EMA fast indicator buffer - error:",GetLastError());
      ResetLastError();
      return;
   }
   // Copy new EMA-slow values into buffer 
   if(CopyBuffer(emaslowHandle, 0, 0, 3, emaslowVal) < 0){
      Alert("Error copying EMA losw indicator buffer - error:",GetLastError());
      ResetLastError();
      return;
   }
   
   // Debug MSG showing latest values
   //Alert("Closed price: ", mrate[0].close, " ema34: ", emafastVal[0], " ema89: ", emaslowVal[0]);
   
   // Per Bar calculations for trading strategy
   emadifference[1] = emadifference[0];
   emadifference[0] = emafastVal[0] - emaslowVal[0];
   
   if (emadifference[1] == 0){   // Abort until real values are calculated
      return;
   }
   
   // check for open positions
   bool Buy_opened   = false;    // variable to hold the result of Buy opened position
   bool Sell_opened  = false;    // variable to hold the result of Sell opened position

   if(PositionSelect(_Symbol) == true){ // we have an opened position
   // TODO: Add search for magic number to prevent false detection of manual opened positions
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
         Buy_opened  = true;     //It is a Buy
      }
      else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
         Sell_opened = true;     // It is a Sell
      }
   } 
   else {
      pstatus = PCLOSED;
   }
   
   
   switch(pstatus){
   
      case PCLOSED:{    
         // TODO: Modify static SL TP Definitions to match real strategy definition
         if((emadifference[0] > 0) && (emadifference[1] < 0)){

            
            // Prepare Data for Buy Position
            ZeroMemory(mrequest);
            ZeroMemory(mresult);
            mrequest.action   = TRADE_ACTION_DEAL;                                        // immediate order execution
            mrequest.price    = NormalizeDouble(latest_price.ask,_Digits);                // latest ask price
            mrequest.sl       = NormalizeDouble(latest_price.ask - STP*_Point,_Digits);   // Stop Loss
            mrequest.tp       = NormalizeDouble(latest_price.ask + TKP*_Point,_Digits);   // Take Profit
            mrequest.symbol   = _Symbol;                                                  // currency pair
            mrequest.volume   = Lot;                                                      // number of lots to trade
            mrequest.magic    = MagicNumber;                                              // Order Magic Number
            mrequest.type     = ORDER_TYPE_BUY;                                           // Buy Order
            mrequest.type_filling = ORDER_FILLING_FOK;                                    // Order execution type
            mrequest.deviation=deviation;                                                 // Deviation from current price
            
            // send order
            int retvalue = OrderSend(mrequest,mresult);
            // get the result code
            if((mresult.retcode == TRADE_RETCODE_DONE) 
             || mresult.retcode == TRADE_RETCODE_PLACED){   //Request is completed or order placed
               Alert("A Buy order has been successfully placed with Ticket#:",mresult.order,"!!");
               orderprice        = mresult.price;           // Get confirmed orderprice for further calculations
               positionticket    = mresult.order;           // Save  order ticket number fur further changes
               ordertakeprofit   = mrequest.tp;             // Save SL for further position modifications
               Alert("confirmed order price: ",orderprice);
               pstatus = POPEN;                             //alter pstatus from Closed to open
            }
            else {
               Alert("The Buy order request could not be completed -error:",GetLastError());
               ResetLastError();           
               return;
            }
         }
         
         // check for sell condition: ema crossover positive to negative
         else if((emadifference[0] < 0) && (emadifference[1] > 0)) {
            Alert("Sell condition detected! Open Sell Request...");
            
            ZeroMemory(mrequest);
            ZeroMemory(mresult);
            mrequest.action   =TRADE_ACTION_DEAL;                                         // immediate order execution
            mrequest.price    = NormalizeDouble(latest_price.bid,_Digits);                // latest Bid price
            mrequest.sl       = NormalizeDouble(latest_price.bid + STP*_Point,_Digits);   // Stop Loss
            mrequest.tp       = NormalizeDouble(latest_price.bid - TKP*_Point,_Digits);   // Take Profit
            mrequest.symbol   = _Symbol;                                                  // currency pair
            mrequest.volume   = Lot;                                                      // number of lots to trade
            mrequest.magic    = MagicNumber;                                              // Order Magic Number
            mrequest.type     = ORDER_TYPE_SELL;                                          // Sell Order
            mrequest.type_filling = ORDER_FILLING_FOK;                                    // Order execution type
            mrequest.deviation=deviation;                                                 // Deviation from current price
            
            // send order
            int retvalue = OrderSend(mrequest,mresult);
            // get the result code
            if((mresult.retcode == TRADE_RETCODE_DONE) 
             || mresult.retcode == TRADE_RETCODE_PLACED){   //Request is completed or order placed
               Alert("A Buy order has been successfully placed with Ticket#:",mresult.order,"!!");
               orderprice        = mresult.price;           // Get confirmed orderprice for further calculations
               positionticket    = mresult.order;           // Save  order ticket number fur further changes
               ordertakeprofit   = mrequest.tp;             // Save SL for further position modifications
               Alert("confirmed order price: ",orderprice);
               pstatus = POPEN;                             //alter pstatus from Closed to open
            }
            else {
               Alert("The Sell order request could not be completed -error:",GetLastError());
               ResetLastError();           
               return;
            }
         }
         break;   
      }
      
      case POPEN:{
         // TODO: check for minimum profitability in order to switch from stoploss into trailing stop modus
         // TODO: alter pstatus if ready
         
         double price = NormalizeDouble(latest_price.bid,_Digits);
         double distancemin = 0;
         if (Buy_opened == true) {
            distancemin = NormalizeDouble(orderprice + TralingSLfactor * STP * _Point, _Digits);
            if (price > distancemin){
               // Todo: Alter stoploss to order open price
               // Alert("Todo: Alter stoploss to order open price");
               
               // Prepare Data for SL modification
               ZeroMemory(mrequest);
               ZeroMemory(mresult);
               mrequest.action   = TRADE_ACTION_SLTP;                                        // Change stoploss
               mrequest.position = positionticket;                                           // ticket number or order
               mrequest.sl       = NormalizeDouble(orderprice, _Digits);                     // new Stop Loss value: initial buy price
               mrequest.tp       = ordertakeprofit;                                          // new Take Profit value: old value
               mrequest.symbol   = _Symbol;                                                  // currency pair
               mrequest.magic    = MagicNumber;                                              // Order Magic Number
               
               Alert("Minimum SL Distance archieved. Trying to break even Stoploss:");
               Alert("Position: ", positionticket, " Symbol: ", mrequest.symbol, " Type: BUY");
               
               // send order
               int retvalue = OrderSend(mrequest,mresult);
               // get the result code
               if((mresult.retcode == TRADE_RETCODE_DONE) 
               || mresult.retcode == TRADE_RETCODE_PLACED){   //Request is completed or order placed
                  pstatus = PTRAILING;
                  Alert("Position is now safe! Switching to trailing mode!");
               }
               else {
                  Alert("The modify TP SL request could not be completed -error:",GetLastError());
                  ResetLastError();           
                  return;
                  pstatus = PHALT;
               }
            }
         }
         
         else if(Sell_opened == true){
            distancemin = NormalizeDouble(orderprice - TralingSLfactor * STP * _Point, _Digits);
            if (price < distancemin){
               // Todo: Alter stoploss to order open price
               // Alert("Todo: Alter stoploss to order open price");
               
               // Prepare Data for SL modification
               ZeroMemory(mrequest);
               ZeroMemory(mresult);
               mrequest.action   = TRADE_ACTION_SLTP;                                        // Change stoploss
               mrequest.position = positionticket;                                           // ticket number or order
               mrequest.sl       = NormalizeDouble(orderprice, _Digits);                     // new Stop Loss value: initial buy price
               mrequest.tp       = ordertakeprofit;                                          // new Take Profit value: old value
               mrequest.symbol   = _Symbol;                                                  // currency pair
               mrequest.magic    = MagicNumber;                                              // Order Magic Number
               
               Alert("Minimum SL Distance archieved. Trying to break even Stoploss:");
               Alert("Position: ", positionticket, " Symbol: ", mrequest.symbol, " Type: BUY");
               
               // send order
               int retvalue = OrderSend(mrequest,mresult);
               // get the result code
               if((mresult.retcode == TRADE_RETCODE_DONE) 
               || mresult.retcode == TRADE_RETCODE_PLACED){   //Request is completed or order placed
                  pstatus = PTRAILING;
                  Alert("Position is now safe! Switching to trailing mode!");
               }
               else {
                  Alert("The modify TP SL request could not be completed -error:",GetLastError());
                  ResetLastError();           
                  return;
                  pstatus = PHALT;
               }
            }
         }
         
         else {
            Alert("Fatal Error: Inside STM-POPEN without order opened!");
            pstatus = PHALT;
         } 
         break;
      }
      
      case PTRAILING:{
         // TODO: Implement trailing algorithm
         //Alert("Todo: Implement trailing algorithm");
         // TODO: Implement Exit strategy (by trailing stop, by slowemacross, by crossover)
         // TODO: Implement Tradeclose by magic number   
         if (false) {
            pstatus = PCLOSED;
         }
         break;
      }
      
      case PUNKNOWN: {
         pstatus = PCLOSED;
         break;
      }
      
      case PHALT: {
         Alert("DEBUG: EA state maschine was halted.");
         break;
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
   double ret = 0.0;
   Alert("DEBUG: OnTester() was called");
   return(ret);
}

//+------------------------------------------------------------------+
//| TesterInit function                                              |
//+------------------------------------------------------------------+
void OnTesterInit()
{
   Alert("DEBUG: OnTesterInit() was called");
}

//+------------------------------------------------------------------+
//| TesterPass function                                              |
//+------------------------------------------------------------------+
void OnTesterPass()
{
   Alert("DEBUG: OnTesterPass() was called"); 
}

//+------------------------------------------------------------------+
//| TesterDeinit function                                            |
//+------------------------------------------------------------------+
void OnTesterDeinit()
{
   Alert("DEBUG: OnTesterDeinit() was called");
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
   Alert("DEBUG: OnChartEvent() was called"); 
}

//+------------------------------------------------------------------+
//| BookEvent function                                               |
//|   Callback Bookevent - change of market depth                    |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
{
   Alert("DEBUG: OnBookEvent() was called");
}





