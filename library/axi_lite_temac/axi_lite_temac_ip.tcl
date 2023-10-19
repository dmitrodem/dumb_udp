###############################################################################
## Copyright (C) 2019-2023 Analog Devices, Inc. All rights reserved.
### SPDX short identifier: ADIBSD
###############################################################################

# ip
source ../../scripts/adi_env.tcl
source $ad_hdl_dir/library/scripts/adi_ip_xilinx.tcl

adi_ip_create axi_lite_temac
adi_ip_files axi_lite_temac [list \
                                 "axi_lite_master.sv" \
                                 "axi_lite_temac.v"]

adi_ip_properties_lite axi_lite_temac

ipx::infer_bus_interface m_axi_aclk xilinx.com:signal:clock_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface m_axi_aresetn xilinx.com:signal:reset_rtl:1.0 [ipx::current_core]
ipx::infer_bus_interface {\
                              m_axi_awvalid \
                              m_axi_awaddr \
                              m_axi_awprot \
                              m_axi_awready \
                              m_axi_wvalid \
                              m_axi_wdata \
                              m_axi_wstrb \
                              m_axi_wready \
                              m_axi_bvalid \
                              m_axi_bresp \
                              m_axi_bready \
                              m_axi_arvalid \
                              m_axi_araddr \
                              m_axi_arprot \
                              m_axi_arready \
                              m_axi_rvalid \
                              m_axi_rdata \
                              m_axi_rresp \
                              m_axi_rready} \
    xilinx.com:interface:aximm_rtl:1.0 [ipx::current_core]

ipx::associate_bus_interfaces -busif m_axi -clock m_axi_aclk -reset m_axi_aresetn [ipx::current_core]


ipx::add_address_space m_axi [ipx::current_core]
set_property master_address_space_ref m_axi [ipx::get_bus_interfaces m_axi]
set_property range 4G [ipx::get_address_spaces m_axi]

set_property company_url {https://wiki.analog.com/resources/fpga/docs/axi_lite_temac} [ipx::current_core]

ipx::save_core [ipx::current_core]
