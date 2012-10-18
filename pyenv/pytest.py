#!/usr/bin/python

import sys, os
sys.path.append ("../scripts")

import vlaunch
import ihex2mem

def run_sim(ihx_name):
    # open the test ihx file and populate ROM
    memim = ihex2mem.mem_image()
    memim.load_ihex (ihx_name)
    print "Loaded",memim.bcount,"bytes"
    for addr in range(memim.min, 32768):
        if (addr in memim.map) and (addr < 32768):
            vlaunch.load_byte (addr, int(memim.map[addr]))
        else:
            vlaunch.load_byte (addr, 0)

    # start simulation        
    #random.seed (1)
    #vlaunch.set_decode(1)
    vlaunch.launch()
    vlaunch.continueSim(200000)

    print "Sim complete, checking results"
    vlaunch.shutdown()

vlaunch.setTrace (1)
print repr(sys.argv)
run_sim (sys.argv[1])

