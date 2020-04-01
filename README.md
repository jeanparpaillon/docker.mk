docker.mk - Makefile for Docker based infrastructure
====================================================

Do you maintain an infrastructure of Docker-based servers ? 
Do you think there is too much over-engineered infrastructure tools when GNU
make could simply make the work ?

docker.mk is made for you !

# Requirements

* GNU make (>= 4.0)
* Docker
* SSH connection to your server. You may need to customize `.ssh/config` to use
  specific SSH key, user, or hostname (see
  [ssh_config(5)](http://man7.org/linux/man-pages/man5/ssh_config.5.html)).

# Quickstart

## Bootstrap

Creates a directory for your project and include docker.mk:

```sh
mkdir my_infra && cd my_infra
wget -O docker.mk https://github.com/jeanparpaillon/docker.mk/raw/master/docker.mk
```

Creates basic structure:

```sh
make -f docker.mk
```

This will create a simple structure:
```sh
Makefile
stacks/           # For stacks definition
hosts/            # Put hosts definition
```

## Add a stack

```sh
mkdir stacks/nginx-proxy
cat > stacks/nginx-proxy <<EOF
version: "3.3"

services:
    proxy:
        image: jwilder/nginx-proxy
        ports:
            - "80:80"
        volumes:
            - /var/run/docker.sock:/tmp/docker.sock:ro

    whoami:
        image: jwilder/whoami
        environment:
            - VIRTUAL_HOST=whoami.local
EOF
```

## Add a host

```sh
mkdir hosts/server.example.com
```

## Add a stack to an host

Associate host to a stack by creating a _symbolic link_ to the stack's
directory.

```sh
cd hosts/server.example.com && ln -s ../../stacks/nginx-proxy
```

## Sync your infrastructure

```sh
make
```

# Principles

## Opinionated

* docker.mk is opinionated. That means it relies on a precise directory
  structure to work. Stacks in `stacks` and hosts in `hosts`;
* docker.mk relies on `ssh`;
* `stacks` sub-directories are stack names;
* `hosts` sub-directories are hostnames.

## Idempotent

Infrastructure tools should be idempotent: they should bring your system to a
desired state, whatever the original state (that is unknown most of time).

docker.mk rules follow this principle, so should be able to run `make` as many
time as you want, without any prior knowledge of the current state of your
system.

## Extensible

When creating new host or stack, a default Makefile is created by docker.mk at
first run. These Makefiles can be easily extended, through the use of
variables and hooks.

* Variables are Makefile variables
* Hooks are Makefile target that can be augmented with custom pre-requisites.

Specific variables and hooks are described in the following sections.

# Stack customization

## Variables

* `networks`: a space-separated list of networks to create before bringing stack
  up.
  * _Example_: `networks=nginx-proxy`

For each network, you can provide custom options providing
`network_NETWORK_NAME_opts` variable. For instance:

```make
networks=nginx-proxy
network_nginx-proxy_opts=--attachable
```

## Hooks

* `stack-pre-up`: executed before bringing stack up
* `stack-post-up`: executed after bringing the stack up
* `stack-pre-down`: executed before bringing stack down
* `stack-post-down`: executed after bringing the stack down

# Host customization

## Hooks

* `host-pre-sync`: executed before pushing repository to server
