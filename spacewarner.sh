#!/bin/bash

#
# Low Free Disk Space Warning System
#

# URL: https://github.com/hachre/spacewarner
# Version: 1.7.20180319.2


#
# Configuration
#

# Supported services are "msmtp", "ssmtp" and "none"
cfgMailService="none"

# Required for both msmtp and ssmtp
cfgMailTo="hachre@dynaloop.com"
cfgMailFrom="solaris@dynaloop.com"
cfgMailFromName="Solaris"

# Required for just msmtp, leave empty or comment out for ssmtp
cfgMailFromHost="solaris.dynaloop.com"
cfgMailServer="orion.dynaloop.net"
cfgMailServerPort="587"
cfgMailUser="server_mail@dynaloop.com"
cfgMailPassFile="/root/.mailpass"

# General configuration options
cfgWarnBelow="10"


#
# Code
#

function help {
	echo "Usage: $0 [--mailtest|--cron]"
	echo " --cron:     Omits all output."
	echo " --mailtest: Send a test mail."
}

function parameterChecks {
	if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
		help
		exit 127
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
			echo "Error: Config value 'cfgMailService' defines 'msmtp' as your desired service, but it is not installed and not in PATH."
			exit 1
		fi
	fi
	if [ "$cfgMailService" == "ssmtp" ]; then
		which ssmtp 1>/dev/null 2>&1
		if [ "$?" != "0" ]; then
			echo "Error: Config value 'cfgMailService' defines 'ssmtp' as your desired service, but it is not installed and not in PATH."
			exit 1
		fi
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

prevIFS="$IFS"
IFS="
"

for entry in $(df -x tmpfs -x devtmpfs --output=source,size,avail | tail -n+2); do
	source=$(echo $entry | awk '{ print $1 }')
	size=$(echo $entry | awk '{ print $2 }')
	avail=$(echo $entry | awk '{ print $3 }')
	percentFree=$(expr $avail \* 100 / $size)
	ok=" [OK]"

	displaySize=$(normalizeUnits $size)
	displayAvail=$(normalizeUnits $avail)

	if [ "$percentFree" -le "$cfgWarnBelow"	]; then
		ok="[BAD]"
		alarm $source $percentFree $size $avail
	fi
	if [ "$1" != "--cron" ] && [ "$1" != "-c" ]; then
		echo "$ok $source: ${percentFree}% free (size: $displaySize, free: $displayAvail)"
	fi
done

IFS="$prevIFS"