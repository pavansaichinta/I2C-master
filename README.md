# I2C Master Controller (Verilog)

A fully synthesizable, parameterized I2C (Inter-Integrated Circuit) Master Controller implemented in Verilog HDL. This design handles standard I2C protocol sequencing to communicate with peripheral devices (like EEPROMs, temperature sensors, or RTCs) using a two-wire serial interface.

## Key Features
- **Protocol Support:** Generates START, STOP, and REPEATED START conditions seamlessly.
- **Parameterized Design:** Adjustable Clock Division Factor to easily scale down the system clock to standard I2C speeds (100 kHz Standard Mode or 400 kHz Fast Mode).
- **Acknowledge Handling:** Supports both Master ACK/NACK generation and Slave ACK verification with error flags.
- **State Machine Architecture:** Clean, robust Finite State Machine (FSM) managing 7-bit addressing, read/write bit operations, and data serialization.

## Architecture & Interface
The controller translates parallel data from a host processor or system bus into the serial I2C format.

### Ports Definition
| Port Name | Direction | Width | Description |
|-----------|-----------|-------|-------------|
| `clk`     | Input     | 1     | System Clock |
| `rst_n`   | Input     | 1     | Active-Low Asynchronous Reset |
| `start`   | Input     | 1     | Initiates a transaction when high |
| `rw`      | Input     | 1     | Read/Write select (0 = Write, 1 = Read) |
| `addr`    | Input     | 7     | 7-bit Target Slave Address |
| `data_in` | Input     | 8     | Parallel data byte to be transmitted |
| `data_out`| Output    | 8     | Parallel data byte received from Slave |
| `busy`    | Output    | 1     | High when a transaction is actively in progress |
| `ack_err` | Output    | 1     | Flag raised if a Slave fails to assert an ACK |
| `sda`     | Inout     | 1     | Serial Data Line (Requires pull-up simulation) |
| `scl`     | Inout/Out | 1     | Serial Clock Line |

---

## State Machine (FSM) Flow
The controller moves through a precise sequence to execute data transfers securely:
1. **IDLE:** Waiting for the `start` signal.
2. **START:** Pulls SDA low while SCL is high to signal a transfer beginning.
3. **ADDRESS + RW:** Shifts out the 7-bit target address followed by the R/W bit.
4. **SLAVE ACK:** Releases SDA line and monitors for the slave's low response.
5. **DATA TRANSFER:** Serializes data bytes (Write mode) or captures incoming bits (Read mode).
6. **MASTER ACK/NACK:** Sends acknowledgment back to the slave during read operations.
7. **STOP:** Drives SDA from low to high while SCL is high to terminate the bus cycle.

---

## Verification & Simulation
The design was verified using a self-checking testbench in Xilinx Vivado and also in EDA Playground. The simulation models a complete Master Write and Master Read operation, verifying exact timing requirements for setup, hold, and clock synchronization.
