#
# Makefile for Docker-based infrastructure
#
# Author: Jean Parpaillon <jean.parpaillon@free.fr>
#
# Copyright (c) 2020 Jean Parpaillon
#

#
# BEGIN: global
#
basedir=$(realpath $(dir $(lastword $(MAKEFILE_LIST))))
remotedir=/opt/docker.mk
#
# END: global
#

#
# BEGIN: logging
#
V=0

gen_v=$(gen_v_$(V))
gen_v_0=@

info=$(info_$(V))
info_0=@sh -c 'printf "\033[33m %-7s\033[0m%s\n" $$1 $$2' info
info_1=:
#
# END: logging
#

#
# BEGIN: common
#
.DEFAULT_GOAL=all

ifeq ($(firstword $(MAKEFILE_LIST)),docker.mk)
all: bootstrap
else ifeq ($(PWD),$(basedir))
all: all-root
else ifeq ($(PWD),$(basedir)/stacks)
all: all-stacks
else ifeq ($(PWD),$(basedir)/hosts)
all: all-hosts
endif

define gen
@mkdir -p $(dir $1)
$(info) "GEN" $1; \
  echo "# Generated on $$(date +'%F %T %Z')" > $1; \
  echo "$2" >> $1
endef
#
# END: common
#

#
# BEGIN: bootstrap
#
define root_mk
include docker.mk
endef

define hosts_mk
include ../docker.mk
endef

define stacks
include ../docker.mk
endef

bootstrap: Makefile hosts/Makefile stacks/Makefile

Makefile:
	$(call gen,$@,$(call root_mk))

hosts/Makefile:
	$(call gen,$@,$(call hosts_mk))

stacks/Makefile:
	$(call gen,$@,$(call stacks_mk))
#
# END: bootstrap
#

#
# BEGIN: root
#
ifeq ($(PWD),$(basedir))
all-root: | hosts/Makefile stacks/Makefile
endif
#
# END: root
#

#
# BEGIN: hosts
#
ifeq ($(PWD),$(basedir)/hosts)
all-hosts:
endif
#
# END: hosts
#

#
# BEGIN: stacks
#
ifeq ($(PWD),$(basedir)/stacks)
all-stacks:
endif
#
# END: stacks
#

help: ## This help
	@grep -E '^[^: ]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":[^:]*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: all all-root all-stacks all-hosts help bootstrap
