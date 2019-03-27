#!/bin/bash

# NAME: revoke.sh
# DECRIPTION: Perform downloads of remote CRL data and host them locally via HTTPD.
# AUTHOR: Tony Cavella (tony@cavella.com)
# VERSION: 1.0
# UPDATED: 2018-06-21

# SCRIPT VARIABLES
scriptName=$0
scriptVersion="0.4.0"
baseDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
confFile="$baseDIR""/conf/revoke.conf"
logFile="$baseDIR""/log/revoke.log"
counterA=0
timeDate=$(date '+%Y-%m-%d %H:%M:%S')
fileDTG=$(date '+%Y%m%d-%H%M%S')


# SCRIPT STARTUP
echo "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *"
echo "*  Script Name: REVOKE                                      *"
echo "*  Version: 0.4.0                                           *"
echo "*  Build Date: 2018-06-22                                   *"
echo "*  Author: Tony Cavella (tony@cavella.com)                  *"
echo "*                                                           *"
echo "*  Description:                                             *"
echo "*   Downloads remotely hosted CRL data and moves it to a    *"
echo "*   local hosting directory. Script is executed via chron.  *"
echo "*                                                           *"
echo "* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] (00) REVOKE/0.4.0 started normal" | tee -a $logFile


# CHECK AND LOAD EXTERNAL CONFIG
if [ ! -e $confFile ]
then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] (64) Configuration file missing, please run setup.sh" | tee -a $logFile
  exit 64
else
  source $confFile
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] (00) Configuration file loaded sucessfully, $confFile" | tee -a $logFile
fi


# CHECK FOR VALID CONNECTION
if  curl -f -k $validationURL >/dev/null 2>&1; 
then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] (00) validation URL successful, $validationURL" | tee -a $logFile
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] (64) validation URL unreachable, $validationURL" | tee -a $logFile
  exit 64
fi


# DOWNLOAD CRL(s)
for i in "${crlURL[@]}"
do
  curl -k -s $i > $downloadDIR${crlName[$counterA]}
  if [ ! -e $downloadDIR${crlName[$counterA]} ]
  then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] (64) crl download failed, $i" | tee -a $logFile
    exit 64
  else 
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] (00) crl download sucessful, $i" | tee -a $logFile
  fi
  let counterA=counterA+1
done


# MOVE CRL(s) FROM /TMP TO PUBLIC HTML DIRECTORY
for i in "${crlName[@]}"
do
  mv $downloadDIR$i $publicWWW
done
exit 0
