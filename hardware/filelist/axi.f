-d XSIM
-d VCS
-d VERILATOR

-i ${COMMON_CELLS}/include
-i ${AXI}/include

${AXI}/src/axi_pkg.sv
${COMMON_CELLS}/src/cf_math_pkg.sv

${AXI}/src/axi_intf.sv
${AXI}/src/axi_atop_filter.sv
${S1}/hardware/fixed/axi_burst_splitter_gran.sv
${AXI}/src/axi_burst_unwrap.sv
${AXI}/src/axi_bus_compare.sv
${AXI}/src/axi_cdc_dst.sv
${AXI}/src/axi_cdc_src.sv
${AXI}/src/axi_cut.sv
${AXI}/src/axi_delayer.sv
${AXI}/src/axi_demux_simple.sv
${S1}/hardware/fixed/axi_dw_downsizer.sv
${AXI}/src/axi_dw_upsizer.sv
${AXI}/src/axi_fifo.sv
${AXI}/src/axi_fifo_delay_dyn.sv
${AXI}/src/axi_id_remap.sv
${AXI}/src/axi_id_prepend.sv
${AXI}/src/axi_inval_filter.sv
${AXI}/src/axi_isolate.sv
${AXI}/src/axi_join.sv
${AXI}/src/axi_lite_demux.sv
${AXI}/src/axi_lite_dw_converter.sv
${AXI}/src/axi_lite_from_mem.sv
${AXI}/src/axi_lite_join.sv
${AXI}/src/axi_lite_lfsr.sv
${AXI}/src/axi_lite_mailbox.sv
${AXI}/src/axi_lite_mux.sv
${AXI}/src/axi_lite_regs.sv
${AXI}/src/axi_lite_to_apb.sv
${AXI}/src/axi_lite_to_axi.sv
${AXI}/src/axi_modify_address.sv
${AXI}/src/axi_mux.sv
${AXI}/src/axi_rw_join.sv
${AXI}/src/axi_rw_split.sv
${AXI}/src/axi_serializer.sv
${AXI}/src/axi_slave_compare.sv
${AXI}/src/axi_throttle.sv
${AXI}/src/axi_to_detailed_mem.sv
${AXI}/src/axi_burst_splitter.sv
${AXI}/src/axi_cdc.sv
${AXI}/src/axi_demux.sv
${AXI}/src/axi_err_slv.sv
${AXI}/src/axi_dw_converter.sv
${AXI}/src/axi_from_mem.sv
${AXI}/src/axi_id_serialize.sv
${AXI}/src/axi_lfsr.sv
${AXI}/src/axi_multicut.sv
${AXI}/src/axi_to_axi_lite.sv
${AXI}/src/axi_to_mem.sv
${AXI}/src/axi_zero_mem.sv
${AXI}/src/axi_interleaved_xbar.sv
${AXI}/src/axi_iw_converter.sv
${AXI}/src/axi_lite_xbar.sv
${AXI}/src/axi_xbar_unmuxed.sv
${AXI}/src/axi_to_mem_banked.sv
${AXI}/src/axi_to_mem_interleaved.sv
${AXI}/src/axi_to_mem_split.sv
${AXI}/src/axi_xbar.sv
${AXI}/src/axi_xp.sv
