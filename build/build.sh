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
buildName=revoke-${dtgFile}
tmpBuild=/tmp/${buildName}


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
mkdir ${tmpBuild}

rsync -av --progress ${sourceDir} ${tmpBuild} --exclude build --exclude .github --exclude install --exclude .gitignore --exclude .git

tar -C /tmp  -czvf ${buildDir}/${buildName}.tar.gz ${buildName}

rm -rf ${tmpBuild}

## UPDATE GITHUB
git add ${buildDir}/${buildName}.tar.gz
git commit -a -m "Added build ${buildName}"
git push


exit 0
