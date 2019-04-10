print_status () {

if [ ! -e $confFile ]
then
  printf "Configuration file is missing, please run ./revoke.sh --setup\n"
  exit 64
else
  source $confFile
  printf "Valid configuration file found\n"
fi

}
