#!/bin/bash

# Check if passed top as argument
if [ -z "$1" ]; then
    echo "Uso: ./run_synth.sh <nome_do_top>"
    exit 1
fi

export TOP_MODULE=$1
yosys -s synth.ys
