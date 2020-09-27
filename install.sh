#!/usr/bin/env bash

# Revoke: CRL fetching and hosting made simple
# (c) 2018 - 2019 Tony Cavella (https://github.com/altCipher/revoke)
# A script to retrieve and host CRL files.
#
# Automatic install and configuration of Revoke.
#
# This file is copyright under the latest version of the GPLv3.
# Please see LICENSE file for your rights under this license.

# Install with this command (from your Linux machine):
#
# curl -sSL https://install.pi-hole.net | bash

# -e option instructs bash to immediately exit if any command [1] has a non-zero exit status
# -u option instructs bash to exit on unset variables (useful for debugging)
set -e
set -u

######## VARIABLES #########
# For better maintainability, we store as much information that can change in variables
# These variables should all be GLOBAL variables, written in CAPS
# Local variables will be in lowercase and will exist only within functions

# Base directories
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__bin="${__dir}/bin"
__conf="${__dir}/conf"

# Global variables
SCRIPT_VERSION="0.1"
INSTALL_CONFIG="${__conf}/install.conf"
INSTALL_DIR="/usr/local/bin/revoke"
DB_DIR="/usr/local/bin/revoke/db"
WWW_DIR="/var/www/revoke"
INSTALL_LOG="${INSTALL_DIR}/install.log"
DTG_PRINT=$(date '+%Y-%m-%d %H:%M:%S')
DTG_FILE=$(date '+%Y%m%d-%H%M%S')

SUPPORTED_OS=("Fedora" "CentOS")
REVOKE_DEPS=(sqlite curl openssl httpd) 

# Color Table
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

revoke // crl fetching and hosting made simple

Automated installation and configuration:"
}

is_command() {
    # Checks for existence of string passed in as only function argument.
    # Exit value of 0 when exists, 1 if not exists. Value is the result
    # of the `command` shell built-in call.
    local check_command="$1"

    command -v "${check_command}" >/dev/null 2>&1
}

get_IPv4_information() {
    # Detects IPv4 address used for communication to WAN addresses.
    # Accepts no arguments, returns no values.

    # Named, local variables
    local route
    local IPv4bare
    local str="Gathering IPv4 details"

    printf "  %b %s..." "${INFO}" "${str}"

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
    IPADDR=${IPV4_ADDRESS%%/*}
    CIDR=${IPV4_ADDRESS##*/}

    printf "%b  %b %s...\\n" "${OVER}" "${TICK}" "${str}"
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

create_db() {
    local str="Creating SQLite database and building table"
    # INITIALIZE DATABASE
    printf "  %b %s..." "${INFO}" "${str}"
    sqlite3 ${DB_DIR}/revoke.db <<'END_SQL'
        CREATE TABLE crlList (
        Row_ID integer PRIMARY KEY AUTOINCREMENT,
        CRL_Uri text,
        CRL_Name text,
        CRL_Hash text,
        CRL_Date text
        );
END_SQL
    printf "%b  %b %s...\\n" "${OVER}" "${TICK}" "${str}"
}

# Create required installation directories
create_install_directory() {
    # Local, named variables
    local str="Creating installation directories"
    printf "  %b %s..." "${INFO}" "${str}"
    install -d -m 755 ${INSTALL_DIR}
    mkdir -p ${INSTALL_DIR}/{conf,db}
    printf "%b  %b %s...\\n" "${OVER}" "${TICK}" "${str}"
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

check_os() {
    # Check for /etc/os-release
    local rel="/etc/os-release"
    if [ -f ${rel} ]; then
        # Set OS values from /etc/os-release
        detected_os_pretty=$(cat ${rel} | grep PRETTY_NAME | cut -d '=' -f2- | tr -d '"') # Full OS name with version
        detectedOS="${detected_os_pretty%% *}" # OS name only
        detected_version=$(cat ${rel} | grep VERSION_ID | cut -d '=' -f2- | tr -d '"') # OS version number
    # Recommend manual installation if os can't be determined
    else
        printf "  %b %bUnable to locate: %s%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${rel}" "${COL_NC}"
        printf "      Please refer to manual installaltion, insructrions\\n"
        printf "      can be found at the following link:\\n"
        printf "      https://github.com/altcipher/revoke/readme.md\\n"
        printf "\\n"
        exit 1
    fi

    # Iterate through suppported OS array
    supported_os_detected=0
    for i in ${SUPPORTED_OS[@]}; do 
        if [ "$detectedOS" = "$i" ]; then
            supported_os_detected=1 # Set to 1 if a match is found in supported OS array
        fi
    done
    
    # Supported OS resulting action
    if [ ${supported_os_detected} = "1" ]; then
        # Notify of supported OS and continue
        printf "  %b Supported OS detected\\n" "${TICK}"
    else
        # Notify of unsupported OS and exit
        printf "  %b %bUnsupported OS detected: %s%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${detected_os_pretty}" "${COL_NC}"
        exit 1
    fi    
}

get_package_manager() {

    # Check for common package managers per OS
    if [ "$detectedOS" = "Fedora" ] || [ "$detectedOS" = "CentOS" ]; then
        if is_command dnf ; then
            PKG_MGR="dnf" # set to dnf
            printf "  %b Package manager: %s\\n" "${TICK}" "${PKG_MGR}"
        elif is_command yum ; then
            PKG_MGR="yum" # set to yum
            printf "  %b Package manager: %s\\n" "${TICK}" "${PKG_MGR}"
        else
            # unable to detect a common yum based package manager
            printf "  %b %bSupported package manager not found%b\\n" "${CROSS}" "${COL_LIGHT_RED}" "${COL_NC}"
        fi
    fi

}

make_temporary_log() {
    # Create a random temporary file for the log
    TEMPLOG=$(mktemp /tmp/revoke_temp.XXXXXX)
    # Open handle 3 for templog
    # https://stackoverflow.com/questions/18460186/writing-outputs-to-log-file-and-console
    exec 3>"$TEMPLOG"
    # Delete templog, but allow for addressing via file handle
    # This lets us write to the log without having a temporary file on the drive, which
    # is meant to be a security measure so there is not a lingering file on the drive during the install process
    rm "$TEMPLOG"
}

copy_to_install_log() {
    # Copy the contents of file descriptor 3 into the install log
    # Since we use color codes such as '\e[1;33m', they should be removed
    sed 's/\[[0-9;]\{1,5\}m//g' < /proc/$$/fd/3 > "${INSTALL_LOG}"
    chmod 644 "${INSTALL_LOG}"
}

install_dependencies() {
    for i in "${REVOKE_DEPS[@]}"
    do
        if is_command ${i}; then
            printf "  %b Dependency found: %s\\n" "${TICK}" "${i}" 
        else
            local str="Installing dependency: ${i}"
            printf "  %b %s" "${INFO}" "${str}"
            ${PKG_MGR} install ${i} -y &> /dev/null
            if [ $? = 0 ]
            then
                printf "%b  %b %s\\n" "${OVER}" "${TICK}" "${str}"
            else
                printf "%b  %b %s\\n" "${OVER}" "${CROSS}" "${str}"
                printf "      Dependency install failed, exiting.\\n\\n"
                exit 1
            fi
        fi
    done
}

get_user_details() {
    local str="Collecting user feedback/variables"
    printf "  %b %s..." "${INFO}" "${str}"

    printf "%b  %b %s...\\n" "${OVER}" "${TICK}" "${str}"
}


main() {

    show_ascii_logo
    check_privilege
    check_os

    get_package_manager
    install_dependencies
    get_IPv4_information


    create_install_directory
    create_db


# Configure Apache HTTPD webserver
    # Install virtual host configuration
    {
        echo "<VirtualHost ${IPADDR}:80>"
        echo "ServerName "
        echo "DocumentRoot \"${WWW_DIR}\""
        echo "</VirtualHost>"
    }>/etc/httpd/conf.d/revoke.conf

    enable_service httpd
    restart_service httpd
}

main