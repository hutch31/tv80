package tv80
import chisel3._
import chisel3.util._
import chisel3.experimental._ // for withClock

class Tv80n(Mode: Int = 0, T2Write: Int = 0, IOWait: Int = 1) extends Module {
  val io = IO(new Bundle {
    val reset_n = Input(Bool())
    val wait_n  = Input(Bool())
    val int_n   = Input(Bool())
    val nmi_n   = Input(Bool())
    val busrq_n = Input(Bool())
    val m1_n    = Output(Bool())
    val mreq_n  = Output(Bool())
    val iorq_n  = Output(Bool())
    val rd_n    = Output(Bool())
    val wr_n    = Output(Bool())
    val rfsh_n  = Output(Bool())
    val halt_n  = Output(Bool())
    val busak_n = Output(Bool())
    val A       = Output(UInt(16.W))
    val di      = Input(UInt(8.W))
    val dout    = Output(UInt(8.W))
  })

  val cen = true.B

  val core = Module(new Tv80Core(Mode, IOWait))
  core.io.reset_n := io.reset_n
  core.io.cen     := cen
  core.io.wait_n  := io.wait_n
  core.io.int_n   := io.int_n
  core.io.nmi_n   := io.nmi_n
  core.io.busrq_n := io.busrq_n
  core.io.dinst   := io.di

  io.m1_n    := core.io.m1_n
  io.rfsh_n  := core.io.rfsh_n
  io.halt_n  := core.io.halt_n
  io.busak_n := core.io.busak_n
  io.A       := core.io.A
  io.dout    := core.io.dout

  val iorq        = core.io.iorq
  val no_read     = core.io.no_read
  val write       = core.io.write
  val intcycle_n  = core.io.intcycle_n
  val mcycle      = core.io.mc
  val tstate      = core.io.ts

  // Combinational next values for control signals
  val nxt_mreq_n = WireDefault(true.B)
  val nxt_iorq_n = WireDefault(true.B)
  val nxt_rd_n   = WireDefault(true.B)
  val nxt_wr_n   = WireDefault(true.B)

  when(mcycle(0)) {
    when(tstate(1) || tstate(2)) {
      nxt_rd_n   := intcycle_n
      nxt_mreq_n := intcycle_n
      nxt_iorq_n := !intcycle_n
    }
  }.otherwise {
    when((tstate(1) || tstate(2)) && !no_read && !write) {
      nxt_rd_n   := false.B
      nxt_iorq_n := !iorq
      nxt_mreq_n := iorq
    }
    if (T2Write == 0) {
      when(tstate(2) && write) {
        nxt_wr_n   := false.B
        nxt_iorq_n := !iorq
        nxt_mreq_n := iorq
      }
    } else {
      when((tstate(1) || (tstate(2) && !io.wait_n)) && write) {
        nxt_wr_n   := false.B
        nxt_iorq_n := !iorq
        nxt_mreq_n := iorq
      }
    }
  }

  // Negative-edge registers for control signals
  val clkNeg = (!clock.asBool).asClock
  val mreq_n = withClock(clkNeg) { Reg(Bool()) }
  val iorq_n = withClock(clkNeg) { Reg(Bool()) }
  val rd_n   = withClock(clkNeg) { Reg(Bool()) }
  val wr_n   = withClock(clkNeg) { Reg(Bool()) }

  withClock(clkNeg) {
    when(!io.reset_n) {
      rd_n   := true.B
      wr_n   := true.B
      iorq_n := true.B
      mreq_n := true.B
    }.otherwise {
      rd_n   := nxt_rd_n
      wr_n   := nxt_wr_n
      iorq_n := nxt_iorq_n
      mreq_n := nxt_mreq_n
    }
  }

  // Positive-edge register for di_reg
  val di_reg = Reg(UInt(8.W))
  when(!io.reset_n) {
    di_reg := 0.U
  }.otherwise {
    when(tstate(2) && io.wait_n) {
      di_reg := io.di
    }
  }
  core.io.di := di_reg

  io.mreq_n := mreq_n
  io.iorq_n := iorq_n
  io.rd_n   := rd_n
  io.wr_n   := wr_n
}
