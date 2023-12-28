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

baseDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
dtg=$(date '+%Y%m%d-%H%M%S')
config="${baseDir}/conf/revoke.yml"
log="${baseDir}/logs/revoke_${dtg}.log"
wwwdir=$(./lib/yq4 -r .default.www ${config})
arraySize=$(./lib/yq4 '.ca | length' ${config})
defgw=$(./lib/yq4 -r .default.gateway ${config})

## FUNCTIONS

show_version() {
    printf "$(date '+%Y-%m-%dT%H:%M:%S') [info] Revoke version: ${ver}\n"
    printf "$(date '+%Y-%m-%dT%H:%M:%S') [info] Bash version: ${BASH_VERSION}\n"
    printf "$(date '+%Y-%m-%dT%H:%M:%S') [info] Operating system: ${DETECTED_OS}\n"
}

make_temporary_log() {
    # Create a random temporary file for the log
    TEMPLOG=$(mktemp /tmp/revoke_temp.XXXXXX)
    # Open handle 3 for templog
    exec 3>${TEMPLOG}
    # Delete templog, but allow for addressing via file handle
    rm ${TEMPLOG}
}

copy_to_run_log() {
    # Copy the contents of file descriptor 3 into the log
    cat /proc/$$/fd/3 > "${log}"
    chmod 644 "${log}"
}

check_config() {
  if [ ! -e $config ]
  then
    printf "$(date '+%Y-%m-%dT%H:%M:%S') [error] unable to locate configuration ${config}\n"
    exit 1
  fi
}

check_network() {
  ping -c 1 $defgw >/dev/null 2>&1;
  pingExit=$?
  if [ $pingExit -eq 0 ]
  then
    printf "$(date '+%Y-%m-%dT%H:%M:%S') [info] received ping response from ${defgw}\n"
  else
    printf "$(date '+%Y-%m-%dT%H:%M:%S') [error] ping response not received from ${defgw}\n"
    exit 1
  fi
}


fix_permissions() {
  printf "$(date '+%Y-%m-%dT%H:%M:%S') [info] fixing permissions on ${wwwdir}\n"
  chown apache:apache ${wwwdir} -R
  restorecon -r ${wwwdir}
}

download_crl() {
  local counterA=0
  while [ ${counterA} -lt ${arraySize} ]
  do
    local crlSource=$(./lib/yq4 -r .ca[${counterA}].uri ${config})
    local crlID=$(./lib/yq4 -r .ca[${counterA}].id ${config})
    local tempfile=$(mktemp)
    printf "$(date '+%Y-%m-%dT%H:%M:%S') [info] downloading ${crlID} source ${crlSource}\n"
    curl -k -s ${crlSource} > ${tempfile} ${crlID}
    if [ ! -e ${tempfile} ]
    then
      printf "$(date '+%Y-%m-%dT%H:%M:%S') [error] download failed ${crlID} missing ${tempfile}\n"
      exit 1
    fi
    if [ ! -s ${tempfile} ]
    then
      printf "$(date '+%Y-%m-%dT%H:%M:%S') [error] download failed ${crlID} zero byte file ${tempfile}\n"
      exit 1
    fi
    openssl crl -inform DER -text -noout -in ${tempfile} | grep 'Certificate Revocation List' &> /dev/null
    if [ $? == 1 ]
    then
      printf "$(date '+%Y-%m-%dT%H:%M:%S') [error] download failed ${crlID} invalid crl ${tempfile}\n"
      exit 1
    fi
    printf "$(date '+%Y-%m-%dT%H:%M:%S') [info] copying ${tempfile} to ${wwwdir}/${crlID}.crl\n"
    mv ${tempfile} ${wwwdir}/${crlID}.crl
    let counterA=counterA+1
  done
}

main() {
  show_version
  check_config
  check_network
  download_crl
  fix_permissions
}

make_temporary_log
main | tee -a /proc/$$/fd/3
copy_to_run_log
exit 0
