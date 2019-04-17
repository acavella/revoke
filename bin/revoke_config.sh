init_config() {

confCOUNT=1

printf "Please enter the URL of the CRL: "
read crlURL[1] 

printf "Please enter a name for this file: "
read crlFN[1]

echo ${#crlURL[@]}
echo ${crlURL[1]} > ${__conf}/revoke.conf
echo ${crlFN[1]} >> ${__conf}/revoke.conf
}
