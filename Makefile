# Copyright 2020-2021 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
PYTHON_BIN ?= python3

OPENLANE_DIR ?= $(shell pwd)

DOCKER_OPTIONS = $(shell $(PYTHON_BIN) ./env.py docker-config)

ifneq (,$(DOCKER_SWAP)) # Set to -1 for unlimited
DOCKER_OPTIONS += --memory-swap=$(DOCKER_SWAP)
endif
ifneq (,$(DOCKER_MEMORY))
DOCKER_OPTIONS += --memory=$(DOCKER_MEMORY)
# To verify: cat /sys/fs/cgroup/memory/memory.limit_in_bytes inside the container
endif

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
DOCKER_OPTIONS += -e DISPLAY=$(DISPLAY) -v /tmp/.X11-unix:/tmp/.X11-unix -v $(HOME)/.Xauthority:/.Xauthority --network host
endif

NPROC ?= $(shell getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu)
THREADS ?= 1

ifneq (,$(ROUTING_CORES))
DOCKER_OPTIONS += -e ROUTING_CORES=$(ROUTING_CORES)
endif

STD_CELL_LIBRARY ?= sky130_fd_sc_hd
SPECIAL_VOLTAGE_LIBRARY ?= sky130_fd_sc_hvl
IO_LIBRARY ?= sky130_fd_io
INSTALL_SRAM ?= disabled

OPEN_PDK_ARGS ?= ""
ifeq ($(INSTALL_SRAM), enabled)
OPEN_PDK_ARGS += --enable-sram-sky130
else ifneq ($(INSTALL_SRAM), disabled)
OPEN_PDK_ARGS += --enable-sram-sky130=$(INSTALL_SRAM)
endif 

ifeq ($(OPENLANE_IMAGE_NAME),)
OPENLANE_TAG ?= $(shell $(PYTHON_BIN) ./dependencies/get_tag.py)
ifneq ($(OPENLANE_TAG),)
export OPENLANE_IMAGE_NAME ?= efabless/openlane:$(OPENLANE_TAG)
endif
endif

TEST_DESIGN ?= spm
DESIGN_LIST ?= spm
BENCHMARK ?= regression_results/benchmark_results/SW_HD.csv
REGRESSION_TAG ?= TEST_SW_HD
FASTEST_TEST_SET_TAG ?= FASTEST_TEST_SET
EXTENDED_TEST_SET_TAG ?= EXTENDED_TEST_SET
PRINT_REM_DESIGNS_TIME ?= 0

SKYWATER_COMMIT ?= $(shell $(PYTHON_BIN) ./dependencies/tool.py sky130 -f commit)
OPEN_PDKS_COMMIT ?= $(shell $(PYTHON_BIN) ./dependencies/tool.py open_pdks -f commit)

# designs is mounted over install so env.tcl is not found inside the Docker
# container.
ENV_COMMAND = $(ENV_START) $(OPENLANE_IMAGE_NAME)

PDK_OPTS = 
ifeq ($(INSTALL_SRAM), enabled)
ifdef PDK_ROOT
$(error PDK_ROOT is undefined, please export it before running make)
else
PDK_OPTS = -v $(PDK_ROOT):$(PDK_ROOT) -e PDK_ROOT=$(PDK_ROOT)
endif
endif

ENV_START = docker run --rm\
	-v $(OPENLANE_DIR):/openlane\
	-v $(OPENLANE_DIR)/designs:/openlane/install\
	$(PDK_OPTS)\
	$(DOCKER_OPTIONS)

.DEFAULT_GOAL := all

.PHONY: all
all: openlane pdk

.PHONY: pdk
pdk: skywater-pdk skywater-library open_pdks build-pdk gen-sources

.PHONY: native-pdk
native-pdk: skywater-pdk skywater-library open_pdks native-build-pdk gen-sources

.PHONY: full-pdk
full-pdk: skywater-pdk all-skywater-libraries open_pdks build-pdk gen-sources

.PHONY: native-full-pdk
native-full-pdk: skywater-pdk all-skywater-libraries open_pdks native-build-pdk gen-sources

$(PDK_ROOT)/:
	mkdir -p $(PDK_ROOT)

$(PDK_ROOT)/skywater-pdk:
	git clone $(shell $(PYTHON_BIN) ./dependencies/tool.py sky130 -f repo) $(PDK_ROOT)/skywater-pdk

.PHONY: skywater-pdk
skywater-pdk: $(PDK_ROOT)/ $(PDK_ROOT)/skywater-pdk
	cd $(PDK_ROOT)/skywater-pdk && \
		git checkout main && git submodule init && git pull --no-recurse-submodules && \
		git checkout -qf $(SKYWATER_COMMIT)

.PHONY: skywater-library
skywater-library: $(PDK_ROOT)/skywater-pdk
	cd $(PDK_ROOT)/skywater-pdk && \
		git submodule update --init libraries/$(STD_CELL_LIBRARY)/latest && \
		git submodule update --init libraries/$(IO_LIBRARY)/latest && \
		git submodule update --init libraries/$(SPECIAL_VOLTAGE_LIBRARY)/latest && \
		git submodule update --init libraries/sky130_fd_pr/latest && \
		$(MAKE) -j$(NPROC) timing

.PHONY: all-skywater-libraries
all-skywater-libraries: skywater-pdk
	cd $(PDK_ROOT)/skywater-pdk && \
		git submodule update --init libraries/sky130_fd_sc_hd/latest && \
		git submodule update --init libraries/sky130_fd_sc_hs/latest && \
		git submodule update --init libraries/sky130_fd_sc_hdll/latest && \
		git submodule update --init libraries/sky130_fd_sc_ms/latest && \
		git submodule update --init libraries/sky130_fd_sc_ls/latest && \
		git submodule update --init libraries/sky130_fd_sc_hvl/latest && \
		git submodule update --init libraries/sky130_fd_io/latest && \
		$(MAKE) -j$(NPROC) timing

### OPEN_PDKS
$(PDK_ROOT)/open_pdks:
	git clone $(shell $(PYTHON_BIN) ./dependencies/tool.py open_pdks -f repo) $(PDK_ROOT)/open_pdks

.PHONY: open_pdks
open_pdks: $(PDK_ROOT)/ $(PDK_ROOT)/open_pdks
	cd $(PDK_ROOT)/open_pdks && \
		git checkout master && \
		git pull && \
		git checkout -qf $(OPEN_PDKS_COMMIT)

.PHONY: build-pdk
native-build-pdk: ENV_COMMAND=env
native-build-pdk: build-pdk
build-pdk: $(PDK_ROOT)/open_pdks $(PDK_ROOT)/skywater-pdk
	[ -d $(PDK_ROOT)/sky130A ] && rm -rf $(PDK_ROOT)/sky130A || true
	$(ENV_COMMAND) sh -c "\
		cd $(PDK_ROOT)/open_pdks && \
		./configure --enable-sky130-pdk=$(PDK_ROOT)/skywater-pdk/libraries $(OPEN_PDK_ARGS)\
	"
	cd $(PDK_ROOT)/open_pdks/sky130 && \
		$(MAKE) veryclean && \
		$(MAKE) prerequisites
	$(ENV_COMMAND) sh -c "\
		cd $(PDK_ROOT)/open_pdks/sky130 && \
		make && \
		make SHARED_PDKS_PATH=$(PDK_ROOT) install && \
		make clean \
	"

gen-sources: $(PDK_ROOT)/sky130A
	touch $(PDK_ROOT)/sky130A/SOURCES
	OPENLANE_COMMIT=$(git rev-parse HEAD)
	printf "openlane " > $(PDK_ROOT)/sky130A/SOURCES
	cd $(OPENLANE_DIR) && git rev-parse HEAD >> $(PDK_ROOT)/sky130A/SOURCES
	printf "magic " >> $(PDK_ROOT)/sky130A/SOURCES
	python3 ./dependencies/tool.py -f commit magic >> $(PDK_ROOT)/sky130A/SOURCES
	printf "\n" >> $(PDK_ROOT)/sky130A/SOURCES
	printf "skywater-pdk " >> $(PDK_ROOT)/sky130A/SOURCES
	cd $(PDK_ROOT)/skywater-pdk && git rev-parse HEAD >> $(PDK_ROOT)/sky130A/SOURCES
	printf "open_pdks " >> $(PDK_ROOT)/sky130A/SOURCES
	cd $(PDK_ROOT)/open_pdks && git rev-parse HEAD >> $(PDK_ROOT)/sky130A/SOURCES

### OPENLANE
.PHONY: openlane
openlane:
	$(MAKE) -C docker openlane

pull-openlane:
	@echo "Pulling most recent OpenLane image relative to your commit..."
	docker pull $(OPENLANE_IMAGE_NAME)

.PHONY: mount
mount:
	cd $(OPENLANE_DIR) && \
		$(ENV_START) -ti $(OPENLANE_IMAGE_NAME)

DLTAG=custom_design_List
.PHONY: test_design_list fastest_test_set extended_test_set
fastest_test_set: DESIGN_LIST=$(shell cat ./.github/test_sets/fastest_test_set)
fastest_test_set: DLTAG=$(FASTEST_TEST_SET_TAG)
fastest_test_set: test_design_list
extended_test_set: DESIGN_LIST=$(shell cat ./.github/test_sets/extended_test_set)
extended_test_set: DLTAG=$(EXTENDED_TEST_SET_TAG)
extended_test_set: test_design_list
test_design_list:
	cd $(OPENLANE_DIR) && \
		$(ENV_COMMAND) sh -c "\
			python3 run_designs.py\
			--tag $(DLTAG)\
			--threads $(THREADS)\
			--print_rem $(PRINT_REM_DESIGNS_TIME)\
			--benchmark $(BENCHMARK)\
			$(DESIGN_LIST)\
		"

.PHONY: test
test:
	cd $(OPENLANE_DIR) && \
		$(ENV_COMMAND) sh -c "./flow.tcl -design $(TEST_DESIGN) -tag openlane_test -disable_output -overwrite"
	@[ -f $(OPENLANE_DIR)/designs/$(TEST_DESIGN)/runs/openlane_test/results/finishing/$(TEST_DESIGN).gds ] && \
		echo "Basic test passed" || \
		echo "Basic test failed"

.PHONY: clean_all clean_runs clean_results
clean_all: clean_runs clean_results

clean_runs:
	@rm -rf ./designs/*/runs && rm -rf ./_build/it_tc_logs && echo "Runs cleaned successfully." || echo "Failed to delete runs."

clean_results:
	@{ find regression_results -mindepth 1 -maxdepth 1 -type d | grep -v benchmark | xargs rm -rf ; } && echo "Results cleaned successfully." || echo "Failed to delete results."
