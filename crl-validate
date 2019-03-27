#!/bin/bash

openssl crl -inform DER -text -noout -in rootx1.crl | grep 'Certificate Revocation List' &> /dev/null
if [ $? == 0 ]; then
  echo "matched"
fi
