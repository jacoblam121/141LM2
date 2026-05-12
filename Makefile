IVERILOG ?= iverilog
VVP      ?= vvp

RTL := rtl/dat_mem.sv rtl/aria_alu.sv rtl/aria_pc.sv rtl/aria_reg_file.sv \
       rtl/aria_decoder.sv rtl/aria_branch.sv rtl/aria_imem.sv rtl/DUT.sv

BUILD := build
TEST_FILES := test_benches_export/test_files/test0.txt \
              test_benches_export/test_files/test1.txt \
              test_benches_export/test_files/test2.txt \
              test_benches_export/test_files/test3.txt \
              test_benches_export/test_files/test4.txt \
              test_benches_export/test_files/test5.txt \
              test_benches_export/test_files/test6.txt \
              test_benches_export/test_files/test7.txt \
              test_benches_export/test_files/test8.txt \
              test_benches_export/test_files/test9.txt

.PHONY: sim_prog1 sim_prog2 sim_prog3 sim_alu_tb sim_pc_tb sim_all clean

sim_all: sim_alu_tb sim_pc_tb sim_prog1 sim_prog2 sim_prog3

$(BUILD)/prog1/tb.sv: test_benches_export/program1/test_bench_new.sv
	@mkdir -p $(dir $@)
	@perl -pe 's/\#([0-9]+)ns/\#$$1/g' $< > $@

$(BUILD)/prog2/tb.sv: test_benches_export/program2/test_bench2_new.sv
	@mkdir -p $(dir $@)
	@perl -pe 's/\#([0-9]+)ns/\#$$1/g' $< > $@

$(BUILD)/prog3/tb.sv: test_benches_export/program3/test_bench3_new.sv
	@mkdir -p $(dir $@)
	@perl -pe 's/\#([0-9]+)ns/\#$$1/g' $< > $@

$(BUILD)/%/test0.txt: $(TEST_FILES)
	@mkdir -p $(dir $@)
	@cp test_benches_export/test_files/test*.txt $(dir $@)

$(BUILD)/prog1/sim.vvp: $(RTL) $(BUILD)/prog1/tb.sv $(BUILD)/prog1/test0.txt
	$(IVERILOG) -g2012 -DPROG1 -o $@ $(RTL) $(BUILD)/prog1/tb.sv

$(BUILD)/prog2/sim.vvp: $(RTL) $(BUILD)/prog2/tb.sv $(BUILD)/prog2/test0.txt
	$(IVERILOG) -g2012 -DPROG2 -o $@ $(RTL) $(BUILD)/prog2/tb.sv

$(BUILD)/prog3/sim.vvp: $(RTL) $(BUILD)/prog3/tb.sv $(BUILD)/prog3/test0.txt
	$(IVERILOG) -g2012 -DPROG3 -o $@ $(RTL) $(BUILD)/prog3/tb.sv

sim_prog1: $(BUILD)/prog1/sim.vvp
	printf 'finish\n' | (cd $(BUILD)/prog1 && $(VVP) sim.vvp)

sim_prog2: $(BUILD)/prog2/sim.vvp
	printf 'finish\n' | (cd $(BUILD)/prog2 && $(VVP) sim.vvp)

sim_prog3: $(BUILD)/prog3/sim.vvp
	printf 'finish\n' | (cd $(BUILD)/prog3 && $(VVP) sim.vvp)

$(BUILD)/alu_tb.vvp: $(RTL) tb/alu_tb.sv
	@mkdir -p $(BUILD)
	$(IVERILOG) -g2012 -o $@ rtl/aria_alu.sv tb/alu_tb.sv

$(BUILD)/pc_tb.vvp: $(RTL) tb/pc_tb.sv
	@mkdir -p $(BUILD)
	$(IVERILOG) -g2012 -o $@ rtl/aria_pc.sv tb/pc_tb.sv

sim_alu_tb: $(BUILD)/alu_tb.vvp
	$(VVP) $<

sim_pc_tb: $(BUILD)/pc_tb.vvp
	$(VVP) $<

clean:
	rm -rf $(BUILD)
