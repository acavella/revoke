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
installDir="/usr/local/bin/revoke"
dbDir="/usr/local/bin/revoke/db"
logFile="${__dir}/revoke_install.log"

supportedOS="Fedora"

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
detectedOS="${detected_os_pretty%% *}"
detected_version=$(cat /etc/*release | grep VERSION_ID | cut -d '=' -f2- | tr -d '"')

for i in ${supportedOS[@]}; do 
    if [ "$detectedOS" = "$i" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Operating System detected: ${detected_os_pretty}" 2>&1 | tee -a $logFile
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] ${detected_os_pretty} is not currently supported, exiting." 2>&1 | tee -a $logFile
        exit
    fi
done

# PACKAGE MANAGER CHECK
if [ "$detectedOS" = "Fedora" ] || [ "$detectedOS" = "CentOS" ]; then
    if is_command dnf ; then
        PKG_MANAGER="dnf"
    else
        PKG_MANAGER="yum"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Package Manager detected: $PKG_MANAGER" 2>&1 | tee -a $logFile
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] Unable to detect appropriate package manager." 2>&1 | tee -a $logFile
fi

# DEPENDENCY CHECK
REVOKE_DEPS=(sqlite3 curl git openssl)

for i in "${REVOKE_DEPS[@]}"
do
    if is_command ${i}; then
        :
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Installing dependency: ${i}" 2>&1 | tee -a $logFile
        ${PKG_MANAGER} install ${i} -y &> /dev/null
    fi
done

# CREATE DIRECTORIES
mkdir -p ${installDir}
mkdir -p ${installDir}/{conf,db}

# INITIALIZE DATABASE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Initializing SQLite database." 2>&1 | tee -a $logFile
sqlite3 ${dbDir}/revoke.db <<'END_SQL'
CREATE TABLE crlList (
        Row_ID integer PRIMARY KEY AUTOINCREMENT,
        CRL_Uri text,
        CRL_Name text
);
END_SQL
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Database initialization completed." 2>&1 | tee -a $logFile