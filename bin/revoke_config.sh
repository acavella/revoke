init_config() {

countA=2

echo "# This file is auto-generated." > ${__conf}/revoke.conf
echo "# User changes will be destroyed the next time revoke --config is run." >> ${__conf}/revoke.conf
echo "configStatus=TRUE" >> ${__conf}/revoke.conf

printf "URL to download CRL: "
read urlIN 

printf "Name of saved CRL file: "
read crlIN

#echo ${#crlURL[@]}
echo "crlURL[1]=${urlIN}" >> ${__conf}/revoke.conf
echo "crlFN[1]=${crlIN}" >> ${__conf}/revoke.conf

printf "Do you have another CRL to enter? (y/n): "
read contIN

while [ ${contIN} = y ]
do
  printf "URL to download CRL: "
  read urlIN

  printf "Name of saved CRL file: "
  read crlIN

  echo "crlURL[${countA}]=${urlIN}" >> ${__conf}/revoke.conf
  echo "crlFN[${countA}]=${crlIN}" >> ${__conf}/revoke.conf

  countA=$((countA+1))

  printf "Do you have another CRL to enter? (y/n): "
  read contIN
done


}
