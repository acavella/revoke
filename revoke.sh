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
lighttpdVer=$(lighttpd -v | awk '{print $2;}')
opensslVer=$(openssl version | awk '{print $2;}')

confFile="${__conf}/revoke.conf"
logFile="/var/log/revoke.log"
counterA=0
timeDate=$(date '+%Y-%m-%d %H:%M:%S')
fileDTG=$(date '+%Y%m%d-%H%M%S')
defGW=$(/usr/sbin/ip route show default | awk '/default/ {print $3}')

# FUNCTIONS
showVer () {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [version] revoke: ${ver}" 2>&1 | tee -a $logFile
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [version] lighttpd: ${lighttpdVer}" 2>&1 | tee -a $logFile
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [version] revoke: ${opensslVer}" 2>&1 | tee -a $logFile
}

showHelp () {
  echo "Add description of the script functions here."
  echo
  echo "Syntax: revoke [-h|v]"
  echo "options:"
  echo "-h        Print this Help."
  echo "-V        Verbose mode."
  echo "--add     Add new CRL to revoke database."
  echo "--list    List CRLs currently in revoke database."
  echo "--del     Remove CRL from revoke database."
  echo
}

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
  mkdir -p ${__www}/${crlName}  # Create CRL directory in __www
  curl -o ${__www}/${crlName}/${crlName}.crl -k -s ${crlUri}  # Download CRL
  validateCrl ${__www}/${crlName}/${crlName}.crl  # Validate CRL
  if [ $? -eq 0 ]
  then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] Unable to validate CRL, validate URL and try again." 2>&1 | tee -a $logFile
    rm -rf ${__www}/${crlName}
    exit 1
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Valid CRL found and added." 2>&1 | tee -a $logFile
    shaHash=$(sha1sum ${__www}/${crlName}/${crlName}.crl)  # Get initial CRL hash
    sqlite3 ${__db} "INSERT INTO crlList VALUES(NULL,'${crlUri}','${crlName}','${shaHash}');" # Add crlHash
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
    return 1 # true / CRL valid
  else
    return 0 # false / CRL invalid
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

if [ "${1}" == "--help" ] || [ "${1}" == "-h" ]
then
  showHelp
elif [ "${1}" == "--version"] || ["${1}" == "-V" ]
then
  showVer
else
  :
fi

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
crlHash=$(sqlite3 ${__db} "SELECT CRL_Hash FROM crlList;")

for row in "${rows[@]}"
do
  curl -k -s ${crlUri[$count]} > "/tmp/${crlName[$count]}.crl" # DOWNLOAD CRL TO TMP
  dlHash=$(sha1sum /tmp/${crlName[$count]}.crl) # GET TMP CRL HASH
  validateCrl /tmp/${crlName[$count]}.crl # VALIDATE CRL
  if [ $dlHash = ${crlHash[$count]} ] # COMPARE STORED AND DL HASH
  then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] CRL hash match, no new CRL data found." 2>&1 | tee -a $logFile
    rm -f /tmp/${crlName[$count]}.crl
  else
    sqlite3 ${__db} "UPDATE crlList SET CRL_Hash = '${dlHash}' WHERE Row_ID = $count;" 
  fi

  
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