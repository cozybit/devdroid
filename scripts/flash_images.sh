#!/bin/bash

# GOAL: this scripts flashes the images located in the out directory of the
# Android Open Source Project.
#
# NOTES: the entire process of flashing takes around 2 minutes.

# Source common functions and parse options
source `dirname ${0}`/common.sh

# flash android images to a given device
# usage: flash_images <device_id> <path_to_images>
function flash_images () {
	_ID=${1}
	_IMG_PATH=${2}
	#Check if it is in adb mode
	if is_adb_mode ${_ID}; then
		dlog ${_ID} "Rebooting device in fastboot mode."
		adb -s ${_ID} reboot bootloader
		#start checking if the device is already booted (2 mins max)
		poll 60 "fastboot devices | grep ${_ID} &>/dev/null" || { dlog ${_ID} "ERROR: device never came back in fastboot mode. Aborting."; return 1; }
	#Check if it is already in fastboot mode
	elif ! is_fastboot_mode ${_ID}; then
		dlog ${_ID} "ERROR: device is not in adb or fastboot mode. Skipping."
		return 1
	fi
	dlog ${_ID} "Flashing device (around 2 min)..."
	ANDROID_PRODUCT_OUT=${_IMG_PATH} fastboot -s ${_ID} -w flashall &>/dev/null || { dlog ${_ID} "ERROR: Can't flash the images. Skipping."; return 1; }
	dlog ${_ID} "Device flash SUCCESSFULLY. Rebooting device (around 1 min)..."
}

# flash specific partition to given device
# usage: flash_part <partition> <device_id> <path_to_images>
function flash_part() {
	_PART=${1}
	_ID=${2}
	_IMG_PATH=${3}

	# iterate through comma seperated partitions
	OLDIFS=${IFS}
	IFS=","
	for part in ${_PART}; do
		check_part ${part} ${_IMG_PATH} || die "ERROR: partition ${part} not found in folder, or doesn't exist in android. Skipping."
	done
	IFS=${OLDIFS}


	if is_adb_mode ${_ID}; then
                dlog ${_ID} "Rebooting device in fastboot mode."
                adb -s ${_ID} reboot bootloader
                #start checking if the device is already booted (2 mins max)
                poll 60 "fastboot devices | grep ${_ID} &>/dev/null" || { dlog ${_ID} "ERROR: device never came back in fastboot mode. Aborting."; return 1; }
        #Check if it is already in fastboot mode
        elif ! is_fastboot_mode ${_ID}; then
                dlog ${_ID} "ERROR: device is not in adb or fastboot mode. Skipping."
                return 1
        fi
        dlog ${_ID} "Flashing device (around 2 min)..."
        # iterate through comma seperated partitions
        OLDIFS=${IFS}
        IFS=","
        for part in ${_PART}; do
		fastboot -s ${_ID} flash ${part} ${_IMG_PATH}/${part}.img &>/dev/null || { dlog ${_ID} "ERROR: Cant flash the partition ${part} Skipping."; return 1; }
        done
        IFS=${OLDIFS}

        dlog ${_ID} "Device flash SUCCESSFULLY. Rebooting device (around 1 min)..."
        fastboot reboot # go back into adb mode
        poll 60 "adb devices | grep ${_ID} &>/dev/null" || { dlog ${_ID} "ERROR: device never came back in adb mode"; return 1; }
}

# check if specific partition is an android partition name and if it exists in the image path
# usage: check_part <partition> <path_to_images>
function check_part() {
	_PART=${1}
	_IMG_PATH=${2}

	case ${_PART} in
	boot);;
	system);;
	recovery);;
	userdata);;
	*) return 1;;
	esac

	# if partition.img exists everything checks out
	[ -e ${_IMG_PATH}/${_PART}.img ] && return 0
	return 1
}

# parse the incoming parameters
usage="$0 [-s <device1>,<device2>,... or all] [ -p <alternative_images_path> ] [-f <partition1[,partition2,...] [-h]"
while getopts "s:p:hf:" options; do
    case $options in
        s ) DEVICES=${OPTARG};;
	p ) IMAGES_PATH=${OPTARG};;
        h ) echo ${usage}
            exit 1;;
	f ) PARTITIONS=${OPTARG};;
        * ) echo ${usage}
            exit 1;;
    esac
done

[ -z "${DEVICES}"  ] && die "ERROR: specify target devices.  Aborting."

if [ "${DEVICES}" == "all" ]; then
        DEVICES=`get_all_connected`
        [ -z "${DEVICES}" ] && die "ERROR: no devices connected. Aborting."
else
        DEVICES=${DEVICES//,/" "}
fi

[ -z "${IMAGES_PATH}" ] && IMAGES_PATH=${AOSP_OUT_DIR}
[ -d ${IMAGES_PATH} ] || die "ERROR: the path ${IMAGES_PATH} does not exist. Have you built Andriod? Aborting. "
echo "Location of the Android Images: ${IMAGES_PATH}"

# iterate through all the devices
for dev in ${DEVICES}; do
	id=`name2id ${dev}`
	if [ -z "${id}" ]; then
		die "ERROR: device ${dev} does not exist in device.lst. Skipping device."
	else
		if [ "x${PARTITIONS}" == "x" ]; then
			flash_images ${id} ${IMAGES_PATH}
		else
			flash_part ${PARTITIONS} ${id} ${IMAGES_PATH}
		fi
	fi
done
