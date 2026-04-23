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
  val q_t = WireDefault(0.U(8.W))

  // Individual flag wires, each defaulting to the corresponding F_In bit
  val f_C = WireDefault(io.F_In(Flag_C))
  val f_N = WireDefault(io.F_In(Flag_N))
  val f_P = WireDefault(io.F_In(Flag_P))
  val f_X = WireDefault(io.F_In(Flag_X))
  val f_H = WireDefault(io.F_In(Flag_H))
  val f_Y = WireDefault(io.F_In(Flag_Y))
  val f_Z = WireDefault(io.F_In(Flag_Z))
  val f_S = WireDefault(io.F_In(Flag_S))

  // DAA registers
  val daaQ0 = Cat(0.U(1.W), io.BusA) // 9-bit
  val daaQ1 = WireDefault(daaQ0)
  val daaQ2 = WireDefault(daaQ1)

  switch(io.ALU_Op) {
    is(0.U, 1.U, 2.U, 3.U, 4.U, 5.U, 6.U, 7.U) {
      // Clear N and C for this group
      f_N := false.B
      f_C := false.B

      switch(io.ALU_Op(2, 0)) {
        is(0.U, 1.U) { // ADD, ADC
          q_t := q_v
          f_C := carry
          f_H := halfCarry
          f_P := overflow
        }
        is(2.U, 3.U, 7.U) { // SUB, SBC, CP
          q_t := q_v
          f_N := true.B
          f_C := !carry
          f_H := !halfCarry
          f_P := overflow
        }
        is(4.U) { // AND
          q_t := io.BusA & io.BusB
          f_H := true.B
        }
        is(5.U) { // XOR
          q_t := io.BusA ^ io.BusB
          f_H := false.B
        }
        is(6.U) { // OR
          q_t := io.BusA | io.BusB
          f_H := false.B
        }
      }

      when(io.ALU_Op(2, 0) === 7.U) { // CP
        f_X := io.BusB(3)
        f_Y := io.BusB(5)
      }.otherwise {
        f_X := q_t(3)
        f_Y := q_t(5)
      }

      when(q_t === 0.U) {
        f_Z := true.B
        when(io.Z16) {
          f_Z := io.F_In(Flag_Z)
        }
      }.otherwise {
        f_Z := false.B
      }

      f_S := q_t(7)

      // Parity for AND/XOR/OR
      val isLogical = (io.ALU_Op(2, 0) === 4.U) || (io.ALU_Op(2, 0) === 5.U) || (io.ALU_Op(2, 0) === 6.U)
      when(isLogical) {
        f_P := !q_t.xorR
      }

      when(io.Arith16) {
        f_S := io.F_In(Flag_S)
        f_Z := io.F_In(Flag_Z)
        f_P := io.F_In(Flag_P)
      }
    }

    is(0xC.U) { // DAA
      // f_H and f_C already default to F_In values

      when(!io.F_In(Flag_N)) {
        // After addition
        when(daaQ0(3, 0) > 9.U || io.F_In(Flag_H)) {
          when(daaQ0(3, 0) > 9.U) {
            f_H := true.B
          }.otherwise {
            f_H := false.B
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
            f_H := false.B
          }
          daaQ1 := Cat(daaQ0(8), daaQ0(7, 0) - 6.U)
        }
        when(io.BusA > 153.U || io.F_In(Flag_C)) {
          daaQ2 := daaQ1 - 352.U
        }
      }

      f_X := daaQ2(3)
      f_Y := daaQ2(5)
      f_C := io.F_In(Flag_C) || daaQ2(8)
      q_t := daaQ2(7, 0)

      when(daaQ2(7, 0) === 0.U) {
        f_Z := true.B
      }.otherwise {
        f_Z := false.B
      }

      f_S := daaQ2(7)
      f_P := !daaQ2.xorR
    }

    is(0xD.U, 0xE.U) { // RLD, RRD
      q_t := Cat(io.BusA(7, 4), Mux(io.ALU_Op(0), io.BusB(7, 4), io.BusB(3, 0)))
      f_H := false.B
      f_N := false.B
      f_X := q_t(3)
      f_Y := q_t(5)
      when(q_t === 0.U) {
        f_Z := true.B
      }.otherwise {
        f_Z := false.B
      }
      f_S := q_t(7)
      f_P := !q_t.xorR
    }

    is(0x9.U) { // BIT
      q_t := io.BusB & bitMask
      f_S := q_t(7)
      when(q_t === 0.U) {
        f_Z := true.B
        f_P := true.B
      }.otherwise {
        f_Z := false.B
        f_P := false.B
      }
      f_H := true.B
      f_N := false.B
      f_X := false.B
      f_Y := false.B
      when(io.IR(2, 0) =/= 6.U) {
        f_X := io.BusB(3)
        f_Y := io.BusB(5)
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
          q_t := Cat(io.BusA(6, 0), io.BusA(7))
          f_C := io.BusA(7)
        }
        is(2.U) { // RL
          q_t := Cat(io.BusA(6, 0), io.F_In(Flag_C))
          f_C := io.BusA(7)
        }
        is(1.U) { // RRC
          q_t := Cat(io.BusA(0), io.BusA(7, 1))
          f_C := io.BusA(0)
        }
        is(3.U) { // RR
          q_t := Cat(io.F_In(Flag_C), io.BusA(7, 1))
          f_C := io.BusA(0)
        }
        is(4.U) { // SLA
          q_t := Cat(io.BusA(6, 0), 0.U(1.W))
          f_C := io.BusA(7)
        }
        is(6.U) { // SLL / SWAP
          if (Mode == 3) {
            q_t := Cat(io.BusA(3, 0), io.BusA(7, 4))
            f_C := false.B
          } else {
            q_t := Cat(io.BusA(6, 0), 1.U(1.W))
            f_C := io.BusA(7)
          }
        }
        is(5.U) { // SRA
          q_t := Cat(io.BusA(7), io.BusA(7, 1))
          f_C := io.BusA(0)
        }
        is(7.U) { // SRL
          q_t := Cat(0.U(1.W), io.BusA(7, 1))
          f_C := io.BusA(0)
        }
      }

      f_H := false.B
      f_N := false.B
      f_X := q_t(3)
      f_Y := q_t(5)
      f_S := q_t(7)
      when(q_t === 0.U) {
        f_Z := true.B
      }.otherwise {
        f_Z := false.B
      }
      f_P := !q_t.xorR

      // For non-CB prefix rotates (RLCA/RRCA/RLA/RRA), preserve some flags
      when(io.ISet === 0.U) {
        f_P := io.F_In(Flag_P)
        f_S := io.F_In(Flag_S)
        f_Z := io.F_In(Flag_Z)
      }
    }
  }

  io.Q    := q_t
  io.F_Out := Cat(f_S, f_Z, f_Y, f_H, f_X, f_P, f_N, f_C)
}
