#!/bin/bash

# Receives a top module as an argument
TOP_MODULE=$1

# Checks if argument was passed
if [ -z "$TOP_MODULE" ]; then
    exit 1
fi

# Criates temporary script replacing TOP_MODULE
TMP_SCRIPT=$(mktemp)
sed "s/TOP_MODULE/$TOP_MODULE/g" synth_yosys.ys > $TMP_SCRIPT

# Executes Yosys
yosys -s $TMP_SCRIPT

# Removes the temporary script
rm $TMP_SCRIPT
