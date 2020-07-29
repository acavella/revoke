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
logFile="${__dir}/revoke_install.log"

printDTG=$(date '+%Y-%m-%d %H:%M:%S')
fileDTG=$(date '+%Y%m%d-%H%M%S')


# SCRIPT STARTUP
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] revoke install v$ver started" 2>&1 | tee -a $logFile