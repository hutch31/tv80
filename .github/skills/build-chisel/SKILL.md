---
name: build-chisel
description: 'Build TV80 Chisel RTL by running sbt. Use when: building Chisel code, generating Verilog from Chisel, running sbt runMain, compiling tv80 Chisel sources, checking for Chisel build errors.'
argument-hint: '[optional: extra sbt arguments]'
---

# Build TV80 Chisel Code

## When to Use
- Compile and build the TV80 Chisel source files
- Generate Verilog output from Chisel RTL
- Check for Chisel/Scala compilation errors
- After editing any `.scala` file under `src/`

## Procedure

### Step 1 – Run the build
```pwsh
cd c:\Users\Guy\Documents\tv80
sbt "runMain tv80.tv80build"
```

### Step 2 – Check the output
- A successful build prints `[success]` at the end
- Errors include file name, line number, and message — fix them in the relevant `.scala` file
- Generated Verilog is written to the project root (or the path configured in the build main)

## Notes
- Run from the workspace root (`c:\Users\Guy\Documents\tv80`)
- Requires Java and sbt on PATH
- Chisel sources are under `src/main/scala/tv80/`
- Do **not** modify RTL files in `rtl/`
