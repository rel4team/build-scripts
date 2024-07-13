ARCH ?= riscv64
ifeq ($(ARCH), riscv64)
PLATFORM := spike
else ifeq ($(ARCH), aarch64)
PLATFORM := qemu-arm-virt
endif
all:

root-task:
#	docker run -d --name rust-root-task-demo \
#		--mount type=bind,src=$(abspath $(work_root)),dst=/work \
#		$(image_tag) sleep inf
#	docker exec -it rust-root-task-demo bash

#	for id in $$(docker ps -aq -f "name=^rust-root-task-demo$$"); do \
#		docker rm -f rust-root-task-demo; \
#	done
#	docker run -it --name rust-root-task-demo \
#		--mount type=bind,src=$(abspath ../),dst=/work \
#		rust-root-task-demo bash

	cd ../root-task-demo && make -C docker/ rm-container && ARCH=$(ARCH) make -C docker/ run

	for id in $$(docker ps -aq -f "name=^rust-root-task-demo$$"); do \
		docker rm -f rust-root-task-demo; \
	done
	docker run -it --name rust-root-task-demo \
		--mount type=bind,src=$(abspath ../),dst=/work \
		rust-root-task-demo bash /work/build-scripts/mi-dev-build.sh

sel4-test:
	cd .. && docker run -v ".:/rel4-test:z" yfblock/rel4-dev:1.2 sh -c "cd /rel4-test/rel4_kernel && ./build.py -p $(PLATFORM)"
	cd ../rel4_kernel/build && ./simulate

debug:
	cd .. && docker run -v ".:/rel4-test:z" yfblock/rel4-dev:1.2 sh -c "cd /rel4-test/rel4_kernel && ./build.py -p $(PLATFORM)"
	cd ../rel4_kernel/build && ./simulate -d

gdb:
	gdb ../rel4_kernel/build/rel4_kernel/build/images/sel4test-driver-image-arm-qemu-arm-virt \
	-ex 'target remote localhost:1234' \
	-ex 'disp /16i $$pc'

fmt:
	cd ../rel4_kernel/ && cargo fmt

clean:
	rm -rf ../rel4_kernel/build/

.PHONY: all root-task sel4-test debug gdb fmt clean
