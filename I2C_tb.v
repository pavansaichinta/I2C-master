`timescale 1ns/1ps


//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.06.2026 13:47:37
// Design Name: 
// Module Name: i2c_master_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////




module i2c_master_tb;

    reg clk;
    reg rst_n;
    reg enable;
    reg read_write;
    reg [6:0] addr;
    reg [7:0] tx_data;
    wire [7:0] rx_data;
    wire ready;
    wire done;
    wire ack_error;
    
    wire i2c_scl;
    wire i2c_sda;

    // Standard tri1 network explicitly handles the pull-up behavior for open-drain
    tri1 i2c_sda_io;
    tri1 i2c_scl_io;

    assign i2c_sda_io = i2c_sda;
    assign i2c_scl_io = i2c_scl;

    i2c_master uut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .read_write(read_write),
        .addr(addr),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .ready(ready),
        .done(done),
        .ack_error(ack_error),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda_io)
    );

    // Mock Slave output controls
    reg slave_sda_out;
    reg slave_drive_en;
    assign i2c_sda_io = (slave_drive_en) ? slave_sda_out : 1'bZ;

    // 50 MHz Clock Generator
    always #10 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, i2c_master_tb);
    end

    // Direct, robust clock delay task for simple execution
    task wait_cycles(input integer count);
        integer i;
        begin
            for (i = 0; i < count; i = i + 1) begin
                @(posedge clk);
            end
        end
    endtask

    initial begin
        clk        = 1'b0;
        rst_n      = 1'b0;
        enable     = 1'b0;
        read_write = 1'b0;
        addr       = 7'h00;
        tx_data    = 8'h00;
        slave_drive_en = 1'b0;
        slave_sda_out  = 1'b1;

        // Release Reset safely
        wait_cycles(10);
        rst_n = 1'b1; 
        wait_cycles(10);

        // ====================================================================
        // TEST CASE 1: WRITE TRANSACTION
        // ====================================================================
        $display("[TB] Starting Stable Write Operation...");
        addr       = 7'h50;  
        tx_data    = 8'hA5;  
        read_write = 1'b0;  
        enable     = 1'b1;   
        wait_cycles(1);
        enable     = 1'b0; 

        // Wait for Address bits transmission to complete
        wait_cycles(550);
        
        // Drive Address ACK Slot
        slave_drive_en = 1'b1;
        slave_sda_out  = 1'b0; 
        wait_cycles(70);
        slave_drive_en = 1'b0; // Release

        // Wait out data frame write sequence
        wait_cycles(520);
        
        // Drive Data ACK Slot
        slave_drive_en = 1'b1;
        slave_sda_out  = 1'b0; 
        wait_cycles(70);
        slave_drive_en = 1'b0; 

        // Wait dynamically for transaction completion signal pulse
        @(posedge done);
        $display("[TB] Write Operation Finished Successfully.");
        wait_cycles(100);

        // ====================================================================
        // TEST CASE 2: READ TRANSACTION
        // ====================================================================
        $display("[TB] Starting Stable Read Operation...");
        addr       = 7'h50;  
        read_write = 1'b1;  // 1 = Read Mode
        enable     = 1'b1;
        wait_cycles(1);
        enable     = 1'b0; 

        // Wait out address transmission bits
        wait_cycles(550);

        // Drive Address ACK Slot
        slave_drive_en = 1'b1;
        slave_sda_out  = 1'b0; 
        wait_cycles(70);
        
        // Feed mock data payload back to master bit-by-bit: 8'h3C (00111100)
        slave_sda_out = 1'b0; wait_cycles(63); // Bit 7
        slave_sda_out = 1'b0; wait_cycles(63); // Bit 6
        slave_sda_out = 1'b1; wait_cycles(63); // Bit 5
        slave_sda_out = 1'b1; wait_cycles(63); // Bit 4
        slave_sda_out = 1'b1; wait_cycles(63); // Bit 3
        slave_sda_out = 1'b1; wait_cycles(63); // Bit 2
        slave_sda_out = 1'b0; wait_cycles(63); // Bit 1
      slave_sda_out = 1'b0; wait_cycles(63); // Bit 0
        
        slave_drive_en = 1'b0; // Release so master can issue NACK frame safely

        // Wait for completion pulse flag
        @(posedge done);

        // Final Automated Verification Check
        if (rx_data === 8'h3C) begin
            $display("[SUCCESS] Simulation Passed! Received rx_data: %h", rx_data);
        end else begin
            $display("[FAIL] Data mismatch! Expected: 3C, Received: %h", rx_data);
        end

        wait_cycles(50);
        $display("[TB] Simulation Completed Successfully.");
        $finish; 
    end

endmodule