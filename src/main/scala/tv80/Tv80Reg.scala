package tv80
import chisel3._
import chisel3.util._

class Tv80Reg extends Module {
  val io = IO(new Bundle {
    val CEN   = Input(Bool())
    val WEH   = Input(Bool())
    val WEL   = Input(Bool())
    val AddrA = Input(UInt(3.W))
    val AddrB = Input(UInt(3.W))
    val AddrC = Input(UInt(3.W))
    val DIH   = Input(UInt(8.W))
    val DIL   = Input(UInt(8.W))
    val DOAH  = Output(UInt(8.W))
    val DOAL  = Output(UInt(8.W))
    val DOBH  = Output(UInt(8.W))
    val DOBL  = Output(UInt(8.W))
    val DOCH  = Output(UInt(8.W))
    val DOCL  = Output(UInt(8.W))
  })

  val RegsH = Reg(Vec(8, UInt(8.W)))
  val RegsL = Reg(Vec(8, UInt(8.W)))

  when(io.CEN) {
    when(io.WEH) { RegsH(io.AddrA) := io.DIH }
    when(io.WEL) { RegsL(io.AddrA) := io.DIL }
  }

  io.DOAH := RegsH(io.AddrA)
  io.DOAL := RegsL(io.AddrA)
  io.DOBH := RegsH(io.AddrB)
  io.DOBL := RegsL(io.AddrB)
  io.DOCH := RegsH(io.AddrC)
  io.DOCL := RegsL(io.AddrC)
}
