SHELL := /bin/bash

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
	@if [[ $$(docker ps -aq -f "name=rust-root-task-demo" | wc -l) -gt 0 ]]; then \
		$$(docker start rust-root-task-demo) ; \
		cd ../root-task-demo && ARCH=$(ARCH)  make -C docker/ exec ; \
	else \
		cd ../root-task-demo && ARCH=$(ARCH) make -C docker/ run ; ARCH=$(ARCH)  make -C docker/ exec ; \
	fi
	# for id in $$(docker ps -aq -f "name=^rust-root-task-demo"); do \
	# 	docker rm -f rust-root-task-demo; \
	# done
	# docker run -it --name rust-root-task-demo \
	# 	--mount type=bind,src=$(abspath ../),dst=/work \
	# 	rust-root-task-demo bash /work/build-scripts/mi-dev-build.sh

sel4-test:
	@if [[ $$(docker ps -aq -f "name=^sel4test-$(PLATFORM)$$" | wc -l) -gt 0 ]]; then \
		docker start -a $$(docker ps -aq -f "name=^sel4test-$(PLATFORM)$$"); \
	else \
		cd .. && docker run --name "sel4test-$(PLATFORM)" \
			-v ".:/rel4-test:z" yfblock/rel4-dev:1.2 \
			sh -c "cd /rel4-test/rel4_kernel && ./build.py -p $(PLATFORM)"; \
	fi
	@-docker images|grep none|awk '{print $3 }'|xargs docker rmi > /dev/null 2>&1
	cd ../rel4_kernel/build && ./simulate
	@-docker rm sel4test-$(PLATFORM) > /dev/null

debug:
	cd .. && docker run -v ".:/rel4-test:z" yfblock/rel4-dev:1.2 sh -c "cd /rel4-test/rel4_kernel && ./build.py -p $(PLATFORM)"
	cd ../rel4_kernel/build && ./simulate -d

gdb:
	gdb ../rel4_kernel/build/rel4_kernel/build/images/sel4test-driver-image-arm-qemu-arm-virt \
	-ex 'target remote localhost:1234' \
	-ex 'disp /16i $$pc'

fmt:
	cd ../rel4_kernel/ && cargo fmt

just-test:
	cd ../rel4_kernel/build && ./simulate

clean:
	rm -rf ../rel4_kernel/build/

.PHONY: all root-task sel4-test debug gdb fmt clean
