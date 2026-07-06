# ✨🌙 DreamStream ✨🌙
### or: The 100G Ethernet Core

DreamStream is a collection of reusable hardware modules for building high-performance streaming protocols on arbitrary data path widths. The architecture scales from 1G and 10G designs up to 100G Ethernet applications while maintaining a simple and consistent programming model.

All interfaces are based on the AXI Stream standard, and every module is designed around a minimal, composable interface.

## Design Principles

DreamStream follows three core principles:

- **KISS:** DreamStream focuses on efficient, high-throughput data streaming. It intentionally avoids implementing complex protocol stacks or infrastructure components such as ARP resolution or TCP. The primary target use case is moving large amounts of data with minimal overhead.

- **Modular Design:** Modules are designed with loose coupling and high cohesion, allowing systems to be assembled from small, reusable building blocks.

- **Abstraction and Reuse:** Common functionality is implemented once and reused throughout the project, minimizing code duplication and simplifying maintenance.

## Core Components

- **FIFO:** A standard AXI Stream FIFO with configurable data width and depth.

- **Parser / Composer:** These modules simplify protocol development. The parser extracts a fixed-size header from the data stream and places it into the `tuser` sideband channel while automatically realigning the payload so that `tkeep` remains MSB-oriented. This enables hierarchical protocol implementations where each protocol layer can be implemented as an independent, reusable module. A typical example is a UDP/IP/Ethernet stack, where each protocol layer uses its own parser and composer instance.

- **Keep Shifter:** A utility module capable of shifting `tkeep` by a constant number of bytes. It is primarily used internally by the parser and composer modules.

- **DSBus:** The DreamStream bus infrastructure provides a lightweight implementation of AXI4-Lite-style register fields and simple 1:N crossbars.

- **DSNet:** The networking package built on top of the parser and composer infrastructure. It contains Ethernet-related modules and protocol building blocks while remaining intentionally compact and easy to understand.

## Supported Architectures

DreamStream is written entirely in standard VHDL and does not rely on vendor-specific primitives.

- Most modules require only VHDL-2008.
- `dsbus` uses selected VHDL-2019 features.

As a result, DreamStream is portable across a wide range of FPGA families.

### Validated Platforms

DreamStream is currently used in atomic physics experiments at GSI Darmstadt and has been deployed on:

- Lattice ECP5 (1G)
- Lattice CertusPro-NX (10G)
- Xilinx Artix (1G)
- Xilinx Kintex (1G)

In addition, the design has been tested with high-speed traffic generators on a Xilinx Alveo U280, demonstrating reliable operation in 100G streaming applications.

## Example
See [example](./example).

## Tests
We added tests of the most critical components into `/testbenches`.

## License
DreamStream is licensed under the CERN OHL-W (see [LICENSE.txt](LICENSE.txt)).

The files `async_fifo.vhd` and `resync.vhd` are derived from the [hdl-modules](https://hdl-modules.com) project, which is licensed under the BSD 3-Clause License.
