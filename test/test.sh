#!/bin/bash


DEFAULT_ROUTE=$(ip route show default | awk '/default/ {print $3}')
ping -c 1 $DEFAULT_ROUTE >/dev/null 2>&1;
SUCCESS=$?

if [ $SUCCESS -eq 0 ]
then
  echo "$DEFAULT_ROUTE has replied"
else
  echo "$DEFAULT_ROUTE didn't reply"
fi
