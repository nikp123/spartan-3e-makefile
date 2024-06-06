###########################################################################
## Xilinx ISE Makefile
##
## To the extent possible under law, the author(s) have dedicated all copyright
## and related and neighboring rights to this software to the public domain
## worldwide. This software is distributed without any warranty.
###########################################################################

include project.cfg


###########################################################################
# Default values
###########################################################################

ifndef XILINX
    $(error XILINX must be defined)
endif

ifndef PROJECT
    $(error PROJECT must be defined)
endif

ifndef TARGET_PART
    $(error TARGET_PART must be defined)
endif

TOPLEVEL        ?= $(PROJECT)
CONSTRAINTS     ?= $(PROJECT).ucf
BITFILE         ?= build/$(PROJECT).bit

COMMON_OPTS     ?= -intstyle xflow
XST_OPTS        ?=
NGDBUILD_OPTS   ?=
MAP_OPTS        ?=
PAR_OPTS        ?=
BITGEN_OPTS     ?=
TRACE_OPTS      ?=
FUSE_OPTS       ?= -incremental

PROGRAMMER      ?= none

IMPACT_OPTS     ?= -batch impact.cmd

DJTG_EXE        ?= djtgcfg
DJTG_DEVICE     ?= DJTG_DEVICE-NOT-SET
DJTG_INDEX      ?= 0

XC3SPROG_EXE    ?= xc3sprog
XC3SPROG_CABLE  ?= none
XC3SPROG_OPTS   ?=

OPALKELLY_EXE   ?= upload-bitfile

# Simulaion args

STOP_TIME       ?= 20000ns
VHDL_ARGS       ?= -fexplicit -fsynopsys --std=08
SIM_TARGET      ?=

###########################################################################
# Internal variables, platform-specific definitions, and macros
###########################################################################

ifeq ($(OS),Windows_NT)
    XILINX := $(shell cygpath -m $(XILINX))
    CYG_XILINX := $(shell cygpath $(XILINX))
    EXE := .exe
    XILINX_PLATFORM ?= nt64
    PATH := $(PATH):$(CYG_XILINX)/bin/$(XILINX_PLATFORM)
else
    EXE :=
    XILINX_PLATFORM ?= lin64
    PATH := $(PATH):$(XILINX)/bin/$(XILINX_PLATFORM)
endif

RUN = @echo -ne "\n\n\e[1;33m======== $(1) ========\e[m\n\n"; \
	cd build && $(XILINX_CONTAINER_EXEC) $(XILINX)/bin/$(XILINX_PLATFORM)/$(1)

# isim executables don't work without this
export XILINX


###########################################################################
# Default build
###########################################################################

default: $(BITFILE)

clean:
	rm -rf build

build/$(PROJECT).prj: project.cfg
	@echo "Updating $@"
	@mkdir -p build
	@rm -f $@
	@$(foreach file,$(VSOURCE),echo "verilog work \"../$(file)\"" >> $@;)
	@$(foreach file,$(VHDSOURCE),echo "vhdl work \"../$(file)\"" >> $@;)

build/$(PROJECT).scr: project.cfg
	@echo "Updating $@"
	@mkdir -p build
	@rm -f $@
	@echo "run" \
	    "-ifn $(PROJECT).prj" \
	    "-ofn $(PROJECT).ngc" \
	    "-ifmt mixed" \
	    "$(XST_OPTS)" \
	    "-top $(TOPLEVEL)" \
	    "-ofmt NGC" \
	    "-p $(TARGET_PART)" \
	    > build/$(PROJECT).scr

$(BITFILE): project.cfg $(VSOURCE) $(CONSTRAINTS) build/$(PROJECT).prj build/$(PROJECT).scr
	@mkdir -p build
	$(call RUN,xst) $(COMMON_OPTS) \
	    -ifn $(PROJECT).scr
	$(call RUN,ngdbuild) $(COMMON_OPTS) $(NGDBUILD_OPTS) \
	    -p $(TARGET_PART) -uc ../$(CONSTRAINTS) \
	    $(PROJECT).ngc $(PROJECT).ngd
	$(call RUN,map) $(COMMON_OPTS) $(MAP_OPTS) \
	    -p $(TARGET_PART) \
	    -w $(PROJECT).ngd -o $(PROJECT).map.ncd $(PROJECT).pcf
	$(call RUN,par) $(COMMON_OPTS) $(PAR_OPTS) \
	    -w $(PROJECT).map.ncd $(PROJECT).ncd $(PROJECT).pcf
	$(call RUN,bitgen) $(COMMON_OPTS) $(BITGEN_OPTS) \
	    -w $(PROJECT).ncd $(PROJECT).bit
	@echo -ne "\e[1;32m======== OK ========\e[m\n"


##########################################################################
# Programming
###########################################################################

ifeq ($(PROGRAMMER), impact)
prog: $(BITFILE)
	$(XILINX)/bin/$(XILINX_PLATFORM)/impact $(IMPACT_OPTS)
endif

ifeq ($(PROGRAMMER), digilent)
prog: $(BITFILE)
	$(DJTG_EXE) prog -d $(DJTG_DEVICE) -i $(DJTG_INDEX) -f $(BITFILE)
endif

ifeq ($(PROGRAMMER), xc3sprog)
prog: $(BITFILE)
	$(XC3SPROG_EXE) -c $(XC3SPROG_CABLE) $(XC3SPROG_OPTS) $(BITFILE)
endif

ifeq ($(PROGRAMMER), opalkelly)
prog: $(BITFILE)
	$(OPALKELLY_EXE) $(BITFILE)
endif

ifeq ($(PROGRAMMER), none)
prog:
	$(error PROGRAMMER must be set to use 'make prog')
endif


###########################################################################
# Generating gtkwave
###########################################################################

ENTITIES = $(SIM_TARGET)
VHDL_EXTENSION = vhd
VHDL_MAIN_PATH = src
VHDL_DEPENDENCIES_PATH = src

VHDL_MOD_TIME = $(OUT_DIR)/vhdl_last_modification_time.txt
CF_MOD_TIME = $(OUT_DIR)/cf_last_modification_time.txt

OUT_DIR = build
VHDL_MAIN := $(VHDL_MAIN_PATH)/*.$(VHDL_EXTENSION)
VHDL_DEPENDENCIES := $(VHDL_DEPENDENCIES_PATH)/*.$(VHDL_EXTENSION)
CF := $(OUT_DIR)/*.cf
GHW := $(OUT_DIR)/*.ghw
ENTITY = $(OUT_DIR)/$${entity}.ghw

$(CF): $(VHDL_DEPENDENCIES) $(VHDL_MAIN)
	@$(MAKE) checkstructure
	@echo "Analyzing $(VHDL_EXTENSION) files..."
	@ghdl -a $(VHDL_ARGS) --workdir=$(OUT_DIR) $(VHDL_DEPENDENCIES)
	@ghdl -a $(VHDL_ARGS) --workdir=$(OUT_DIR) $(VHDL_MAIN)
	@for entity in $(ENTITIES); do \
		echo "Compiling entity $${entity}..."; \
		ghdl -e $(VHDL_ARGS) --workdir=$(OUT_DIR) $${entity}; \
	done

# Make this the dependency of $(GHW) if the files are always compiled even when not modified
# $(CF_MOD_TIME): $(CF)
# 	@[ -f "$(CF_MOD_TIME)" ] || touch $(CF_MOD_TIME)
# 	@find $(CF) -type f -exec stat -f "%m %N" {} \; | sort -nr | head -1 > $(CF_MOD_TIME)

$(GHW): $(CF)
	@for entity in $(ENTITIES); do \
		echo "Generating $${entity}.ghw file..."; \
		ghdl -r $(VHDL_ARGS) --workdir=$(OUT_DIR) $${entity} --wave=$(ENTITY) --stop-time=$(STOP_TIME); \
	done


simulate: $(GHW)
	@for entity in $(ENTITIES); do \
		echo "Opening $${entity}.ghw in gtkwave..."; \
		gtkwave $(ENTITY); \
	done


checkstructure:
	@[ -d $(OUT_DIR) ] || ( echo "Creating output directory..."; mkdir -p $(OUT_DIR) )

###########################################################################

# vim: set filetype=make: #

