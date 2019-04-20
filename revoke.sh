#!/usr/bin/env bash

## script/revoke.sh
## Automates the download and hosting of CRL data from a remote Certificate Authority.
## Tony Cavella (tony@cavella.com)
## https://github.com/revokehq/revoke

## CONFIGURE DEFAULT ENVIRONMENT
set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace #debugging

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__bin="${__dir}/bin"
__conf="${__dir}/conf"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)"


## GLOBAL VARIABLES
arg1="${1:-}"
arg2="${2:-}"
log="/var/log/revoke.log"
ver=`cat ${__dir}/VERSION`
dtg=`date '+%Y-%m-%d %H:%M:%S'`
dtgFile=`date '+%Y%m%d_%H%M%S'`


## LOAD CONFIGURATION
confFile=${__conf}/revoke.conf
source ${confFile}

## LOAD FUNCTIONS
source ${__bin}/revoke_verify.sh
source ${__bin}/revoke_help.sh
source ${__bin}/revoke_status.sh
source ${__bin}/revoke_config.sh

## PERFORM VALIDATION
verify_module


## GENERAL FUNCTIONS
if [ "${arg1}" == "--help" ]
then
  print_help
fi

if [ "${arg1}" == "--version" ]
then
  printf "revoke/${ver}\n"
fi

if [ "${arg1}" == "--status" ]
then
  print_status
fi

if [ "${arg1}" == "--config" ]
then
  init_config
fi


## MAIN FUNCTIONS



exit 0
## OLD SCRIPT BELOW 
# SCRIPT VARIABLES
scriptName=$0
scriptVersion="1.0.1"
baseDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
confFile="$baseDIR""/conf/revoke.conf"
logFile="/var/log/revoke.log"
counterA=0
timeDate=$(date '+%Y-%m-%d %H:%M:%S')
fileDTG=$(date '+%Y%m%d-%H%M%S')
#defGW=$(ip route show default | awk '/default/ {print $3}')

# SCRIPT STARTUP
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] (00) revoke v$scriptVersion started" >> $logFile


## CHECK AND LOAD EXTERNAL CONFIG
if [ ! -e $confFile ]
then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] (64) Configuration file missing, please run setup.sh" >> $logFile
  exit 64
else
  source $confFile
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] (00) Configuration file loaded sucessfully, $confFile" >> $logFile
fi

source bin/netcheck.sh


# DOWNLOAD CRL(s)
for i in "${crlURL[@]}"
do
  curl -k -s $i > $downloadDIR${crlName[$counterA]}
  if [ ! -e $downloadDIR${crlName[$counterA]} ]
  then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] (64) crl download failed, $i" >> $logFile
  else 
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] (00) crl download sucessful, $i" >> $logFile
    mv $downloadDIR${crlName[$counterA]} $publicWWW
  fi
let counterA=counterA+1
done


exit 0
