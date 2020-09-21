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
wwwDir="/var/www/html/revoke"
logFile="${installDir}/install.log"
printDTG=$(date '+%Y-%m-%d %H:%M:%S')
fileDTG=$(date '+%Y%m%d-%H%M%S')



supportedOS=("Fedora" "CentOS")
REVOKE_DEPS=(sqlite3 curl openssl httpd) 
INSTALL_DEPS=(tar)



is_command() {
    # Checks for existence of string passed in as only function argument.
    # Exit value of 0 when exists, 1 if not exists. Value is the result
    # of the `command` shell built-in call.
    local check_command="$1"

    command -v "${check_command}" >/dev/null 2>&1
}

# ROOT/SUDO CHECK
if [ "$EUID" -ne 0 ] ; then 
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] Installation must be executed as root or sudo, exiting." 2>&1 | tee -a $logFile
    exit
else 
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Installation executed as root or sudo." 2>&1 | tee -a $logFile
fi

# CREATE DIRECTORIES
mkdir -p ${installDir}
mkdir -p ${installDir}/{conf,db}

# SCRIPT STARTUP
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Automated Installer v$ver" 2>&1 | tee -a $logFile
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Installing: revoke" 2>&1 | tee -a $logFile

# OPERATING SYSTEM CHECK

if [ -f "/etc/os-release" ]; then
    rel="/etc/os-release"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] Unable to determine OS version, automated installation exiting." 2>&1 | tee -a $logFile
    exit 1
fi

detected_os_pretty=$(cat ${rel} | grep PRETTY_NAME | cut -d '=' -f2- | tr -d '"')
detectedOS="${detected_os_pretty%% *}"
detected_version=$(cat ${rel} | grep VERSION_ID | cut -d '=' -f2- | tr -d '"')

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
for i in "${REVOKE_DEPS[@]}"
do
    if is_command ${i}; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Dependency satisfied: ${i}" 2>&1 | tee -a $logFile
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Installing dependency: ${i}" 2>&1 | tee -a $logFile
        ${PKG_MANAGER} install ${i} -y &> /dev/null
        if [ $? = 0 ]
        then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Dependency installed: ${i}" 2>&1 | tee -a $logFile
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] Unable to install dependency: ${i}" 2>&1 | tee -a $logFile
        fi
    fi
done

# INITIALIZE DATABASE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Initializing SQLite database." 2>&1 | tee -a $logFile
sqlite3 ${dbDir}/revoke.db <<'END_SQL'
CREATE TABLE crlList (
        Row_ID integer PRIMARY KEY AUTOINCREMENT,
        CRL_Uri text,
        CRL_Name text,
        CRL_Hash text,
        CRL_Date text
);
END_SQL
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Database initialization completed." 2>&1 | tee -a $logFile

# INSTALL WEBSERVER


