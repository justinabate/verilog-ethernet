###################################################################
# 
# Xilinx Vivado FPGA Makefile
# 
# Copyright (c) 2016 Alex Forencich
# 
###################################################################
# 
# Parameters:
# FPGA_TOP - Top module name
# FPGA_FAMILY - FPGA family (e.g. VirtexUltrascale)
# FPGA_DEVICE - FPGA device (e.g. xcvu095-ffva2104-2-e)
# SYN_FILES - space-separated list of source files
# INC_FILES - space-separated list of include files
# XDC_FILES - space-separated list of timing constraint files
# XCI_FILES - space-separated list of IP XCI files
# 
# Example:
# 
# FPGA_TOP = fpga
# FPGA_FAMILY = VirtexUltrascale
# FPGA_DEVICE = xcvu095-ffva2104-2-e
# SYN_FILES = rtl/fpga.v
# XDC_FILES = fpga.xdc
# XCI_FILES = ip/pcspma.xci
# include ../common/vivado.mk
# 
###################################################################

# phony targets
.PHONY: clean fpga mcs

# prevent make from deleting intermediate files and reports
.PRECIOUS: %.xpr %.bit %.mcs %.prm
.SECONDARY:

CONFIG ?= config.mk
-include ../$(CONFIG)

SYN_FILES_REL = $(patsubst %, ../%, $(SYN_FILES))
INC_FILES_REL = $(patsubst %, ../%, $(INC_FILES))
XCI_FILES_REL = $(patsubst %, ../%, $(XCI_FILES))
IP_TCL_FILES_REL = $(patsubst %, ../%, $(IP_TCL_FILES))

ifdef XDC_FILES
  XDC_FILES_REL = $(patsubst %, ../%, $(XDC_FILES))
else
  XDC_FILES_REL = $(FPGA_TOP).xdc
endif

###################################################################
# Main Targets
#
# all: build everything
# clean: remove output files and project files
###################################################################

all: fpga

fpga: $(FPGA_TOP).bit $(FPGA_TOP).mcs

mcs: $(FPGA_TOP).mcs

vivado: $(FPGA_TOP).xpr
	vivado $(FPGA_TOP).xpr

tmpclean:
	@rm -rf *.log *.jou *.cache *.gen *.hbs *.hw *.ip_user_files *.runs *.xpr *.html *.xml *.sim *.srcs *.str .Xil defines.v
	@rm -rf make_*.tcl program_*.tcl

clean: tmpclean
	@rm -rf *.bit *.mcs *.prm  make_*.tcl  program_*.tcl

distclean: clean
	@rm -rf rev

###################################################################
# Target implementations
###################################################################

# XPR project
__%_project_is_built__: Makefile $(XCI_FILES_REL) $(IP_TCL_FILES_REL) 
	@echo "[INFO] building $* XPR from Makefile" 
	@rm -rf defines.v
	@touch defines.v
	@for x in $(DEFS); do echo '`define' $$x >> defines.v; done
	@echo "create_project -force -part $(FPGA_PART) $*" > make_xpr.tcl
	@echo "add_files -fileset sources_1 defines.v" >> make_xpr.tcl
	@for x in $(SYN_FILES_REL); do echo "add_files -fileset sources_1 $$x" >> make_xpr.tcl; done
	@for x in $(XDC_FILES_REL); do echo "add_files -fileset constrs_1 $$x" >> make_xpr.tcl; done
	@for x in $(XCI_FILES_REL); do echo "import_ip $$x" >> make_xpr.tcl; done
	@for x in $(IP_TCL_FILES_REL); do echo "source $$x" >> make_xpr.tcl; done
	@echo "exit" >> make_xpr.tcl
	vivado -nojournal -nolog -mode batch -source make_xpr.tcl && touch __$*_project_is_built__

# synthesized netlist
%.runs/synth_1/%.dcp: __%_project_is_built__ $(SYN_FILES_REL)
	@echo "[INFO] synthesizing $*" 
	@echo "open_project $*.xpr" > make_syn_dcp.tcl
	@echo "reset_run synth_1" >> make_syn_dcp.tcl
	@echo "launch_runs -jobs 4 synth_1" >> make_syn_dcp.tcl
	@echo "wait_on_run synth_1" >> make_syn_dcp.tcl
	@echo "exit" >> make_syn_dcp.tcl
	vivado -nojournal -nolog -mode batch -source make_syn_dcp.tcl

# routed FPGA
%.runs/impl_1/%_routed.dcp: %.runs/synth_1/%.dcp
	@echo "[INFO] $* implementation running" 
	@echo "open_project $*.xpr" > make_par_dcp.tcl
	@echo "reset_run impl_1" >> make_par_dcp.tcl
	@echo "launch_runs -jobs 4 impl_1" >> make_par_dcp.tcl
	@echo "wait_on_run impl_1" >> make_par_dcp.tcl
	@echo "exit" >> make_par_dcp.tcl
	vivado -nojournal -nolog -mode batch -source make_par_dcp.tcl

# bitstream
%.bit: %.runs/impl_1/%_routed.dcp
	@echo "open_project $*.xpr" > make_bit.tcl
	@echo "open_run impl_1" >> make_bit.tcl
	@echo "write_bitstream -force $*.bit" >> make_bit.tcl
	@echo "exit" >> make_bit.tcl
	vivado -nojournal -nolog -mode batch -source make_bit.tcl
	@mkdir -p rev
	@EXT=bit; COUNT=100; \
	while [ -e rev/$*_rev$$COUNT.$$EXT ]; \
	do COUNT=$$((COUNT+1)); done; \
	cp $@ rev/$*_rev$$COUNT.$$EXT; \
	echo "Output: rev/$*_rev$$COUNT.$$EXT";

# MCS file (flash = mt25ql128)
%.mcs %.prm: %.bit
	@echo "open_project $*.xpr" > make_mcs.tcl
	@echo "write_cfgmem -force -format mcs -size 16 -interface SPIx4 -loadbit {up 0x0000000 $*.bit} -checksum -file $*.mcs" >> make_mcs.tcl
	@echo "exit" >> make_mcs.tcl
	@vivado -nojournal -nolog -mode batch -source make_mcs.tcl
	@mkdir -p rev
	@COUNT=100; \
	while [ -e rev/$*_rev$$COUNT.bit ]; \
	do COUNT=$$((COUNT+1)); done; \
	COUNT=$$((COUNT-1)); \
	for x in .mcs .prm; \
	do cp $*$$x rev/$*_rev$$COUNT$$x; \
	echo "Output: rev/$*_rev$$COUNT$$x"; done;


# %.mcs: %.bit
# 	echo "open_project $*.xpr" > make_mcs.tcl
# 	echo "write_cfgmem  -format mcs -size 16 -interface SPIx4 -loadbit {up 0x00000000 $*.bit } -file $*.mcs" >> make_mcs.tcl
# 	echo "exit" >> make_mcs.tcl
# 	vivado -nojournal -nolog -mode batch -source make_mcs.tcl


program_bit: $(FPGA_TOP).bit
	@echo "open_project $(FPGA_TOP).xpr" > program_bit.tcl
	@echo "open_hw" >> program_bit.tcl
	@echo "connect_hw_server" >> program_bit.tcl
	@echo "open_hw_target" >> program_bit.tcl
	@echo "current_hw_device [lindex [get_hw_devices] 0]" >> program_bit.tcl
	@echo "refresh_hw_device -update_hw_probes false [current_hw_device]" >> program_bit.tcl
	@echo "set_property PROGRAM.FILE {$(FPGA_TOP).bit} [current_hw_device]" >> program_bit.tcl
	@echo "program_hw_devices [current_hw_device]" >> program_bit.tcl
	@echo "exit" >> program_bit.tcl
	vivado -nojournal -nolog -mode batch -source program_bit.tcl


program_flash: $(FPGA_TOP).mcs
	@echo "open_project $(FPGA_TOP).xpr" > program_mcs.tcl
	@echo "open_hw_manager" >> program_mcs.tcl
	@echo "connect_hw_server -allow_non_jtag" >> program_mcs.tcl
	@echo "open_hw_target" >> program_mcs.tcl
	@echo "current_hw_device [get_hw_devices xc7a35t_0]" >> program_mcs.tcl
	@echo "create_hw_cfgmem -hw_device [lindex [get_hw_devices xc7a35t_0] 0] [lindex [get_cfgmem_parts {mt25ql128-spi-x1_x2_x4}] 0]" >> program_mcs.tcl
	@echo "set_property PROGRAM.BLANK_CHECK  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a35t_0] 0]]" >> program_mcs.tcl
	@echo "set_property PROGRAM.ERASE  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a35t_0] 0]]" >> program_mcs.tcl
	@echo "set_property PROGRAM.CFG_PROGRAM  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a35t_0] 0]]" >> program_mcs.tcl
	@echo "set_property PROGRAM.VERIFY  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a35t_0] 0]]" >> program_mcs.tcl
	@echo "set_property PROGRAM.CHECKSUM  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a35t_0] 0]]" >> program_mcs.tcl
	@echo "set_property PROGRAM.ADDRESS_RANGE  {use_file} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a35t_0] 0]]" >> program_mcs.tcl
	@echo "set_property PROGRAM.FILES [list $(FPGA_TOP).mcs ] [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a35t_0] 0]]" >> program_mcs.tcl
	@echo "set_property PROGRAM.PRM_FILE {$(FPGA_TOP).prm} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a35t_0] 0]]" >> program_mcs.tcl
	@echo "set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a35t_0] 0]]" >> program_mcs.tcl
	@echo "set_property PROGRAM.BLANK_CHECK  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a35t_0] 0]]" >> program_mcs.tcl
	@echo "set_property PROGRAM.ERASE  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a35t_0] 0]]" >> program_mcs.tcl
	@echo "set_property PROGRAM.CFG_PROGRAM  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a35t_0] 0]]" >> program_mcs.tcl
	@echo "set_property PROGRAM.VERIFY  1 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a35t_0] 0]]" >> program_mcs.tcl
	@echo "set_property PROGRAM.CHECKSUM  0 [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a35t_0] 0]]" >> program_mcs.tcl
	@echo "startgroup " >> program_mcs.tcl
	@echo "create_hw_bitstream -hw_device [lindex [get_hw_devices xc7a35t_0] 0] [get_property PROGRAM.HW_CFGMEM_BITFILE [ lindex [get_hw_devices xc7a35t_0] 0]]; program_hw_devices [lindex [get_hw_devices xc7a35t_0] 0]; refresh_hw_device [lindex [get_hw_devices xc7a35t_0] 0];" >> program_mcs.tcl
	@echo "program_hw_cfgmem -hw_cfgmem [ get_property PROGRAM.HW_CFGMEM [lindex [get_hw_devices xc7a35t_0] 0]]" >> program_mcs.tcl
	@echo "boot_hw_device  [lindex [get_hw_devices xc7a35t_0] 0]" >> program_mcs.tcl
	@echo "exit" >> program_mcs.tcl
	vivado -nojournal -nolog -mode batch -source program_mcs.tcl


# flash: $(FPGA_TOP).mcs $(FPGA_TOP).prm
# 	echo "open_hw" > flash.tcl
# 	echo "connect_hw_server" >> flash.tcl
# 	echo "open_hw_target" >> flash.tcl
# 	echo "current_hw_device [lindex [get_hw_devices] 0]" >> flash.tcl
# 	echo "refresh_hw_device -update_hw_probes false [current_hw_device]" >> flash.tcl
# 	echo "create_hw_cfgmem -hw_device [current_hw_device] [lindex [get_cfgmem_parts {mt25ql128-spi-x1_x2_x4}] 0]" >> flash.tcl
# 	echo "current_hw_cfgmem -hw_device [current_hw_device] [get_property PROGRAM.HW_CFGMEM [current_hw_device]]" >> flash.tcl
# 	echo "set_property PROGRAM.FILES [list \"$(FPGA_TOP).mcs\"] [current_hw_cfgmem]" >> flash.tcl
# 	echo "set_property PROGRAM.PRM_FILES [list \"$(FPGA_TOP).prm\"] [current_hw_cfgmem]" >> flash.tcl
# 	echo "set_property PROGRAM.ERASE 1 [current_hw_cfgmem]" >> flash.tcl
# 	echo "set_property PROGRAM.CFG_PROGRAM 1 [current_hw_cfgmem]" >> flash.tcl
# 	echo "set_property PROGRAM.VERIFY 1 [current_hw_cfgmem]" >> flash.tcl
# 	echo "set_property PROGRAM.CHECKSUM 0 [current_hw_cfgmem]" >> flash.tcl
# 	echo "set_property PROGRAM.ADDRESS_RANGE {use_file} [current_hw_cfgmem]" >> flash.tcl
# 	echo "set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} [current_hw_cfgmem]" >> flash.tcl
# 	echo "create_hw_bitstream -hw_device [current_hw_device] [get_property PROGRAM.HW_CFGMEM_BITFILE [current_hw_device]]" >> flash.tcl
# 	echo "program_hw_devices [current_hw_device]" >> flash.tcl
# 	echo "refresh_hw_device [current_hw_device]" >> flash.tcl
# 	echo "program_hw_cfgmem -hw_cfgmem [current_hw_cfgmem]" >> flash.tcl
# 	echo "boot_hw_device [current_hw_device]" >> flash.tcl
# 	echo "exit" >> flash.tcl
# 	vivado -nojournal -nolog -mode batch -source flash.tcl


