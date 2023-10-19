`timescale 1ns/1ps

module axi_lite_temac
   (
    // System Signals
    input wire m_axi_aclk,
    input wire m_axi_aresetn,

    // Master Interface Write Address
    output wire [31:0] m_axi_awaddr,
    output wire [2:0] m_axi_awprot,
    output wire m_axi_awvalid,
    input wire m_axi_awready,

    // Master Interface Write Data
    output wire [31:0] m_axi_wdata,
    output wire [3:0] m_axi_wstrb,
    output wire m_axi_wvalid,
    input wire m_axi_wready,

    // Master Interface Write Response
    input wire [1:0] m_axi_bresp,
    input wire m_axi_bvalid,
    output wire m_axi_bready,

    // Master Interface Read Address
    output wire [31:0] m_axi_araddr,
    output wire [2:0] m_axi_arprot,
    output wire m_axi_arvalid,
    input wire m_axi_arready,

    // Master Interface Read Data 
    input wire [31:0] m_axi_rdata,
    input wire [1:0] m_axi_rresp,
    input wire m_axi_rvalid,
    output wire m_axi_rready,
    
    input wire start,
    output wire link_ok);
    
   axi_lite_master #(
    .C_M_AXI_ADDR_WIDTH (C_M_AXI_ADDR_WIDTH),
    .C_M_AXI_DATA_WIDTH (C_M_AXI_DATA_WIDTH))
    u0 (
    // System Signals
    .M_AXI_ACLK (m_axi_aclk),
    .M_AXI_ARESETN (m_axi_aresetn),

    // Master Interface Write Address
    .M_AXI_AWADDR (m_axi_awaddr),
    .M_AXI_AWPROT (m_axi_awprot),
    .M_AXI_AWVALID (m_axi_awvalid),
    .M_AXI_AWREADY (m_axi_awready),

    // Master Interface Write Data
    .M_AXI_WDATA (m_axi_wdata),
    .M_AXI_WSTRB (m_axi_wstrb),
    .M_AXI_WVALID (m_axi_wvalid),
    .M_AXI_WREADY (m_axi_wready),

    // Master Interface Write Response
    .M_AXI_BRESP (m_axi_bresp),
    .M_AXI_BVALID (m_axi_bvalid),
    .M_AXI_BREADY (m_axi_bready),

    // Master Interface Read Address
    .M_AXI_ARADDR (m_axi_araddr),
    .M_AXI_ARPROT (m_axi_arprot),
    .M_AXI_ARVALID (m_axi_arvalid),
    .M_AXI_ARREADY (m_axi_arready),

    // Master Interface Read Data 
    .M_AXI_RDATA (m_axi_rdata),
    .M_AXI_RRESP (m_axi_rresp),
    .M_AXI_RVALID (m_axi_rvalid),
    .M_AXI_RREADY (m_axi_rready),
    
    .start   (start),
    .link_ok (link_ok));

endmodule
