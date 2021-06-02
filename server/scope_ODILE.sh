#!/bin/bash

npacks=5

if [ $# -gt 0 ]; then
    npacks=$1		
fi

port=0x1002

if [ $# -gt 1 ]; then
    port=$2		
fi

c_dir=/home/damic/code/c++

${c_dir}/write_config.exe -i 192.168.0.3 -c ${c_dir}/ODILE_scope_config.ini

${c_dir}/../python_UDP/reciever.py $port 1 $npacks

