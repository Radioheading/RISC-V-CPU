all:
	cd riscv && make build_sim
	cp ./riscv/testspace/test code