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

# Unmount and unloop drive
if [ `sudo mount -l|grep -c ${DRIVE}` -ge 1 ]; then
	sudo umount ${DRIVE}
fi
if [ -f ${IMAGE} ]; then
	sudo losetup -j ${IMAGE} 2>&1 >/dev/null
	if [ $? -eq 0 ]; then
		LOOP=`sudo losetup -j ${IMAGE}`
		sudo losetup -d ${LOOP:0:10}
	fi
fi

# Remove all the binary files
if [ -f ${IMAGE} ]; then
	rm -v ${IMAGE};
fi
if [ -f ${BOOTLOADER_HEX} ]; then
	rm -v ${BOOTLOADER_HEX};
fi
if [ -f ${LOADER_HEX} ]; then
	rm -v ${LOADER_HEX};
fi
if [ -f ${KERNEL_HEX} ]; then
	rm -v ${KERNEL_HEX};
fi

# Clean the symbol files
if [ -f ${BOOTLOADER_LST} ]; then
	rm -v ${BOOTLOADER_LST};
fi
if [ -f ${LOADER_LST} ]; then
	rm -v ${LOADER_LST};
fi
if [ -f ${KERNEL_LST} ]; then
	rm -v ${KERNEL_LST};
fi

# Remove old partition table backup
if [ -f "${ROOT}partition_table" ]; then
	rm -v ${root}partition_table;
fi
