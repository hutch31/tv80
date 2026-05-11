package tv80
import chisel3._
import chisel3.util._

class Tv80Core(Mode: Int = 1, IOWait: Int = 1) extends Module {
  val Flag_C = 0
  val Flag_N = 1
  val Flag_P = 2
  val Flag_X = 3
  val Flag_H = 4
  val Flag_Y = 5
  val Flag_Z = 6
  val Flag_S = 7

  val io = IO(new Bundle {
    val cen         = Input(Bool())
    val wait_n      = Input(Bool())
    val int_n       = Input(Bool())
    val nmi_n       = Input(Bool())
    val busrq_n     = Input(Bool())
    val m1_n        = Output(Bool())
    val iorq        = Output(Bool())
    val no_read     = Output(Bool())
    val write       = Output(Bool())
    val rfsh_n      = Output(Bool())
    val halt_n      = Output(Bool())
    val busak_n     = Output(Bool())
    val A           = Output(UInt(16.W))
    val dinst       = Input(UInt(8.W))
    val di          = Input(UInt(8.W))
    val dout        = Output(UInt(8.W))
    val mc          = Output(UInt(7.W))
    val ts          = Output(UInt(7.W))
    val intcycle_n  = Output(Bool())
    val IntE        = Output(Bool())
    val stop        = Output(Bool())
  })

  val aNone = 7.U(3.W)
  val aBC   = 0.U(3.W)
  val aDE   = 1.U(3.W)
  val aXY   = 2.U(3.W)
  val aIOA  = 4.U(3.W)
  val aSP   = 5.U(3.W)
  val aZI   = 6.U(3.W)

  def numberToBitvec(num: UInt): UInt = {
    MuxLookup(num, 1.U(7.W))(Seq(
      1.U -> "b0000001".U(7.W),
      2.U -> "b0000010".U(7.W),
      3.U -> "b0000100".U(7.W),
      4.U -> "b0001000".U(7.W),
      5.U -> "b0010000".U(7.W),
      6.U -> "b0100000".U(7.W),
      7.U -> "b1000000".U(7.W),
    ))
  }

  def mcycToNumber(mcyc: UInt): UInt = {
    MuxCase(1.U(3.W), Seq(
      mcyc(6) -> 7.U(3.W),
      mcyc(5) -> 6.U(3.W),
      mcyc(4) -> 5.U(3.W),
      mcyc(3) -> 4.U(3.W),
      mcyc(2) -> 3.U(3.W),
      mcyc(1) -> 2.U(3.W),
      mcyc(0) -> 1.U(3.W),
    ))
  }

  // All registers
  val PC        = RegInit(0.U(16.W))
  val A_reg     = RegInit(0.U(16.W))
  val TmpAddr   = RegInit(0.U(16.W))
  val IR        = RegInit(0.U(8.W))
  val ISet      = RegInit(0.U(2.W))
  val XY_State  = RegInit(0.U(2.W))
  val IStatus   = RegInit(0.U(2.W))
  val mcycles_r = RegInit(0.U(3.W))
  val dout_r    = RegInit(0.U(8.W))
  val ACC       = RegInit(0xFF.U(8.W))
  val F         = RegInit(VecInit(Seq.fill(8)(true.B)))
  val Ap        = RegInit(0xFF.U(8.W))
  val Fp        = RegInit(0xFF.U(8.W))
  val I         = RegInit(0.U(8.W))
  val SP        = RegInit(0xFFFF.U(16.W))
  val Alternate = RegInit(false.B)
  val Read_To_Reg_r = RegInit(0.U(5.W))
  val Arith16_r = RegInit(false.B)
  val BTR_r     = RegInit(false.B)
  val Z16_r     = RegInit(false.B)
  val ALU_Op_r  = RegInit(0.U(4.W))
  val Save_ALU_r = RegInit(false.B)
  val PreserveC_r = RegInit(false.B)
  val XY_Ind    = RegInit(false.B)

  // State machine registers
  val mcycle      = RegInit("b0000001".U(7.W))
  val tstate      = RegInit("b0000001".U(7.W))
  val Pre_XY_F_M  = RegInit(0.U(3.W))
  val Halt_FF     = RegInit(false.B)
  val BusAck      = RegInit(false.B)
  val NMICycle    = RegInit(false.B)
  val IntCycle    = RegInit(false.B)
  val IntE_FF1    = RegInit(false.B)
  val IntE_FF2    = RegInit(false.B)
  val No_BTR      = RegInit(false.B)
  val Auto_Wait_t1 = RegInit(false.B)
  val Auto_Wait_t2 = RegInit(false.B)
  val m1_n_r      = RegInit(true.B)
  val BusReq_s    = RegInit(false.B)
  val INT_s       = RegInit(false.B)
  val NMI_s       = RegInit(false.B)
  val Oldnmi_n    = RegInit(false.B)

  // Buses (registered)
  val BusB = Reg(UInt(8.W))
  val BusA = Reg(UInt(8.W))

  // Register file interface regs
  val RegAddrA_r = RegInit(0.U(3.W))
  val RegAddrB_r = RegInit(0.U(3.W))
  val RegAddrC   = RegInit(0.U(3.W))
  val RegBusA_r  = RegInit(0.U(16.W))
  val IncDecZ    = RegInit(false.B)

  // Microcode outputs (wires)
  val mcycles_d   = Wire(UInt(3.W))
  val tstates     = Wire(UInt(3.W))
  val Prefix      = Wire(UInt(2.W))
  val Inc_PC      = Wire(Bool())
  val Inc_WZ      = Wire(Bool())
  val IncDec_16   = Wire(UInt(4.W))
  val Read_To_Acc = Wire(Bool())
  val Read_To_Reg = Wire(Bool())
  val Set_BusB_To = Wire(UInt(4.W))
  val Set_BusA_To = Wire(UInt(4.W))
  val ALU_Op      = Wire(UInt(4.W))
  val Save_ALU    = Wire(Bool())
  val PreserveC   = Wire(Bool())
  val Arith16     = Wire(Bool())
  val Set_Addr_To = Wire(UInt(3.W))
  val iorq_i      = Wire(Bool())
  val Jump        = Wire(Bool())
  val JumpE       = Wire(Bool())
  val JumpXY      = Wire(Bool())
  val Call        = Wire(Bool())
  val RstP        = Wire(Bool())
  val LDZ         = Wire(Bool())
  val LDW         = Wire(Bool())
  val LDSPHL      = Wire(Bool())
  val Special_LD  = Wire(UInt(3.W))
  val ExchangeDH  = Wire(Bool())
  val ExchangeRp  = Wire(Bool())
  val ExchangeAF  = Wire(Bool())
  val ExchangeRS  = Wire(Bool())
  val I_DJNZ      = Wire(Bool())
  val I_CPL       = Wire(Bool())
  val I_CCF       = Wire(Bool())
  val I_SCF       = Wire(Bool())
  val I_RETN      = Wire(Bool())
  val I_BT        = Wire(Bool())
  val I_BC        = Wire(Bool())
  val I_BTR       = Wire(Bool())
  val I_RLD       = Wire(Bool())
  val I_RRD       = Wire(Bool())
  val I_INRC      = Wire(Bool())
  val SetDI       = Wire(Bool())
  val SetEI       = Wire(Bool())
  val IMode       = Wire(UInt(2.W))
  val Halt        = Wire(Bool())
  val no_read_w   = Wire(Bool())
  val write_w     = Wire(Bool())

  // Microcode instance
  val i_mcode = Module(new Tv80Mcode(Mode))
  i_mcode.io.IR       := IR
  i_mcode.io.ISet     := ISet
  i_mcode.io.MCycle   := mcycle
  i_mcode.io.F        := F.asUInt
  i_mcode.io.NMICycle := NMICycle
  i_mcode.io.IntCycle := IntCycle
  mcycles_d   := i_mcode.io.MCycles
  tstates     := i_mcode.io.TStates
  Prefix      := i_mcode.io.Prefix
  Inc_PC      := i_mcode.io.Inc_PC
  Inc_WZ      := i_mcode.io.Inc_WZ
  IncDec_16   := i_mcode.io.IncDec_16
  Read_To_Acc := i_mcode.io.Read_To_Acc
  Read_To_Reg := i_mcode.io.Read_To_Reg
  Set_BusB_To := i_mcode.io.Set_BusB_To
  Set_BusA_To := i_mcode.io.Set_BusA_To
  ALU_Op      := i_mcode.io.ALU_Op
  Save_ALU    := i_mcode.io.Save_ALU
  PreserveC   := i_mcode.io.PreserveC
  Arith16     := i_mcode.io.Arith16
  Set_Addr_To := i_mcode.io.Set_Addr_To
  iorq_i      := i_mcode.io.IORQ
  Jump        := i_mcode.io.Jump
  JumpE       := i_mcode.io.JumpE
  JumpXY      := i_mcode.io.JumpXY
  Call        := i_mcode.io.Call
  RstP        := i_mcode.io.RstP
  LDZ         := i_mcode.io.LDZ
  LDW         := i_mcode.io.LDW
  LDSPHL      := i_mcode.io.LDSPHL
  Special_LD  := i_mcode.io.Special_LD
  ExchangeDH  := i_mcode.io.ExchangeDH
  ExchangeRp  := i_mcode.io.ExchangeRp
  ExchangeAF  := i_mcode.io.ExchangeAF
  ExchangeRS  := i_mcode.io.ExchangeRS
  I_DJNZ      := i_mcode.io.I_DJNZ
  I_CPL       := i_mcode.io.I_CPL
  I_CCF       := i_mcode.io.I_CCF
  I_SCF       := i_mcode.io.I_SCF
  I_RETN      := i_mcode.io.I_RETN
  I_BT        := i_mcode.io.I_BT
  I_BC        := i_mcode.io.I_BC
  I_BTR       := i_mcode.io.I_BTR
  I_RLD       := i_mcode.io.I_RLD
  I_RRD       := i_mcode.io.I_RRD
  I_INRC      := i_mcode.io.I_INRC
  SetDI       := i_mcode.io.SetDI
  SetEI       := i_mcode.io.SetEI
  IMode       := i_mcode.io.IMode
  Halt        := i_mcode.io.Halt
  no_read_w   := i_mcode.io.NoRead
  write_w     := i_mcode.io.Write

  // ALU instance
  val i_alu = Module(new Tv80Alu(Mode))
  i_alu.io.Arith16 := Arith16_r
  i_alu.io.Z16     := Z16_r
  i_alu.io.ALU_Op  := ALU_Op_r
  i_alu.io.IR      := IR(5, 0)
  i_alu.io.ISet    := ISet
  i_alu.io.BusA    := BusA
  i_alu.io.BusB    := BusB
  i_alu.io.F_In    := F.asUInt
  val ALU_Q = i_alu.io.Q
  val F_Out = i_alu.io.F_Out
  val cpiXYN = ALU_Q - Cat(0.U(7.W), F_Out(Flag_H))

  // Combinational signal declarations (must precede i_reg which references them)
  val ClkEn_w           = Wire(Bool())
  val T_Res_w           = Wire(Bool())
  val NextIs_XY_Fetch_w = Wire(Bool())
  val Save_Mux_w        = Wire(UInt(8.W))
  val DI_Reg            = Wire(UInt(8.W))
  val last_mcycle       = Wire(Bool())
  val last_tstate       = Wire(Bool())
  val Auto_Wait_w       = Wire(Bool())
  val RegWEH_w          = Wire(Bool())
  val RegWEL_w          = Wire(Bool())

  // Register file instance
  val RegAddrA  = Wire(UInt(3.W))
  val RegAddrB  = Wire(UInt(3.W))
  val RegDIH    = Wire(UInt(8.W))
  val RegDIL    = Wire(UInt(8.W))
  val RegBusA   = Wire(UInt(16.W))
  val RegBusB   = Wire(UInt(16.W))
  val RegBusC   = Wire(UInt(16.W))

  val i_reg = Module(new Tv80Reg)
  i_reg.io.CEN   := ClkEn_w
  i_reg.io.WEH   := RegWEH_w
  i_reg.io.WEL   := RegWEL_w
  i_reg.io.AddrA := RegAddrA
  i_reg.io.AddrB := RegAddrB
  i_reg.io.AddrC := RegAddrC
  i_reg.io.DIH   := RegDIH
  i_reg.io.DIL   := RegDIL
  RegBusA := Cat(i_reg.io.DOAH, i_reg.io.DOAL)
  RegBusB := Cat(i_reg.io.DOBH, i_reg.io.DOBL)
  RegBusC := Cat(i_reg.io.DOCH, i_reg.io.DOCL)

  // Combinational logic
  ClkEn_w := io.cen && !BusAck
  T_Res_w := last_tstate

  // last_mcycle
  last_mcycle := MuxLookup(mcycles_r, mcycle(0))(Seq(
    1.U -> mcycle(0),
    2.U -> mcycle(1),
    3.U -> mcycle(2),
    4.U -> mcycle(3),
    5.U -> mcycle(4),
    6.U -> mcycle(5),
    7.U -> mcycle(6),
  ))

  // last_tstate
  last_tstate := MuxLookup(tstates, tstate(0))(Seq(
    0.U -> tstate(0),
    1.U -> tstate(1),
    2.U -> tstate(2),
    3.U -> tstate(3),
    4.U -> tstate(4),
    5.U -> tstate(5),
    6.U -> tstate(6),
  ))

  // NextIs_XY_Fetch
  NextIs_XY_Fetch_w :=
    XY_State =/= 0.U && !XY_Ind &&
    ((Set_Addr_To === aXY) ||
     (mcycle(0) && IR === 0xCB.U) ||
     (mcycle(0) && IR === 0x36.U))

  // Save_Mux
  Save_Mux_w := Mux(ExchangeRp, BusB,
                  Mux(!Save_ALU_r, DI_Reg, ALU_Q))

  DI_Reg := io.di

  // Auto_Wait
  Auto_Wait_w := (IntCycle || NMICycle) && mcycle(0)

  // RegAddrA (combinational)
  RegAddrA := RegAddrA_r
  when((tstate(2) || (tstate(3) && mcycle(0) && IncDec_16(2))) && XY_State === 0.U) {
    RegAddrA := Cat(Alternate, IncDec_16(1, 0))
  }.elsewhen((tstate(2) || (tstate(3) && mcycle(0) && IncDec_16(2))) && IncDec_16(1, 0) === 2.U) {
    RegAddrA := Cat(XY_State(1), 3.U(2.W))
  }.elsewhen(ExchangeDH && tstate(3)) {
    RegAddrA := Cat(Alternate, 2.U(2.W))
  }.elsewhen(ExchangeDH && tstate(4)) {
    RegAddrA := Cat(Alternate, 1.U(2.W))
  }

  // RegAddrB (combinational)
  RegAddrB := RegAddrB_r
  when(ExchangeDH && tstate(3)) {
    RegAddrB := Cat(Alternate, 1.U(2.W))
  }

  // RegWEH, RegWEL (combinational)
  RegWEH_w := false.B
  RegWEL_w := false.B
  when((tstate(1) && !Save_ALU_r && !Auto_Wait_t1) ||
       (Save_ALU_r && (ALU_Op_r =/= 7.U))) {
    when(Read_To_Reg_r(4) && Read_To_Reg_r(3, 0) <= 5.U &&
         Read_To_Reg_r(3, 0) =/= 6.U && Read_To_Reg_r(3, 0) =/= 7.U) {
      // Check 5'b1xxxx where xxx in 0..5
      when(Read_To_Reg_r === "b10000".U || Read_To_Reg_r === "b10001".U ||
           Read_To_Reg_r === "b10010".U || Read_To_Reg_r === "b10011".U ||
           Read_To_Reg_r === "b10100".U || Read_To_Reg_r === "b10101".U) {
        RegWEH_w := !Read_To_Reg_r(0)
        RegWEL_w := Read_To_Reg_r(0)
      }
    }
  }
  when(ExchangeDH && (tstate(3) || tstate(4))) {
    RegWEH_w := true.B
    RegWEL_w := true.B
  }
  when(IncDec_16(2) && ((tstate(2) && io.wait_n && !mcycle(0)) ||
       (tstate(3) && mcycle(0)))) {
    when(IncDec_16(1, 0) === 0.U || IncDec_16(1, 0) === 1.U || IncDec_16(1, 0) === 2.U) {
      RegWEH_w := true.B
      RegWEL_w := true.B
    }
  }

  // RegDIH, RegDIL (combinational)
  val ID16    = Wire(UInt(16.W))
  val PC16    = Wire(UInt(16.W))
  val SP16    = Wire(UInt(16.W))
  val PC16_B  = Wire(UInt(16.W))
  val SP16_A  = Wire(UInt(16.W))
  val SP16_B  = Wire(UInt(16.W))
  val ID16_B  = Wire(UInt(16.W))

  RegDIH := Save_Mux_w
  RegDIL := Save_Mux_w
  when(ExchangeDH && tstate(3)) {
    RegDIH := RegBusB(15, 8)
    RegDIL := RegBusB(7, 0)
  }.elsewhen(ExchangeDH && tstate(4)) {
    RegDIH := RegBusA_r(15, 8)
    RegDIL := RegBusA_r(7, 0)
  }.elsewhen(IncDec_16(2) && ((tstate(2) && !mcycle(0)) || (tstate(3) && mcycle(0)))) {
    RegDIH := ID16(15, 8)
    RegDIL := ID16(7, 0)
  }

  // PC arithmetic
  PC16_B := Mux(JumpE, Cat(Fill(8, DI_Reg(7)), DI_Reg),
             Mux(BTR_r, 0xFFFE.U(16.W), 1.U(16.W)))
  PC16 := PC + PC16_B

  // SP arithmetic
  SP16_A := Mux(tstate(3), RegBusC, SP)
  SP16_B := Mux(tstate(3), Cat(Fill(8, DI_Reg(7)), DI_Reg),
             Mux(IncDec_16(3), 0xFFFF.U(16.W), 1.U(16.W)))
  SP16 := SP16_A + SP16_B

  ID16_B := Mux(IncDec_16(3), 0xFFFF.U(16.W), 1.U(16.W))
  ID16 := RegBusA + ID16_B

  // Core datapath update
  when(ClkEn_w) {
      ALU_Op_r     := 0.U
      Save_ALU_r   := false.B
      Read_To_Reg_r := 0.U

      mcycles_r := mcycles_d

      when(IMode =/= 3.U) {
        IStatus := IMode
      }

      Arith16_r   := Arith16
      PreserveC_r := PreserveC
      when(ISet === 2.U && !ALU_Op(2) && ALU_Op(0) && mcycle(2)) {
        Z16_r := true.B
      }.otherwise {
        Z16_r := false.B
      }

      when(mcycle(0) && (tstate(1) || tstate(2) || tstate(3))) {
        // M1 cycles
        when(tstate(2) && io.wait_n) {
          when(!Jump && !Call && !NMICycle && !IntCycle &&
               !(Halt_FF || Halt)) {
            PC := PC16
          }
          when(IntCycle && IStatus === 1.U) {
            IR := 0xFF.U
          }.elsewhen(Halt_FF || (IntCycle && IStatus === 2.U) || NMICycle) {
            IR := 0.U
            TmpAddr := Cat(TmpAddr(15, 8), io.dinst)
          }.otherwise {
            IR := io.dinst
          }

          ISet := 0.U
          when(Prefix =/= 0.U) {
            when(Prefix === 3.U) {
              when(IR(5)) { XY_State := 2.U }
              .otherwise  { XY_State := 1.U }
            }.otherwise {
              when(Prefix === 2.U) {
                XY_State := 0.U
                XY_Ind   := false.B
              }
              ISet := Prefix
            }
          }.otherwise {
            XY_State := 0.U
            XY_Ind   := false.B
          }
        } // tstate(2) && wait_n
      }.otherwise {
        // Not M1, or M1 with tstate > 3
        when(mcycle(5)) {
          XY_Ind := true.B
          when(Prefix === 1.U) {
            ISet := 1.U
          }
        }

        when(T_Res_w) {
          BTR_r := (I_BT || I_BC || I_BTR) && !No_BTR

          when(Jump) {
            A_reg    := Cat(DI_Reg, TmpAddr(7, 0))
            PC       := Cat(DI_Reg, TmpAddr(7, 0))
          }.elsewhen(JumpXY) {
            A_reg := RegBusC
            PC    := RegBusC
          }.elsewhen(Call || RstP) {
            A_reg := TmpAddr
            PC    := TmpAddr
          }.elsewhen(last_mcycle && NMICycle) {
            A_reg := 0x0066.U
            PC    := 0x0066.U
          }.elsewhen(mcycle(2) && IntCycle && IStatus === 2.U) {
            A_reg    := Cat(I, TmpAddr(7, 0))
            PC       := Cat(I, TmpAddr(7, 0))
          }.otherwise {
            switch(Set_Addr_To) {
              is(aXY) {
                when(XY_State === 0.U) {
                  A_reg := RegBusC
                }.otherwise {
                  when(NextIs_XY_Fetch_w) { A_reg := PC }
                  .otherwise              { A_reg := TmpAddr }
                }
              }
              is(aIOA) {
                if (Mode == 3) {
                  A_reg := Cat(0xFF.U(8.W), DI_Reg)
                } else if (Mode == 2) {
                  A_reg := Cat(DI_Reg, DI_Reg)
                } else {
                  A_reg := Cat(ACC, DI_Reg)
                }
              }
              is(aSP) { A_reg := SP }
              is(aBC) {
                if (Mode == 3) {
                  when(iorq_i) {
                    A_reg := Cat(0xFF.U(8.W), RegBusC(7, 0))
                  }.otherwise {
                    A_reg := RegBusC
                  }
                } else {
                  A_reg := RegBusC
                }
              }
              is(aDE) { A_reg := RegBusC }
              is(aZI) {
                when(Inc_WZ) { A_reg := TmpAddr + 1.U }
                .otherwise   { A_reg := Cat(DI_Reg, TmpAddr(7, 0)) }
              }
              is(aNone) { A_reg := PC }
            }
          }

          Save_ALU_r := Save_ALU
          ALU_Op_r   := ALU_Op

          when(I_CPL) {
            ACC        := ~ACC
            F(Flag_Y)  := (~ACC)(5)
            F(Flag_H)  := true.B
            F(Flag_X)  := (~ACC)(3)
            F(Flag_N)  := true.B
          }
          when(I_CCF) {
            F(Flag_C) := !F(Flag_C)
            F(Flag_Y) := ACC(5)
            F(Flag_H) := F(Flag_C)
            F(Flag_X) := ACC(3)
            F(Flag_N) := false.B
          }
          when(I_SCF) {
            F(Flag_C) := true.B
            F(Flag_Y) := ACC(5)
            F(Flag_H) := false.B
            F(Flag_X) := ACC(3)
            F(Flag_N) := false.B
          }
        } // T_Res

        when(tstate(2) && io.wait_n) {
          when(ISet === 1.U && mcycle(6)) { IR := io.dinst }
          when(JumpE)   { PC := PC16 }
          .elsewhen(Inc_PC) { PC := PC16 }
          when(BTR_r)   { PC := PC16 }
          when(RstP)    { TmpAddr := Cat(0.U(10.W), IR(5, 3), 0.U(3.W)) }
        }
        when(tstate(3) && mcycle(5)) {
          TmpAddr := SP16
        }

        when((tstate(2) && io.wait_n) || (tstate(4) && mcycle(0))) {
          when(IncDec_16(2, 0) === 7.U) {
            SP := SP16
          }
        }

        when(LDSPHL) { SP := RegBusC }
        when(ExchangeAF) {
          Ap  := ACC;  ACC := Ap
          Fp  := F.asUInt;  F := VecInit(Fp.asBools)
        }
        when(ExchangeRS) { Alternate := !Alternate }
      } // else (not M1 t1..t3)

      when(tstate(3)) {
        when(LDZ)           { TmpAddr := Cat(TmpAddr(15, 8), DI_Reg) }
        when(LDW)           { TmpAddr := Cat(DI_Reg, TmpAddr(7, 0)) }
        when(Special_LD(2)) {
          switch(Special_LD(1, 0)) {
            is(0.U) { // LD A,I
              ACC       := I
              F(Flag_P) := IntE_FF2
              F(Flag_Z) := (I === 0.U)
              F(Flag_S) := I(7)
              F(Flag_H) := false.B
              F(Flag_N) := false.B
            }
            is(1.U) { // LD A,R (R not implemented, use 0)
              ACC       := 0.U
              F(Flag_P) := IntE_FF2
              F(Flag_Z) := (I === 0.U)
              F(Flag_S) := I(7)
              F(Flag_H) := false.B
              F(Flag_N) := false.B
            }
            is(2.U) { // LD I,A
              I := ACC
            }
            // LD R,A: not implemented (no R register)
          }
        }
      }

      // ALU result handling
      when((!I_DJNZ && Save_ALU_r) || ALU_Op_r === 9.U) {
        if (Mode == 3) {
          F(6) := F_Out(6)
          F(5) := F_Out(5)
          F(7) := F_Out(7)
          when(!PreserveC_r) { F(4) := F_Out(4) }
        } else {
          F(7) := F_Out(7); F(6) := F_Out(6); F(5) := F_Out(5)
          F(4) := F_Out(4); F(3) := F_Out(3); F(2) := F_Out(2); F(1) := F_Out(1)
          when(!PreserveC_r) { F(Flag_C) := F_Out(0) }
        }
      }

      when(T_Res_w && I_INRC) {
        F(Flag_H) := false.B
        F(Flag_N) := false.B
        when(DI_Reg === 0.U) { F(Flag_Z) := true.B }
        .otherwise            { F(Flag_Z) := false.B }
        F(Flag_S) := DI_Reg(7)
        F(Flag_P) := !DI_Reg.xorR
      }

      when(tstate(1) && !Auto_Wait_t1) {
        dout_r := BusB
        when(I_RLD) { dout_r := Cat(BusB(3, 0), BusA(3, 0)) }
        when(I_RRD) { dout_r := Cat(BusA(3, 0), BusB(7, 4)) }
      }

      when(T_Res_w) {
        Read_To_Reg_r := Cat(Read_To_Acc || Read_To_Reg,
                             Mux(Read_To_Acc, 7.U(4.W), Set_BusA_To))
      }

      when(tstate(1) && I_BT) {
        F(Flag_X) := ALU_Q(3)
        F(Flag_Y) := ALU_Q(1)
        F(Flag_H) := false.B
        F(Flag_N) := false.B
      }
      when(tstate(1) && I_BC) {
        F(Flag_X) := cpiXYN(3)
        F(Flag_Y) := cpiXYN(1)
      }
      when(I_BC || I_BT) {
        F(Flag_P) := IncDecZ
      }

      when((tstate(1) && !Save_ALU_r && !Auto_Wait_t1) ||
           (Save_ALU_r && ALU_Op_r =/= 7.U)) {
        switch(Read_To_Reg_r) {
          is("b10111".U) { ACC   := Save_Mux_w }
          is("b10110".U) { dout_r := Save_Mux_w }
          is("b11000".U) { SP    := Cat(SP(15, 8), Save_Mux_w) }
          is("b11001".U) { SP    := Cat(Save_Mux_w, SP(7, 0)) }
          is("b11011".U) { F     := VecInit(Save_Mux_w.asBools) }
        }
      }

  } // ClkEn

  // Register file addr/data registered updates
  when(ClkEn_w) {
      // Bus A addr
      RegAddrA_r := Cat(Alternate, Set_BusA_To(2, 1))
      when(!XY_Ind && XY_State =/= 0.U && Set_BusA_To(2, 1) === 2.U) {
        RegAddrA_r := Cat(XY_State(1), 3.U(2.W))
      }
      // Bus B addr
      RegAddrB_r := Cat(Alternate, Set_BusB_To(2, 1))
      when(!XY_Ind && XY_State =/= 0.U && Set_BusB_To(2, 1) === 2.U) {
        RegAddrB_r := Cat(XY_State(1), 3.U(2.W))
      }
      // Bus C addr
      RegAddrC := Cat(Alternate, Set_Addr_To(1, 0))
      when(JumpXY || LDSPHL) {
        RegAddrC := Cat(Alternate, 2.U(2.W))
      }
      when(((JumpXY || LDSPHL) && XY_State =/= 0.U) || mcycle(5)) {
        RegAddrC := Cat(XY_State(1), 3.U(2.W))
      }

      // IncDecZ
      if (Mode < 2) { when(I_DJNZ && Save_ALU_r) {
        IncDecZ := F_Out(Flag_Z)
      }}
      when((tstate(2) || (tstate(3) && mcycle(0))) && IncDec_16(2, 0) === 4.U) {
        IncDecZ := (ID16 =/= 0.U)
      }

    RegBusA_r := RegBusA
  }

  // Bus registers (posedge clk, no reset in Verilog)
  when(ClkEn_w) {
    switch(Set_BusB_To) {
      is(7.U)  { BusB := ACC }
      is(0.U, 1.U, 2.U, 3.U, 4.U, 5.U) {
        when(Set_BusB_To(0)) { BusB := RegBusB(7, 0) }
        .otherwise            { BusB := RegBusB(15, 8) }
      }
      is(6.U)  { BusB := DI_Reg }
      is(8.U)  { BusB := SP(7, 0) }
      is(9.U)  { BusB := SP(15, 8) }
      is(10.U) { BusB := 1.U }
      is(11.U) { BusB := F.asUInt }
      is(12.U) { BusB := PC(7, 0) }
      is(13.U) { BusB := PC(15, 8) }
      is(14.U) { BusB := 0.U }
      is(15.U) { BusB := 0.U }
    }
    switch(Set_BusA_To) {
      is(7.U)  { BusA := ACC }
      is(0.U, 1.U, 2.U, 3.U, 4.U, 5.U) {
        when(Set_BusA_To(0)) { BusA := RegBusA(7, 0) }
        .otherwise            { BusA := RegBusA(15, 8) }
      }
      is(6.U)  { BusA := DI_Reg }
      is(8.U)  { BusA := SP(7, 0) }
      is(9.U)  { BusA := SP(15, 8) }
      is(10.U) { BusA := 0.U }
      is(11.U) { BusA := 0.U }
      is(12.U) { BusA := 0.U }
      is(13.U) { BusA := 0.U }
      is(14.U) { BusA := 0.U }
      is(15.U) { BusA := 0.U }
    }
  }

  // Sync inputs
  when(io.cen) {
    BusReq_s := !io.busrq_n
    INT_s    := !io.int_n
    when(NMICycle) { NMI_s := false.B }
    .elsewhen(!io.nmi_n && Oldnmi_n) { NMI_s := true.B }
    Oldnmi_n := io.nmi_n
  }

  // Main state machine
  when(io.cen) {
      when(T_Res_w) { Auto_Wait_t1 := false.B }
      .otherwise    { Auto_Wait_t1 := Auto_Wait_w || (iorq_i && !Auto_Wait_t2) }
      Auto_Wait_t2 := Auto_Wait_t1 && !T_Res_w

      No_BTR := (I_BT && (!IR(4) || !F(Flag_P))) ||
                (I_BC && (!IR(4) || F(Flag_Z) || !F(Flag_P))) ||
                (I_BTR && (!IR(4) || F(Flag_Z)))

      when(tstate(2)) {
        when(SetEI) {
          when(!NMICycle) { IntE_FF1 := true.B }
          IntE_FF2 := true.B
        }
        when(I_RETN) { IntE_FF1 := IntE_FF2 }
      }
      when(tstate(3)) {
        when(SetDI) {
          IntE_FF1 := false.B
          IntE_FF2 := false.B
        }
      }

      when(IntCycle || NMICycle) { Halt_FF := false.B }
      when(mcycle(0) && tstate(2) && io.wait_n) { m1_n_r := true.B }

      when(BusReq_s && BusAck) {
        // stay
      }.otherwise {
        BusAck := false.B
        when(tstate(2) && !io.wait_n) {
          // wait
        }.elsewhen(T_Res_w) {
          when(Halt) { Halt_FF := true.B }
          when(BusReq_s) {
            BusAck := true.B
          }.otherwise {
            tstate := "b0000010".U
            when(NextIs_XY_Fetch_w) {
              mcycle    := "b0100000".U
              Pre_XY_F_M := mcycToNumber(mcycle)
              when(IR === 0x36.U && Mode.asUInt === 0.U) { Pre_XY_F_M := 2.U }
            }.elsewhen(mcycle(6) || (mcycle(5) && Mode.asUInt === 1.U && ISet =/= 1.U)) {
              mcycle := numberToBitvec(Pre_XY_F_M +& 1.U)
            }.elsewhen(last_mcycle || No_BTR ||
                       (mcycle(1) && I_DJNZ && IncDecZ)) {
              m1_n_r   := false.B
              mcycle   := "b0000001".U
              IntCycle := false.B
              NMICycle := false.B
              when(NMI_s && Prefix === 0.U) {
                NMICycle := true.B
                IntE_FF1 := false.B
              }.elsewhen(IntE_FF1 && INT_s && Prefix === 0.U && !SetEI) {
                IntCycle := true.B
                IntE_FF1 := false.B
                IntE_FF2 := false.B
              }
            }.otherwise {
              mcycle := Cat(mcycle(5, 0), mcycle(6))
            }
          }
        }.otherwise {
          when(!(Auto_Wait_w && !Auto_Wait_t2) &&
               !(IOWait.asUInt === 1.U && iorq_i && !Auto_Wait_t1)) {
            tstate := Cat(tstate(5, 0), tstate(6))
          }
        }
      }
    // M1 is only asserted during the opcode-fetch machine cycle.
    when(tstate(0) && mcycle(0)) { m1_n_r := false.B }
  }

  // Output assignments
  io.rfsh_n    := true.B  // TV80_REFRESH not defined
  io.m1_n      := m1_n_r
  io.iorq      := iorq_i
  io.no_read   := no_read_w
  io.write     := write_w
  io.halt_n    := !Halt_FF
  io.busak_n   := !BusAck
  io.intcycle_n := !IntCycle
  io.IntE      := IntE_FF1
  io.stop      := I_DJNZ
  io.A         := A_reg
  io.dout      := dout_r
  io.mc        := mcycle
  io.ts        := tstate
}
