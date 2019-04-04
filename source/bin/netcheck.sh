## CHECK FOR NETWORK CONNECTIVTY
defGW=$(ip route show default | awk '/default/ {print $3}')

ping -c 1 $defGW >/dev/null 2>&1;

if [ $? -eq 0 ]
then
   echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] (00) Default gateway available, $defGW" >> $logFile
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] (64) Default gateway is unreachable, $defGW" >> $logFile
  exit 1
fi

