prefix = $(shell pwd)
# Folder Path
src = $(prefix)/src
testspace = $(prefix)/testspace

sim_testcase = $(prefix)/testcase/sim
fpga_testcase = $(prefix)/testcase/fpga

sim = $(prefix)/sim
riscv_toolchain = /opt/riscv
riscv_bin = $(riscv_toolchain)/bin
sys = $(prefix)/sys

all:
	cd $(src) && iverilog -o $(testspace)/test $(sim)/testbench.v $(src)/common/block_ram/*.v $(src)/common/fifo/*.v $(src)/common/uart/*.v $(src)/*.v $(src)/InsFetch/*.v $(src)/InsDecode/*.v $(src)/Execute/*.v
	# cp ./testspace/test code