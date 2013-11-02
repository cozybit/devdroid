#!/bin/bash

# Source common functions and parse options
source `dirname ${0}`/common.sh

# install all the external apks on a given device
# usage: install_apks <device_id>
function install_apks () {
    _ID=${1}
    # TODO: This should be externalized in a external file to make sure it's easy to
    # install external apks
    _FULL_LIST="/home/guillermo/dev/magnet-service/bin/magnet-service-release.apk /home/guillermo/dev/presenter-2.x/bin/presenter-release.apk /home/guillermo/dev/Android-File-Manager/bin/open_file_manager-release.apk /home/guillermo/dev/meshball/bin/Meshball-release.apk /home/guillermo/dev/file-share/bin/meshshare-release.apk $(ls ${OTHER_APKS_DIR}/*.apk)"

    for apk in ${_FULL_LIST}; do
        dlog ${_ID} "Installing $(basename ${apk}) ..."
        adb_agnostic ${_ID} install -r ${apk} | grep "Failure" &> /dev/null
        [ $? -eq 0 ] && dlog ${_ID} "ERROR: something happened when installing ${apk}. Continuing..."
    done

    dlog ${_ID} "All applications installed in the device."
}

# parse the incoming parameters
usage="$0 [-s <device1>,<device2>,..] [-h]"
while getopts "s:h" options; do
    case $options in
        s ) DEVICES=${OPTARG};;
        h ) echo ${usage}
            exit 1;;
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

# iterate through all the devices
for dev in ${DEVICES}; do
    install_apks ${dev}
done

#TODO: this should be moved to common.sh and it should apply to all the scripts 
#ID=${1}
#if [ -z ${ID} ]; then
#        ID=`get_single_dev_id`
#        [ "${ID}" == "" ] && die "ERROR: no device ID provided. Aborting."
#        echo Detected device: ${ID}
#fi
