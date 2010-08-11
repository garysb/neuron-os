#!/bin/bash
# Excepts an argument to do full build
if [ $# -eq 1 ]; then
	if [ ! -f ${IMAGE} ]; then
		echo "ERROR: Need an image to run part install."
		exit 1
	fi
fi

# Include our configuration file
if [ -f "../config/scripts.conf" ]; then
	. ../config/scripts.conf
elif [ -f "./config/scripts.conf" ]; then
	. ./config/scripts.conf
else
	echo "Error finding config file"
	exit 1;
fi

# Check needed utilities exist
if [ ! -x ${NASM:0:${#NASM}-${#ROOT}-3} ]; then
	echo "You need an ASM compiler to make this code (install nasm).";
	exit 1;
fi

if [ ! -x ${HEXDUMP} ]; then
	echo "You need to install a hexdumper to view this code (install hexdump).";
	exit 1;
fi

#--------------------------------------------------------------------------------
# BOOTLOADER
#--------------------------------------------------------------------------------
# Compile the asm code into hex
${NASM} "${BOOTLOADER_ASM}" -o ${BOOTLOADER_HEX} -Z "${BOOTLOADER_LOG}" -l ${BOOTLOADER_LST}

# Check the bootloader compiled successfully
if [ $? -ne 0 ]; then
	echo "Error compiling ${BOOTLOADER_ASM}, please check ${BOOTLOADER_LOG} for more information.";
	cat ${BOOTLOADER_LOG};
	exit 1;
else
	# Display the bootloader to the user
	echo "--------------------------------------------------------------------------------";
	echo "${BOOTLOADER_ASM} compiled successfully.";
	echo "--------------------------------------------------------------------------------";
	${HEXDUMP} ${BOOTLOADER_HEX};
	echo "--------------------------------------------------------------------------------";
fi

# Check the size of the bootloader output to ensure it fits into the mbr without overwriting the partition table
# The partition table runs from 1BEh to 1EEh (4x16bytes, 1x16byte segment per partition)
BOOTLOADER_LEN=$(stat -c%s "${BOOTLOADER_HEX}");
if [ ${BOOTLOADER_LEN} -gt ${BOOTLOADER_MAX} ];then
	echo "${BOOTLOADER_HEX} is ${BOOTLOADER_LEN} bytes, but should be ${BOOTLOADER_MAX} bytes. Check ${BOOTLOADER_LOG} to find out why.";
	exit 1;
fi

#--------------------------------------------------------------------------------
# CONTENT LOADER
#--------------------------------------------------------------------------------
# Compile the asm code into hex
${NASM} "${LOADER_ASM}" -o ${LOADER_HEX} -Z "${LOADER_LOG}"  -l ${LOADER_LST}

# Check the loader compiled successfully
if [ $? -ne 0 ]; then
	echo "Error compiling ${LOADER_ASM}, please check ${LOADER_LOG} for more information.";
	cat ${LOADER_LOG};
	exit 1;
else
	# Display the loader to the user
	echo "${LOADER_ASM} compiled successfully.";
	echo "--------------------------------------------------------------------------------";
	${HEXDUMP} ${LOADER_HEX};
	echo "--------------------------------------------------------------------------------";
fi

# Check the size of the loader output to ensure it fits into two sectors
LOADER_LEN=$(stat -c%s "${LOADER_HEX}");
if [ ${LOADER_LEN} -gt ${LOADER_MAX} ];then
	echo "${LOADER_HEX} is ${LOADER_LEN} bytes, but should be ${LOADER_MAX} bytes. Check ${LOADER_LOG} to find out why.";
	exit 1;
fi

#--------------------------------------------------------------------------------
# KERNEL
#--------------------------------------------------------------------------------
# Compile the asm code into hex
${NASM} "${KERNEL_ASM}" -o ${KERNEL_HEX} -Z "${KERNEL_LOG}" -l ${KERNEL_LST} # -f elf -F dwarf

# Check the kernel compiled successfully
if [ $? -ne 0 ]; then
	echo "Error compiling ${KERNEL_ASM}, please check ${KERNEL_LOG} for more information.";
	cat ${KERNEL_LOG};
	exit 1;
else
	# Display the kernel to the user
	echo "${KERNEL_ASM} compiled successfully.";
	echo "--------------------------------------------------------------------------------";
	${HEXDUMP} ${KERNEL_HEX};
	echo "--------------------------------------------------------------------------------";
	KERNEL_LEN=$(stat -c%s "${KERNEL_HEX}");
	echo "Kernel is ${KERNEL_LEN} bytes in size."
fi

#--------------------------------------------------------------------------------
# BUILD THE IMAGE
#--------------------------------------------------------------------------------
echo "Building hardrive image (may take a few seconds).";
echo "--------------------------------------------------------------------------------";
# Get a free loopback
LOOP=`sudo losetup -f`;

# Based on the Seagate ST3600A
#  (size:528MB cylinders:1024 heads:16 sectors:63 wpcomp:0 lzone:0 type:ide)
# Build the image
if [ $# -eq 1 ]; then
	dd if=/dev/zero of=${IMAGE} bs=512c count=1032192 # count=1024*16*63
	sudo losetup ${LOOP} ${IMAGE}
	sudo fdisk -C1024 -S63 -H16 ${LOOP} << EOF
n
p
1
1
1024
t
83
a
1
w
EOF

	sudo losetup -d ${LOOP}
	sudo losetup -o32256 ${LOOP} ${IMAGE} # offset: start_sector(1)*block_size(512)
	sudo /sbin/mke2fs ${LOOP}

	# Make a copy of the partition table (NOTE: we use 440, not 446 becuase of fdisk)
	rm -f partition_table
	dd ibs=1 if=${IMAGE} obs=1 of=partition_table conv=notrunc skip=440 count=72
fi

# Add our bootloader onto the drive
dd ibs=1 if=${BOOTLOADER_HEX} obs=1 of=${IMAGE} conv=notrunc count=440
dd ibs=1 if=${LOADER_HEX} obs=1 of=${IMAGE} seek=512 conv=notrunc count=${LOADER_LEN}
dd ibs=1 if=${KERNEL_HEX} obs=1 of=${IMAGE} seek=5120 conv=notrunc count=${KERNEL_LEN}

# Display the partition table to the user
echo "--------------------------------------------------------------------------------";
echo "Partition table created and mbr set.";
echo "--------------------------------------------------------------------------------";
${HEXDUMP} partition_table;
echo "--------------------------------------------------------------------------------";

# Mount the drive to copy the kernel on
# Display the partition table to the user
echo "Mounting partition and copying kernel onto it.";
echo "--------------------------------------------------------------------------------";
echo "Partition mounted at ${DRIVE}.";
echo "--------------------------------------------------------------------------------";
sudo losetup -o32256 ${LOOP} ${IMAGE} # offset: start_sector(1)*block_size(512)
sudo mount -t ext2 ${LOOP} ${DRIVE}

# Copy the kernel onto the drive
sudo cp ${KERNEL_HEX} ${DRIVE}/kernel

# Unmount drive and remove loopback device
sudo umount ${LOOP}
sudo losetup -d ${LOOP}

