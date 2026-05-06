package tv80
import chisel3._
import chisel3.util._

class Tv80Mcode(Mode: Int = 0) extends Module {
  val io = IO(new Bundle {
    val IR          = Input(UInt(8.W))
    val ISet        = Input(UInt(2.W))
    val MCycle      = Input(UInt(7.W))
    val F           = Input(UInt(8.W))
    val NMICycle    = Input(Bool())
    val IntCycle    = Input(Bool())
    val MCycles     = Output(UInt(3.W))
    val TStates     = Output(UInt(3.W))
    val Prefix      = Output(UInt(2.W))
    val Inc_PC      = Output(Bool())
    val Inc_WZ      = Output(Bool())
    val IncDec_16   = Output(UInt(4.W))
    val Read_To_Reg = Output(Bool())
    val Read_To_Acc = Output(Bool())
    val Set_BusA_To = Output(UInt(4.W))
    val Set_BusB_To = Output(UInt(4.W))
    val ALU_Op      = Output(UInt(4.W))
    val Save_ALU    = Output(Bool())
    val PreserveC   = Output(Bool())
    val Arith16     = Output(Bool())
    val Set_Addr_To = Output(UInt(3.W))
    val IORQ        = Output(Bool())
    val Jump        = Output(Bool())
    val JumpE       = Output(Bool())
    val JumpXY      = Output(Bool())
    val Call        = Output(Bool())
    val RstP        = Output(Bool())
    val LDZ         = Output(Bool())
    val LDW         = Output(Bool())
    val LDSPHL      = Output(Bool())
    val Special_LD  = Output(UInt(3.W))
    val ExchangeDH  = Output(Bool())
    val ExchangeRp  = Output(Bool())
    val ExchangeAF  = Output(Bool())
    val ExchangeRS  = Output(Bool())
    val I_DJNZ      = Output(Bool())
    val I_CPL       = Output(Bool())
    val I_CCF       = Output(Bool())
    val I_SCF       = Output(Bool())
    val I_RETN      = Output(Bool())
    val I_BT        = Output(Bool())
    val I_BC        = Output(Bool())
    val I_BTR       = Output(Bool())
    val I_RLD       = Output(Bool())
    val I_RRD       = Output(Bool())
    val I_INRC      = Output(Bool())
    val SetDI       = Output(Bool())
    val SetEI       = Output(Bool())
    val IMode       = Output(UInt(2.W))
    val Halt        = Output(Bool())
    val NoRead      = Output(Bool())
    val Write       = Output(Bool())
  })

  // Address constants
  val aNone = 7.U(3.W)
  val aBC   = 0.U(3.W)
  val aDE   = 1.U(3.W)
  val aXY   = 2.U(3.W)
  val aIOA  = 4.U(3.W)
  val aSP   = 5.U(3.W)
  val aZI   = 6.U(3.W)

  // Bus source select constants (for Set_BusA_To / Set_BusB_To)
  // Values 0-5: register file (bits[2:1] = pair addr, bit[0] = 1 for low byte)
  val bsB    = 0.U(4.W)   // Register B
  val bsC    = 1.U(4.W)   // Register C
  val bsD    = 2.U(4.W)   // Register D
  val bsE    = 3.U(4.W)   // Register E
  val bsH    = 4.U(4.W)   // Register H
  val bsL    = 5.U(4.W)   // Register L
  val bsDI   = 6.U(4.W)   // Data input register (DI_Reg)
  val bsA    = 7.U(4.W)   // Accumulator (ACC)
  val bsSPL  = 8.U(4.W)   // SP low byte
  val bsSPH  = 9.U(4.W)   // SP high byte
  // Values 10-15: BusB-specific sources; BusA outputs 0 for these values
  val bsOne  = 10.U(4.W)  // Constant 1 (BusB) / 0 (BusA)
  val bsF    = 11.U(4.W)  // Flags register F (BusB) / 0 (BusA)
  val bsPCL  = 12.U(4.W)  // PC low byte (BusB) / 0 (BusA)
  val bsPCH  = 13.U(4.W)  // PC high byte (BusB) / 0 (BusA)
  val bsZero = 14.U(4.W)  // Constant 0

  // Flag bit positions (Scala constants, mode-dependent)
  val Flag_C = if (Mode == 3) 4 else 0
  val Flag_N = 1
  val Flag_P = 2
  val Flag_X = 3
  val Flag_H = 4
  val Flag_Y = 5
  val Flag_Z = if (Mode == 3) 7 else 6
  val Flag_S = 7

  def isCcTrue(ff: UInt, cc: UInt): Bool = {
    if (Mode == 3) {
      MuxLookup(cc, false.B)(Seq(
        0.U -> !ff(7),
        1.U -> ff(7).asBool,
        2.U -> !ff(4),
        3.U -> ff(4).asBool,
        4.U -> false.B,
        5.U -> false.B,
        6.U -> false.B,
        7.U -> false.B,
      ))
    } else {
      MuxLookup(cc, false.B)(Seq(
        0.U -> !ff(6),
        1.U -> ff(6).asBool,
        2.U -> !ff(0),
        3.U -> ff(0).asBool,
        4.U -> !ff(2),
        5.U -> ff(2).asBool,
        6.U -> !ff(7),
        7.U -> ff(7).asBool,
      ))
    }
  }

  // Default values for all outputs
  val mcycles    = WireDefault(1.U(3.W))
  val tStates    = WireDefault(Mux(io.MCycle(0), 4.U(3.W), 3.U(3.W)))
  val prefix     = WireDefault(0.U(2.W))
  val incPC      = WireDefault(false.B)
  val incWZ      = WireDefault(false.B)
  val incDec16   = WireDefault(0.U(4.W))
  val readToReg  = WireDefault(false.B)
  val readToAcc  = WireDefault(false.B)
  val setBusATo  = WireDefault(bsB)
  val setBusBTo  = WireDefault(bsB)
  val aluOp      = WireDefault(Cat(0.U(1.W), io.IR(5,3)))
  val saveALU    = WireDefault(false.B)
  val preserveC  = WireDefault(false.B)
  val arith16    = WireDefault(false.B)
  val iorq       = WireDefault(false.B)
  val setAddrTo  = WireDefault(aNone)
  val jump       = WireDefault(false.B)
  val jumpE      = WireDefault(false.B)
  val jumpXY     = WireDefault(false.B)
  val call       = WireDefault(false.B)
  val rstP       = WireDefault(false.B)
  val ldz        = WireDefault(false.B)
  val ldw        = WireDefault(false.B)
  val ldsphl     = WireDefault(false.B)
  val specialLD  = WireDefault(0.U(3.W))
  val exchangeDH = WireDefault(false.B)
  val exchangeRp = WireDefault(false.B)
  val exchangeAF = WireDefault(false.B)
  val exchangeRS = WireDefault(false.B)
  val iDJNZ      = WireDefault(false.B)
  val iCPL       = WireDefault(false.B)
  val iCCF       = WireDefault(false.B)
  val iSCF       = WireDefault(false.B)
  val iRETN      = WireDefault(false.B)
  val iBT        = WireDefault(false.B)
  val iBC        = WireDefault(false.B)
  val iBTR       = WireDefault(false.B)
  val iRLD       = WireDefault(false.B)
  val iRRD       = WireDefault(false.B)
  val iINRC      = WireDefault(false.B)
  val setDI      = WireDefault(false.B)
  val setEI      = WireDefault(false.B)
  val iMode      = WireDefault(3.U(2.W))
  val halt       = WireDefault(false.B)
  val noRead     = WireDefault(false.B)
  val write      = WireDefault(false.B)

  // Local combinational signals
  val DDD   = io.IR(5,3)
  val SSS   = io.IR(2,0)
  val DPAIR = io.IR(5,4)

  // ============================================================
  // ISet == 0: Unprefixed instructions
  // ============================================================
  when(io.ISet === 0.U) {

    // 8'b01zzzzzz: LD r,r' / HALT
    when(io.IR(7,6) === 1.U) {
      when(io.IR(5,0) === 0x36.U) {
        // HALT
        halt := true.B
      }.elsewhen(io.IR(2,0) === 6.U) {
        // LD r,(HL)
        mcycles := 2.U
        when(io.MCycle(0)) { setAddrTo := aXY }
        when(io.MCycle(1)) {
          setBusATo := Cat(0.U(1.W), DDD)
          readToReg := true.B
        }
      }.elsewhen(io.IR(5,3) === 6.U) {
        // LD (HL),r
        mcycles := 2.U
        when(io.MCycle(0)) {
          setAddrTo := aXY
          setBusBTo := Cat(0.U(1.W), SSS)
        }
        when(io.MCycle(1)) { write := true.B }
      }.otherwise {
        // LD r,r'
        setBusBTo  := Cat(0.U(1.W), SSS)
        exchangeRp := true.B
        setBusATo  := Cat(0.U(1.W), DDD)
        readToReg  := true.B
      }

    // 8'b00zzz110: LD (HL),n or LD r,n
    }.elsewhen(io.IR(7,6) === 0.U && io.IR(2,0) === 6.U) {
      when(io.IR(5,3) === 6.U) {
        // LD (HL),n
        mcycles := 3.U
        when(io.MCycle(1)) {
          incPC     := true.B
          setAddrTo := aXY
          setBusBTo := Cat(0.U(1.W), SSS)
        }
        when(io.MCycle(2)) { write := true.B }
      }.otherwise {
        // LD r,n
        mcycles := 2.U
        when(io.MCycle(1)) {
          incPC     := true.B
          setBusATo := Cat(0.U(1.W), DDD)
          readToReg := true.B
        }
      }

    // 8'b00001010: LD A,(BC)
    }.elsewhen(io.IR === 0x0A.U) {
      mcycles := 2.U
      when(io.MCycle(0)) { setAddrTo := aBC }
      when(io.MCycle(1)) { readToAcc := true.B }

    // 8'b00011010: LD A,(DE)
    }.elsewhen(io.IR === 0x1A.U) {
      mcycles := 2.U
      when(io.MCycle(0)) { setAddrTo := aDE }
      when(io.MCycle(1)) { readToAcc := true.B }

    // 8'b00111010: LD A,(nn) or LDD A,(HL) [Mode==3]
    }.elsewhen(io.IR === 0x3A.U) {
      if (Mode == 3) {
        // LDD A,(HL)
        mcycles := 2.U
        when(io.MCycle(0)) { setAddrTo := aXY }
        when(io.MCycle(1)) {
          readToAcc := true.B
          incDec16  := 0xE.U  // 4'b1110
        }
      } else {
        // LD A,(nn)
        mcycles := 4.U
        when(io.MCycle(1)) {
          incPC := true.B
          ldz   := true.B
        }
        when(io.MCycle(2)) {
          setAddrTo := aZI
          incPC     := true.B
        }
        when(io.MCycle(3)) { readToAcc := true.B }
      }

    // 8'b00000010: LD (BC),A
    }.elsewhen(io.IR === 0x02.U) {
      mcycles := 2.U
      when(io.MCycle(0)) {
        setAddrTo := aBC
        setBusBTo := bsA
      }
      when(io.MCycle(1)) { write := true.B }

    // 8'b00010010: LD (DE),A
    }.elsewhen(io.IR === 0x12.U) {
      mcycles := 2.U
      when(io.MCycle(0)) {
        setAddrTo := aDE
        setBusBTo := bsA
      }
      when(io.MCycle(1)) { write := true.B }

    // 8'b00110010: LD (nn),A or LDD (HL),A [Mode==3]
    }.elsewhen(io.IR === 0x32.U) {
      if (Mode == 3) {
        // LDD (HL),A
        mcycles := 2.U
        when(io.MCycle(0)) {
          setAddrTo := aXY
          setBusBTo := bsA
        }
        when(io.MCycle(1)) {
          write    := true.B
          incDec16 := 0xE.U  // 4'b1110
        }
      } else {
        // LD (nn),A
        mcycles := 4.U
        when(io.MCycle(1)) {
          incPC := true.B
          ldz   := true.B
        }
        when(io.MCycle(2)) {
          setAddrTo := aZI
          incPC     := true.B
          setBusBTo := bsA
        }
        when(io.MCycle(3)) { write := true.B }
      }

    // 8'b00zz0001: LD dd,nn
    }.elsewhen(io.IR(7,6) === 0.U && io.IR(3,0) === 1.U) {
      mcycles := 3.U
      when(io.MCycle(1)) {
        incPC     := true.B
        readToReg := true.B
        setBusATo := Mux(DPAIR === 3.U, bsSPL, Cat(0.U(1.W), DPAIR, 1.U(1.W)))
      }
      when(io.MCycle(2)) {
        incPC     := true.B
        readToReg := true.B
        setBusATo := Mux(DPAIR === 3.U, bsSPH, Cat(0.U(1.W), DPAIR, 0.U(1.W)))
      }

    // 8'b00101010: LD HL,(nn) or LDI A,(HL) [Mode==3]
    }.elsewhen(io.IR === 0x2A.U) {
      if (Mode == 3) {
        // LDI A,(HL)
        mcycles := 2.U
        when(io.MCycle(0)) { setAddrTo := aXY }
        when(io.MCycle(1)) {
          readToAcc := true.B
          incDec16  := 6.U  // 4'b0110
        }
      } else {
        // LD HL,(nn)
        mcycles := 5.U
        when(io.MCycle(1)) {
          incPC := true.B
          ldz   := true.B
        }
        when(io.MCycle(2)) {
          setAddrTo := aZI
          incPC     := true.B
          ldw       := true.B
        }
        when(io.MCycle(3)) {
          setBusATo := bsL
          readToReg := true.B
          incWZ     := true.B
          setAddrTo := aZI
        }
        when(io.MCycle(4)) {
          setBusATo := bsH
          readToReg := true.B
        }
      }

    // 8'b00100010: LD (nn),HL or LDI (HL),A [Mode==3]
    }.elsewhen(io.IR === 0x22.U) {
      if (Mode == 3) {
        // LDI (HL),A
        mcycles := 2.U
        when(io.MCycle(0)) {
          setAddrTo := aXY
          setBusBTo := bsA
        }
        when(io.MCycle(1)) {
          write    := true.B
          incDec16 := 6.U  // 4'b0110
        }
      } else {
        // LD (nn),HL
        mcycles := 5.U
        when(io.MCycle(1)) {
          incPC := true.B
          ldz   := true.B
        }
        when(io.MCycle(2)) {
          setAddrTo := aZI
          incPC     := true.B
          ldw       := true.B
          setBusBTo := bsL
        }
        when(io.MCycle(3)) {
          incWZ     := true.B
          setAddrTo := aZI
          write     := true.B
          setBusBTo := bsH
        }
        when(io.MCycle(4)) { write := true.B }
      }

    // 8'b11111001: LD SP,HL
    }.elsewhen(io.IR === 0xF9.U) {
      tStates := 6.U
      ldsphl  := true.B

    // 8'b11zz0101: PUSH qq
    }.elsewhen(io.IR(7,6) === 3.U && io.IR(3,0) === 5.U) {
      mcycles := 3.U
      when(io.MCycle(0)) {
        tStates   := 5.U
        incDec16  := 0xF.U  // 4'b1111 (dec SP)
        setAddrTo := aSP
        setBusBTo := Mux(DPAIR === 3.U, bsA, Cat(0.U(1.W), DPAIR, 0.U(1.W)))
      }
      when(io.MCycle(1)) {
        incDec16  := 0xF.U
        setAddrTo := aSP
        setBusBTo := Mux(DPAIR === 3.U, bsF, Cat(0.U(1.W), DPAIR, 1.U(1.W)))
        write     := true.B
      }
      when(io.MCycle(2)) { write := true.B }

    // 8'b11zz0001: POP qq
    }.elsewhen(io.IR(7,6) === 3.U && io.IR(3,0) === 1.U) {
      mcycles := 3.U
      when(io.MCycle(0)) { setAddrTo := aSP }
      when(io.MCycle(1)) {
        incDec16  := 7.U  // 4'b0111 (inc SP)
        setAddrTo := aSP
        readToReg := true.B
        setBusATo := Mux(DPAIR === 3.U, bsF, Cat(0.U(1.W), DPAIR, 1.U(1.W)))
      }
      when(io.MCycle(2)) {
        incDec16  := 7.U
        readToReg := true.B
        setBusATo := Mux(DPAIR === 3.U, bsA, Cat(0.U(1.W), DPAIR, 0.U(1.W)))
      }

    // 8'b11101011: EX DE,HL
    }.elsewhen(io.IR === 0xEB.U) {
      if (Mode != 3) { exchangeDH := true.B }

    // 8'b00001000: EX AF,AF' or LD (nn),SP [Mode==3]
    }.elsewhen(io.IR === 0x08.U) {
      if (Mode == 3) {
        // LD (nn),SP
        mcycles := 5.U
        when(io.MCycle(1)) {
          incPC := true.B
          ldz   := true.B
        }
        when(io.MCycle(2)) {
          setAddrTo := aZI
          incPC     := true.B
          ldw       := true.B
          setBusBTo := bsSPL
        }
        when(io.MCycle(3)) {
          incWZ     := true.B
          setAddrTo := aZI
          write     := true.B
          setBusBTo := bsSPH
        }
        when(io.MCycle(4)) { write := true.B }
      } else if (Mode < 2) {
        exchangeAF := true.B
      }

    // 8'b11011001: EXX or RETI [Mode==3]
    }.elsewhen(io.IR === 0xD9.U) {
      if (Mode == 3) {
        // RETI
        mcycles := 3.U
        when(io.MCycle(0)) { setAddrTo := aSP }
        when(io.MCycle(1)) {
          incDec16  := 7.U
          setAddrTo := aSP
          ldz       := true.B
        }
        when(io.MCycle(2)) {
          jump     := true.B
          incDec16 := 7.U
          iRETN    := true.B
          setEI    := true.B
        }
      } else if (Mode < 2) {
        exchangeRS := true.B
      }

    // 8'b11100011: EX (SP),HL
    }.elsewhen(io.IR === 0xE3.U) {
      if (Mode != 3) {
        mcycles := 5.U
        when(io.MCycle(0)) { setAddrTo := aSP }
        when(io.MCycle(1)) {
          readToReg := true.B
          setBusATo := bsL
          setBusBTo := bsL
          setAddrTo := aSP
        }
        when(io.MCycle(2)) {
          incDec16  := 7.U
          setAddrTo := aSP
          tStates   := 4.U
          write     := true.B
        }
        when(io.MCycle(3)) {
          readToReg := true.B
          setBusATo := bsH
          setBusBTo := bsH
          setAddrTo := aSP
        }
        when(io.MCycle(4)) {
          incDec16 := 0xF.U
          tStates  := 5.U
          write    := true.B
        }
      }

    // 8'b10zzzzzz: ALU A,r or ALU A,(HL)
    }.elsewhen(io.IR(7,6) === 2.U) {
      when(io.IR(2,0) === 6.U) {
        // ALU A,(HL)
        mcycles := 2.U
        when(io.MCycle(0)) { setAddrTo := aXY }
        when(io.MCycle(1)) {
          readToReg := true.B
          saveALU   := true.B
          setBusBTo := Cat(0.U(1.W), SSS)
          setBusATo := bsA
        }
      }.otherwise {
        // ALU A,r
        setBusBTo := Cat(0.U(1.W), SSS)
        setBusATo := bsA
        readToReg := true.B
        saveALU   := true.B
      }

    // 8'b11zzz110: ALU A,n
    }.elsewhen(io.IR(7,6) === 3.U && io.IR(2,0) === 6.U) {
      mcycles := 2.U
      when(io.MCycle(1)) {
        incPC     := true.B
        readToReg := true.B
        saveALU   := true.B
        setBusBTo := Cat(0.U(1.W), SSS)
        setBusATo := bsA
      }

    // 8'b00zzz100: INC r or INC (HL)
    }.elsewhen(io.IR(7,6) === 0.U && io.IR(2,0) === 4.U) {
      when(io.IR(5,3) === 6.U) {
        // INC (HL)
        mcycles := 3.U
        when(io.MCycle(0)) { setAddrTo := aXY }
        when(io.MCycle(1)) {
          tStates   := 4.U
          setAddrTo := aXY
          readToReg := true.B
          saveALU   := true.B
          preserveC := true.B
          aluOp     := 0.U
          setBusBTo := bsOne  // 4'b1010
          setBusATo := Cat(0.U(1.W), DDD)
        }
        when(io.MCycle(2)) { write := true.B }
      }.otherwise {
        // INC r
        setBusBTo := bsOne
        setBusATo := Cat(0.U(1.W), DDD)
        readToReg := true.B
        saveALU   := true.B
        preserveC := true.B
        aluOp     := 0.U
      }

    // 8'b00zzz101: DEC r or DEC (HL)
    }.elsewhen(io.IR(7,6) === 0.U && io.IR(2,0) === 5.U) {
      when(io.IR(5,3) === 6.U) {
        // DEC (HL)
        mcycles := 3.U
        when(io.MCycle(0)) { setAddrTo := aXY }
        when(io.MCycle(1)) {
          tStates   := 4.U
          setAddrTo := aXY
          aluOp     := 2.U
          readToReg := true.B
          saveALU   := true.B
          preserveC := true.B
          setBusBTo := bsOne
          setBusATo := Cat(0.U(1.W), DDD)
        }
        when(io.MCycle(2)) { write := true.B }
      }.otherwise {
        // DEC r
        setBusBTo := bsOne
        setBusATo := Cat(0.U(1.W), DDD)
        readToReg := true.B
        saveALU   := true.B
        preserveC := true.B
        aluOp     := 2.U
      }

    // 8'b00100111: DAA
    }.elsewhen(io.IR === 0x27.U) {
      setBusATo := bsA
      readToReg := true.B
      aluOp     := 0xC.U
      saveALU   := true.B

    // 8'b00101111: CPL
    }.elsewhen(io.IR === 0x2F.U) {
      iCPL := true.B

    // 8'b00111111: CCF
    }.elsewhen(io.IR === 0x3F.U) {
      iCCF := true.B

    // 8'b00110111: SCF
    }.elsewhen(io.IR === 0x37.U) {
      iSCF := true.B

    // 8'b00000000: NOP / NMI / INT
    }.elsewhen(io.IR === 0x00.U) {
      when(io.NMICycle) {
        mcycles := 3.U
        when(io.MCycle(0)) {
          tStates   := 5.U
          incDec16  := 0xF.U
          setAddrTo := aSP
          setBusBTo := bsPCH
        }
        when(io.MCycle(1)) {
          tStates   := 4.U
          write     := true.B
          incDec16  := 0xF.U
          setAddrTo := aSP
          setBusBTo := bsPCL
        }
        when(io.MCycle(2)) {
          tStates := 4.U
          write   := true.B
        }
      }.elsewhen(io.IntCycle) {
        mcycles := 5.U
        when(io.MCycle(0)) {
          ldz       := true.B
          tStates   := 5.U
          incDec16  := 0xF.U
          setAddrTo := aSP
          setBusBTo := bsPCH
        }
        when(io.MCycle(1)) {
          tStates   := 4.U
          write     := true.B
          incDec16  := 0xF.U
          setAddrTo := aSP
          setBusBTo := bsPCL
        }
        when(io.MCycle(2)) {
          tStates := 4.U
          write   := true.B
        }
        when(io.MCycle(3)) {
          incPC := true.B
          ldz   := true.B
        }
        when(io.MCycle(4)) { jump := true.B }
      }

    // 8'b11110011: DI
    }.elsewhen(io.IR === 0xF3.U) {
      setDI := true.B

    // 8'b11111011: EI
    }.elsewhen(io.IR === 0xFB.U) {
      setEI := true.B

    // 8'b00zz1001: ADD HL,ss
    }.elsewhen(io.IR(7,6) === 0.U && io.IR(3,0) === 9.U) {
      mcycles := 3.U
      when(io.MCycle(1)) {
        noRead    := true.B
        aluOp     := 0.U
        readToReg := true.B
        saveALU   := true.B
        setBusATo := bsL
        when(io.IR(5,4) === 0.U || io.IR(5,4) === 1.U || io.IR(5,4) === 2.U) {
          setBusBTo := Cat(0.U(1.W), io.IR(5,4), 1.U(1.W))
        }.otherwise {
          setBusBTo := bsSPL
        }
        tStates := 4.U
        arith16 := true.B
      }
      when(io.MCycle(2)) {
        noRead    := true.B
        readToReg := true.B
        saveALU   := true.B
        aluOp     := 1.U
        setBusATo := bsH
        when(io.IR(5,4) === 0.U || io.IR(5,4) === 1.U || io.IR(5,4) === 2.U) {
          setBusBTo := Cat(0.U(1.W), io.IR(5,4), 0.U(1.W))
        }.otherwise {
          setBusBTo := bsSPH
        }
        arith16 := true.B
      }

    // 8'b00zz0011: INC ss
    }.elsewhen(io.IR(7,6) === 0.U && io.IR(3,0) === 3.U) {
      tStates  := 6.U
      incDec16 := Cat("b01".U(2.W), DPAIR)

    // 8'b00zz1011: DEC ss
    }.elsewhen(io.IR(7,6) === 0.U && io.IR(3,0) === 11.U) {
      tStates  := 6.U
      incDec16 := Cat("b11".U(2.W), DPAIR)

    // 8'b00000111,00010111,00001111,00011111: RLCA,RLA,RRCA,RRA
    }.elsewhen(io.IR === 0x07.U || io.IR === 0x17.U || io.IR === 0x0F.U || io.IR === 0x1F.U) {
      setBusATo := bsA
      aluOp     := 8.U
      readToReg := true.B
      saveALU   := true.B

    // 8'b11000011: JP nn
    }.elsewhen(io.IR === 0xC3.U) {
      mcycles := 3.U
      when(io.MCycle(1)) {
        incPC := true.B
        ldz   := true.B
      }
      when(io.MCycle(2)) {
        incPC := true.B
        jump  := true.B
      }

    // 8'b11zzz010: JP cc,nn (or Mode3 LD instructions)
    }.elsewhen(io.IR(7,6) === 3.U && io.IR(2,0) === 2.U) {
      if (Mode == 3) {
        when(io.IR(5)) {
          // Mode 3 special instructions based on IR[4:3]
          switch(io.IR(4,3)) {
            is(0.U) {
              // LD ($FF00+C),A
              mcycles := 2.U
              when(io.MCycle(0)) {
                setAddrTo := aBC
                setBusBTo := bsA
              }
              when(io.MCycle(1)) {
                write := true.B
                iorq  := true.B
              }
            }
            is(1.U) {
              // LD (nn),A
              mcycles := 4.U
              when(io.MCycle(1)) {
                incPC := true.B
                ldz   := true.B
              }
              when(io.MCycle(2)) {
                setAddrTo := aZI
                incPC     := true.B
                setBusBTo := bsA
              }
              when(io.MCycle(3)) { write := true.B }
            }
            is(2.U) {
              // LD A,($FF00+C)
              mcycles := 2.U
              when(io.MCycle(0)) { setAddrTo := aBC }
              when(io.MCycle(1)) {
                readToAcc := true.B
                iorq      := true.B
              }
            }
            is(3.U) {
              // LD A,(nn)
              mcycles := 4.U
              when(io.MCycle(1)) {
                incPC := true.B
                ldz   := true.B
              }
              when(io.MCycle(2)) {
                setAddrTo := aZI
                incPC     := true.B
              }
              when(io.MCycle(3)) { readToAcc := true.B }
            }
          }
        }.otherwise {
          // JP cc,nn
          mcycles := 3.U
          when(io.MCycle(1)) {
            incPC := true.B
            ldz   := true.B
          }
          when(io.MCycle(2)) {
            incPC := true.B
            when(isCcTrue(io.F, io.IR(5,3))) { jump := true.B }
          }
        }
      } else {
        // JP cc,nn
        mcycles := 3.U
        when(io.MCycle(1)) {
          incPC := true.B
          ldz   := true.B
        }
        when(io.MCycle(2)) {
          incPC := true.B
          when(isCcTrue(io.F, io.IR(5,3))) { jump := true.B }
        }
      }

    // 8'b00011000: JR e
    }.elsewhen(io.IR === 0x18.U) {
      if (Mode != 2) {
        mcycles := 3.U
        when(io.MCycle(1)) { incPC := true.B }
        when(io.MCycle(2)) {
          noRead  := true.B
          jumpE   := true.B
          tStates := 5.U
        }
      }

    // 8'b001zz000: JR cc,e (NZ/Z/NC/C)
    }.elsewhen(io.IR(7,5) === 1.U && io.IR(2,0) === 0.U) {
      if (Mode != 2) {
        mcycles := 3.U
        when(io.MCycle(1)) {
          incPC := true.B
          switch(io.IR(4,3)) {
            is(0.U) { mcycles := Mux(io.F(Flag_Z), 2.U(3.W), 3.U(3.W)) }  // JR NZ
            is(1.U) { mcycles := Mux(!io.F(Flag_Z), 2.U(3.W), 3.U(3.W)) } // JR Z
            is(2.U) { mcycles := Mux(io.F(Flag_C), 2.U(3.W), 3.U(3.W)) }  // JR NC
            is(3.U) { mcycles := Mux(!io.F(Flag_C), 2.U(3.W), 3.U(3.W)) } // JR C
          }
        }
        when(io.MCycle(2)) {
          noRead  := true.B
          jumpE   := true.B
          tStates := 5.U
        }
      }

    // 8'b11101001: JP (HL)
    }.elsewhen(io.IR === 0xE9.U) {
      jumpXY := true.B

    // 8'b00010000: DJNZ,e or I_DJNZ [Mode==3]
    }.elsewhen(io.IR === 0x10.U) {
      if (Mode == 3) {
        iDJNZ := true.B
      } else if (Mode < 2) {
        mcycles := 3.U
        when(io.MCycle(0)) {
          tStates   := 5.U
          iDJNZ     := true.B
          setBusBTo := bsOne
          setBusATo := bsB
          readToReg := true.B
          saveALU   := true.B
          aluOp     := 2.U
        }
        when(io.MCycle(1)) {
          iDJNZ := true.B
          incPC := true.B
        }
        when(io.MCycle(2)) {
          noRead  := true.B
          jumpE   := true.B
          tStates := 5.U
        }
      }

    // 8'b11001101: CALL nn
    }.elsewhen(io.IR === 0xCD.U) {
      mcycles := 5.U
      when(io.MCycle(1)) {
        incPC := true.B
        ldz   := true.B
      }
      when(io.MCycle(2)) {
        incDec16  := 0xF.U
        incPC     := true.B
        tStates   := 4.U
        setAddrTo := aSP
        ldw       := true.B
        setBusBTo := bsPCH
      }
      when(io.MCycle(3)) {
        write     := true.B
        incDec16  := 0xF.U
        setAddrTo := aSP
        setBusBTo := bsPCL
      }
      when(io.MCycle(4)) {
        write := true.B
        call  := true.B
      }

    // 8'b11zzz100: CALL cc,nn
    }.elsewhen(io.IR(7,6) === 3.U && io.IR(2,0) === 4.U) {
      // Verilog: if (IR[5] == 1'b0 || Mode != 3) — Mode is compile-time
      if (Mode != 3) {
        mcycles := 5.U
        when(io.MCycle(1)) {
          incPC := true.B
          ldz   := true.B
        }
        when(io.MCycle(2)) {
          incPC := true.B
          ldw   := true.B
          when(isCcTrue(io.F, io.IR(5,3))) {
            incDec16  := 0xF.U
            setAddrTo := aSP
            tStates   := 4.U
            setBusBTo := bsPCH
          }.otherwise {
            mcycles := 3.U
          }
        }
        when(io.MCycle(3)) {
          write     := true.B
          incDec16  := 0xF.U
          setAddrTo := aSP
          setBusBTo := bsPCL
        }
        when(io.MCycle(4)) {
          write := true.B
          call  := true.B
        }
      } else {
        // Mode == 3: only decode when IR[5] == 0
        when(!io.IR(5)) {
          mcycles := 5.U
          when(io.MCycle(1)) {
            incPC := true.B
            ldz   := true.B
          }
          when(io.MCycle(2)) {
            incPC := true.B
            ldw   := true.B
            when(isCcTrue(io.F, io.IR(5,3))) {
              incDec16  := 0xF.U
              setAddrTo := aSP
              tStates   := 4.U
              setBusBTo := bsPCH
            }.otherwise {
              mcycles := 3.U
            }
          }
          when(io.MCycle(3)) {
            write     := true.B
            incDec16  := 0xF.U
            setAddrTo := aSP
            setBusBTo := bsPCL
          }
          when(io.MCycle(4)) {
            write := true.B
            call  := true.B
          }
        }
      }

    // 8'b11001001: RET
    }.elsewhen(io.IR === 0xC9.U) {
      mcycles := 3.U
      when(io.MCycle(0)) { setAddrTo := aSP }
      when(io.MCycle(1)) {
        incDec16  := 7.U
        setAddrTo := aSP
        ldz       := true.B
      }
      when(io.MCycle(2)) {
        jump     := true.B
        incDec16 := 7.U
      }

    // 8'b11zzz000: RET cc or Mode3 instructions
    }.elsewhen(io.IR(7,6) === 3.U && io.IR(2,0) === 0.U) {
      if (Mode == 3) {
        when(io.IR(5)) {
          switch(io.IR(4,3)) {
            is(0.U) {
              // LD ($FF00+nn),A
              mcycles := 3.U
              when(io.MCycle(1)) {
                incPC     := true.B
                setAddrTo := aIOA
                setBusBTo := bsA
              }
              when(io.MCycle(2)) { write := true.B }
            }
            is(1.U) {
              // ADD SP,n
              mcycles := 3.U
              when(io.MCycle(1)) {
                aluOp     := 0.U
                incPC     := true.B
                readToReg := true.B
                saveALU   := true.B
                setBusATo := bsSPL
                setBusBTo := bsDI
              }
              when(io.MCycle(2)) {
                noRead    := true.B
                readToReg := true.B
                saveALU   := true.B
                aluOp     := 1.U
                setBusATo := bsSPH
                setBusBTo := bsZero
              }
            }
            is(2.U) {
              // LD A,($FF00+nn)
              mcycles := 3.U
              when(io.MCycle(1)) {
                incPC     := true.B
                setAddrTo := aIOA
              }
              when(io.MCycle(2)) { readToAcc := true.B }
            }
            is(3.U) {
              // LD HL,SP+n
              mcycles := 5.U
              when(io.MCycle(1)) {
                incPC := true.B
                ldz   := true.B
              }
              when(io.MCycle(2)) {
                setAddrTo := aZI
                incPC     := true.B
                ldw       := true.B
              }
              when(io.MCycle(3)) {
                setBusATo := bsL
                readToReg := true.B
                incWZ     := true.B
                setAddrTo := aZI
              }
              when(io.MCycle(4)) {
                setBusATo := bsH
                readToReg := true.B
              }
            }
          }
        }.otherwise {
          // RET cc
          mcycles := 3.U
          when(io.MCycle(0)) {
            when(isCcTrue(io.F, io.IR(5,3))) {
              setAddrTo := aSP
            }.otherwise {
              mcycles := 1.U
            }
            tStates := 5.U
          }
          when(io.MCycle(1)) {
            incDec16  := 7.U
            setAddrTo := aSP
            ldz       := true.B
          }
          when(io.MCycle(2)) {
            jump     := true.B
            incDec16 := 7.U
          }
        }
      } else {
        // RET cc
        mcycles := 3.U
        when(io.MCycle(0)) {
          when(isCcTrue(io.F, io.IR(5,3))) {
            setAddrTo := aSP
          }.otherwise {
            mcycles := 1.U
          }
          tStates := 5.U
        }
        when(io.MCycle(1)) {
          incDec16  := 7.U
          setAddrTo := aSP
          ldz       := true.B
        }
        when(io.MCycle(2)) {
          jump     := true.B
          incDec16 := 7.U
        }
      }

    // 8'b11zzz111: RST p
    }.elsewhen(io.IR(7,6) === 3.U && io.IR(2,0) === 7.U) {
      mcycles := 3.U
      when(io.MCycle(0)) {
        tStates   := 5.U
        incDec16  := 0xF.U
        setAddrTo := aSP
        setBusBTo := bsPCH
      }
      when(io.MCycle(1)) {
        write     := true.B
        incDec16  := 0xF.U
        setAddrTo := aSP
        setBusBTo := bsPCL
      }
      when(io.MCycle(2)) {
        write := true.B
        rstP  := true.B
      }

    // 8'b11011011: IN A,(n)
    }.elsewhen(io.IR === 0xDB.U) {
      if (Mode != 3) {
        mcycles := 3.U
        when(io.MCycle(1)) {
          incPC     := true.B
          setAddrTo := aIOA
        }
        when(io.MCycle(2)) {
          readToAcc := true.B
          iorq      := true.B
        }
      }

    // 8'b11010011: OUT (n),A
    }.elsewhen(io.IR === 0xD3.U) {
      if (Mode != 3) {
        mcycles := 3.U
        when(io.MCycle(1)) {
          incPC     := true.B
          setAddrTo := aIOA
          setBusBTo := bsA
        }
        when(io.MCycle(2)) {
          write := true.B
          iorq  := true.B
        }
      }

    // 8'b11001011: CB prefix
    }.elsewhen(io.IR === 0xCB.U) {
      if (Mode != 2) { prefix := 1.U }

    // 8'b11101101: ED prefix
    }.elsewhen(io.IR === 0xED.U) {
      if (Mode < 2) { prefix := 2.U }

    // 8'b11011101,8'b11111101: DD/FD prefix
    }.elsewhen(io.IR === 0xDD.U || io.IR === 0xFD.U) {
      if (Mode < 2) { prefix := 3.U }
    }

  // ============================================================
  // ISet == 1: CB-prefixed instructions
  // ============================================================
  }.elsewhen(io.ISet === 1.U) {
    setBusATo := Cat(0.U(1.W), io.IR(2,0))
    setBusBTo := Cat(0.U(1.W), io.IR(2,0))

    when(io.IR(7,6) === 0.U && io.IR(2,0) =/= 6.U) {
      // RLC/RL/RRC/RR/SLA/SRA/SRL/SLL r
      when(io.MCycle(0)) {
        aluOp     := 8.U
        readToReg := true.B
        saveALU   := true.B
      }
    }.elsewhen(io.IR(7,6) === 0.U) {
      // RLC/RL/RRC/RR/SLA/SRA/SRL/SLL (HL)
      mcycles := 3.U
      when(io.MCycle(0) || io.MCycle(6)) { setAddrTo := aXY }
      when(io.MCycle(1)) {
        aluOp     := 8.U
        readToReg := true.B
        saveALU   := true.B
        setAddrTo := aXY
        tStates   := 4.U
      }
      when(io.MCycle(2)) { write := true.B }
    }.elsewhen(io.IR(7,6) === 1.U && io.IR(2,0) =/= 6.U) {
      // BIT b,r
      when(io.MCycle(0)) {
        setBusBTo := Cat(0.U(1.W), io.IR(2,0))
        aluOp     := 9.U
      }
    }.elsewhen(io.IR(7,6) === 1.U) {
      // BIT b,(HL)
      mcycles := 2.U
      when(io.MCycle(0) || io.MCycle(6)) { setAddrTo := aXY }
      when(io.MCycle(1)) {
        aluOp   := 9.U
        tStates := 4.U
      }
    }.elsewhen(io.IR(7,6) === 3.U && io.IR(2,0) =/= 6.U) {
      // SET b,r
      when(io.MCycle(0)) {
        aluOp     := 0xA.U
        readToReg := true.B
        saveALU   := true.B
      }
    }.elsewhen(io.IR(7,6) === 3.U) {
      // SET b,(HL)
      mcycles := 3.U
      when(io.MCycle(0) || io.MCycle(6)) { setAddrTo := aXY }
      when(io.MCycle(1)) {
        aluOp     := 0xA.U
        readToReg := true.B
        saveALU   := true.B
        setAddrTo := aXY
        tStates   := 4.U
      }
      when(io.MCycle(2)) { write := true.B }
    }.elsewhen(io.IR(7,6) === 2.U && io.IR(2,0) =/= 6.U) {
      // RES b,r
      when(io.MCycle(0)) {
        aluOp     := 0xB.U
        readToReg := true.B
        saveALU   := true.B
      }
    }.elsewhen(io.IR(7,6) === 2.U) {
      // RES b,(HL)
      mcycles := 3.U
      when(io.MCycle(0) || io.MCycle(6)) { setAddrTo := aXY }
      when(io.MCycle(1)) {
        aluOp     := 0xB.U
        readToReg := true.B
        saveALU   := true.B
        setAddrTo := aXY
        tStates   := 4.U
      }
      when(io.MCycle(2)) { write := true.B }
    }

  // ============================================================
  // ISet default (ED-prefixed instructions)
  // ============================================================
  }.otherwise {

    // 8'b01010111: LD A,I
    when(io.IR === 0x57.U) {
      specialLD := 4.U
      tStates   := 5.U

    // 8'b01011111: LD A,R
    }.elsewhen(io.IR === 0x5F.U) {
      specialLD := 5.U
      tStates   := 5.U

    // 8'b01000111: LD I,A
    }.elsewhen(io.IR === 0x47.U) {
      specialLD := 6.U
      tStates   := 5.U

    // 8'b01001111: LD R,A
    }.elsewhen(io.IR === 0x4F.U) {
      specialLD := 7.U
      tStates   := 5.U

    // 8'b01xx1011: LD dd,(nn)
    }.elsewhen(io.IR === 0x4B.U || io.IR === 0x5B.U || io.IR === 0x6B.U || io.IR === 0x7B.U) {
      mcycles := 5.U
      when(io.MCycle(1)) {
        incPC := true.B
        ldz   := true.B
      }
      when(io.MCycle(2)) {
        setAddrTo := aZI
        incPC     := true.B
        ldw       := true.B
      }
      when(io.MCycle(3)) {
        readToReg := true.B
        setBusATo := Mux(io.IR(5,4) === 3.U, bsSPL, Cat(0.U(1.W), io.IR(5,4), 1.U(1.W)))
        incWZ     := true.B
        setAddrTo := aZI
      }
      when(io.MCycle(4)) {
        readToReg := true.B
        setBusATo := Mux(io.IR(5,4) === 3.U, bsSPH, Cat(0.U(1.W), io.IR(5,4), 0.U(1.W)))
      }

    // 8'b01xx0011: LD (nn),dd
    }.elsewhen(io.IR === 0x43.U || io.IR === 0x53.U || io.IR === 0x63.U || io.IR === 0x73.U) {
      mcycles := 5.U
      when(io.MCycle(1)) {
        incPC := true.B
        ldz   := true.B
      }
      when(io.MCycle(2)) {
        setAddrTo := aZI
        incPC     := true.B
        ldw       := true.B
        setBusBTo := Mux(io.IR(5,4) === 3.U, bsSPL, Cat(0.U(1.W), io.IR(5,4), 1.U(1.W)))
      }
      when(io.MCycle(3)) {
        incWZ     := true.B
        setAddrTo := aZI
        write     := true.B
        setBusBTo := Mux(io.IR(5,4) === 3.U, bsSPH, Cat(0.U(1.W), io.IR(5,4), 0.U(1.W)))
      }
      when(io.MCycle(4)) { write := true.B }

    // 8'b101x1000,8'b101x0000: LDI,LDD,LDIR,LDDR (0xA0,0xA8,0xB0,0xB8)
    }.elsewhen(io.IR === 0xA0.U || io.IR === 0xA8.U || io.IR === 0xB0.U || io.IR === 0xB8.U) {
      mcycles := 4.U
      when(io.MCycle(0)) {
        setAddrTo := aXY
        incDec16  := 0xC.U  // dec BC
      }
      when(io.MCycle(1)) {
        setBusBTo := bsDI
        setBusATo := bsA  // A
        aluOp     := 0.U
        setAddrTo := aDE
        incDec16  := Mux(io.IR(3), 0xE.U, 6.U)  // dec or inc IX
      }
      when(io.MCycle(2)) {
        iBT     := true.B
        tStates := 5.U
        write   := true.B
        incDec16 := Mux(io.IR(3), 0xD.U, 5.U)  // dec or inc DE
      }
      when(io.MCycle(3)) {
        noRead  := true.B
        tStates := 5.U
      }

    // 8'b101x1001,8'b101x0001: CPI,CPD,CPIR,CPDR (0xA1,0xA9,0xB1,0xB9)
    }.elsewhen(io.IR === 0xA1.U || io.IR === 0xA9.U || io.IR === 0xB1.U || io.IR === 0xB9.U) {
      mcycles := 4.U
      when(io.MCycle(0)) {
        setAddrTo := aXY
        incDec16  := 0xC.U
      }
      when(io.MCycle(1)) {
        setBusBTo := bsDI
        setBusATo := bsA
        aluOp     := 7.U
        saveALU   := true.B
        preserveC := true.B
        incDec16  := Mux(io.IR(3), 0xE.U, 6.U)
      }
      when(io.MCycle(2)) {
        noRead  := true.B
        iBC     := true.B
        tStates := 5.U
      }
      when(io.MCycle(3)) {
        noRead  := true.B
        tStates := 5.U
      }

    // 8'b01xx0100 variants: NEG
    }.elsewhen(io.IR === 0x44.U || io.IR === 0x4C.U || io.IR === 0x54.U || io.IR === 0x5C.U ||
               io.IR === 0x64.U || io.IR === 0x6C.U || io.IR === 0x74.U || io.IR === 0x7C.U) {
      aluOp     := 2.U
      setBusBTo := bsA
      setBusATo := bsOne
      readToAcc := true.B
      saveALU   := true.B

    // IM 0
    }.elsewhen(io.IR === 0x46.U || io.IR === 0x4E.U || io.IR === 0x66.U || io.IR === 0x6E.U) {
      iMode := 0.U

    // IM 1
    }.elsewhen(io.IR === 0x56.U || io.IR === 0x76.U) {
      iMode := 1.U

    // IM 2
    }.elsewhen(io.IR === 0x5E.U || io.IR === 0x7E.U || io.IR === 0x77.U) {
      iMode := 2.U

    // 8'b01xx1010: ADC HL,ss
    }.elsewhen(io.IR === 0x4A.U || io.IR === 0x5A.U || io.IR === 0x6A.U || io.IR === 0x7A.U) {
      mcycles := 3.U
      when(io.MCycle(1)) {
        noRead    := true.B
        aluOp     := 1.U
        readToReg := true.B
        saveALU   := true.B
        setBusATo := bsL
        when(io.IR(5,4) === 0.U || io.IR(5,4) === 1.U || io.IR(5,4) === 2.U) {
          setBusBTo := Cat(0.U(1.W), io.IR(5,4), 1.U(1.W))
        }.otherwise {
          setBusBTo := bsSPL
        }
        tStates := 4.U
      }
      when(io.MCycle(2)) {
        noRead    := true.B
        readToReg := true.B
        saveALU   := true.B
        aluOp     := 1.U
        setBusATo := bsH
        when(io.IR(5,4) === 0.U || io.IR(5,4) === 1.U || io.IR(5,4) === 2.U) {
          setBusBTo := Cat(0.U(1.W), io.IR(5,4), 0.U(1.W))
        }.otherwise {
          setBusBTo := bsSPH
        }
      }

    // 8'b01xx0010: SBC HL,ss
    }.elsewhen(io.IR === 0x42.U || io.IR === 0x52.U || io.IR === 0x62.U || io.IR === 0x72.U) {
      mcycles := 3.U
      when(io.MCycle(1)) {
        noRead    := true.B
        aluOp     := 3.U
        readToReg := true.B
        saveALU   := true.B
        setBusATo := bsL
        when(io.IR(5,4) === 0.U || io.IR(5,4) === 1.U || io.IR(5,4) === 2.U) {
          setBusBTo := Cat(0.U(1.W), io.IR(5,4), 1.U(1.W))
        }.otherwise {
          setBusBTo := bsSPL
        }
        tStates := 4.U
      }
      when(io.MCycle(2)) {
        noRead    := true.B
        aluOp     := 3.U
        readToReg := true.B
        saveALU   := true.B
        setBusATo := bsH
        when(io.IR(5,4) === 0.U || io.IR(5,4) === 1.U || io.IR(5,4) === 2.U) {
          setBusBTo := Cat(0.U(1.W), io.IR(5,4), 0.U(1.W))
        }.otherwise {
          setBusBTo := bsSPH
        }
      }

    // 8'b01101111: RLD
    }.elsewhen(io.IR === 0x6F.U) {
      mcycles := 4.U
      when(io.MCycle(1)) {
        noRead    := true.B
        setAddrTo := aXY
      }
      when(io.MCycle(2)) {
        readToReg := true.B
        setBusBTo := bsDI
        setBusATo := bsA
        aluOp     := 0xD.U
        tStates   := 4.U
        setAddrTo := aXY
        saveALU   := true.B
      }
      when(io.MCycle(3)) {
        iRLD  := true.B
        write := true.B
      }

    // 8'b01100111: RRD
    }.elsewhen(io.IR === 0x67.U) {
      mcycles := 4.U
      when(io.MCycle(1)) { setAddrTo := aXY }
      when(io.MCycle(2)) {
        readToReg := true.B
        setBusBTo := bsDI
        setBusATo := bsA
        aluOp     := 0xE.U
        tStates   := 4.U
        setAddrTo := aXY
        saveALU   := true.B
      }
      when(io.MCycle(3)) {
        iRRD  := true.B
        write := true.B
      }

    // 8'b01xx0101,01xx1101: RETN/RETI
    }.elsewhen(io.IR === 0x45.U || io.IR === 0x4D.U || io.IR === 0x55.U || io.IR === 0x5D.U ||
               io.IR === 0x65.U || io.IR === 0x6D.U || io.IR === 0x75.U || io.IR === 0x7D.U) {
      mcycles := 3.U
      when(io.MCycle(0)) { setAddrTo := aSP }
      when(io.MCycle(1)) {
        incDec16  := 7.U
        setAddrTo := aSP
        ldz       := true.B
      }
      when(io.MCycle(2)) {
        jump     := true.B
        incDec16 := 7.U
        iRETN    := true.B
      }

    // 8'b01xxx000: IN r,(C)
    }.elsewhen(io.IR === 0x40.U || io.IR === 0x48.U || io.IR === 0x50.U || io.IR === 0x58.U ||
               io.IR === 0x60.U || io.IR === 0x68.U || io.IR === 0x70.U || io.IR === 0x78.U) {
      mcycles := 2.U
      when(io.MCycle(0)) { setAddrTo := aBC }
      when(io.MCycle(1)) {
        iorq  := true.B
        when(io.IR(5,3) =/= 6.U) {
          readToReg := true.B
          setBusATo := Cat(0.U(1.W), io.IR(5,3))
        }
        iINRC := true.B
      }

    // 8'b01xxx001: OUT (C),r
    }.elsewhen(io.IR === 0x41.U || io.IR === 0x49.U || io.IR === 0x51.U || io.IR === 0x59.U ||
               io.IR === 0x61.U || io.IR === 0x69.U || io.IR === 0x71.U || io.IR === 0x79.U) {
      mcycles := 2.U
      when(io.MCycle(0)) {
        setAddrTo := aBC
        setBusBTo := Cat((io.IR(5,3) === 6.U), io.IR(5,3))
      }
      when(io.MCycle(1)) {
        write := true.B
        iorq  := true.B
      }

    // 8'b101x1010,8'b101x0010: INI,IND,INIR,INDR (0xA2,0xAA,0xB2,0xBA)
    }.elsewhen(io.IR === 0xA2.U || io.IR === 0xAA.U || io.IR === 0xB2.U || io.IR === 0xBA.U) {
      mcycles := 4.U
      when(io.MCycle(0)) {
        setAddrTo := aBC
        setBusBTo := bsOne
        setBusATo := bsB
        readToReg := true.B
        saveALU   := true.B
        aluOp     := 2.U
      }
      when(io.MCycle(1)) {
        iorq      := true.B
        setBusBTo := bsDI
        setAddrTo := aXY
      }
      when(io.MCycle(2)) {
        incDec16 := Mux(io.IR(3), 0xE.U, 6.U)
        tStates  := 4.U
        write    := true.B
        iBTR     := true.B
      }
      when(io.MCycle(3)) {
        noRead  := true.B
        tStates := 5.U
      }

    // 8'b101x1011,8'b101x0011: OUTI,OUTD,OTIR,OTDR (0xA3,0xAB,0xB3,0xBB)
    }.elsewhen(io.IR === 0xA3.U || io.IR === 0xAB.U || io.IR === 0xB3.U || io.IR === 0xBB.U) {
      mcycles := 4.U
      when(io.MCycle(0)) {
        tStates   := 5.U
        setAddrTo := aXY
        setBusBTo := bsOne
        setBusATo := bsB
        readToReg := true.B
        saveALU   := true.B
        aluOp     := 2.U
      }
      when(io.MCycle(1)) {
        setBusBTo := bsDI
        setAddrTo := aBC
        incDec16  := Mux(io.IR(3), 0xE.U, 6.U)
      }
      when(io.MCycle(2)) {
        incDec16 := Mux(io.IR(3), 0xA.U, 2.U)
        iorq     := true.B
        write    := true.B
        iBTR     := true.B
      }
      when(io.MCycle(3)) {
        noRead  := true.B
        tStates := 5.U
      }
    }
  }

  // ============================================================
  // Post-processing (overrides ISet-block assignments)
  // ============================================================
  if (Mode == 1) {
    when(!io.MCycle(0)) { tStates := 3.U }
  }

  if (Mode == 3) {
    when(!io.MCycle(0)) { tStates := 4.U }
  }

  if (Mode < 2) {
    when(io.MCycle(5)) {
      incPC := true.B
      if (Mode == 1) {
        setAddrTo := aXY
        tStates   := 4.U
        setBusBTo := Cat(0.U(1.W), SSS)
      }
      when(io.IR === "b00110110".U || io.IR === "b11001011".U) {
        setAddrTo := aNone
      }
    }
    when(io.MCycle(6)) {
      if (Mode == 0) { tStates := 5.U }
      when(io.ISet =/= 1.U) { setAddrTo := aXY }
      setBusBTo := Cat(0.U(1.W), SSS)
      when(io.IR === "b00110110".U || io.ISet === 1.U) {
        incPC := true.B
      }.otherwise {
        noRead := true.B
      }
    }
  }

  // ============================================================
  // Connect outputs
  // ============================================================
  io.MCycles      := mcycles
  io.TStates      := tStates
  io.Prefix       := prefix
  io.Inc_PC       := incPC
  io.Inc_WZ       := incWZ
  io.IncDec_16    := incDec16
  io.Read_To_Reg  := readToReg
  io.Read_To_Acc  := readToAcc
  io.Set_BusA_To  := setBusATo
  io.Set_BusB_To  := setBusBTo
  io.ALU_Op       := aluOp
  io.Save_ALU     := saveALU
  io.PreserveC    := preserveC
  io.Arith16      := arith16
  io.Set_Addr_To  := setAddrTo
  io.IORQ         := iorq
  io.Jump         := jump
  io.JumpE        := jumpE
  io.JumpXY       := jumpXY
  io.Call         := call
  io.RstP         := rstP
  io.LDZ          := ldz
  io.LDW          := ldw
  io.LDSPHL       := ldsphl
  io.Special_LD   := specialLD
  io.ExchangeDH   := exchangeDH
  io.ExchangeRp   := exchangeRp
  io.ExchangeAF   := exchangeAF
  io.ExchangeRS   := exchangeRS
  io.I_DJNZ       := iDJNZ
  io.I_CPL        := iCPL
  io.I_CCF        := iCCF
  io.I_SCF        := iSCF
  io.I_RETN       := iRETN
  io.I_BT         := iBT
  io.I_BC         := iBC
  io.I_BTR        := iBTR
  io.I_RLD        := iRLD
  io.I_RRD        := iRRD
  io.I_INRC       := iINRC
  io.SetDI        := setDI
  io.SetEI        := setEI
  io.IMode        := iMode
  io.Halt         := halt
  io.NoRead       := noRead
  io.Write        := write
}
