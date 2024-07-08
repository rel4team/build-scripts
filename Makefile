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

	cd ../root-task-demo && make -C docker/ rm-container && ARCH=aarch64 make -C docker/ run

	for id in $$(docker ps -aq -f "name=^rust-root-task-demo$$"); do \
		docker rm -f rust-root-task-demo; \
	done
	docker run -it --name rust-root-task-demo \
		--mount type=bind,src=$(abspath ../),dst=/work \
		rust-root-task-demo bash /work/build-scripts/mi-dev-build.sh

sel4-test:
	cd .. && docker run -v ".:/rel4-test:z" yfblock/rel4-dev:1.2 sh -c "cd /rel4-test/rel4_kernel && ./build.py -p $(PLATFORM)"
	cd ../rel4_kernel/build && ./simulate
.PHONY: all root-task sel4-test
