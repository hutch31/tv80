# Overview

The task for you, the verification engineer, is to 
 - create a verification plan for the TV80 processor
 - Create a new verification environment in Cocotb
 - Create new tests to implement the verification plan
 - Execute the plan and collect coverage data
 - Analyze coverage data to determine that testing is complete
 - Add new elements to the verification plan and repeat as needed until coverage goals are met

# Environment

Tests run in a local docker container.  The container has cocotb and Verilator installed.  Test
coverage should be collected with verilator.

# Hierarchy

/verif

Contains all new verification files

/verif/doc

Contains documentation about the environment and test plan

/verif/env 

Contains the verification environment code in cocotb

/verif/tests

Contains C and asm test code

# Test Structure

The point of control for all tests is a program which runs on the Z80.  The test interacts
with the cocotb environment by writing to Z80 control port locations.  The cocotb testbench
should use the legacy testbench in @env/env_io.v as examples of how to provision and implement
IO port control.

# Coverage Goals

Test coverage goals are:
 - 99% line coverage
 - 90% branch coverage
 
