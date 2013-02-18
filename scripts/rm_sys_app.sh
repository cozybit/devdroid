#!/bin/bash

# source common functions and parse options
source `dirname ${0}`/common.sh

# remove system app from a given device
# usage: remove_apps <device_id> <app1> <app2> ...
function remove_apps () {
	_ID=${1}; shift 1; _APPS=${*}
	Q adb_agnostic ${_ID} root || { dlog ${_ID} "ERROR: something happened while enabling root permissions. Skipping device."; return 1; }
	sleep 2
	Q adb_agnostic ${_ID} remount || { dlog ${_ID} "ERROR: something happened while remounting the system partition. Skipping device."; return 1; }
	sleep 4

	for app in ${_APPS}; do
	    adb_agnostic ${_ID} shell rm /system/app/${app} | grep "failed" &> /dev/null
	    [ $? -eq 0 ] && dlog ${_ID} "ERROR: System app ${app} can't be deleted. Continuing..." && return 1
	done

	dlog ${_ID} "Applications deleted! Rebooting device."
	Q adb_agnostic ${_ID} reboot
}

# parse the incoming parameters
usage="$0 [-s <device1>,<device2>,.. or all] [-a <apk1>,<apk2>,..] [-h]"
while getopts "s:a:h" options; do
    case $options in
        s ) DEVICES=${OPTARG};;
        a ) APP_LIST=${OPTARG};;
	h ) echo ${usage}
	    exit 1;;
        * ) echo ${usage}
            exit 1;;
    esac
done

[ -z "${DEVICES}"  ] && die "ERROR: specify target devices.  Aborting."
[ -z "${APP_LIST}" ] && die "ERROR: probide application/s to delete. Aborting."

if [ "${DEVICES}" == "all" ]; then
	DEVICES=`get_all_connected`
	[ -z "${DEVICES}" ] && die "ERROR: no devices connected. Aborting."
else
	DEVICES=${DEVICES//,/" "}
fi

# iterate through all the devices
for dev in ${DEVICES}; do
	id=`name2id ${dev}`
	#verify the device name first
        if [ -z "${id}" ]; then
                echo "ERROR: device ${dev} does not exist in device.lst. Skipping device."
        else
		APP_LIST=${APP_LIST//,/" "}
		remove_apps ${id} ${APP_LIST}
        fi
done
