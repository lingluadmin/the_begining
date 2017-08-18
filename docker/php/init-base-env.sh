#!/bin/bash

set -e

function run_cmd() {
    t=`date`
    echo $t":" $1
    eval $1
}

PYTHON_PIP_VERSION=8.1.2

run_cmd "apt-get install -y vim exuberant-ctags wget git"
run_cmd "rm -rf /var/lib/apt/lists/*"
run_cmd "git clone https://github.com/liaohuqiu/vim_anywhere"
run_cmd "cd vim_anywhere"
run_cmd "bash setup.sh"
