package tv80

import circt.stage.ChiselStage

object tv80build extends App {
  ChiselStage.emitSystemVerilog(new Tv80s, Array.empty, Array("-o", "rtl/generated", "--split-verilog", "--lowering-options=disallowExpressionInliningInPorts,disallowLocalVariables"))
}