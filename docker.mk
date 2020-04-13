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
.SECONDARY:
.EXPORT_ALL_VARIABLES:

basedir=$(realpath $(dir $(lastword $(MAKEFILE_LIST))))
remotedir=/opt/docker.mk

esh=$(basedir)/tools/esh
esh_src=https://github.com/jirutka/esh/raw/v0.3.0/esh

%: %.esh %.esh.env | $(esh)
	$(info_v) "GEN" "$@"; $(esh) $< > $@

%.esh.env: environment
	$(gen_v)printenv > $@.tmp; \
	if ! diff -q $@ $@.tmp > /dev/null 2>&1; then \
	  $(info) "ENV" "$*"; \
	  cp $@.tmp $@; \
	fi
	@rm -f $@.tmp

$(esh):
	$(info_v) "FETCH" "esh"; \
	  mkdir -p $(@D) && wget -q -O $@ $(esh_src) && chmod 755 $@

.PHONY: environment
#
# END: global
#

#
# BEGIN: logging
#
V=0

gen_v=$(gen_v_$(V))
gen_v_0=@

info=sh -c 'printf "\033[33m %-7s\033[0m%s\n" $$1 $$2' info

info_v=$(info_v_$(V))
info_v_0=@$(info)
info_v_1=:
#
# END: logging
#

#
# BEGIN: common
#
.DEFAULT_GOAL=all

all:

ifeq ($(firstword $(MAKEFILE_LIST)),docker.mk)
all: bootstrap
else ifeq ($(PWD),$(basedir))
all: all-root
else ifeq ($(PWD),$(basedir)/stacks)
all: all-stacks
else ifeq ($(PWD),$(basedir)/hosts)
all: all-hosts
else ifeq ($(dir $(PWD)),$(basedir)/hosts/)
all: all-host
else ifeq ($(dir $(PWD)),$(basedir)/stacks/)
all: all-stack
endif

.PHONY: all

define gen
@mkdir -p $(dir $1)
$(info_v) "GEN" $1; \
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

define stacks_mk
include ../docker.mk
endef

bootstrap: Makefile hosts/Makefile stacks/Makefile $(prereqs)

Makefile:
	$(call gen,$@,$(call root_mk))

hosts/Makefile:
	$(call gen,$@,$(call hosts_mk))

stacks/Makefile:
	$(call gen,$@,$(call stacks_mk))

.PHONY: bootstrap
#
# END: bootstrap
#

#
# BEGIN: root
#
ifeq ($(PWD),$(basedir))
all-root: | hosts/Makefile stacks/Makefile
	@cd hosts && $(MAKE) --no-print-directory

.PHONY: all-root
endif
#
# END: root
#

#
# BEGIN: hosts
#
ifeq ($(PWD),$(basedir)/hosts)

HOST?=

define host_mk
include ../../docker.mk
endef

hosts=$(eval hosts := $$(shell find . -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))$(hosts)
hosts_mk=$(patsubst %,%/Makefile,$(hosts))

all-hosts: | $(hosts_mk)
	@for host in $(hosts); do \
	  (cd $$stack && $(MAKE) --no-print-directory); \
	done

ifeq ($(HOST),)
new-host:
	@echo "Missing variable: HOST"; false
else
new-host: $(HOST)/Makefile
endif

%/Makefile:
	$(call gen,$@,$(call host_mk))

.PHONY: all-hosts new-host
endif
#
# END: hosts
#

#
# BEGIN: host
#
ifeq ($(dir $(PWD)),$(basedir)/hosts/)
host=$(notdir $(PWD))
stacks=$(eval stacks := $$(shell find . -maxdepth 1 -type l -lname '**/stacks/*' -exec basename {} \;))$(stacks)
host_remote?=0

ifeq ($(host_remote),0)
all-host: host-sync
	$(info_v) "SSH" $(host); \
	  ssh $(host) "cd $(remotedir)/hosts/$(host) && $(MAKE) host_remote=1"
else
all-host:
	$(info_v) "UPDATE" $(host); for stack in $(stacks); do \
	  (cd $(remotedir)/stacks/$${stack} && $(MAKE)); \
	done
endif

host-sync: host-pre-sync
	$(info_v) "SYNC" $(host); \
	  rsync -aq --delete --exclude='.git' --exclude='.history' $(basedir)/ $(host):$(remotedir)

host-pre-sync:

.PHONY: all-host host-sync host-pre-sync
endif
#
# END: host
#

#
# BEGIN: stacks
#
ifeq ($(PWD),$(basedir)/stacks)

STACK?=

define stack_mk
include ../../docker.mk
endef

stacks=$(eval stacks := $$(shell find . -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))$(stacks)
stacks_mk=$(patsubst %,%/Makefile,$(stacks))

all-stacks: | $(stacks_mk)
	@for stack in $(stacks); do \
	  (cd $$stack && $(MAKE) --no-print-directory); \
	done

ifeq ($(STACK),)
new-stack:
	@echo "Missing variable: STACK"; false
else
new-stack: $(STACK)/Makefile
endif

%/Makefile:
	$(call gen,$@,$(call stack_mk))

.PHONY: all-stacks new-stack
endif
#
# END: stacks
#

#
# BEGIN: stack
#
ifeq ($(dir $(PWD)),$(basedir)/stacks/)
stack=$(notdir $(PWD))
networks?=
swarm=$(eval swarm := $$(shell docker info --format '{{ .Swarm.LocalNodeState }}'))$(swarm)

define stack-net
stack-net-$(1)-up:
	$(gen_v)if [ -z "$$$$(docker network ls -f name=$(1) --format '{{ .ID }}')" ]; then \
	  docker network create $(network_$(1)_opts) $(1); \
	fi

stack-net-$(1)-down:
	$(gen_v)if [ -n "$$$$(docker network ls -f name=$(1) --format '{{ .ID }}')" ]; then \
	  docker network rm $(1); \
	fi

.PHONY: stack-net-$(1)-up stack-net-$(1)-down
endef

all-stack: stack-up

ifeq ($(swarm),active)
stack-up: stack-pre-up
	$(info_v) "UP" $(stack); docker stack deploy -c docker-compose.yml --prune $(stack)
	$(MAKE) stack-post-up

stack-down: stack-pre-down
	$(info_v) "DOWN" $(stack); docker stack rm $(stack)
else
stack-up: stack-pre-up
	$(info_v) "UP" $(stack); docker-compose up -d
	$(MAKE) stack-post-up

stack-down: stack-pre-down
	$(info_v) "DOWN" $(stack); docker-compose down
	$(MAKE) stack-post-down
endif

stack-pre-up: stack-net-up docker-compose.yml

stack-post-up:

stack-pre-down: docker-compose.yml

stack-post-down:

stack-net-up: $(foreach net,$(networks), stack-net-$(net)-up)

stack-net-down: $(foreach net,$(networks), stack-net-$(net)-down)

$(foreach net,$(networks),$(eval $(call stack-net,$(net))))

.PHONY: all-stack stack-up stack-pre-up stack-post-up stack-pre-down stack-post-down stack-net-up stack-net-down
endif
#
# END: stack
#
