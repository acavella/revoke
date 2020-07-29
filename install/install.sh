#!/usr/bin/env bash

# NAME: install.sh
# DECRIPTION: Performs automated installation of revoke cdp
# AUTHOR: Tony Cavella (tony@cavella.com)
# SOURCE: https://github.com/altCipher/revoke

## CONFIGURE DEFAULT ENVIRONMENT
set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

## VARIABLES
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__bin="${__dir}/bin"
__conf="${__dir}/conf"

ver="0.1"
confFile="${__conf}/install.conf"
installDir="/usr/local/bin/revoke/"
logFile="${__dir}/revoke_install.log"

printDTG=$(date '+%Y-%m-%d %H:%M:%S')
fileDTG=$(date '+%Y%m%d-%H%M%S')

is_command() {
    # Checks for existence of string passed in as only function argument.
    # Exit value of 0 when exists, 1 if not exists. Value is the result
    # of the `command` shell built-in call.
    local check_command="$1"

    command -v "${check_command}" >/dev/null 2>&1
}

# SCRIPT STARTUP
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] revoke install v$ver started" 2>&1 | tee -a $logFile

# ROOT/SUDO CHECK
if [ "$EUID" -ne 0 ] ; then 
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] Installation must be executed as root or sudo, exiting." 2>&1 | tee -a $logFile
    exit
else 
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Installation executed as root or sudo." 2>&1 | tee -a $logFile
fi

# OPERATING SYSTEM CHECK
detected_os_pretty=$(cat /etc/*release | grep PRETTY_NAME | cut -d '=' -f2- | tr -d '"')
detected_os="${detected_os_pretty%% *}"
detected_version=$(cat /etc/*release | grep VERSION_ID | cut -d '=' -f2- | tr -d '"')

# PACKAGE MANAGER CHECK
if is_command dnf ; then
    PKG_MANAGER="dnf"
else
    PKG_MANAGER="yum"
fi
