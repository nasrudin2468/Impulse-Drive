//################################################################################
//#                                                                              #
//#   Impulse-Drive.mq5                                                          #
//#   Copyright 2020, nasrudin2458                                               #
//#                                                                              #
//#                                                                              #
//################################################################################
//#                                                                              #
//#   Impulse-Drive.mq5                                                          #
//#   This is the main project sourcefile.                    		               #
//#                                                                              #
//#                                                                              #
//################################################################################


//################################################################################
// hardcoded properties
// --> hidden in mql project file: right-click on "...mqproj" - properties

//################################################################################
// Input Parameters
input int      EmaFastPeriod        = 34;    // value count of fast exponential average, used for cross over signal
input int      EmaSlowPeriod        = 89;    // value count of slow exponential average, used for cross over signal
input int      StopLoss             = 30;    // absolut stop loss difference (pip value, might be scaled dependent on post comma letter count) 
input int      TakeProfit           = 100;   // absolut take profit difference (pip value, might be scaled dependent on post comma letter count)
input double   TrailingSLfactor     = 0.5;   // relative factor of Buyprice - SL price over trigger price - buyprice for switching into 
                                             // trailing SL mode
input int      HetchSLEnable        = 1;     // Use a hetch trade with stoploss at entry to replace a stoploss to save a trade on spikes
input double   HetchSLEntryfactor   = 0.1;   // Percentage of Stoploss distance to enter hetchtrade
input double   HetchSLBEfactor      = 0.2;   // Percentage of Stoploss distance to set hetch stoploss break even 
input int      ExitByTSL            = 1;     // exit strategy by trailing stop loss (0: OFF | 1: on | 2: on TICKWISE)
input int      ExitByCrossover      = 1;     // exit strategy by ema crossover (0: OFF | 1: on | 2: on TICKWISE)
input int      ExitBySlowEmaCross   = 1;     // exit strategy by candle crossing the slowEma (0: OFF | 1: on | 2: on TICKWISE)
input int      ExitByFastEmaCross   = 0;     // exit strategy by canlde crossing the slowEma (0: OFF | 1: on | 2: on TICKWISE)
input double   TSLRelativeGain      = 0.5;   // Trailing stop relative profit value based on highest profit since order start
input double   Lot                  = 0.1;   // static lotsize to Trade
input int      deviation            = 100;   // maximum allowed price difference of actual price over requested price for placing an order
input int      MagicNumber          = 2468;  // additional identification number added to each order opened by the expert advisor

//################################################################################
// global defines (replace magic numbers)
#define PCLOSED      0                       // no position open 
#define POPEN        10                      // position opened. wait for hetch / trailing condition
#define PHETCH       20                      // Position is in hetching mode
#define PTRAILING    30                      // position is in trailing stop modus
#define PUNKNOWN     90                      // unknown status, possible malfunction
#define PHALT        100                     // Force-stop EA state machine from further changes - debugging only

//################################################################################
// global declarations
int      emafastHandle;                      // handle id of the EmaFast indicator
int      emaslowHandle;                      // handle id of the EmaSlow indicator
int      emanexttimeframeHandle;             // handle id of the EMAFast indicator of the next higher timeframe
double   emafastVal[], emaslowVal[];         // Dynamic arrays to hold the values of Moving Averages for each bars
double   emanextTimeframeVal[];
double   p_close;                            // Variable to store the close value of a bar
double   emadifference[2];                   // Stores substraction result of both emas over acual and last value. 
int      STP, TKP;                           // To be used for Stop Loss & Take Profit values
int      countbuypositions;
int      countsellpositions;                 // order counters
double   orderprice        = 0;              // confirmed position order price
double   tslprice          = 0;              // calculated trailing stop price level
ulong    positionticket    = 0;              // ticket number of position
double   ordertakeprofit   = 0;              // tp value from open order, needs to be given on sl changes
int      pstatus           = PUNKNOWN;       // indicates status of trades
                                             //     0: no position open 
                                             //    10: position opened
                                             //    20: position is in trailing stop modus
                                             //    90: unknown status, possible malfunction

                                             
//################################################################################
// debug parameters
bool debughalt = false;
bool debugpauseontrade = false;
   


//################################################################################
//# Includes                                                                     #
//################################################################################
#include "tdinterface.mqh"
#include "unusedfunctions.mqh"


//################################################################################
//# int initTradeRequest(MqlTradeRequest &request)                               #
//#   satinizes given struct and prepares it with  standard values               #
//################################################################################
int initTradeRequest(MqlTradeRequest &request)
{
   ZeroMemory(request);
   request.symbol       = _Symbol;                                      // currency pair
   request.volume       = Lot;                                          // number of lots to trade
   request.magic        = MagicNumber;                                  // Order Magic Number
   request.type_filling = ORDER_FILLING_FOK;                            // Order execution type
   request.deviation    = deviation;                                    // Deviation from current price
   return 0;
}


//################################################################################
//# Expert initialization function                                               #
//#   called after activating an expert advisor by dragging on chart |           #
//################################################################################
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


//################################################################################
//# Expert deinitialization function                                             #
//#   called after deleting an expert advisor from chart                         #
//################################################################################
void OnDeinit(const int reason)
{
   //Release indicator handles
   IndicatorRelease(emafastHandle);
   IndicatorRelease(emaslowHandle);
   // Kill timer
   EventKillTimer();   
}


//################################################################################
//# TradeTransaction function                                                    #
//#   Callback function OrderSendAsync                                           #
//################################################################################
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   //Alert("DEBUG: OnTradeTransaction() was called");
}


//################################################################################
//# Expert tick function                                                         #
//#   called every time a new price is released on main asset                    #
//################################################################################
void OnTick()
{
   if (debughalt == true){ return;}
   
   static datetime Old_Time;
   datetime New_Time[1];
   bool IsNewBar = false;
   int retcode = 0;

   // copying the last bar time to the element New_Time[0]
   int copied = CopyTime(_Symbol, _Period, 0, 1, New_Time);
   if(copied > 0) {                       // ok, the data has been copied successfully
      if(Old_Time != New_Time[0]) {       // if old time isn't equal to new bar time
         IsNewBar = true;                 // if it isn't a first call, the new bar has appeared
         
         if(MQL5InfoInteger(MQL5_DEBUGGING)) {
            //Print("We have new bar here ", New_Time[0]," old time was ", Old_Time);
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
   bool Buy_opened   = false;             // variable to hold the result of Buy opened position
   bool Sell_opened  = false;             // variable to hold the result of Sell opened position

   if(PositionSelect(_Symbol) == true){   // we have an opened position
   // TODO: Add search for magic number to prevent false detection of manual opened positions
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
         Buy_opened  = true;              //It is a Buy
      }
      else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
         Sell_opened = true;              // It is a Sell
      }
   } 
   else {
      pstatus = PCLOSED;
   }
   
   
   switch(pstatus){
   
      case PCLOSED:{    
         // TODO: Modify static SL TP Definitions to match real strategy definition
         // TODO: SL on EMA89 like original Seidel strategy
         if((emadifference[0] > 0) && (emadifference[1] <= 0)){
            Print("Buy condition detected! Open Buy Request...");

            // Prepare Data for Buy Position
            initTradeRequest(mrequest);
            mrequest.price    = NormalizeDouble(latest_price.ask,_Digits);                // latest ask price
            mrequest.sl       = NormalizeDouble(latest_price.ask - STP*_Point,_Digits);   // Stop Loss
            mrequest.type     = ORDER_TYPE_BUY;
            if (TKP != 0) {
               mrequest.tp       = NormalizeDouble(latest_price.ask + TKP*_Point,_Digits);   // Take Profit
            }
            ZeroMemory(mresult);
            
            // open buy position
            retcode = tdi_setPosition(mrequest, mresult);
            
            if ((HetchSLEnable == 1 ) && (retcode == TRADE_RETCODE_DONE)) {
               // Prepare Hetch data
               // Open Hetchtrade
            }
         }
         
         // check for sell condition: ema crossover positive to negative
         else if((emadifference[0] < 0) && (emadifference[1] >= 0)) {
            Print("Sell condition detected! Open Sell Request...");
            
            // Prepare Data for Sell Position
            initTradeRequest(mrequest);
            mrequest.price    = NormalizeDouble(latest_price.bid,_Digits);                // latest Bid price
            mrequest.sl       = NormalizeDouble(latest_price.bid + STP*_Point,_Digits);   // Stop Loss
            mrequest.type     = ORDER_TYPE_SELL;
            if (TKP != 0) {
               mrequest.tp       = NormalizeDouble(latest_price.bid - TKP*_Point,_Digits);   // Take Profit 
            }
            ZeroMemory(mresult);
            
            // open sell  position
            retcode = tdi_setPosition(mrequest, mresult);
            
            if ((HetchSLEnable == 1 ) && (retcode == TRADE_RETCODE_DONE)) {
               // Prepare Hetch data
               // Open Hetchtrade
            }
         }
         break;   
      }
      
      case POPEN:{

         
         double price = NormalizeDouble(latest_price.bid,_Digits);
         double distancemin = 0;
         
         if (Buy_opened == true) {
            // Calculate values for further strategy decitions
            distancemin = NormalizeDouble(orderprice + TrailingSLfactor * STP * _Point, _Digits);
            
            // Check for switch in Trailing mode
            if (price > distancemin){
               // Todo: Alter stoploss to order open price
               // Print("Todo: Alter stoploss to order open price");
               Print("Minimum SL Distance archieved. Trying to break even Stoploss:");
               Print("Position: ", positionticket, " Symbol: ", mrequest.symbol, " Type: BUY");
               
               // Prepare Data for SL modification
               initTradeRequest(mrequest);
               mrequest.position = positionticket;                                           // ticket number or order
               mrequest.sl       = NormalizeDouble(orderprice, _Digits);                     // new Stop Loss value: initial buy price
               mrequest.tp       = ordertakeprofit;                                          // new Take Profit value: old value
               ZeroMemory(mresult);
               
               // send order
               tdi_ModifyTPSL(mrequest, mresult);
            }
            // Else if Hetch condition has happened
            //    Goto PHetch
         }
         
         else if(Sell_opened == true){
            distancemin = NormalizeDouble(orderprice - TrailingSLfactor * STP * _Point, _Digits);
            if (price < distancemin){
               // Todo: Alter stoploss to order open price
               // Print("Todo: Alter stoploss to order open price");
               Print("Minimum SL Distance archieved. Trying to break even Stoploss:");
               Print("Position: ", positionticket, " Symbol: ", mrequest.symbol, " Type: SELL");
               
               // Prepare Data for SL modification
               initTradeRequest(mrequest);
               mrequest.position = positionticket;                                           // ticket number or order
               mrequest.sl       = NormalizeDouble(orderprice, _Digits);                     // new Stop Loss value: initial buy price
               mrequest.tp       = ordertakeprofit;                                          // new Take Profit value: old value
               ZeroMemory(mresult);
               
              // send order
               tdi_ModifyTPSL(mrequest, mresult);
            }
         }
         
         else {
            Alert("Fatal Error: Inside STM-POPEN without order opened!");
            pstatus = PHALT;
         } 
         break;
      }
      
      case PTRAILING:{
         double price   = NormalizeDouble(latest_price.bid,_Digits);    // Get latest price for further calculations
         bool doexit    = false;                                        // control variable for exit process

         if(ExitByTSL > 0){
            if((ExitByTSL == 2) || (IsNewBar == true)){
               // TODO: Implement Exit strategy by trailing stop
               if(Buy_opened == true){

                  // calculate actual tsl price level based on TSL Relative gain 
                  double tsldifference = price - orderprice;
                  double newtslprice   = orderprice + (tsldifference * TSLRelativeGain);
                  
                  // replace tsl price value if larger than old value
                  if(newtslprice > tslprice){
                     tslprice = newtslprice;
                  }

                  // check if price is lower than tsl
                  if(price < tslprice){
                     doexit = true;
                     Print("Exit by TSL (BUY) condition triggered!");
                  }
               }
               
               else if(Sell_opened == true){
                  // calculate actual tsl price level based on TSL Relative gain 
                  double tsldifference = orderprice - price;
                  double newtslprice   = orderprice - (tsldifference * TSLRelativeGain);
                  
                  // replace tsl price value if larger than old value
                  if(newtslprice < tslprice){
                     tslprice = newtslprice;
                  }

                  // check if price is lower than tsl
                  if(price > tslprice){
                     doexit = true;
                     Print("Exit by TSL (SELL) condition triggeded!");
                  }
               }
            }
         }
 
         if(ExitBySlowEmaCross>0){
            if((ExitBySlowEmaCross == 2) || (IsNewBar == true)){
               if((( Buy_opened == true) && (price < emaslowVal[0]))
                  || (( Sell_opened == true) && (price > emaslowVal[0]))){
                     doexit = true;
                     Print("Exit by SlowEmaCross condition triggeded!");
                  }
               }
            } 
         if(ExitByFastEmaCross>0) {
            if((ExitByFastEmaCross == 2) || (IsNewBar == true)){
               if((( Buy_opened == true) && (price < emafastVal[0]))
               || (( Sell_opened == true) && (price> emafastVal[0]))){
                  doexit = true;
                  Print("Exit by FastEmaCross condition triggeded!");
                  }
               }
            }

         if(ExitByCrossover>0){
            if((ExitByCrossover == 2) || (IsNewBar == true)){
               // TODO: Implement Exit strategy by crossover
               if(((emadifference[0] > 0) && (emadifference[1] <= 0))
               || ((emadifference[0] < 0) && (emadifference[1] >= 0))){
                  doexit = true;
                  Print("Exit by EMA Crossover condition triggeded!");
               }
            }
         }

         // check if close condition happend and trigger positio close
         if(doexit == true){
            // Todo: Implement instant position close. On sucess:change State!
           
            // Prepare Data for position close
            initTradeRequest(mrequest);
            
            if(Buy_opened == true) {         // close buy position by selling it
               mrequest.price=SymbolInfoDouble(_Symbol,SYMBOL_BID);
               mrequest.type =ORDER_TYPE_SELL;
            }
            else if (Sell_opened == true){   //close sell position by buying it
               mrequest.price=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
               mrequest.type =ORDER_TYPE_BUY;
            }
            else {
               Alert("Fatal Error! Tried to close position of unknown type (buy / sell");
               pstatus = PUNKNOWN;
               return;
            }
            ZeroMemory(mresult);
            
            // send order
            tdi_setPosition(mrequest, mresult);
         }
         break;
      }
      
      case PUNKNOWN: {
         pstatus = PCLOSED;
         break;
      }
      
      case PHALT: {
         Print("DEBUG: EA state maschine was halted.");
         break;
      }    
   }
   // Copy the bar close price for the previous bar prior to the current bar, that is Bar 1
   p_close=mrate[1].close;  // bar 1 close price
}


//################################################################################
//# EOF






