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
//# Opens a SL secured instant position with given parameters                    #
//#                                                                              #
//################################################################################
int tdi_OpenPosition(MqlTradeRequest &request, MqlTradeResult &result)
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
int tdi_ModifySL()
{
   return 0;
}


//################################################################################
//# Close an opened position                                                     #
//#                                                                              #
//################################################################################
int tdi_ClosePosition()
{
   return 0;
}