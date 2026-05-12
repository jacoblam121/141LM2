# ARIA SystemVerilog Simulation

## Dependencies

The provided Makefile targets use:

- `make`
- `perl`
- `iverilog`
- `vvp`

On Ubuntu/Debian:

```sh
sudo apt-get update
sudo apt-get install -y make perl iverilog
```

`vvp` is installed with the `iverilog` package.

## Running Tests

Run all component and exported program benches:

```sh
make sim_all
```

Individual targets:

```sh
make sim_alu_tb
make sim_pc_tb
make sim_prog1
make sim_prog2
make sim_prog3
```

The Makefile copies `test_benches_export/test_files/test0.txt` through `test9.txt` into each build directory so the exported benches' bare `$readmemb("testN.txt", ...)` paths resolve. It also sanitizes Icarus delay syntax from `#50ns` to `#50` in generated build copies of the benches; the exported source files are not modified.

The `$readmemb` warnings about "Not enough words in the file for the requested range [0:255]" are expected because the test files initialize the input operand region, not all 256 data-memory entries.

## Cleaning

```sh
make clean
```
