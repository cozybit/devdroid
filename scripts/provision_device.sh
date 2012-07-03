#!/bin/bash

# Source common functions and parse options
source `dirname ${0}`/common.sh

# first argument has to be the device ID
ID=$1

[ "${ID}" == "" ] && die "ERROR: no device ID provided. Aborting."

# check if this works
[ -d ${AOSP_DIR} ] || die "Opss! Where does your aosp lives?. Aborting."

adb devices | grep ${ID} &>/dev/null && { echo "Rebooting device ${ID} in fastboot mode."; adb reboot bootloader; }
# start checking if the device is already booted (2 mins max)
poll 60 "fastboot devices | grep ${ID} &>/dev/null" || die "ERROR: the device ${ID} is not in fastboot mode. Aborting."

echo "Flashing images ( wait around 2 mins )..."
Q ./`dirname ${0}`/flash_images.sh ${ID}
[ $? -ne 0 ] && die "ERROR: something happened when flashing the android images. Aborting."

echo "Wait until the devices boots ups. This might take a while (max 3 mins)..."
# wait a bit, until it starts to boot up, reboots, etc
sleep 60
# start checking if the device is already booted (2 mins max)
poll 120 "adb devices | grep ${ID} &>/dev/null" || die "ERROR: the device ${ID} never came back after 2 mins. Aborting."

echo "Device is back! Start installing non-integrated projects and 3rd party apks."

#install all the apks
./`dirname ${0}`/install_apks.sh ${ID}

echo "SUCCESS!! Device ready to use."
