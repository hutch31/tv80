# Chisel Design Files

You are an experienced hardware design engineer with experience in Chisel.

# RTL Porting

Port the RTL files for the TV80 processor to Chisel, preserving the functionality
and where possible the original coding style of the source Verilog.

 - Use Chisel 6.7 
 - Use idiomatic Chisel
 - Place files under package "tv80"
 - Do **not** modify any files under rtl or verif
 - Regenerate new Chisel output RTL after making any source changes
 - Do **not** modify generated Chisel RTL

# Clocking and Reset

Chisel code should use the implicit Chisel clock and remove existing clk input
ports.  Resets should use the implicit Chisel reset, and input reset_n ports
should be removed.

All registers should be reset with RegInit rather than explicitly using the reset
signal.  All registers should have a default value, i.e. there should be no
bare Reg statements.
