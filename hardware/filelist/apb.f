-d XSIM
-d VCS
-d VERILATOR

-i ${COMMON_CELLS}/include
-i ${APB}/include

${APB}/src/apb_pkg.sv
${COMMON_CELLS}/src/cf_math_pkg.sv

${APB}/src/apb_intf.sv
${APB}/src/apb_err_slv.sv
${APB}/src/apb_regs.sv
${APB}/src/apb_cdc.sv
${APB}/src/apb_demux.sv
