#!/usr/bin/env bash

# NAME: install.sh
# DECRIPTION: Performs automated installation of revoke cdp
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

ver="0.1"
confFile="${__conf}/install.conf"
installDir="/usr/local/bin/revoke"
dbDir="/usr/local/bin/revoke/db"
wwwDir="/var/www/revoke"
logFile="${installDir}/install.log"
printDTG=$(date '+%Y-%m-%d %H:%M:%S')
fileDTG=$(date '+%Y%m%d-%H%M%S')



supportedOS=("Fedora" "CentOS")
REVOKE_DEPS=(sqlite3 curl openssl httpd) 
INSTALL_DEPS=(tar)
IPV4_ADDRESS=${IPV4_ADDRESS}

# COLOR TABLE
    COL_NC='\e[0m' # No Color
    COL_LIGHT_GREEN='\e[1;32m'
    COL_LIGHT_RED='\e[1;31m'
    TICK="[${COL_LIGHT_GREEN}✓${COL_NC}]"
    CROSS="[${COL_LIGHT_RED}✗${COL_NC}]"
    INFO="[i]"
    # shellcheck disable=SC2034
    DONE="${COL_LIGHT_GREEN} done!${COL_NC}"
    OVER="\\r\\033[K"

# Simple function to echo logo
show_ascii_logo() {
    echo -e "
    
            MMMMMMMMMMMMMMM             
         MMMMMMMMMMMMMMMM               
      .MMMMMMMI        .                
     MMMMMM                      ~MM    
   =MMMMM                       MMMMM,  
  DMMMM                       MMMMMM    
  MMMM                       MMMMM      
 MMMM                      MMMMMM       
MMMMM                    ~MMMMM         
MMMM                    MMMMMD          
MMMM      MMM         MMMMMM            
MMM~     MMMMM       MMMMM              
MMM~      MMMMMM   MMMMMM          =MMMI
MMMM        MMMMM=MMMMM            MMMM 
MMMM.        =MMMMMMM:             MMMM 
MMMMM          MMMMM              ,MMMM 
 MMMM            M                MMMM  
  MMMM                           MMMM   
  DMMMM                         MMMMD   
   =MMMMM                     MMMMM=    
     MMMMMM                 MMMMMM      
      .MMMMMMMI         :MMMMMMM.       
         MMMMMMMMMMMMMMMMMMMMM          
            MMMMMMMMMMMMMMM             
                . ?M?                 

revoke // simple crl fetching and hosting

"
}

is_command() {
    # Checks for existence of string passed in as only function argument.
    # Exit value of 0 when exists, 1 if not exists. Value is the result
    # of the `command` shell built-in call.
    local check_command="$1"

    command -v "${check_command}" >/dev/null 2>&1
}

find_IPv4_information() {
    # Detects IPv4 address used for communication to WAN addresses.
    # Accepts no arguments, returns no values.

    # Named, local variables
    local route
    local IPv4bare

    # Find IP used to route to outside world by checking the the route to Google's public DNS server
    route=$(ip route get 8.8.8.8)

    # Get just the interface IPv4 address
    # shellcheck disable=SC2059,SC2086
    # disabled as we intentionally want to split on whitespace and have printf populate
    # the variable with just the first field.
    printf -v IPv4bare "$(printf ${route#*src })"
    # Get the default gateway IPv4 address (the way to reach the Internet)
    # shellcheck disable=SC2059,SC2086
    printf -v IPv4gw "$(printf ${route#*via })"

    if ! valid_ip "${IPv4bare}" ; then
        IPv4bare="127.0.0.1"
    fi

    # Append the CIDR notation to the IP address, if valid_ip fails this should return 127.0.0.1/8
    IPV4_ADDRESS=$(ip -oneline -family inet address show | grep "${IPv4bare}/" |  awk '{print $4}' | awk 'END {print}')
}

valid_ip() {
    # Local, named variables
    local ip=${1}
    local stat=1

    # One IPv4 element is 8bit: 0 - 256
    local ipv4elem="(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9][0-9]?|0)";
    # optional port number starting '#' with range of 1-65536
    local portelem="(#([1-9]|[1-8][0-9]|9[0-9]|[1-8][0-9]{2}|9[0-8][0-9]|99[0-9]|[1-8][0-9]{3}|9[0-8][0-9]{2}|99[0-8][0-9]|999[0-9]|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-6]))?"
    # build a full regex string from the above parts
    local regex="^${ipv4elem}\.${ipv4elem}\.${ipv4elem}\.${ipv4elem}${portelem}$"

    [[ $ip =~ ${regex} ]]

    stat=$?
    # Return the exit code
    return "${stat}"
}

# Enable service so that it will start with next reboot
enable_service() {
    # Local, named variables
    local str="Enabling ${1} service to start on reboot"
    printf "  %b %s..." "${INFO}" "${str}"
    # If systemctl exists,
    if is_command systemctl ; then
        # use that to enable the service
        systemctl enable "${1}" &> /dev/null
    # Otherwise,
    else
        # use update-rc.d to accomplish this
        update-rc.d "${1}" defaults &> /dev/null
    fi
    printf "%b  %b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

# Start/Restart service passed in as argument
restart_service() {
    # Local, named variables
    local str="Restarting ${1} service"
    printf "  %b %s..." "${INFO}" "${str}"
    # If systemctl exists,
    if is_command systemctl ; then
        # use that to restart the service
        systemctl restart "${1}" &> /dev/null
    # Otherwise,
    else
        # fall back to the service command
        service "${1}" restart &> /dev/null
    fi
    printf "%b  %b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

check_privilege() {
    # Must be root to install
    local str="Root user check"
    printf "\\n"

    # If the user's id is zero,
    if [[ "${EUID}" -eq 0 ]]; then
        # they are root and all is good
        printf "  %b %s\\n" "${TICK}" "${str}"     
    # Otherwise,
    else
        # They do not have enough privileges, so let the user know
        printf "  %b %s\\n" "${CROSS}" "${str}"
        printf "  %b %bScript called with non-root privileges%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "      Revoke requires elevated privileges to install and run\\n\\n"
    fi
}

find_os() {
    # Check for /etc/os-release
    local rel="/etc/os-release"
    if [ -f ${rel} ]; then
        :
    # Recommend manual installation if os can't be determined
    else
        printf "  %b %bUnable to locate: %s%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${rel}" "${COL_NC}"
        printf "      Please refer to manual installaltion, insructrions\\n"
        printf "      can be found at the following link:\\n"
        printf "      https://github.com/altcipher/revoke/readme.md\\n"
        printf "\\n"
        exit 1
    fi

    detected_os_pretty=$(cat ${rel} | grep PRETTY_NAME | cut -d '=' -f2- | tr -d '"')
    detectedOS="${detected_os_pretty%% *}"
    detected_version=$(cat ${rel} | grep VERSION_ID | cut -d '=' -f2- | tr -d '"')

    for i in ${supportedOS[@]}; do 
        if [ "$detectedOS" = "$i" ]; then
            printf "  %b %bSupported OS detected%b\\n" "${TICK}" "${COL_LIGHT_GREEN}" "${COL_NC}"
        else
            printf "  %b %bUnsupported OS detected: %s%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${detected_os_pretty}" "${COL_NC}"
            exit 1
        fi
    done
}

main() {

    show_ascii_logo
    check_privilege

# CREATE DIRECTORIES
mkdir -p ${installDir}
mkdir -p ${installDir}/{conf,db}

# SCRIPT STARTUP
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Automated Installer v$ver" 2>&1 | tee -a $logFile
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Installing: revoke" 2>&1 | tee -a $logFile

# GET NETWORK DETAILS
find_IPv4_information
IPADDR=${IPV4_ADDRESS%%/*}
CIDR=${IPV4_ADDRESS##*/}



# PACKAGE MANAGER CHECK
if [ "$detectedOS" = "Fedora" ] || [ "$detectedOS" = "CentOS" ]; then
    if is_command dnf ; then
        PKG_MANAGER="dnf"
    else
        PKG_MANAGER="yum"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Package Manager detected: $PKG_MANAGER" 2>&1 | tee -a $logFile
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] Unable to detect appropriate package manager." 2>&1 | tee -a $logFile
fi

# DEPENDENCY CHECK
for i in "${REVOKE_DEPS[@]}"
do
    if is_command ${i}; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Dependency satisfied: ${i}" 2>&1 | tee -a $logFile
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Installing dependency: ${i}" 2>&1 | tee -a $logFile
        ${PKG_MANAGER} install ${i} -y &> /dev/null
        if [ $? = 0 ]
        then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Dependency installed: ${i}" 2>&1 | tee -a $logFile
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] [error] Unable to install dependency: ${i}" 2>&1 | tee -a $logFile
        fi
    fi
done

# INITIALIZE DATABASE
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Initializing SQLite database." 2>&1 | tee -a $logFile
sqlite3 ${dbDir}/revoke.db <<'END_SQL'
CREATE TABLE crlList (
        Row_ID integer PRIMARY KEY AUTOINCREMENT,
        CRL_Uri text,
        CRL_Name text,
        CRL_Hash text,
        CRL_Date text
);
END_SQL
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [info] Database initialization completed." 2>&1 | tee -a $logFile

# Configure Apache HTTPD webserver
    # Install virtual host configuration
    {
        echo "<VirtualHost ${IPADDR}:80>"
        echo "ServerName "
        echo "DocumentRoot \"${wwwDir}\""
        echo "</VirtualHost>"
    }>/etc/httpd/conf.d/revoke.conf

    enable_service httpd
    restart_service httpd
}