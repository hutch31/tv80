%module vlaunch
%{
#include <svdpi.h>
void launch();
void setFinishTime (int t);
extern void addDpiDriverData (int driverId, int data);
extern int  getDpiDriverData (int driverId);
void tbInit();
void setTrace (bool t);
void continueSim (int add_t);
void runQueueEmpty(int start, int end);
 void shutdown();
void setScope (char *scope);
 svScope  svGetScopeFromName (const char *scope);
 extern "C" void load_byte (int addr, int data);
 extern "C" void set_decode (int en);
%}

%init %{
  tbInit();
%}

void launch();
void setFinishTime (int t);
void setTrace (bool t);
void continueSim (int add_t);
void runQueueEmpty(int start, int end);
extern void addDpiDriverData (int driverId, int data);
extern int  getDpiDriverData (int driverId);
void setScope (char *scope);
 svScope  svGetScopeFromName (const char *scope);
 void shutdown();
extern "C" void load_byte (int addr, int data);
 extern "C" void set_decode (int en);
