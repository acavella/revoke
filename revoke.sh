#!/usr/bin/env bash

# NAME: revoke.sh
# DECRIPTION: Perform downloads of remote CRL data and host them locally via HTTPD.
# AUTHOR: Tony Cavella (tony@cavella.com)
# SOURCE: https://github.com/acavella/revoke

## CONFIGURE DEFAULT ENVIRONMENT
set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

## VARIABLES
ver=$(<VERSION)

scriptName=$0
baseDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
timeDate=$(date '+%Y-%m-%d %H:%M:%S')
fileDTG=$(date '+%Y%m%d-%H%M%S')
confFile="$baseDIR/conf/revoke.yml"
log="${baseDIR}/logs/revoke_${fileDTG}.log"
counterA=0
defGW=$(/usr/sbin/ip route show default | /usr/bin/awk '/default/ {print $3}')

## FUNCTIONS

show_version() {
    printf "$(date '+%Y-%m-%dT%H:%M:%S') [info] Revoke version: ${VERSION}\n"
    printf "$(date '+%Y-%m-%dT%H:%M:%S') [info] Bash version: ${BASH_VERSION}\n"
    printf "$(date '+%Y-%m-%dT%H:%M:%S') [info] Operating system: ${DETECTED_OS}\n"
}

make_temporary_log() {
    # Create a random temporary file for the log
    TEMPLOG=$(mktemp /tmp/revoke_temp.XXXXXX)
    # Open handle 3 for templog
    # https://stackoverflow.com/questions/18460186/writing-outputs-to-log-file-and-console
    exec 3>${TEMPLOG}
    # Delete templog, but allow for addressing via file handle
    # This lets us write to the log without having a temporary file on the drive, which
    # is meant to be a security measure so there is not a lingering file on the drive during the install process
    rm ${TEMPLOG}
}

copy_to_run_log() {
    # Copy the contents of file descriptor 3 into the log
    cat /proc/$$/fd/3 > "${log}"
    chmod 644 "${log}"
}

get_array_size() {
  arraySize=$(yq '.ca | length' ${confFile})
}

main() {
    show_version
    get_cacerts
    extract_pkcs12
    reenroll
}

make_temporary_log
main | tee -a /proc/$$/fd/3
copy_to_run_log

# SCRIPT STARTUP
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] (00) revoke v$ver started" >> $logFile


## CHECK AND LOAD EXTERNAL CONFIG
if [ ! -e $confFile ]
then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] (64) Configuration file missing, please run setup.sh" >> $logFile
  exit 64
else
  source $confFile
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] (00) Configuration file loaded sucessfully, $confFile" >> $logFile
fi


## CHECK FOR NETWORK CONNECTIVTY
ping -c 1 $defGW >/dev/null 2>&1;
pingExit=$?
if [ $pingExit -eq 0 ]
then
   echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] (00) Default gateway available, $defGW" >> $logFile
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] (64) Default gateway is unreachable, $defGW" >> $logFile
  exit 64
fi


# DOWNLOAD CRL(s)
for i in "${crlURL[@]}"
do
  curl -k -s $i > $downloadDIR${crlName[$counterA]}
  if [ ! -e $downloadDIR${crlName[$counterA]} ]
  then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] (64) crl download failed, $i" >> $logFile
  else 
    if [ -s $downloadDIR${crlName[$counterA]} ]
    then
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] (00) crl download sucessful, $i" >> $logFile
      mv $downloadDIR${crlName[$counterA]} $publicWWW
    else
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] (64) crl download failed (zero-byte file), $i" >> $logFile
    fi
  fi
let counterA=counterA+1
done

exit 0