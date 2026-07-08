`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.06.2026 17:47:37
// Design Name: 
// Module Name: i2c_master
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




module i2c_master (
    input wire clk,          
    input wire rst_n,        
    input wire enable,       
    input wire read_write,   
    input wire [6:0] addr,   
    input wire [7:0] tx_data,
    output reg [7:0] rx_data,
    output reg ready,        
    output reg done,         
    output reg ack_error,    
    output reg i2c_scl,      
    inout wire i2c_sda       
);

    // FSM States
    localparam STATE_IDLE   = 3'b000;
    localparam STATE_START  = 3'b001;
    localparam STATE_ADDR   = 3'b010;
    localparam STATE_ACK1   = 3'b011;
    localparam STATE_DATA   = 3'b100;
    localparam STATE_ACK2   = 3'b101;
    localparam STATE_STOP   = 3'b110;

    reg [2:0] state;
    reg [3:0] bit_cnt;
    reg [7:0] shift_reg;
    
    reg sda_out;
    reg sda_oe; 
    reg [7:0] clk_cnt;
    
    // Core Clock Enable Pulse Generator (Toggles every 62 clock cycles)
    wire scl_edge = (clk_cnt == 8'd62);

    assign i2c_sda = (sda_oe) ? sda_out : 1'bZ;

    // Fully Synchronous State Machine and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= STATE_IDLE;
            clk_cnt        <= 8'd0;
            bit_cnt        <= 4'd7;
            shift_reg      <= 8'h00;
            rx_data        <= 8'h00;
            ack_error      <= 1'b0;
            done           <= 1'b0;
            ready          <= 1'b1;
            sda_out        <= 1'b1;
            sda_oe         <= 1'b1;
            i2c_scl        <= 1'b1;
        end else begin
            // Increment the clock divider counter
            if (scl_edge) clk_cnt <= 8'd0;
            else          clk_cnt <= clk_cnt + 8'd1;

            // Default done pulse reset
            done <= 1'b0;

            case (state)
                STATE_IDLE: begin  //0
                    ready   <= 1'b1;
                    i2c_scl <= 1'b1;
                    sda_out <= 1'b1;
                    sda_oe  <= 1'b1;
                    if (enable) begin
                        state     <= STATE_START;
                        shift_reg <= {addr, read_write};
                        bit_cnt   <= 4'd7;
                        ready     <= 1'b0;
                    end
                end

                STATE_START: begin    //1
                    if (scl_edge) begin
                      sda_out <= 1'b0; // Pull SDA Low (Start Condition)....while scl is high
                        state   <= STATE_ADDR;
                    end
                end

                STATE_ADDR: begin      //2
                    if (clk_cnt == 8'd0)  i2c_scl <= 1'b0; // Pull SCL low to shift data
                    if (clk_cnt == 8'd31) sda_out <= shift_reg[7]; // Setup data bit
                    if (clk_cnt == 8'd45) i2c_scl <= 1'b1; // Release SCL high for slave capture

                    if (scl_edge) begin
                        if (bit_cnt > 4'd0) begin
                            bit_cnt   <= bit_cnt - 4'd1;
                            shift_reg <= {shift_reg[6:0], 1'b0};
                        end else begin
                            state  <= STATE_ACK1;
                            sda_oe <= 1'b0; // Release SDA for ACK
                        end
                    end
                end

                STATE_ACK1: begin             //3
                    if (clk_cnt == 8'd0)  i2c_scl <= 1'b0;
                    if (clk_cnt == 8'd45) begin
                        i2c_scl   <= 1'b1;
                        ack_error <= i2c_sda; // Sample ACK status
                    end

                    if (scl_edge) begin
                        state   <= STATE_DATA;
                        bit_cnt <= 4'd7;
                        if (read_write) begin
                            sda_oe    <= 1'b0; // Read mode: stay input
                            shift_reg <= 8'h00;
                        end else begin
                            sda_oe    <= 1'b1; // Write mode: turn output back on
                            shift_reg <= tx_data;
                        end
                    end
                end

                STATE_DATA: begin              //4
                    if (clk_cnt == 8'd0) i2c_scl <= 1'b0;
                    if (clk_cnt == 8'd31 && !read_write) sda_out <= shift_reg[7]; 
                    if (clk_cnt == 8'd45) begin
                        i2c_scl <= 1'b1;
                        if (read_write) shift_reg <= {shift_reg[6:0], i2c_sda}; // Sample incoming data
                    end

                    if (scl_edge) begin
                        if (bit_cnt > 4'd0) begin
                            bit_cnt <= bit_cnt - 4'd1;
                            if (!read_write) shift_reg <= {shift_reg[6:0], 1'b0};
                        end else begin
                            state <= STATE_ACK2;
                            if (read_write) begin
                                sda_out <= 1'b1; // Master NACK
                                sda_oe  <= 1'b1;
                                rx_data <= shift_reg;
                            end else begin
                                sda_oe  <= 1'b0; // Write mode: read slave ACK
                            end
                        end
                    end
                end

                STATE_ACK2: begin                //5
                    if (clk_cnt == 8'd0)  i2c_scl <= 1'b0;
                    if (clk_cnt == 8'd45) i2c_scl <= 1'b1;

                    if (scl_edge) begin
                        state   <= STATE_STOP;
                        sda_oe  <= 1'b1;
                        sda_out <= 1'b0; // Prep SDA low for stop rising edge
                    end
                end

                STATE_STOP: begin                 //6
                    if (clk_cnt == 8'd0)  i2c_scl <= 1'b0;
                    if (clk_cnt == 8'd31) i2c_scl <= 1'b1; // SCL high first
                    if (clk_cnt == 8'd45) sda_out <= 1'b1; // SDA rising edge (Stop Condition)

                    if (scl_edge) begin
                        done  <= 1'b1;
                        state <= STATE_IDLE;
                    end
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end
endmodule