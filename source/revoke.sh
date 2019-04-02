#!/bin/bash

# NAME: revoke.sh
# DECRIPTION: Perform downloads of remote CRL data and host them locally via HTTPD.
# AUTHOR: Tony Cavella (tony@cavella.com)
# VERSION: 0.2.0-alpha
# UPDATED: 2019-03-30

# SCRIPT VARIABLES
scriptName=$0
scriptVersion="0.2.0-alpha"
baseDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
confFile="$baseDIR""/conf/revoke.conf"
logFile="/var/log/revoke.log"
counterA=0
timeDate=$(date '+%Y-%m-%d %H:%M:%S')
fileDTG=$(date '+%Y%m%d-%H%M%S')
defGW=$(ip route show default | awk '/default/ {print $3}')

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
    exit 64
  else 
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] (00) crl download sucessful, $i" >> $logFile
  fi
  openssl crl -inform DER -text -noout -in $downloadDIR${crlName[$counterA]} | grep 'Certificate Revocation List' &> /dev/null
  if [ $? == 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] (00) crl $crlName[$counterA] format valid, copying" >> $logFile
    mv $downloadDIR${crlName[$counterA]} $publicWWW
  else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] (64) crl $crlName[$counterA] format invalid, skipping" >> $logFile
  fi
  let counterA=counterA+1
done


# MOVE CRL(s) FROM /TMP TO PUBLIC HTML DIRECTORY
#for i in "${crlName[@]}"
#do
#  mv $downloadDIR$i $publicWWW
#done
exit 0
