# Targets
TARGETS:=

# Subdirectories
SUBDIRS = fpga
SUBDIRS_CLEAN = $(patsubst %,%.clean,$(SUBDIRS))

# Rules
.PHONY: all
all: $(SUBDIRS) $(TARGETS)

.PHONY: $(SUBDIRS)
$(SUBDIRS):
	cd $@ && $(MAKE)

.PHONY: $(SUBDIRS_CLEAN)
$(SUBDIRS_CLEAN):
	cd $(@:.clean=) && $(MAKE) clean

.PHONY: clean
clean: $(SUBDIRS_CLEAN)
	-rm -rf $(TARGETS)

# note: if vivado HW manager is open, djtgcfg fails with "ERROR: failed to initialize scan chain"
# djtgcfg prog -d Arty --index 0 --file fpga/fpga.bit
program_bit: 
	cd $(SUBDIRS) && make program_bit

program_mcs:
	cd $(SUBDIRS) && make program_flash