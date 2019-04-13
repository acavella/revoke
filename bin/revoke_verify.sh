verify_module() {

rpm -q curl
if [ ${?} -eq 1 ] 
then
  printf "curl is not available\n"
  exit 1
else
  printf "curl is installed\n"
fi

}
