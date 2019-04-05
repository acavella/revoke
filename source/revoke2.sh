#!/usr/bin/env bash

## script/revoke.sh
## Automates the download and hosting of CRL data from a remote Certificate Authority.
## Tony Cavella (tony@cavella.com)
## https://github.com/tonycavella/revoke

## CONFIGURE DEFAULT ENVIRONMENT
set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace #debugging

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)"


## GLOBAL VARIABLES
arg1="${1:-}"
arg2="${2:-}"
log="/var/log/revoke.log"
ver=`cat ${__dir}/VERSION`
dtg=`date '+%Y-%m-%d %H:%M:%S'`
file_dtg=`date '+%Y-%m-%d_%H:%M:%S'`


## GENERAL SCRIPT FUNCTIONS
if [ "${arg1}" == "--help" ]
then
  source ${__dir}/bin/printhelp.sh
fi

if [ "${arg1}" == "--version" ]
then
  printf "revoke/${ver}\n"
fi

if [ "${arg1}" == "--status" ]
then
  printf "Print configuration status\n"    
fi

## LOAD FUNCTIONS
#source


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
