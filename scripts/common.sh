# perform a command quietly unless debugging is enabled.i
# usage: Q <anything>
function Q () {
        if [ "${VERBOSE}" == "1" ]; then
                $*
        else
                $* &> /dev/null
        fi
}

# relate a log entry with a given device
# usage: log <device_id> <log_message>
function dlog () {
	_ID=${1}; shift 1
	_DEV=`id2name ${_ID}`
	echo "[${_DEV}] ${*}"
}

# print message and exit the script
# usage: die <message>
function die () {
	echo ${*}
	exit -1
}

# validate a list of given devices and returns a formatted list. The returned
# list is just the list of devices separated by spaces. If not fails.
# valid input formats: 
#   CB01,CB02,CB03 | all | CB01:CB10
# usage: validate_devices <devices>
function validate_devices() {

	_DEVS=${1}

	[ -z "${_DEVS}" ] && die "ERROR: specify target devices.  Aborting."

        if [ "${_DEVS}" == "all" ]; then
                _DEVS=`get_all_connected`
                [ -z "${_DEVS}" ] && die "ERROR: no devices connected. Aborting."
        elif [[ "${_DEVS}" =~ ":"  ]]; then
                _RANGE=${_DEVS//CB/}
		_OLD_IFS="${IFS}"
		IFS=":"
		_RANGE=( ${_RANGE} )
		IFS="${_OLD_IFS}"
                [ "${_RANGE[0]}" -lt "${_RANGE[1]}" ] || die "ERROR: invalid range of devices. Right format: CB05:CB10"
                _DEVS="CB`seq -s " CB" ${_RANGE[0]} ${_RANGE[1]}`"
        else
                _DEVS=${_DEVS//,/" "}
        fi

	echo ${_DEVS} && return 0
}

# adb_agnostic check the status device before executing the adb command
# usage: adb_agnostic <device_id> <adb params>
function adb_agnostic () {
	_ID=${1}; shift 1;
	_DEV_NAME=`id2name ${_ID}`
	if ! is_adb_mode ${_ID} && ! _IP=`is_tcpip_mode ${_ID}` ; then
		echo "[${_DEV_NAME}/${_ID}] WARNING: device not connected to adb (via USB or TCP). Skipping device." >/dev/stderr
		return 1
	fi
	# if is not USB adb, then replace ID with IP:PORT
	is_adb_mode ${_ID} || _ID=${_IP}:${ADB_TCP_PORT}
	echo "[${_DEV_NAME}] adb ${*}"
	adb -s ${_ID} ${*}
}

# repeat command until it either returns success, or timeout is reached.
# The total execution time in seconds is echoed in either case. Return success
# if command did not time out.
# usage: poll <timeout> <cmd>
function poll () {
        _TIMEOUT=${1}
        shift 1
        _CMD=${*}
        _poll ${_TIMEOUT} 0 "${_CMD}"

}

function _poll () {
        _TIMEOUT=$1
        _EC=$2
        _CMD=${3}
        TIMEFORMAT=%R # have 'time' just print seconds
        _START_TIME=`date +%s.%N`
        _EXE_TIME=$( (time while true; do
                        Q eval "${_CMD}"; [ "$?" == "${_EC}" ] && break
                        _NOW=`date +%s.%N`
                        echo "${_NOW} ${_START_TIME} ${_TIMEOUT}" | \
                                awk '{exit $1 > ($2 + $3)}' || break
                done) 3>&2 2>&1 1>&3 )

        echo "${_EXE_TIME} ${_TIMEOUT}" | awk '{exit $1 > $2}' || _TIMED_OUT="y"
        _MSG="finished"
        if [ "${_TIMED_OUT}" == "y" ]; then
                _MSG="timed out"
        fi
        Q echo "${_CMD} ${_MSG} in ${_EXE_TIME}s"
        [ "${_TIMED_OUT}" != "y" ]
}

# extract the vale of a specific tag attribue in a xml file
# usage: extractAttributeXML <file.xml> </root/child1/child2> <attribute name>
function extractAttributeXML () {
        _FILE=${1}
        _PATH=${2}
        _ATTR=${3}
        _RESULTS=`echo 'cat '${_PATH}'/@*[name()="'${_ATTR}'"]' | xmllint --shell ${_FILE} | grep ${_ATTR}= | cut -d"=" -f2 `
        echo ${_RESULTS//\"/}
}

# extract the value from a key=value pair.
# usage: extract_value <key> <file_name>
function extract_value () {
	_KEY=${1}
	_FILE=${2}
	_AUX=`grep ${_KEY} ${_FILE}`
	for var in ${_AUX}; do
		if [[ "${var}" == *${_KEY}* ]]; then
			_VALUE=`echo ${var} | cut -d"=" -f2`
			_VALUE=${_VALUE//\"/}
			echo -n ${_VALUE}
		fi
	done
	echo -n ""
	return 1
}

# check if the device ${1} is in adb mode
# usage: is_adb_mode <device_id>
function is_adb_mode () {
	_ID=${1}
	adb devices | grep ${_ID} | grep device &>/dev/null && return 0
	return 1
}

# check if the device ${1} is in fastboot mode
# usage: is_fastboot_mode <device_id>
function is_fastboot_mode () {
        _ID=${1}
        fastboot devices | grep ${_ID} | grep fastboot &>/dev/null && return 0
        return 1
}

# check if the device ${1} is in tcpip mode
# usage: is_tcpip_mode <device_id>
function is_tcpip_mode () {
	_ID=${1}
	_IPS=`id2ips ${_ID}`
	[ -z "${_IPS}" ] && return 1
	IFS=","
	for ip in ${_IPS}; do
		sudo ping -f -c 4 -w 3 ${ip} &>/dev/null
		if [ $? -eq 0 ]; then
			adb connect ${ip}:${ADB_TCP_PORT} &>/dev/null
			sleep 1
			adb devices | grep ${ip} | grep device &>/dev/null && echo -n ${ip} && return 0
		fi
		adb disconnect ${ip} &>/dev/null
	done
	return 1
}

# returns the device ID when a single device is connected to adb or fastboot
# usage: get_single_dev_id
function get_single_dev_id () {
	_DEVICES=`adb devices | grep -v "List of" | grep -v '^$' -c`
	if [ ${_DEVICES} -eq 1 ]; then
		echo `adb devices | grep -v "List of" | grep -v '^$' |  cut -d"$(echo -e "\t")" -f1`
	fi

	_DEVICES=`fastboot devices | grep -c "fastboot"`
        if [ ${_DEVICES} -eq 1 ]; then
                echo `fastboot devices | grep "fastboot" |  cut -d"$(echo -e "\t")" -f1`
        fi
}

# returns a list with the device names of the devices connected to adb
# usage: get_all_connected
function get_all_connected () {
	_DEV_IDS=`adb devices | grep -v "List of" | grep -v '^$' |  cut -d"$(echo -e "\t")" -f1`
	for id in ${_DEV_IDS}; do
		if [[ "${id}" == *:* ]]; then
			_IP=`echo -e ${id} | cut -d":" -f1`
			_DEV_NAMES="${_DEV_NAMES} `ip2name ${_IP}`"
		else
			_DEV_NAMES="${_DEV_NAMES} `id2name ${id}`"
		fi
	done
	echo -n ${_DEV_NAMES}
}

# cats the device.lst config file avoiding the commented lines
# usage: cat_conf
function cat_conf () {
	[ -n ${DEVICE_LIST} -a -f ${DEVICE_LIST} ] || die "ERROR: The list of devices is not especified or does not exist. Aborting."
	cat ${DEVICE_LIST} | grep -v "#"
}

# returns the device serial ID.
# It gets the info from the config file device_ids.lst
# usage: name2id <device_name>
function name2id () {
	_DEV_NAME=${1}
	_DEV_ID=`cat_conf | grep ${_DEV_NAME} 2>/dev/null | cut -d";" -f2`
	[ -z "${_DEV_ID}" ] && { echo "WARNING: Device ${_DEV_NAME} has no ID assigned in devices.lst.">/dev/stderr ; return 1; }
	echo -n ${_DEV_ID}
}

# returns the device serial ID.
# It gets the info from the config file device_ids.lst
# usage: name2id <device_name>
function id2name () {
	_DEV_ID=${1}
	_DEV_NAME=`cat_conf | grep ${_DEV_ID} 2>/dev/null | cut -d";" -f1`
	[ -z "${_DEV_NAME}" ] && { echo "WARNING: Device ${_DEV_ID} has no name assigned in devices.lst.">/dev/stderr ; return 1; }
	echo -n ${_DEV_NAME}
}

# returns the IP address of the device_id.
# It gets the info from the config file device_ids.lst
# usage: id2ips <device_ID>
function id2ips () {
        _DEV_ID=${1}
        _DEV_IP=`cat_conf | grep ${_DEV_ID} 2>/dev/null | cut -d";" -f3`
	[ -z "${_DEV_IP}" ] && { echo "WARNING: Device ${_DEV_ID} has no IP assigned in devices.lst.">/dev/stderr ; return 1; }
        echo -n ${_DEV_IP}
}

# returns the ID that corresponds to the given IP.
# It gets the info from the config file device_ids.lst
# usage: ip2id <device_IP>
function ip2id () {
        _DEV_IP=${1}
        _DEV_ID=`cat_conf | grep ${_DEV_IP} 2>/dev/null | cut -d";" -f2`
	[ -z "${_DEV_ID}" ] && { echo "WARNING: IP ${_DEV_IP} is not present in devices.lst.">/dev/stderr; return 1; }
        echo -n ${_DEV_ID}
}

# returns the ID that corresponds to the given IP.
# It gets the info from the config file device_ids.lst
# usage: ip2name <device_IP>
function ip2name () {
        _DEV_IP=${1}
        _DEV_NAME=`cat_conf | grep ${_DEV_IP} 2>/dev/null | cut -d";" -f1`
	[ -z "${_DEV_NAME}" ] && { echo "WARNING: IP ${_DEV_IP} is not present in devices.lst.">/dev/stderr; return 1; }
        echo -n ${_DEV_NAME}
}

# returns the MAC address of the mesh iface.
# It gets the info from the config file device_ids.lst
# usage: name2mac <device_name>
function name2mac () {
	_DEV_NAME=${1}
	_DEV_MAC=`cat_conf | grep ${_DEV_NAME} 2>/dev/null | cut -d";" -f4`
	[ -z "${_DEV_MAC}" ] && { echo "WARNING: Device ${_DEV_IP} has no MAC for its mesh iface in devices.lst.">/dev/stderr; return 1; }
	echo -n ${_DEV_MAC}
}

# converts a given MAC address to a known IP with format 10.X.X.X
# usage: mac2ip <mac_address>
function mac2ip () {
        _MAC=`echo ${1} | tr '[:lower:]' '[:upper:]'`
	[ -z ${_MAC} ] && return 1
        _HEX=(${_MAC//:/" "})
        _IP="10"
        for i in 3 4 5; do
                _DEC=`echo "ibase=16; ${_HEX[$i]}" | bc`
                _IP=${_IP}.${_DEC}
        done
        echo -n ${_IP}
}

# converts a given IP address to a MAC
# usage: ip2mac <ip_address>
function ip2mac () {
        _IP=${1}
	_MAC=`adb -s ${_IP}:${ADB_TCP_PORT} shell netcfg | grep mesh0 | awk '{ printf $5 }' | tr -d '\r'`
	echo -n ${_MAC}
}

# return (echo) the mac for given interface
# use: if2mac <iface>
function if2mac () {
        _IF=${1}
        echo -n `ip link show ${_IF} | awk '/ether/ {print $2}'`
}

# returns the name of the current git branch
function git.branch {
  br=`git branch | grep "*"`
  echo ${br/* /}
}

# enable debug is specified
[ "${DEBUG}" == "1" ] && set -x

# check if the main environment variable is set. It defines the top directory. Otherwise, abort
[ -z ${DEVDROID} ] && die "ERROR: The environment variable DEVDROID is not set. Aborting."

# allow user to override configuration file in environment
[ -z ${DEVDROID_CONF} ] && DEVDROID_CONF=${DEVDROID}/config/devdroid.conf

# source the config variables
if [ -e ${DEVDROID_CONF} ]; then
        source ${DEVDROID_CONF}
else
	die "ERROR: config file ${DEVDROID_CONF} does not exist"
fi

# validate minimal configuration
[ -z ${AOSP_DIR} ] && die "ERROR: No AOSP_DIR specified"
[ -z ${OTHER_APKS_DIR} ] && die "ERROR: No OTHER_APKS_DIR directory specified"
[ -z ${RELEASES_DIR} ] && die "ERROR: No RELEASES_DIR directory specified"
[ -z ${AOSP_VERSION} ] && die "ERROR: No AOSP_VERSION specified"
[ -z ${AOSP_FLAVOR} ] && die "ERROR: No AOSP_FLAVOR specified"
[ -z ${AOSP_BUILD_TYPE} ] && die "ERROR: No AOSP_BUILD_TYPE specified"
[ -z ${ADB_TCP_PORT} ] && die "ERROR: No ADB_TCP_PORT specified"

export AOSP_OUT_DIR=${AOSP_DIR}/out/target/product/${AOSP_FLAVOR}
