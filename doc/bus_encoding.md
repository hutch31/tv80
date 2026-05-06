# Bus Source Encoding (`Set_BusA_To` / `Set_BusB_To`)

The 4-bit `Set_BusA_To` and `Set_BusB_To` signals select the source loaded into the ALU A and B input registers each clock cycle. Named constants are defined in `Tv80Mcode.scala`.

## Encoding Table

| Value | Constant | BusB source    | BusA source    |
|-------|----------|----------------|----------------|
| 0     | `bsB`    | Register B     | Register B     |
| 1     | `bsC`    | Register C     | Register C     |
| 2     | `bsD`    | Register D     | Register D     |
| 3     | `bsE`    | Register E     | Register E     |
| 4     | `bsH`    | Register H     | Register H     |
| 5     | `bsL`    | Register L     | Register L     |
| 6     | `bsDI`   | DI_Reg         | DI_Reg         |
| 7     | `bsA`    | ACC            | ACC            |
| 8     | `bsSPL`  | SP(7:0)        | SP(7:0)        |
| 9     | `bsSPH`  | SP(15:8)       | SP(15:8)       |
| 10    | `bsOne`  | Constant 1     | 0 (unused)     |
| 11    | `bsF`    | Flags (F)      | 0 (unused)     |
| 12    | `bsPCL`  | PC(7:0)        | 0 (unused)     |
| 13    | `bsPCH`  | PC(15:8)       | 0 (unused)     |
| 14    | `bsZero` | Constant 0     | Constant 0     |
| 15    | —        | Constant 0     | Constant 0     |

## Notes

- Values 0–5 index the register file. Bits [2:1] select the register pair (BC=00, DE=01, HL=10, SP/AF=11) and bit [0] selects the byte within the pair: 0 = high byte, 1 = low byte.
- Values 10–14 are only meaningful for BusB. BusA outputs 0 for all values ≥ 10.
- `bsF` (11) is used when pushing AF to the stack (PUSH qq, CALL, interrupt handling), placing the flags register on BusB.
- `bsPCL`/`bsPCH` (12/13) are used when pushing the return address to the stack during CALL, RST, NMI and INT sequences.
- `bsOne` (10) is used as the constant +1 operand for INC/DEC 8-bit operations and as the decrement operand for DJNZ.
- `bsZero` (14) is used to supply a zero carry byte for the high byte of ADD SP,n.
