package tv80
import chisel3._
import chisel3.util._

class Tv80Alu(Mode: Int = 0) extends Module {
  val Flag_C = 0
  val Flag_N = 1
  val Flag_P = 2
  val Flag_X = 3
  val Flag_H = 4
  val Flag_Y = 5
  val Flag_Z = 6
  val Flag_S = 7

  val io = IO(new Bundle {
    val Arith16 = Input(Bool())
    val Z16     = Input(Bool())
    val ALU_Op  = Input(UInt(4.W))
    val IR      = Input(UInt(6.W))
    val ISet    = Input(UInt(2.W))
    val BusA    = Input(UInt(8.W))
    val BusB    = Input(UInt(8.W))
    val F_In    = Input(UInt(8.W))
    val Q       = Output(UInt(8.W))
    val F_Out   = Output(UInt(8.W))
  })

  def addSub4(a: UInt, b: UInt, sub: Bool, carryIn: Bool): UInt = {
    val bMod = Mux(sub, ~b, b)
    Cat(0.U(1.W), a) + Cat(0.U(1.W), bMod) + Cat(0.U(4.W), carryIn)
  }

  def addSub3(a: UInt, b: UInt, sub: Bool, carryIn: Bool): UInt = {
    val bMod = Mux(sub, ~b, b)
    Cat(0.U(1.W), a) + Cat(0.U(1.W), bMod) + Cat(0.U(3.W), carryIn)
  }

  def addSub1(a: UInt, b: UInt, sub: Bool, carryIn: Bool): UInt = {
    val bMod = Mux(sub, ~b, b)
    Cat(0.U(1.W), a) + Cat(0.U(1.W), bMod) + Cat(0.U(1.W), carryIn)
  }

  // BitMask computation
  val bitMask = WireDefault(0x01.U(8.W))
  switch(io.IR(5, 3)) {
    is(0.U) { bitMask := 0x01.U }
    is(1.U) { bitMask := 0x02.U }
    is(2.U) { bitMask := 0x04.U }
    is(3.U) { bitMask := 0x08.U }
    is(4.U) { bitMask := 0x10.U }
    is(5.U) { bitMask := 0x20.U }
    is(6.U) { bitMask := 0x40.U }
    is(7.U) { bitMask := 0x80.U }
  }

  // AddSub variables
  val useCarry   = WireDefault(false.B)
  val halfCarry  = WireDefault(false.B)
  val carry7     = WireDefault(false.B)
  val overflow   = WireDefault(false.B)
  val carry      = WireDefault(false.B)
  val q_v        = WireDefault(0.U(8.W))

  useCarry := !io.ALU_Op(2) && io.ALU_Op(0)
  val sub      = io.ALU_Op(1)
  val carryIn0 = sub ^ (useCarry && io.F_In(Flag_C))

  val res4 = addSub4(io.BusA(3, 0), io.BusB(3, 0), sub, carryIn0)
  halfCarry  := res4(4)
  val qv3_0 = res4(3, 0)

  val res3 = addSub3(io.BusA(6, 4), io.BusB(6, 4), sub, halfCarry)
  carry7    := res3(3)
  val qv6_4 = res3(2, 0)

  val res1 = addSub1(io.BusA(7), io.BusB(7), sub, carry7)
  carry     := res1(1)
  val qv7   = res1(0)

  overflow  := carry ^ carry7
  q_v       := Cat(qv7, qv6_4, qv3_0)

  // Main ALU logic
  val q_t   = WireDefault(0.U(8.W))
  val fOut  = WireDefault(io.F_In)

  // DAA registers
  val daaQ0 = Cat(0.U(1.W), io.BusA) // 9-bit
  val daaQ1 = WireDefault(daaQ0)
  val daaQ2 = WireDefault(daaQ1)

  switch(io.ALU_Op) {
    is(0.U, 1.U, 2.U, 3.U, 4.U, 5.U, 6.U, 7.U) {
      fOut  := Cat(io.F_In(7, 1), io.F_In(0))  // preserve F_In first
      // Clear N and C
      fOut(Flag_N) := false.B
      fOut(Flag_C) := false.B

      switch(io.ALU_Op(2, 0)) {
        is(0.U, 1.U) { // ADD, ADC
          q_t          := q_v
          fOut(Flag_C) := carry
          fOut(Flag_H) := halfCarry
          fOut(Flag_P) := overflow
        }
        is(2.U, 3.U, 7.U) { // SUB, SBC, CP
          q_t          := q_v
          fOut(Flag_N) := true.B
          fOut(Flag_C) := !carry
          fOut(Flag_H) := !halfCarry
          fOut(Flag_P) := overflow
        }
        is(4.U) { // AND
          q_t          := io.BusA & io.BusB
          fOut(Flag_H) := true.B
        }
        is(5.U) { // XOR
          q_t          := io.BusA ^ io.BusB
          fOut(Flag_H) := false.B
        }
        is(6.U) { // OR
          q_t          := io.BusA | io.BusB
          fOut(Flag_H) := false.B
        }
      }

      when(io.ALU_Op(2, 0) === 7.U) { // CP
        fOut(Flag_X) := io.BusB(3)
        fOut(Flag_Y) := io.BusB(5)
      }.otherwise {
        fOut(Flag_X) := q_t(3)
        fOut(Flag_Y) := q_t(5)
      }

      when(q_t === 0.U) {
        fOut(Flag_Z) := true.B
        when(io.Z16) {
          fOut(Flag_Z) := io.F_In(Flag_Z)
        }
      }.otherwise {
        fOut(Flag_Z) := false.B
      }

      fOut(Flag_S) := q_t(7)

      // Parity for AND/XOR/OR
      val isLogical = (io.ALU_Op(2, 0) === 4.U) || (io.ALU_Op(2, 0) === 5.U) || (io.ALU_Op(2, 0) === 6.U)
      when(isLogical) {
        fOut(Flag_P) := !q_t.xorR
      }

      when(io.Arith16) {
        fOut(Flag_S) := io.F_In(Flag_S)
        fOut(Flag_Z) := io.F_In(Flag_Z)
        fOut(Flag_P) := io.F_In(Flag_P)
      }
    }

    is(0xC.U) { // DAA
      fOut(Flag_H) := io.F_In(Flag_H)
      fOut(Flag_C) := io.F_In(Flag_C)

      when(!io.F_In(Flag_N)) {
        // After addition
        when(daaQ0(3, 0) > 9.U || io.F_In(Flag_H)) {
          when(daaQ0(3, 0) > 9.U) {
            fOut(Flag_H) := true.B
          }.otherwise {
            fOut(Flag_H) := false.B
          }
          daaQ1 := daaQ0 + 6.U
        }
        when(daaQ1(8, 4) > 9.U || io.F_In(Flag_C)) {
          daaQ2 := daaQ1 + 96.U
        }
      }.otherwise {
        // After subtraction
        when(daaQ0(3, 0) > 9.U || io.F_In(Flag_H)) {
          when(daaQ0(3, 0) > 5.U) {
            fOut(Flag_H) := false.B
          }
          daaQ1 := Cat(daaQ0(8), daaQ0(7, 0) - 6.U)
        }
        when(io.BusA > 153.U || io.F_In(Flag_C)) {
          daaQ2 := daaQ1 - 352.U
        }
      }

      fOut(Flag_X) := daaQ2(3)
      fOut(Flag_Y) := daaQ2(5)
      fOut(Flag_C) := io.F_In(Flag_C) || daaQ2(8)
      q_t          := daaQ2(7, 0)

      when(daaQ2(7, 0) === 0.U) {
        fOut(Flag_Z) := true.B
      }.otherwise {
        fOut(Flag_Z) := false.B
      }

      fOut(Flag_S) := daaQ2(7)
      fOut(Flag_P) := !daaQ2.xorR
    }

    is(0xD.U, 0xE.U) { // RLD, RRD
      q_t(7, 4) := io.BusA(7, 4)
      when(io.ALU_Op(0)) {
        q_t(3, 0) := io.BusB(7, 4)
      }.otherwise {
        q_t(3, 0) := io.BusB(3, 0)
      }
      fOut(Flag_H) := false.B
      fOut(Flag_N) := false.B
      fOut(Flag_X) := q_t(3)
      fOut(Flag_Y) := q_t(5)
      when(q_t === 0.U) {
        fOut(Flag_Z) := true.B
      }.otherwise {
        fOut(Flag_Z) := false.B
      }
      fOut(Flag_S) := q_t(7)
      fOut(Flag_P) := !q_t.xorR
    }

    is(0x9.U) { // BIT
      q_t := io.BusB & bitMask
      fOut(Flag_S) := q_t(7)
      when(q_t === 0.U) {
        fOut(Flag_Z) := true.B
        fOut(Flag_P) := true.B
      }.otherwise {
        fOut(Flag_Z) := false.B
        fOut(Flag_P) := false.B
      }
      fOut(Flag_H) := true.B
      fOut(Flag_N) := false.B
      fOut(Flag_X) := false.B
      fOut(Flag_Y) := false.B
      when(io.IR(2, 0) =/= 6.U) {
        fOut(Flag_X) := io.BusB(3)
        fOut(Flag_Y) := io.BusB(5)
      }
    }

    is(0xA.U) { // SET
      q_t := io.BusB | bitMask
    }

    is(0xB.U) { // RES
      q_t := io.BusB & ~bitMask
    }

    is(0x8.U) { // ROT
      switch(io.IR(5, 3)) {
        is(0.U) { // RLC
          q_t(7, 1) := io.BusA(6, 0)
          q_t(0)    := io.BusA(7)
          fOut(Flag_C) := io.BusA(7)
        }
        is(2.U) { // RL
          q_t(7, 1) := io.BusA(6, 0)
          q_t(0)    := io.F_In(Flag_C)
          fOut(Flag_C) := io.BusA(7)
        }
        is(1.U) { // RRC
          q_t(6, 0) := io.BusA(7, 1)
          q_t(7)    := io.BusA(0)
          fOut(Flag_C) := io.BusA(0)
        }
        is(3.U) { // RR
          q_t(6, 0) := io.BusA(7, 1)
          q_t(7)    := io.F_In(Flag_C)
          fOut(Flag_C) := io.BusA(0)
        }
        is(4.U) { // SLA
          q_t(7, 1) := io.BusA(6, 0)
          q_t(0)    := false.B
          fOut(Flag_C) := io.BusA(7)
        }
        is(6.U) { // SLL / SWAP
          if (Mode == 3) {
            q_t(7, 4) := io.BusA(3, 0)
            q_t(3, 0) := io.BusA(7, 4)
            fOut(Flag_C) := false.B
          } else {
            q_t(7, 1) := io.BusA(6, 0)
            q_t(0)    := true.B
            fOut(Flag_C) := io.BusA(7)
          }
        }
        is(5.U) { // SRA
          q_t(6, 0) := io.BusA(7, 1)
          q_t(7)    := io.BusA(7)
          fOut(Flag_C) := io.BusA(0)
        }
        is(7.U) { // SRL
          q_t(6, 0) := io.BusA(7, 1)
          q_t(7)    := false.B
          fOut(Flag_C) := io.BusA(0)
        }
      }

      fOut(Flag_H) := false.B
      fOut(Flag_N) := false.B
      fOut(Flag_X) := q_t(3)
      fOut(Flag_Y) := q_t(5)
      fOut(Flag_S) := q_t(7)
      when(q_t === 0.U) {
        fOut(Flag_Z) := true.B
      }.otherwise {
        fOut(Flag_Z) := false.B
      }
      fOut(Flag_P) := !q_t.xorR

      // For non-CB prefix rotates (RLCA/RRCA/RLA/RRA), preserve some flags
      when(io.ISet === 0.U) {
        fOut(Flag_P) := io.F_In(Flag_P)
        fOut(Flag_S) := io.F_In(Flag_S)
        fOut(Flag_Z) := io.F_In(Flag_Z)
      }
    }
  }

  io.Q    := q_t
  io.F_Out := fOut
}
