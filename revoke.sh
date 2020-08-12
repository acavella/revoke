#!/usr/bin/env bash

# NAME: revoke.sh
# DECRIPTION: Perform downloads of remote CRL data and host them locally via HTTPD.
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
__db="${__dir}/db/revoke.db"
__www="/var/www/revoke"

ver=$(<VERSION)
scriptName=$0

confFile="${__conf}/revoke.conf"
logFile="/var/log/revoke.log"
counterA=0
timeDate=$(date '+%Y-%m-%d %H:%M:%S')
fileDTG=$(date '+%Y%m%d-%H%M%S')
defGW=$(/usr/sbin/ip route show default | awk '/default/ {print $3}')

# FUNCTIONS
checkHash () {
  hash1=$(sha1sum $1 | awk '{print $1;}')
  hash2=$(sha1sum $2 | awk '{print $1;}')
        
  if [ $hash1 = $hash2 ] 
  then
    return 1 # true
  else
    return 0 # false
  fi
}

addCrl () { 
  read -p "Enter revocation list Uri (Example: https://crl.pki.goog/gtsr1/gtsr1.crl): " crlUri
  read -p "Enter revocation list short name (Example: GTRS1): " crlName
  # Create CRL directory in __www
  # Download CRL
  # Validate CRL
  # Get initial CRL hash
  sqlite3 ${__db} "INSERT INTO crlList VALUES(NULL,'${crlUri}','${crlName}');" # Add crlHash
}

showCrl () {
  sqlite3 ${__db} -header -column "SELECT * FROM crlList;"
}

remCrl () {
  read -p "Enter ROW_ID to remove: " remSelection
  sqlite3 ${__db} "DELETE FROM crlList WHERE ROW_ID = '${remSelection}';"
}

validateCrl () {
  ## Dirty check for PEM vs DER
  cat ${1} | grep "Begin X509 CRL"

  ## Read CRL with OpenSSL
  if [ $? -eq 0 ] 
  then
    openssl crl -text -noout -in ${1} | grep "Certificate Revocation List" &> /dev/null
  else
    openssl crl -inform DER -text -noout -in ${1} | grep "Certificate Revocation List" &> /dev/null
  fi

  ## Return validation
  if [ $? -eq 0 ] 
  then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Valid CRL found, ${1}" 2>&1 | tee -a $logFile
    return 1 # true / CRL valid
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] Invalid CRL file, ${1}" 2>&1 | tee -a $logFile
    return 0 # false / CRL invalid
    exit 1
  fi
}

validateConn () {
  ## Attempt to ping default gateway
  ping -c 1 $defGW &> /dev/null

  ## Continue if success, exit if fail
  if [ $? -eq 0 ]
  then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Default gateway available, $defGW" 2>&1 | tee -a $logFile
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] Default gateway is unreachable, $defGW" 2>&1 | tee -a $logFile
    exit 1
  fi
}

# SCRIPT STARTUP
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] revoke v$ver" 2>&1 | tee -a $logFile

# CONFIGURATION AND CLI INPUT 


# CHECK AND LOAD EXTERNAL CONFIG
if [ ! -e $confFile ]
then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] Unabled to locate configuration, exiting." 2>&1 | tee -a $logFile
  exit 1
else
  source $confFile
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Configuration loaded, $confFile." 2>&1 | tee -a $logFile
fi

# CHECK FOR NETWORK CONNECTIVTY
validateConn

# DOWNLOAD CRL(s)
count="1"

rows=$(sqlite3 ${__db} "SELECT Row_ID FROM crlList;")
crlUri=$(sqlite3 ${__db} "SELECT CRL_Uri FROM crlList;")
crlName=$(sqlite3 ${__db} "SELECT CRL_Name FROM crlList;")

for row in "${rows[@]}"
do
  curl -k -s ${crlUri[$count]} > "/tmp/${crlName[$count]}"

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
