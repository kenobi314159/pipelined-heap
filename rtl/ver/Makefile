ENZAN ?= enzan

LIB_DIR ?= rtl_libs

WAVE_LIST ?= wave.tcl

SIM_ARGS ?=

$(LIB_DIR)/.stamp: filelist.f
	$(ENZAN) analyse --out-lib $(LIB_DIR) --timescale ns -f filelist.f --depfile $(LIB_DIR)/deps.d --depfile-target $@
	@touch $@

synth: $(LIB_DIR)/.stamp

-include $(LIB_DIR)/deps.d

check: synth
	$(ENZAN) elaborate --in-lib $(LIB_DIR) tb

sim: synth
	$(ENZAN) run $(SIM_ARGS) --in-lib $(LIB_DIR) tb

sim-gui: SIM_ARGS_MOD += "$(SIM_ARGS) --gui --wave-list $(WAVE_LIST)"
sim-gui: synth
	$(MAKE) sim SIM_ARGS=$(SIM_ARGS_MOD)

clean:
	-rm -rf $(LIB_DIR)
