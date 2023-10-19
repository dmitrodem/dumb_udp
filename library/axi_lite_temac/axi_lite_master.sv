///////////////////////////////////////////////////////////////////////////////
//
// AXI4-Lite Master
//
////////////////////////////////////////////////////////////////////////////
//
// Structure:
//   axi_lite_master
//
// Last Update:
//   7/8/2010
////////////////////////////////////////////////////////////////////////////
/*
 AXI4-Lite Master Example

 The purpose of this design is to provide a simple AXI4-Lite example.

 The distinguishing characteristics of AXI4-Lite are the single-beat transfers,
 limited data width, and limited other transaction qualifiers. These make it
 best suited for low-throughput control functions.

 The example user application will perform a set of writes from a lookup
 table. This may be useful for initial register configurations, such as
 setting the AXI_VDMA register settings. After completing all the writes,
 the example design will perform reads and attempt to verify the values.

 If the reads match the write values and no error responses were captured,
 the DONE_SUCCESS output will be asserted.

 To modify this example for other applications, edit/remove the logic
 associated with the 'Example' section comments. Generally, this example
 works by the user providing a 'push_write' or 'pop_read' command to initiate
 a command and data transfer.

 The latest version of this file can be found in Xilinx Answer 37425
 http://www.xilinx.com/support/answers/37425.htm
 */
`timescale 1ns/1ps

module axi_lite_master #
  (
  parameter integer C_M_AXI_ADDR_WIDTH = 32,
  parameter integer C_M_AXI_DATA_WIDTH = 32
)
  (
  // System Signals
  input wire M_AXI_ACLK,
  input wire M_AXI_ARESETN,

  // Master Interface Write Address
  output wire [C_M_AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR,
  output wire [3-1:0] M_AXI_AWPROT,
  output wire M_AXI_AWVALID,
  input wire M_AXI_AWREADY,

  // Master Interface Write Data
  output wire [C_M_AXI_DATA_WIDTH-1:0] M_AXI_WDATA,
  output wire [C_M_AXI_DATA_WIDTH/8-1:0] M_AXI_WSTRB,
  output wire M_AXI_WVALID,
  input wire M_AXI_WREADY,

  // Master Interface Write Response
  input wire [2-1:0] M_AXI_BRESP,
  input wire M_AXI_BVALID,
  output wire M_AXI_BREADY,

  // Master Interface Read Address
  output wire [C_M_AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR,
  output wire [3-1:0] M_AXI_ARPROT,
  output wire M_AXI_ARVALID,
  input wire M_AXI_ARREADY,

  // Master Interface Read Data
  input wire [C_M_AXI_DATA_WIDTH-1:0] M_AXI_RDATA,
  input wire [2-1:0] M_AXI_RRESP,
  input wire M_AXI_RVALID,
  output wire M_AXI_RREADY,

  input wire start,
  output wire link_ok

);


  localparam bit [7:0] PHY_ADDR   = 8'h07;
  localparam bit [1:0] MDIO_READ  = 2'b10;
  localparam bit [1:0] MDIO_WRITE = 2'b01;

  typedef enum bit [4:0] {
    ST_RESET,
    ST_INIT_DELAY,
    ST_MDC_SCALER,
    ST_MAC_SPEED,
    ST_ADV_1G,
    ST_ADV_10_100,
    ST_PHY_RESET,
    ST_REQ_PHY_STATUS,
    ST_CHECK_PHY_STATUS,
    ST_RESET_MAC_RX,
    ST_RESET_MAC_TX,
    ST_MAC_SPEED1,
    ST_DISABLE_FLOW_CONTROL,
    ST_ENABLE_PROMISC_MODE,
    ST_FINISH_MAC_CFG,
    ST_REQ_PHY_STATUS1,
    ST_CHECK_PHY_STATUS1
  } fsm_t;

  typedef enum bit [1:0] {
    AXI_STATE_IDLE,
    AXI_STATE_WRITE,
    AXI_STATE_READ
  } axi_state_t;

  typedef enum bit [1:0] {
    AXI_RESULT_NONE,
    AXI_RESULT_PENDING,
    AXI_RESULT_OK,
    AXI_RESULT_ERROR
  } axi_result_t;

  typedef enum bit [2:0] {
    MDIO_IDLE,
    MDIO_READ0, MDIO_READ1,
    MDIO_WRITE0, MDIO_WRITE1, MDIO_WRITE2
  } mdio_state_t;

  typedef struct packed {
    bit [C_M_AXI_ADDR_WIDTH-1:0] awaddr;
    bit [3-1:0] awprot;
    bit         awvalid;

    bit [C_M_AXI_DATA_WIDTH-1:0]   wdata;
    bit [C_M_AXI_DATA_WIDTH/8-1:0] wstrb;
    bit                            wvalid;

    bit                            bready;

    bit [C_M_AXI_ADDR_WIDTH-1:0]   araddr;
    bit [3-1:0]                    arprot;
    bit                            arvalid;

    bit                            rready;

    fsm_t                          state;
    bit [23:0]                     cnt;

    bit [C_M_AXI_DATA_WIDTH-1:0]   rdata;
    bit [2:0]                      bresp;

    bit                            start;

    axi_state_t axi_state;
    axi_result_t axi_result;
    mdio_state_t mdio_state;
    bit [15:0] mdio_data;
    bit        link_ok;
  } reg_t;

  localparam reg_t RES_reg_t = '{
    awaddr  : {C_M_AXI_ADDR_WIDTH{1'b0}},
    awprot  : 3'b000,
    awvalid : 1'b0,
    wdata   : {C_M_AXI_DATA_WIDTH{1'b0}},
    wstrb   : {C_M_AXI_DATA_WIDTH/8{1'b1}},
    wvalid  : 1'b0,
    bready  : 1'b0,
    araddr  : {C_M_AXI_ADDR_WIDTH{1'b0}},
    arprot  : 3'b000,
    arvalid : 1'b0,
    rready  : 1'b0,
    state   : ST_RESET,
    cnt     : {24{1'b1}},
    rdata   : {C_M_AXI_DATA_WIDTH{1'b0}},
    bresp   : 3'b000,
    start   : 1'b0,
    axi_state : AXI_STATE_IDLE,
    axi_result : AXI_RESULT_NONE,
    mdio_state : MDIO_IDLE,
    mdio_data : 16'h0,
    link_ok   : 1'b0
  };

  reg_t r;
  reg_t rin;

  localparam bit [31:0] AXI_BASE = 32'h44a00000;

  task automatic axi_write_start (
     output           reg_t v,
     input bit [31:0] address,
     input bit [31:0] data);
    begin
      v.axi_state = AXI_STATE_WRITE;
      v.axi_result = AXI_RESULT_PENDING;
      v.awaddr    = address;
      v.wdata     = data;
      v.awvalid   = 1'b1;
      v.wvalid    = 1'b1;
      v.bready    = 1'b1;
    end
  endtask : axi_write_start

  task automatic axi_read_start (
    output           reg_t v,
    input bit [31:0] address);
    begin
      v.axi_state  = AXI_STATE_READ;
      v.axi_result = AXI_RESULT_PENDING;
      v.araddr     = address;
      v.arvalid    = 1'b1;
      v.rready     = 1'b1;
    end
  endtask : axi_read_start

  function automatic axi_done (
    input reg_t r);
    begin
      return (r.axi_state == AXI_STATE_IDLE);
    end
  endfunction : axi_done

  task automatic mdio_read_start (
    output          reg_t v,
    input bit [7:0] address);
    begin
      axi_write_start(v, AXI_BASE | 32'h504, {PHY_ADDR, address, MDIO_READ, 3'h1, 11'h0});
      v.mdio_state = MDIO_READ0;
    end
  endtask : mdio_read_start

  task automatic mdio_write_start (
     output           reg_t v,
     input bit [7:0]  address,
     input bit [15:0] data);
    begin
      axi_write_start(v, AXI_BASE | 32'h504, {PHY_ADDR, address, MDIO_WRITE, 3'h1, 11'h0});
      v.mdio_data  = data;
      v.mdio_state = MDIO_WRITE0;
    end
  endtask : mdio_write_start

  function automatic bit mdio_done (
    input reg_t r);
    begin
      return (r.mdio_state == MDIO_IDLE);
    end
  endfunction : mdio_done


  always_comb begin : x_comb
    automatic reg_t v;
    v = r;

    v.start = start;
    case (r.state)
      ST_RESET : begin
        v.link_ok = 1'b0;
        v.cnt = -1;
        v.state = ST_INIT_DELAY;
      end
      ST_INIT_DELAY :
        if (r.cnt == 0) begin
          v.state = ST_MDC_SCALER;
        end else begin
          v.cnt = r.cnt - 1;
        end
      ST_MDC_SCALER : begin
        // set MDIO MDC frequency to 2.5 MHz
        axi_write_start(v, AXI_BASE | 32'h500, 32'h68);
        v.state = ST_MAC_SPEED;
      end
      ST_MAC_SPEED : // MAC speed = 1G
        if (axi_done(r)) begin
          axi_write_start(v, AXI_BASE | 32'h410, 32'h80000000);
          v.state = ST_ADV_1G;
        end
      ST_ADV_1G : // PHY_1000BASE_T -> advertize 1000BASE-T Full Duplex only
        if (axi_done(r)) begin
          mdio_write_start(v, 8'h09, 16'h0200);
          v.state = ST_ADV_10_100;
        end
      ST_ADV_10_100 : // PHY_AUTONEG -> do not advertize 10/100 Mbit/s
        if (mdio_done(r)) begin
          mdio_write_start(v, 8'h04, 16'h0000);
          v.state = ST_PHY_RESET;
        end
      ST_PHY_RESET : // PHY_CONTROL -> reset + autonegotiate
        if (mdio_done(r)) begin
          mdio_write_start(v, 8'h00, 16'h9000);
          v.state = ST_REQ_PHY_STATUS;
        end
      ST_REQ_PHY_STATUS : // PHY_STATUS -> poll autonegotiation completion
        if (mdio_done(r)) begin
          mdio_read_start(v, 8'h01);
          v.state = ST_CHECK_PHY_STATUS;
        end
      ST_CHECK_PHY_STATUS : // Check PHY_STATUS
        if (mdio_done(r)) begin
          if (r.mdio_data[5]) begin // autoneg finished
            v.state = ST_RESET_MAC_RX;
          end else begin
            v.state = ST_REQ_PHY_STATUS;
          end
        end
      ST_RESET_MAC_RX : begin
        // Reset MAC RX
        axi_write_start(v, AXI_BASE | 32'h404, 32'h90000000);
        v.state = ST_RESET_MAC_TX;
      end
      ST_RESET_MAC_TX : // Reset MAC TX
        if (axi_done(r)) begin
          axi_write_start(v, AXI_BASE | 32'h408, 32'h90000000);
          v.state = ST_MAC_SPEED1;
        end
      ST_MAC_SPEED1 : // set MDC clock to 2.5 MHz
        if (axi_done(r)) begin
          axi_write_start(v, AXI_BASE | 32'h500, 32'h68);
          v.state = ST_DISABLE_FLOW_CONTROL;
        end
      ST_DISABLE_FLOW_CONTROL : // disable flow control
        if (axi_done(r)) begin
          axi_write_start(v, AXI_BASE | 32'h40c, 32'h0);
          v.state = ST_ENABLE_PROMISC_MODE;
        end
      ST_ENABLE_PROMISC_MODE : // enable promiscuous mode
        if (axi_done(r)) begin
          axi_write_start(v, AXI_BASE | 32'h708, 32'h80000000);
          v.state = ST_FINISH_MAC_CFG;
        end
      ST_FINISH_MAC_CFG: begin // finish MAC configuration
        if (axi_done(r)) begin
          v.state = ST_REQ_PHY_STATUS1;
        end
      end
      ST_REQ_PHY_STATUS1 : begin // poll PHY_1000BASE_T_STATUS
        mdio_read_start(v, 8'h0a);
        v.state = ST_CHECK_PHY_STATUS1;
      end
      ST_CHECK_PHY_STATUS1 : begin // check PHY status
        if (mdio_done(r)) begin
          v.link_ok = (r.mdio_data[13:11] == 3'b111);
          v.state = ST_REQ_PHY_STATUS1;
        end
      end
      default : begin
        v.state = ST_RESET;
      end
    endcase // case r.state

    if ({r.start, start} == 2'b01) begin
      v.state = ST_RESET;
    end

    case (r.mdio_state)
      MDIO_IDLE : begin
      end
      MDIO_READ0 : begin
        if (axi_done(r)) begin
          axi_read_start(v, AXI_BASE | 32'h50c);
          v.mdio_state = MDIO_READ1;
        end
      end
      MDIO_READ1 : begin
        if (axi_done(r)) begin
          if (r.rdata[16]) begin
            v.mdio_data  = r.rdata[15:0];
            v.mdio_state = MDIO_IDLE;
          end else begin
            axi_read_start(v, AXI_BASE | 32'h50c);
          end
        end
      end
      MDIO_WRITE0 : begin
        if (axi_done(r)) begin
          axi_write_start(v, AXI_BASE | 32'h508, {16'h0, r.mdio_data});
          v.mdio_state = MDIO_WRITE1;
        end
      end
      MDIO_WRITE1 : begin
        if (axi_done(r)) begin
          axi_read_start(v, AXI_BASE | 32'h50c);
          v.mdio_state = MDIO_WRITE2;
        end
      end
      MDIO_WRITE2 : begin
        if (axi_done(r)) begin
          if (r.rdata[16]) begin
            v.mdio_state = MDIO_IDLE;
          end else begin
            axi_read_start(v, AXI_BASE | 32'h50c);
          end
        end
      end
      default: begin
        v.mdio_state = MDIO_IDLE;
      end
    endcase // case (r.mdio_state)

    case (r.axi_state)
      AXI_STATE_IDLE: begin
      end
      AXI_STATE_WRITE: begin
        if (M_AXI_AWREADY) begin
          v.awvalid = 1'b0;
        end
        if (M_AXI_WREADY) begin
          v.wvalid = 1'b0;
        end
        if (M_AXI_BVALID) begin
          v.bready     = 1'b0;
          v.axi_result = (M_AXI_BRESP == 3'b000) ? AXI_RESULT_OK : AXI_RESULT_ERROR;
          v.axi_state  = AXI_STATE_IDLE;
        end
      end // case: AXI_STATE_WRITE
      AXI_STATE_READ: begin
        if (M_AXI_ARREADY) begin
          v.arvalid = 1'b0;
        end
        if (M_AXI_RVALID) begin
          v.rready     = 1'b0;
          v.rdata      = M_AXI_RDATA;
          v.axi_result = (M_AXI_RRESP == 3'b000) ? AXI_RESULT_OK : AXI_RESULT_ERROR;
          v.axi_state  = AXI_STATE_IDLE;
        end
      end // case: AXI_STATE_READ
      default: begin
        v.axi_state = AXI_STATE_IDLE;
      end
    endcase // case (r.axi_state)


    if (~M_AXI_ARESETN) begin
      v = RES_reg_t;
    end
    rin = v;
  end : x_comb

  always_ff @(posedge M_AXI_ACLK) begin : x_seq
    r <= rin;
  end : x_seq

  assign M_AXI_AWADDR = r.awaddr;
  assign M_AXI_AWPROT = r.awprot;
  assign M_AXI_AWVALID = r.awvalid;

  assign M_AXI_WDATA = r.wdata;
  assign M_AXI_WSTRB = r.wstrb;
  assign M_AXI_WVALID = r.wvalid;

  assign M_AXI_BREADY = r.bready;

  assign M_AXI_ARADDR = r.araddr;
  assign M_AXI_ARPROT = r.arprot;
  assign M_AXI_ARVALID = r.arvalid;

  assign M_AXI_RREADY = r.rready;

  assign link_ok = r.link_ok;

endmodule
