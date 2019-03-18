#!/bin/bash

# Functions first.
set_evault_install_variables()
{

  EXEC_DIRECTORY=`pwd`
  EVAULT_WEBCC_PORT="8086"
  EVAULT_INSTALL_DIR="/root/evault"
  EVAULT_ANSWER_FILE="answers.txt"
  EVAULT_INSTALL_LOCATION="/opt/BUAgent"
	detect_institution

  # OS specific variables.
  if [ -e /etc/redhat-release ] ; then
    echo "Red Hat based distribution detected..."
    OS_VENDOR=`awk '{print $1}' /etc/redhat-release | tr [a-z] [A-Z]`
    if [ ${OS_VENDOR} = "RED" ]; then
          OS_VENDOR="REDHAT"
    fi
    OS_VERSION=`sed -n -e 's/(.*)//' -e 's/^.*release //p' /etc/redhat-release`
    OS_VERSION_MAJOR=`echo ${OS_VERSION} | cut -d. -f1`
    OS_VERSION_MINOR=`echo ${OS_VERSION} | cut -d. -f2`
    OS_INSTALL_TOOL="/usr/bin/yum -y install"
    set_evault_version "Agent-Linux-8.11.5251"
  elif [ -e /usr/bin/lsb_release ] ; then
    echo "Debian based distribution detected..."
    OS_VENDOR=`lsb_release -si | tr '[a-z]' '[A-Z]'`
    OS_VERSION_MAJOR=`lsb_release -sr | cut -d. -f1`
    OS_VERSION_MINOR=`lsb_release -sr | cut -d. -f2`
    OS_INSTALL_TOOL="apt-get -y install"
    set_evault_version "Agent-Linux-8.11.5251"
  fi
}

# Takes argument to set appropriate EVault variables per arch.
set_evault_version()
{
  if [ `uname -m` = "x86_64" ] ; then
    OS_ARCH="64"
  else
    OS_ARCH="32"
  fi

  if [ "${OS_ARCH}" = "32" ] ; then
    EVAULT_UNTAR_DIR="${1}"
    EVAULT_AGENT="${EVAULT_UNTAR_DIR}-i686.tar.gz"
  elif [ "${OS_ARCH}" = "64" ] ; then
    EVAULT_UNTAR_DIR="${1}"
    EVAULT_AGENT="${EVAULT_UNTAR_DIR}-x64.tar.gz"
  else
    echo "Could not detect OS_ARCH."
    exit 1
  fi
}

detect_institution() {
 if ping -c 1 webcc.service.usgov.softlayer.com ; then
   DOWNLOAD_HOST="downloads.service.usgov.softlayer.com/evault/"
   EVAULT_WEBCC_HOST="webcc.service.usgov.softlayer.com"
 elif ping -c 1 ev-webcc01.service.softlayer.com ; then
   DOWNLOAD_HOST="downloads.service.softlayer.com/evault/"
   EVAULT_WEBCC_HOST="ev-webcc01.service.softlayer.com"
 else
   echo "Could not reach EVault WebCC!"
   exit 1
 fi
}

# Request WebCC credentials
evault_request_credentials () {
  echo
  echo
  echo -n "Please supply the WebCC username for this server: "
  read EVAULT_WEBCC_USER
  if [ -z "${EVAULT_WEBCC_USER}" ]
    then
      echo
      echo "Exiting, Username was empty!"
      echo
      exit 1
    else
     if `echo ${EVAULT_WEBCC_USER} | grep -iq -- -m`
       then
         echo
         echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
         echo "!! It appears that you are trying to register this agent with the !!"
         echo "!! master WebCC user. Please use the WebCC user associated with   !!"
         echo "!! this hardware. The user name should end with -X where X is a   !!"
         echo "!! number and not M.                                              !!"
         echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
         echo
         exit 1
     fi
  fi

  echo
  echo -n "Please supply the WebCC password for this server: "
  read EVAULT_WEBCC_PASS
  if [ -z "${EVAULT_WEBCC_PASS}" ]
   then
    echo
    echo "Exiting. Password was empty!"
    echo
    exit 1
  fi
}

install_dependencies()
{
  EVAULT_APT_PKGS="libstdc++6 libacl1 libattr1"
  EVAULT_YUM_PKGS="libstdc++ libacl libacl-devel libattr libattr-devel libgcc"

  if [ "${OS_VENDOR}" = "REDHAT" ] || [ "${OS_VENDOR}" = "CENTOS" ] ; then
    ${OS_INSTALL_TOOL} ${EVAULT_YUM_PKGS}
    if [ $? -ne 0 ] ; then
      echo "Failed to install the required dependencies for EVault."
      exit 1
    fi
  elif [ "${OS_VENDOR}" = "UBUNTU" ] || [ "${OS_VENDOR}" = "DEBIAN" ] ; then
    ${OS_INSTALL_TOOL} ${EVAULT_APT_PKGS}
    if [ $? -ne 0 ] ; then
      echo "Failed to install the required dependencies for EVault."
      exit 1
    fi
  fi
}

download_evault()
{
  echo "Downloading EVault..."
  mkdir -p ${EVAULT_INSTALL_DIR}
  cd ${EVAULT_INSTALL_DIR}
  wget http://${DOWNLOAD_HOST}${EVAULT_AGENT}
  if [ $? -ne 0 ] ; then
    echo "Failed to download EVault software."
    exit 1
  fi

  if [ -s "${EVAULT_INSTALL_DIR}/${EVAULT_AGENT}" ] ; then
    mkdir ${EVAULT_UNTAR_DIR}
    tar -zxf ${EVAULT_AGENT} -C ${EVAULT_UNTAR_DIR} --strip-components=1
    if [ $? -ne 0 ] || [ ! -d "${EVAULT_INSTALL_DIR}/${EVAULT_UNTAR_DIR}" ] ; then
      echo "Failed to extract EVault software."
      exit 1
    fi
  fi
}

evault_create_answers()
{
  echo "Creating modern EVault answers file..."
  echo "${EVAULT_INSTALL_LOCATION}" > ${EVAULT_INSTALL_DIR}/${EVAULT_ANSWER_FILE}
  echo "y" >> ${EVAULT_INSTALL_DIR}/${EVAULT_ANSWER_FILE}
  echo "en-US" >> ${EVAULT_INSTALL_DIR}/${EVAULT_ANSWER_FILE}
  echo "y" >> ${EVAULT_INSTALL_DIR}/${EVAULT_ANSWER_FILE}
  echo "${EVAULT_WEBCC_HOST}" >> ${EVAULT_INSTALL_DIR}/${EVAULT_ANSWER_FILE}
  echo "${EVAULT_WEBCC_PORT}" >> ${EVAULT_INSTALL_DIR}/${EVAULT_ANSWER_FILE}
  echo "${EVAULT_WEBCC_USER}" >> ${EVAULT_INSTALL_DIR}/${EVAULT_ANSWER_FILE}
  echo "${EVAULT_WEBCC_PASS}" >> ${EVAULT_INSTALL_DIR}/${EVAULT_ANSWER_FILE}
  echo "A" >> ${EVAULT_INSTALL_DIR}/${EVAULT_ANSWER_FILE}
}

evault_install()
{
  echo "Installing modern EVault..."
  cd ${EVAULT_INSTALL_DIR}/${EVAULT_UNTAR_DIR}
  ./install.sh < ${EVAULT_INSTALL_DIR}/${EVAULT_ANSWER_FILE}
  if [ $? -ne 0 ] ; then
    echo "Failed to install the modern EVault software."
  fi

  # Disable DirectConsole feature as it causes crashes.
  # Plus we don't use it for customers. We go through WebCC instead.
  sed -i 's!<agentdata:useDirectConsole.*!<agentdata:useDirectConsole>false</agentdata:useDirectConsole>!' ${EVAULT_INSTALL_LOCATION}/buagent.cfg
  echo "Issuing a restart of the EVault daemon in the background..."
  /etc/init.d/vvagent restart &
}


evault_cleanup()
{
  echo "EVault installation cleanup..."
  if [ -d "${EVAULT_INSTALL_DIR}" ] ; then
    rm -rf ${EVAULT_INSTALL_DIR}
  fi
  if [ -f "${EVAULT_INSTALL_DIR}/${EVAULT_AGENT}" ] ; then
    rm -rf ${EVAULT_INSTALL_DIR}/${EVAULT_AGENT}
  fi
}

rhel_based_install()
{
  echo "Starting Red Hat based installation..."
  set_evault_install_variables
  install_dependencies
  download_evault
  evault_create_answers
  evault_install
  evault_cleanup
}

debian_based_install()
{
  echo "Debian based installation..."
  set_evault_install_variables
  install_dependencies
  download_evault
  evault_create_answers
  evault_install
  evault_cleanup
}

# Begin

# Don't depend on the user's PATH to be sane.
PATH="/usr/kerberos/sbin:/usr/kerberos/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin"


# Check that we are root ... so non-root users stop here
if [ `id -u` != 0 ]
  then
    echo
    echo "This script must be run as root."
    echo
    exit 1
fi


# Make sure we are running on a Linux os.
if [ `uname -s` != "Linux" ]
  then
    echo
    echo "This script is currently only supported on Linux"
    echo
    exit 1
fi

set_evault_install_variables
evault_request_credentials
case "${OS_VENDOR}" in
  REDHAT|CENTOS)
    rhel_based_install
    ;;
  UBUNTU|DEBIAN)
    debian_based_install
    ;;
  *)
    echo "EVault not supported on this OS."
    ;;
esac
