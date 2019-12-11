#!/bin/bash
#
# version: 1.0.2
# date: 2019-12-10

### Colors ###
RED='\e[0;31m'
LTRED='\e[1;31m'
BLUE='\e[0;34m'
LTBLUE='\e[1;34m'
GREEN='\e[0;32m'
LTGREEN='\e[1;32m'
ORANGE='\e[0;33m'
YELLOW='\e[1;33m'
CYAN='\e[0;36m'
LTCYAN='\e[1;36m'
PURPLE='\e[0;35m'
LTPURPLE='\e[1;35m'
GRAY='\e[1;30m'
LTGRAY='\e[0;37m'
WHITE='\e[1;37m'
NC='\e[0m'
##############

TARGET_FILES_DIR="/targets"
IQN="iqn.$(date +%Y)-$(date +%m).local.iscsi"
SERVER_IQN="${IQN}.$(hostname -s)"

usage() {
  echo
  echo "USAGE: ${0} targetcli|tgt <target_name>[,<target_name>[,...]] [<initiator_hostname>[,<initiator_hostname>[,...]]"
  echo
}

if [ -z "${1}" ]
then
  echo
  echo -e "${LTRED}ERROR: You must provide the target daemon to use. (targetcli or tgt)${NC}"
  usage
  exit
else
  TARGET_DAEMON=${1}
fi

if [ -z "${2}" ]
then
  echo
  echo -e "${LTRED}ERROR: You must provide a comma delimited list of target names.${NC}"
  usage
  exit
else
  if echo ${2} | grep -q ","
  then
    TARGET_LIST=$(echo ${2} | sed 's/,/ /g')
  else
    TARGET_LIST=${2}
  fi
fi

case ${TARGET_DAEMON} in
  targetcli)
    if [ -z "${3}" ]
    then
      echo
      echo -e "${LTRED}ERROR: You must provide a comma delimited list of initiator hostnames.${NC}"
      usage
      exit
    else
      if echo ${3} | grep -q ","
      then
        INITIATOR_LIST=$(echo ${3} | sed 's/,/ /g')
      else
        INITIATOR_LIST=${3}
      fi
    fi
  ;;
esac

create_targetcli_luns() {
  echo -e "${LTBLUE}===============================================================================${NC}"
  echo -e "${LTBLUE}               Configuring iSCSI Target(s) with targetcli ...${NC}"
  echo -e "${LTBLUE}===============================================================================${NC}"
  echo -e "${LTCYAN}-Checking for required packages ...${NC}"

  if grep -qi suse /etc/os-release
  then
    if zypper se | grep "^i | targetcli "
    then
      echo -e "${LTCYAN}-Removing unrequired packages ...${NC}"
      echo -e "${GREEN}COMMAND: ${GRAY}sudo zypper -n remove lio-utils python-rtslib python-configshell targetcli${NC}"
      sudo zypper -n remove lio-utils python-rtslib python-configshell targetcli
      echo
    fi
  fi

  if grep -qi suse /etc/os-release
  then
    if ! zypper se "^i | targetcli-fb "
    then
      echo -e "${LTCYAN}-Installing required packages ...${NC}"
      echo -e "${GREEN}COMMAND: ${GRAY}sudo zypper -n ref${NC}"
      sudo zypper -n ref
      echo -e "${GREEN}COMMAND: ${GRAY}sudo zypper -n install targetcli-fb${NC}"
      sudo zypper -n install targetcli-fb
      echo
    fi
  fi

  echo -e "${GREEN}COMMAND: ${GRAY}sudo systemctl enable targetcli.service${NC}"
  sudo systemctl enable targetcli.service

  echo -e "${GREEN}COMMAND: ${GRAY}sudo systemctl start targetcli.service${NC}"
  sudo systemctl start targetcli.service

  if ! [ -e ${TARGET_FILES_DIR} ]
  then
    echo
    echo -e "${GREEN}COMMAND: ${GRAY}sudo mkdir -p ${TARGET_FILES_DIR}${NC}"
    sudo mkdir -p ${TARGET_FILES_DIR}
    echo
  fi

  for TARGET in ${TARGET_LIST}
  do
    echo -e "${LTCYAN}------------------------------------------------------------${NC}"
    echo -e "${LTCYAN}Target: ${GRAY} ${SERVER_IQN}:${TARGET}${NC}"
    echo -e "${LTCYAN}------------------------------------------------------------${NC}"
    echo -e "${GREEN}COMMAND: ${GRAY}sudo targetcli backstores/fileio create ${TARGET} ${TARGET_FILES_DIR}/${TARGET} 50M write_back=false${NC}"
    sudo targetcli backstores/fileio create ${TARGET} ${TARGET_FILES_DIR}/${TARGET} 50M write_back=false

    echo -e "${GREEN}COMMAND: ${GRAY}sudo targetcli iscsi/ create ${SERVER_IQN}:${TARGET}${NC}"
    sudo targetcli iscsi/ create ${SERVER_IQN}:${TARGET}

    echo -e "${GREEN}COMMAND: ${GRAY}sudo targetcli iscsi/${SERVER_IQN}:${TARGET}/tpg1/luns/ create /backstores/fileio/${TARGET}${NC}"
    sudo targetcli iscsi/${SERVER_IQN}:${TARGET}/tpg1/luns/ create /backstores/fileio/${TARGET}
 
    echo
    for INITIATOR in ${INITIATOR_LIST}
    do
      echo -e "${GREEN}COMMAND: ${GRAY}sudo targetcli iscsi/${SERVER_IQN}:${TARGET}/tpg1/acls/ create ${IQN}:${INITIATOR}${NC}"
      sudo targetcli iscsi/${SERVER_IQN}:${TARGET}/tpg1/acls/ create ${IQN}:${INITIATOR}
    done
    echo
  done

  echo -e "${GREEN}COMMAND: ${GRAY}sudo targetcli saveconfig${NC}"
  sudo targetcli saveconfig
  echo

  echo
  echo -e "${LTCYAN}------------------------------------------------------------${NC}"
  echo -e "${GREEN}COMMAND: ${GRAY}sudo targetcli ls${NC}"
  sudo targetcli ls
  echo
}

create_tgtd_luns() {
  echo -e "${LTBLUE}===============================================================================${NC}"
  echo -e "${LTBLUE}               Configuring iSCSI Target(s) with tgtd ...${NC}"
  echo -e "${LTBLUE}===============================================================================${NC}"
  echo -e "${LTCYAN}-Checking for required packages ...${NC}"

  if grep -qi suse /etc/os-release
  then
    if ! zypper se "^i | tgt  "
    then
      echo -e "${LTCYAN}-Installing required packages ...${NC}"
      echo -e "${GREEN}COMMAND: ${GRAY}sudo zypper -n ref${NC}"
      sudo zypper -n ref
      echo -e "${GREEN}COMMAND: ${GRAY}sudo zypper -n install tgt${NC}"
      sudo zypper -n install tgt
      echo
    fi
  fi

  if ! [ -e ${TARGET_FILES_DIR} ]
  then
    echo
    echo -e "${GREEN}COMMAND: ${GRAY}mkdir -p ${TARGET_FILES_DIR} ${NC}"
    mkdir -p ${TARGET_FILES_DIR} 
    echo
  fi

  for TARGET in ${TARGET_LIST}
  do
    echo -e "${LTCYAN}------------------------------------------------------------${NC}"
    echo -e "${LTCYAN}Target: ${GRAY} ${SERVER_IQN}:${TARGET}${NC}"
    echo -e "${LTCYAN}------------------------------------------------------------${NC}"
    echo -e "${GREEN}COMMAND: ${GRAY}tgtimg --op new --device-type disk --type disk --size 50 --file ${TARGET_FILES_DIR}/${TARGET}.raw${NC}"
    tgtimg --op new --device-type disk --type disk --size 50 --file ${TARGET_FILES_DIR}/${TARGET}.raw
    echo
 
    echo -e "${LTPURPLE}/etc/tgt/conf.d/${TARGET}.conf:${NC}
<target ${SERVER_IQN}:${TARGET}>
  backing-store ${TARGET_FILES_DIR}/${TARGET}.raw
</target>
  "
    echo "<target ${SERVER_IQN}:${TARGET}>
  backing-store ${TARGET_FILES_DIR}/${TARGET}.raw
</target>
  " >> /etc/tgt/conf.d/${TARGET}.conf
  echo
  done

  echo -e "${GREEN}COMMAND: ${GRAY}sudo systemctl enable tgtd.service${NC}"
  sudo systemctl enable tgtd.service

  echo -e "${GREEN}COMMAND: ${GRAY}sudo systemctl start tgtd.service${NC}"
  sudo systemctl start tgtd.service

  echo
  echo -e "${LTCYAN}------------------------------------------------------------${NC}"
  echo -e "${GREEN}COMMAND: ${GRAY}sudo tgtadm --lld iscsi --mode target --op show${NC}"
  sudo tgtadm --lld iscsi --mode target --op show
  echo
}

show_configure_initiators() {
  local SERVER_IP=$(ip addr show | grep "inet " | grep -v 127.* | head -1 | awk '{ print $2}' | cut -d \/ -f 1)

  echo
  echo -e "${LTBLUE}===============================================================================${NC}"
  echo -e "${LTBLUE}                                 Next Steps ...${NC}"
  echo -e "${LTBLUE}===============================================================================${NC}"
  echo
  case ${TARGET_DAEMON} in
    targetcli)
      echo -e "${ORANGE}-On each initiator, insure that the IQNs in ${LTPURPLE}/etc/iscsi/initiatorname.iscsi${NC}"
      echo -e "${ORANGE} match the following (for the corresponding initiator host):${NC}"
      for INITIATOR in ${INITIATOR_LIST}
      do
        echo -e "  ${LTPURPLE}Initiator host [${GRAY}${INITIATOR}${LTPURPLE}]: ${GRAY}InitiatorName=${IQN}:${INITIATOR}${NC}"
      done
      echo
    ;;
    tgt|tgtd)
      echo -e "${ORANGE}-On each initiator, insure that the IQNs in ${LTPURPLE}/etc/iscsi/initiatorname.iscsi${NC}"
      echo -e "${ORANGE} are unique${NC}"
      echo
    ;;
  esac

  echo -e "${ORANGE}-On each initiator, enable and (re)start the initiator service by running the following:${NC}"
  echo -e "${GRAY}  sudo systemctl enable iscsid${NC}"
  echo -e "${GRAY}  sudo systemctl enable iscsi${NC}"
  echo -e "${GRAY}  sudo systemctl restart iscsid${NC}"
  echo -e "${GRAY}  sudo systemctl restart iscsi${NC}"
  echo

  echo -e "${ORANGE}-On each initiator, connect to these targets by running the following:${NC}"
  echo -e "${GRAY}  sudo iscsiadm -m discovery --type=st --portal=${SERVER_IP}:3260${NC}"
  echo
  for TARGET in ${TARGET_LIST}
  do
    echo -e "${GRAY}  sudo iscsiadm -m node -T ${SERVER_IQN}:${TARGET} --login --portal=${SERVER_IP}:3260${NC}"
  done
  echo
  echo -e "${GRAY}  sudo iscsiadm -m node -p ${SERVER_IP}:3260 --op=update --name=node.startup --value=automatic${NC}"
  echo
  echo -e "${ORANGE}  -------------------------------------------------------------------------${NC}"
  echo -e "${ORANGE}  NOTE: ${GRAY}${SERVER_IP} ${ORANGE}is the IP address of the first network interface"
  echo -e "${ORANGE}        on the server. If you wish to use a different network interface,"
  echo -e "${ORANGE}        use the corresponding IP address in the previous commands instead.${NC}"
  echo -e "${ORANGE}  -------------------------------------------------------------------------${NC}"
  echo
}


main() {
  case ${TARGET_DAEMON} in
    targetcli)
      create_targetcli_luns
    ;;
    tgt|tgtd)
      create_tgtd_luns
    ;;
  esac
  show_configure_initiators
}

#############################################################################

main ${*}
