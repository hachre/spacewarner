#!/bin/bash

#
# SpaceWarner
#

# Description: Warns when disk space is dangerously low and sends notification mails.
# License: MIT, Copyright (c) 2018 Harald Glatt
# URL: https://github.com/hachre/spacewarner
# Version: 1.13.20191117.7


#
# Configuration
#

cfgConfigLocation="/etc/spacewarner.conf"

#
# Code
#

function help {
	echo "Usage: $0 [--help|--cron|--mailtest]"
	echo ""
	echo "The default is to show a list of all your drives and whether they are considered in a good or bad state."
	echo "Use '--cron' to disable any normal output and enable sending of warning mails instead."
	echo ""
	echo " --cron:     Disables all normal output. Enables sending warning mails."
	echo " --mailtest: Send a test mail."
}

function parameterChecks {
	if [ "$1" == "--help" ]; then
		help
		exit 127
	fi
	if [ ! -z "$1" ] && [ "$1" != "--cron" ] && [ "$1" != "--mailtest" ]; then
		help
		echo -e "\nError: Unknown parameter '$1'. See usage help above."
		exit 127
	fi
	if [ ! -z "$cfgConfigLocation" ]; then
		if [ ! -f "$cfgConfigLocation" ]; then
			echo "Error: Config file at '$cfgConfigLocation' can not be read."
			exit 1
		fi
		source "$cfgConfigLocation"
		if [ "$?" != "0" ]; then
			echo "Error: There were errors while reading the configuration file from '$cfgConfigLocation'."
			exit 1
		fi
	fi
	if [ -z "$cfgHideZFSDevices" ]; then
		echo "Error: Config value 'cfgHideZFSDevices' has to be set to either 'true' or 'false'."
		exit 1
	fi
	if [ -z "$cfgMailService" ]; then
		echo "Error: Config value 'cfgMailService' has to be set to either 'msmtp' or 'ssmtp'."
		exit 1
	fi
	if [ "$cfgMailService" != "msmtp" ] && [ "$cfgMailService" != "ssmtp" ] && [ "$cfgMailService" != "none" ]; then
		echo "Error: Config value 'cfgMailService' has to be set to 'msmtp', 'ssmtp' or 'none'."
		exit 1
	fi
	if [ -z "$cfgMailTo" ]; then
		echo "Error: Config value 'cfgMailTo' has to be set to a valid recipient mail address."
		exit 1
	fi
	if [ -z "$cfgMailFrom" ]; then
		echo "Error: Config value 'cfgMailFrom' has to be set to a valid sender mail address."
		exit 1
	fi
	if [ -z "$cfgMailFromName" ]; then
		echo "Error: Config value 'cfgMailFromName' should be set to a sender name."
		exit 1
	fi
	if [ "$cfgMailService" == "msmtp" ]; then
		if [ -z "$cfgMailFromHost" ]; then
			echo "Error: Config value 'cfgMailFromHost' has to be set to a valid sender hostname."
			exit 1
		fi
		if [ -z "$cfgMailServer" ]; then
			echo "Error: Config value 'cfgMailServer' has to be set to a SMTP mail server hostname."
			exit 1
		fi
		if [ -z "$cfgMailServerPort" ]; then
			echo "Error: Config value 'cfgMailServerPort' has to be set to a SMTP mail server port."
			exit 1
		fi
		if [ -z "$cfgMailUser" ]; then
			echo "Error: Config value 'cfgMailUser' has to be set to a SMTP authentication username."
			exit 1
		fi
		if [ -z "$cfgMailPassFile" ]; then
			echo "Error: Config value 'cfgMailPassFile' has to be set to the location of the file containing the SMTP authentication password."
			exit 1
		fi
		which msmtp 1>/dev/null 2>&1
		if [ "$?" != "0" ]; then
			echo "Error: Config value 'cfgMailService' defines 'msmtp' as your desired service, but it is not installed or not in \$PATH."
			exit 1
		fi
	fi
	if [ "$cfgMailService" == "ssmtp" ]; then
		which ssmtp 1>/dev/null 2>&1
		if [ "$?" != "0" ]; then
			echo "Error: Config value 'cfgMailService' defines 'ssmtp' as your desired service, but it is not installed or not in \$PATH."
			exit 1
		fi
	fi
	which mktemp 1>/dev/null 2>&1
	if [ "$?" != "0" ]; then
		echo "Error: Required tool 'mktemp' is not installed or not in \$PATH."
		exit 1
	fi
}
parameterChecks $*

function mail {
	if [ "$cfgMailService" == "msmtp" ]; then
		# add -P after --auth=on to enable debugging msmtp
		echo -e "From: $cfgMailFromName <$cfgMailFrom>\nSubject: Low Disk Space Warning\n$*" | msmtp --host=$cfgMailServer --user=$cfgMailUser --passwordeval="cat $cfgMailPassFile" --from=$cfgMailFrom --domain=$cfgMailFromHost --tls=on --tls-certcheck=off --port=$cfgMailServerPort --auth=on $cfgMailTo
		return $?
	fi
	if [ "$cfgMailService" == "ssmtp" ]; then
		echo -e "To: $cfgMailTo\nFrom: $cfgMailFromName <$cfgMailFrom>\nSubject: Low Disk Space Warning\n\n$*" | ssmtp $cfgMailTo
		return $?
	fi
	if [ "$cfgMailService" == "none" ]; then
		return 0
	fi
	echo "Error 1337: This point should not be reached. Please report as a bug together with configuration options and parameters!"
	exit 1337
}

function mailtest {
	if [ "$cfgMailService" == "msmtp" ] || [ "$cfgMailService" == "ssmtp" ]; then
		echo "Sending a test mail to '$cfgMailTo'..."
		mail "Low Disk Space Warner has successfully reached you!"
		exit $?
	fi
	echo "Error: 'cfgMailService' has been set to 'none'. Mail warnings are disabled and cannot be tested."
	exit 1
}
if [ "$1" == "--mailtest" ] || [ "$1" == "--testmail" ]; then
	mailtest
fi

function normalizeUnits {
	# initial value is a KB value (as delivered by df)
	value="$1"

	level=0
	if [ ! -z "$2" ]; then
		level="$2"
	fi

	unit="KB"
	if [ "$level" == "1" ]; then
		unit="MB"
	fi
	if [ "$level" == "2" ]; then
		unit="GB"
	fi
	if [ "$level" == "3" ]; then
		unit="TB"
	fi

	if [ "$1" -ge "1024" ]; then
		let level=level+1
		value=$(expr $value / 1024)
	else
		echo "$value $unit"
		return
	fi

	normalizeUnits "$value" "$level"
}

function alarm {
	volume=$1
	freePercent=$2
	size=$(normalizeUnits $3)
	avail=$(normalizeUnits $4)
	mail "One of your volumes has fallen below the warning threshold!\n\nHostname: $(hostname)\nVolume: $volume\nSize: $size\nFree: $avail (${freePercent}%)"
}

# Call through 'contains "$haystack" "$needle"'
function contains {
	haystack="$1"
	needle="$2"

	IFS=" "

	for entry in $haystack; do
		# Attempt to match exactly. (needle '/dev/loop4' doesn't match against haystack entry '/dev/loop')
		if [ "$needle" == "$entry" ]; then
			return 0
		fi

		# If haystack entry ends on *, match in reverse (needle '/dev/loop4' matches haystack entry '/dev/loop')
		if [ "${entry:${#entry}-1:1}" == "*" ]; then
			entry="${entry:0:-1}"
			if [[ $needle == *$entry* ]]; then
				return 0
			fi
		fi
	done

	# If nothing matches, return 1
	return 1
}

function getCustomWarnLevel() {
	# If we don't have a cfgCustomWarnBelow variable, immediately return default warning threshold
	if [ -z "$cfgCustomWarnBelow" ]; then
		echo $cfgWarnBelow
		return
	fi

	# Find the specified filesystem ($1) and output its corresponding warning threshold
	for entry in ${cfgCustomWarnBelow[@]}; do
		fs=$(echo $entry | cut -d ',' -f 1)
		warnLevel=$(echo $entry | cut -d ',' -f 2)
		if [ "$fs" == "$1" ]; then
			echo "$warnLevel"
			return
		fi
	done

	# If we weren't able to find anything, return the default warn level
	echo "$cfgWarnBelow"
}

# Prepare execution
dfTransform="$cfgCustomDFParams"
if [ "$cfgHideZFSDevices" == "true" ]; then
	dfTransform="$dfTransform -x zfs"
fi

tmpfile=$(mktemp)
df -x tmpfs -x devtmpfs $dfTransform --output=source,size,avail | tail -n+2 > $tmpfile

# Execute iteration through df to find filesystems to check
prevIFS="$IFS"
IFS="
"
for entry in $(cat $tmpfile); do
	source=$(echo $entry | awk '{ print $1 }')
	size=$(echo $entry | awk '{ print $2 }')
	avail=$(echo $entry | awk '{ print $3 }')

	expr $size \* 1 1>/dev/null 2>&1
	if [ "$?" != "0" ]; then
		# Parsing of size didn't work (most likely because of spaces in the path) skip this entry
		continue
	fi

	percentFree=$(expr $avail \* 100 / $size)
	displaySize=$(normalizeUnits $size)
	displayAvail=$(normalizeUnits $avail)

	ok=""

	# Execute ignore & hide params
	contains "$cfgHiddenDevices" "$source" && continue
	contains "$cfgIgnoredDevices" "$source" && ok="[IGN]"

	# Decide whether this is an entry that has fallen below the threshold
	if [ "$percentFree" -le $(getCustomWarnLevel "$source") ] && [ -z "$ok" ]; then
		ok="[BAD]"
		if [ "$1" == "--cron" ]; then
			alarm $source $percentFree $size $avail
		fi
	fi
	if [ "$1" != "--cron" ]; then
		if [ -z "$ok" ]; then
			ok="[ OK]"
		fi
		echo "$ok $source: ${percentFree}% free (size: $displaySize, free: $displayAvail)"
	fi
done
rm $tmpfile

IFS="$prevIFS"
