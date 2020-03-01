//################################################################################
//#                                                                              #
//#   Impulse-Drive.mq5                                                          #
//#   Copyright 2020, nasrudin2458                                               #
//#                                                                              #
//#                                                                              #
//################################################################################
//#                                                                              #
//# tdinterface.mph                                                              #
//#                                                                              #
//# This file contains all functions which directly control positions via MT5    #
//# Trade terminal                                                               #
//#                                                                              #
//#                                                                              #
//################################################################################



//################################################################################
//# Opens / closes a SL secured instant position with given parameters           #
//#  Closing a position is done by an inverted tradeaction on a given trade-id   #
//#                                                                              #
//################################################################################
int tdi_setPosition(MqlTradeRequest &request, MqlTradeResult &result)
{
   // Prepare Data for Buy Position
   request.action   = TRADE_ACTION_DEAL;           // immediate order execution
           
   // send order
   bool retOrderSend = OrderSend(request,result);
   if (retOrderSend != true) {
      Print("tdi_OpenPosition - OrderSend basis check structures failed! Abort OpenPosition");
   }
   
   // get the result code
   if((result.retcode == TRADE_RETCODE_DONE) 
   || result.retcode == TRADE_RETCODE_PLACED){     //Request is completed or order placed
      Print("A Buy order has been successfully placed with Ticket#:",result.order,"!!");
      orderprice        = result.price;            // Get confirmed orderprice for further calculations
      positionticket    = result.order;            // Save  order ticket number fur further changes
      ordertakeprofit   = request.tp;              // Save SL for further position modifications
      Print("confirmed order price: ",orderprice);
      pstatus = POPEN;                             //alter pstatus from Closed to open
   }
   else {
      Alert("The Buy order request could not be completed -error:",GetLastError());
      ResetLastError();              
   }
   return (int) result.retcode;
}


//################################################################################
//# Opens a SL secured Stop position with given parameters                       #
//#                                                                              #
//################################################################################
int tdi_OpenStop()
{
   return 0;
}


//################################################################################
//# Modify Stoploss of an existing Trade                                         #
//#                                                                              #
//################################################################################
int tdi_ModifyTPSL(MqlTradeRequest &request, MqlTradeResult &result)
{
   request.action   = TRADE_ACTION_SLTP;                                        // Change stoploss
   request.sl       = NormalizeDouble(orderprice, _Digits);                     // new Stop Loss value: initial buy price
   request.tp       = ordertakeprofit;                                          // new Take Profit value: old value
               
   Print("Minimum SL Distance archieved. Trying to break even Stoploss:");
   Print("Position: ", positionticket, " Symbol: ", request.symbol, " Type: BUY");
               
   // send order
   int retvalue = OrderSend(request,result);
   
   // get the result code
   if((result.retcode == TRADE_RETCODE_DONE) 
   || result.retcode == TRADE_RETCODE_PLACED){   //Request is completed or order placed
      pstatus = PTRAILING;
      Print("Position is now safe! Switching to trailing mode!");
   }
   else {
      Alert("The modify TP SL request could not be completed -error:",GetLastError());
      ResetLastError();           
      pstatus = PHALT;
   }
   return (int) result.retcode;
}

