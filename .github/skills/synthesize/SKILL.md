---
name: synthesize
description: 'Synthesize TV80 RTL using Yosys. Use when: running synthesis, checking area/cell counts, generating netlists, analyzing logic, checking for synthesis warnings or errors, reporting gate-level statistics.'
argument-hint: '[target: generic|synth_ice40|synth_xilinx] [extra yosys flags]'
---

# TV80 Synthesis with Yosys

## When to Use
- Synthesize the tv80s top-level and its core files
- Check cell counts, flip-flop counts, and logic area
- Generate a synthesized netlist
- Detect synthesis warnings or unresolved references
- Evaluate RTL changes against gate-level results

## Environment
- Container: `davidsiaw/yosys-docker:latest`
- RTL source: `rtl/core/` (tv80s.v, tv80_core.v, tv80_mcode.v, tv80_alu.v, tv80_reg.v)
- Top-level module: `tv80s`
- Output: `synth/` directory at project root

## Procedure

### Step 1 – Create output directory
```pwsh
New-Item -ItemType Directory -Force -Path "c:\Users\Guy\Documents\tv80\synth" | Out-Null
```

### Step 2 – Run Yosys synthesis
```pwsh
$prj = "c:\Users\Guy\Documents\tv80"
podman run --rm -v "${prj}:/app" -w /app davidsiaw/yosys-docker:latest yosys -p `
  "read_verilog rtl/core/tv80_reg.v rtl/core/tv80_alu.v rtl/core/tv80_mcode.v rtl/core/tv80_core.v rtl/core/tv80s.v; `
   hierarchy -check -top tv80s; `
   synth -top tv80s; `
   stat; `
   write_verilog -noattr synth/tv80s_synth.v" 2>&1
```

This performs the default generic synthesis flow:
1. Reads all five core RTL files
2. Checks hierarchy starting from `tv80s`
3. Runs `synth` (elaboration → coarse → fine → map to generic cells)
4. Prints cell statistics (`stat`)
5. Writes the synthesized netlist to `synth/tv80s_synth.v`

### Step 3 – Technology-specific synthesis (optional)

For iCE40 FPGA targets (requires `synth_ice40` in yosys):
```pwsh
$prj = "c:\Users\Guy\Documents\tv80"
podman run --rm -v "${prj}:/app" -w /app davidsiaw/yosys-docker:latest yosys -p `
  "read_verilog rtl/core/tv80_reg.v rtl/core/tv80_alu.v rtl/core/tv80_mcode.v rtl/core/tv80_core.v rtl/core/tv80s.v; `
   hierarchy -check -top tv80s; `
   synth_ice40 -top tv80s; `
   stat; `
   write_verilog -noattr synth/tv80s_ice40.v" 2>&1
```

For Xilinx/Vivado targets:
```pwsh
$prj = "c:\Users\Guy\Documents\tv80"
podman run --rm -v "${prj}:/app" -w /app davidsiaw/yosys-docker:latest yosys -p `
  "read_verilog rtl/core/tv80_reg.v rtl/core/tv80_alu.v rtl/core/tv80_mcode.v rtl/core/tv80_core.v rtl/core/tv80s.v; `
   hierarchy -check -top tv80s; `
   synth_xilinx -top tv80s; `
   stat; `
   write_verilog -noattr synth/tv80s_xilinx.v" 2>&1
```

### Step 4 – Interpret results

Key lines to look for in the `stat` output:
- `Number of wires` / `Number of cells` — overall design size
- `$_DFF_` / `$dff` — flip-flop count (≈ state elements in cpu)
- `$_MUX_` / `$mux` — multiplexer count (large in control logic)
- Warnings: `Warning: multiple conflicting drivers` or `Warning: found no top module`

### Step 5 – Check for errors
Any line containing `ERROR` or `Assert failed` indicates a synthesis failure.
Lines containing `Warning` should be reviewed — undriven inputs or multi-driver nets may indicate RTL issues.

## Notes
- The `TV80DELAY` macro (used in tv80s.v) expands to nothing for synthesis; no special defines needed
- Do **not** include testbench or simulation-only files (`verif/`) in the synthesis run
- The `sd_zmem.v` and `sd_access64.v` files in `rtl/core/` are not part of `tv80s` hierarchy; they are standalone utilities
- Output netlist is placed in `synth/` which is not version-controlled (add to `.gitignore` if needed)
