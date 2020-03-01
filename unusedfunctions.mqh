//################################################################################
//#                                                                              #
//#   Impulse-Drive.mq5                                                          #
//#   Copyright 2020, nasrudin2458                                               #
//#                                                                              #
//#										 #
//################################################################################
//#                                                                              #
//#   unusedfunctions.mqh							 #	 
//#   This file contains unused MQL5 callback functions		 		 #
//#                                                                              #
//#                                                                              #
//################################################################################


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