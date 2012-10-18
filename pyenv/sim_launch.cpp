#include "Vpytb_top.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

// includes for DPI call
#include "svdpi.h"
#include "Vpytb_top__Dpi.h"
#include <queue>

#define MAX_DRV_ID 2048

static int finishTime = 1000;
static int period = 6;
queue<int> *driverQ[MAX_DRV_ID];
double targetRate[MAX_DRV_ID];
bool traceOn;
VerilatedVcdC *tfp;
Vpytb_top *top;

void tbInit () {
  for (int i=0; i<MAX_DRV_ID; i++) {
    driverQ[i] = new queue<int>;
    targetRate[i] = 1.0;
  }
  traceOn = false;

  tfp = new VerilatedVcdC;
  top = new Vpytb_top("tb_top");

  svScope ss = svGetScopeFromName ("tb_top.v");
  if (ss == NULL) {
    printf ("Warning: svSetScope returned NULL\n");
  }
  svSetScope (ss);
}

void setScope (char *scope) {
  svScope r;
  r = svGetScopeFromName (scope);
  if (r == NULL) {
    printf ("Warning: svSetScope returned NULL\n");
  }
  svSetScope (r);
}

void setFinishTime (int t) { finishTime = t; }

void setTrace (bool t) { 
  traceOn = t; 
  Verilated::traceEverOn(traceOn);
}

vluint64_t nstime = 0;

double sc_time_stamp () {       // Called by $time in Verilog
  return nstime;           // converts to double, to match
                                        // what SystemC does
}

void runSim () {
  while (!Verilated::gotFinish() && (nstime < finishTime)) { 
    if (nstime > 100) top->reset = 0;
    //if (nstime & 1) top->clk = 1; 
    //else top->clk = 0;
    top->clk = 1;
    top->eval(); 
    tfp->dump (nstime);
    nstime += period / 2;
    top->clk = 0;
    top->eval();
    tfp->dump (nstime);
    nstime += period / 2;
  }
}

// Continue to run until all queues in the given
// range are empty 
void runQueueEmpty(int start, int end) {
  bool allEmpty = false;

  while (!allEmpty) {
    runSim();

    allEmpty = true;
    for (int i = start; i<=end; i++)
      if (!driverQ[i]->empty()) {
        allEmpty = false;
        finishTime += 100;
        break;
      }
  }
}

void launch() {
  //Verilated::commandArgs(argc, argv);
  top->reset = 1;
  if (traceOn) {
    top->trace (tfp, 99);
    tfp->open ("sim.vcd");
  }

  runSim();
}

void continueSim (int add_t) {
  finishTime += add_t;
  runSim();
}

void shutdown() {
  if (traceOn) tfp->close();
}

double getTargetRate (int driverId) {
  return targetRate[driverId];
}

void setTargetRate (int driverId, double rate) {
  targetRate[driverId] = rate;
}

void addDpiDriverData (int driverId, int data) {
  if ((driverId >=0) && (driverId < MAX_DRV_ID))
    driverQ[driverId]->push (data);
}

//int add (int a, int b) { return a+b; }
int getDpiDriverData (int driverId)
{
  int rv;
  if ((driverId >=0) && (driverId < MAX_DRV_ID)) {
    if (driverQ[driverId]->empty())
      return -1;
    else {
      rv = driverQ[driverId]->front();
      driverQ[driverId]->pop();
    }
    return rv;
  } else return -1;
}

