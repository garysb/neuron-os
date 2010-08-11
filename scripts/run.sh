#!/bin/bash
# Include our configuration file
if [ -f "../config/scripts.conf" ]; then
	. ../config/scripts.conf
elif [ -f "./config/scripts.conf" ]; then
	. ./config/scripts.conf
else
	echo "Error finding config file"
	exit 1;
fi

# Script to compile the code, then build the image, then execute bochs
bochs -qf `echo ${BOCHS_CONFIG}`;

