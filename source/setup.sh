#!/bin/bash

# NAME: setup.sh 
# DESCRIPTION: This script is a basic shell script used to install and configure a script using
# basic user input.  User input is defined as variables in a .conf file.  
# AUTHOR: Tony Cavella
# EMAIL: tony@cavella.com

scriptName=$0
setupVersion="0.1"

# SCRIPT STARTUP
echo "$scriptName Ver. $setupVersion"

# SETUP SPECIFIC VARIABLES
scriptUSER="acavella"
scriptDIR="/usr/local/bin/revoke/"

# ROOT User Check
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# CHECK FOR DEPENDENCIES AND INSTALL
if ! httpd --version; then 
  echo "HTTPD not installed, installing..."
  yum install httpd -y -q 
else
  echo "HTTPD installed"
fi

# COLLECT USER INPUT \\COMING SOON
# echo "Which user should REVOKE run as [pkiuser]:"
# read revokeUser
# if ! id $revokeUser; then
#   echo "$revokeUser does not exist, creating $revokeUser"
#   echo "Please enter a password for $revokeUser:"
#   read revokeUserPass 
#   useradd $revokeUser -p $revokeUserPass -G apache

# USER SETUP AND VALIDATION



# CREATE INSTALL DIRECTORY
mkdir -p $scriptDIR

# COPY REVOKE TO DIRECTORY
cp revoke.sh $scriptDIR
cp CHANGELOG $scriptDIR
cp README $scriptDIR
cp -r conf/ $scriptDIR
cp -r log/ $scriptDIR


# SET PERMISSIONS
chown $scriptUSER:$scriptUSER $scriptDIR -R
chmod 544 $scriptDIR
chmod 500 $scriptDIR/revoke.sh
chmod 444 $scriptDIR/CHANGELOG
chmod 444 $scriptDIR/README
chmod 500 $scriptDIR/conf
chmod 400 $scriptDIR/conf/revoke.conf
chmod 500 $scriptDIR/log
chmod 600 $scriptDIR/log/revoke.log

# CREATE HTTPD DIRECTORY AND SET PERMISSIONS
mkdir -p /var/www/revoke
chown apache:apache /var/www/revoke -R
chmod 775 /var/www/revoke -R


# INSTALL CRON JOB
crontab -u $scriptUser -l > setupfiles/revokecron
echo "*/15 * * * * /usr/local/bin/revoke/revoke.sh" >> setupfiles/revokecron
crontab -u $scriptUser setupfiles/revokecron

# INSTALL HTTPD VHOST
cp setupfiles/revokehttpd.conf /etc/httpd/conf.d/
