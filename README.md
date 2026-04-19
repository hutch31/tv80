TV80 is a Z80-compatible synthesizable Verilog core.

The TV80 core aims to be an area-efficient core which closely mimics
the original operation and cycle timing of the Zilog Z80.  The core
has been used by the author/porter in multiple silicon tape-outs as
a utility processor or programmable state machine.

The top level wrapper is the tv80s, which presents a synchronous
interface where all signals transition on the positive edge of the clock.

## Docker/Podman

A Dockerfile is provided for hosting verification tools for the project.  To build the container
and run it use the following commands:

```
docker build -t tvtools .
docker run -it -v <prj_folder>:/app -w /app tvtools

# Build all tests
docker run -it -v <prj_folder>:/app -w /app tvtools sh -c "(cd tests; make)"
```
