#!/usr/bin/env bash

## gitbot.sh
## Automates common Git functions.
## Tony Cavella (tony@cavella.com)
## https://github.com/tonycavella/gitbot

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
#ver=`cat ${__dir}/VERSION`
dtg=`date '+%Y-%m-%d %H:%M:%S'`
dtgFile=`date '+%Y%m%d_%H%M%S'`
buildDir=${__dir}/periodic
sourceDir=/home/acavella/repo/revoke/
buildFilename=revoke-${dtgFile}.tar.gz


## LOAD CONFIGURATION
#confFile=${__dir}/conf/gb.conf
#source ${confFile}


## LOAD SOURCES
#source ${__dir}/bin/gb_nightly.sh


## GENERAL FUNCTIONS
if [ "${arg1}" == "--help" ]
then
  print_help
fi

if [ "${arg1}" == "--version" ]
then
  printf "build.sh/0.1\n"
fi

if [ "${arg1}" == "--status" ]
then
  print_status
fi


## MAIN FUNCTIONS
tar -czvf ${buildDir}/${buildFilename} ${sourceDir} --exclude "/home/acavella/repo/revoke/builds"

#build_nightly


exit 0
