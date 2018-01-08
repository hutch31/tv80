TV80 is a Z80-compatible synthesizable Verilog core.

The TV80 core aims to be an area-efficient core which closely mimics
the original operation and cycle timing of the Zilog Z80.  The core
has been used by the author/porter in multiple silicon tape-outs as
a utility processor or programmable state machine.

The top level wrapper is the tv80s, which presents a synchronous
interface where all signals transition on the positive edge of the clock.

