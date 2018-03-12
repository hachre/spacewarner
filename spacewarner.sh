#!/bin/bash

#
# Low Free Disk Space Warning System
#

# URL: https://github.com/hachre/spacewarner
# Version: 1.2.20180312.4


#
# Configuration
#

cfgMailTo="hachre@dynaloop.com"
cfgMailFrom="solaris@dynaloop.com"
cfgMailFromName="Solaris"
cfgMailFromHost="solaris.dynaloop.com"
cfgMailServer="orion.dynaloop.net"
cfgMailUser="server_mail@dynaloop.com"
cfgMailPassFile="/root/.mailpass"
cfgWarnBelow="10"


#
# Code
#

function help {
	echo "Usage: $0 [--mailtest|--verbose]"
	echo " --verbose:  Tells everything that's happening."
	echo " --mailtest: Send a test mail."
}
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
	help
	exit 127
fi

function checks {
	which msmtp 1>/dev/null 2>&1
	if [ "$?" != "0" ]; then
		echo "Error: 'msmtp' is not installed or not in PATH."
		exit 1
	fi
}
checks

function mail {
	# add -P after --auth=on to enable debugging msmtp
	echo -e "From: $cfgMailFromName <$cfgMailFrom>\nSubject: Low Disk Space Warning\n$*" | msmtp --host=$cfgMailServer --user=$cfgMailUser --passwordeval="cat $cfgMailPassFile" --from=$cfgMailFrom --domain=$cfgMailFromHost --auth=on $cfgMailTo
	return $?
}

function mailtest {
	echo "Sending a test mail to '$cfgMailTo'..."
	mail "Low Disk Space Warner has successfully reached you!"
	exit $?
}
if [ "$1" == "--mailtest" ] || [ "$1" == "--testmail" ]; then
	mailtest
fi

function alarm {
	mail "Attention! Your volume '$1' has fallen under the warning threshold: It has ${2}% space free."
}

prevIFS="$IFS"
IFS="
"

for entry in $(df -x tmpfs -x devtmpfs --output=source,size,avail | tail -n+2); do
	source=$(echo $entry | awk '{ print $1 }')
	size=$(echo $entry | awk '{ print $2 }')
	avail=$(echo $entry | awk '{ print $3 }')
	percentFree=$(expr $avail \* 100 / $size)
	ok=" [OK]"
	if [ "$percentFree" -le "$cfgWarnBelow"	]; then
		ok="[BAD]"
		alarm $source $percentFree
	fi
	if [ "$1" == "--verbose" ]; then
		echo "$ok $source: ${percentFree}% (size: $size, avail: $avail)"
	fi
done

IFS="$prevIFS"
