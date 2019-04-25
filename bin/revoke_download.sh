countB=1

while [ $countB -le  ${#crlURL[@]} ]
do
  curl -k ${crlURL[${countB}]} -o ${__crl}/${crlFN[${countB}]}
  countB=$((countB+1))
fi
