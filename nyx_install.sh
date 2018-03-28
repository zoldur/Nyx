#!/bin/bash

TMP_FOLDER=$(mktemp -d)
CONFIG_FILE="nyx.conf"
NYX_DAEMON="/usr/local/bin/nyxd"
NYX_CLI="/usr/local/bin/nyx-cli"
NYX_REPO="https://github.com/nyxpay/nyx/releases/download/v0.12.1.7/nyx-0.12.1-linux64.tar.gz"
SENTINEL_REPO="https://github.com/nyxpay/sentinel.git"
DEFAULTNYXPORT=4330
DEFAULTNYXUSER="nyx"
NODEIP=$(curl -s4 icanhazip.com)


RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'


function get_ip() {
  declare -a NODE_IPS
  for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
  do
    NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com))
  done

  if [ ${#NODE_IPS[@]} -gt 1 ]
    then
      echo -e "${GREEN}More than one IP. Please type 0 to use the first IP, 1 for the second and so on...${NC}"
      INDEX=0
      for ip in "${NODE_IPS[@]}"
      do
        echo ${INDEX} $ip
        let INDEX=${INDEX}+1
      done
      read -e choose_ip
      NODEIP=${NODE_IPS[$choose_ip]}
  else
    NODEIP=${NODE_IPS[0]}
  fi
}


function compile_error() {
if [ "$?" -gt "0" ];
 then
  echo -e "${RED}Failed to compile $@. Please investigate.${NC}"
  exit 1
fi
}


function checks() {
if [[ $(lsb_release -d) != *16.04* ]]; then
  echo -e "${RED}You are not running Ubuntu 16.04. Installation is cancelled.${NC}"
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

if [ -n "$(pidof $NYX_DAEMON)" ] || [ -e "$NYX_DAEMOM" ] ; then
  echo -e "${GREEN}\c"
  read -e -p "Nyx is already installed. Do you want to add another MN? [Y/N]" NEW_NYX
  echo -e "{NC}"
  clear
else
  NEW_NYX="new"
fi
}

function prepare_system() {

echo -e "Checking if swap space is needed."
PHYMEM=$(free -g|awk '/^Mem:/{print $2}')
SWAP=$(free -g|awk '/^Swap:/{print $2}')
if [ "$PHYMEM" -lt "2" ] && [ -n "$SWAP" ]
  then
    echo -e "${GREEN}Server is running with less than 2G of RAM without SWAP, creating 2G swap file.${NC}"
    SWAPFILE=$(mktemp)
    dd if=/dev/zero of=$SWAPFILE bs=1024 count=2M
    chmod 600 $SWAPFILE
    mkswap $SWAPFILE
    swapon -a $SWAPFILE
else
  echo -e "${GREEN}Server running with at least 2G of RAM, no swap needed.${NC}"
fi
clear

echo -e "Prepare the system to install Nyx master node."
apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get update > /dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" -y -qq upgrade >/dev/null 2>&1
apt install -y software-properties-common >/dev/null 2>&1
echo -e "${GREEN}Adding bitcoin PPA repository"
apt-add-repository -y ppa:bitcoin/bitcoin >/dev/null 2>&1
echo -e "Installing required packages, it may take some time to finish.${NC}"
apt-get update >/dev/null 2>&1
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" make software-properties-common \
build-essential libtool autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev libboost-program-options-dev \
libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git wget pwgen curl libdb4.8-dev bsdmainutils libdb4.8++-dev \
libminiupnpc-dev libgmp3-dev ufw fail2ban python-virtualenv >/dev/null 2>&1
clear
if [ "$?" -gt "0" ];
  then
    echo -e "${RED}Not all required packages were installed properly. Try to install them manually by running the following commands:${NC}\n"
    echo "apt-get update"
    echo "apt -y install software-properties-common"
    echo "apt-add-repository -y ppa:bitcoin/bitcoin"
    echo "apt-get update"
    echo "apt install -y make build-essential libtool software-properties-common autoconf libssl-dev libboost-dev libboost-chrono-dev libboost-filesystem-dev \
libboost-program-options-dev libboost-system-dev libboost-test-dev libboost-thread-dev sudo automake git pwgen curl libdb4.8-dev \
bsdmainutils libdb4.8++-dev libminiupnpc-dev libgmp3-dev ufw fail2ban python-virtualenv"
 exit 1
fi
clear
}

function compile_node() {
  echo -e "Download binaries. This may take some time. Press a key to continue."
  cd $TMP_FOLDER >/dev/null 2>&1
  wget -q $NYX_REPO >/dev/null 2>&1
  tar xvzf $(echo $NYX_REPO | awk -F"/" '{print $NF}') --strip 1 >/dev/null 2>&1
  compile_error NyxCoin
  cp nyx* /usr/local/bin
  cd ~
  rm -rf $TMP_FOLDER
  clear
}

function enable_firewall() {
  echo -e "Installing and setting up firewall to allow ingress on port ${GREEN}$NYXPORT${NC}"
  ufw allow $NYXPORT/tcp comment "NYX MN port" >/dev/null
  ufw allow $[NYXPORT+1]/tcp comment "NYX RPC port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
}

function configure_systemd() {
  cat << EOF > /etc/systemd/system/$NYXUSER.service
[Unit]
Description=NYX service
After=network.target

[Service]
User=$NYXUSER
Group=$NYXUSER

Type=forking
PIDFile=$NYXFOLDER/$NYXUSER.pid

ExecStart=$NYX_DAEMON -daemon -pid=$NYXFOLDER/$NYXUSER.pid -conf=$NYXFOLDER/$CONFIG_FILE -datadir=$NYXFOLDER -reindex
ExecStop=-$NYX_CLI -conf=$NYXFOLDER/$CONFIG_FILE -datadir=$NYXFOLDER stop

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=2s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  sleep 3
  systemctl start $NYXUSER.service
  systemctl enable $NYXUSER.service

  if [[ -z "$(ps axo user:15,cmd:100 | egrep ^$NYXUSER | grep $NYX_DAEMON)" ]]; then
    echo -e "${RED}NYX is not running${NC}, please investigate. You should start by running the following commands as root:"
    echo -e "${GREEN}systemctl start $NYXUSER.service"
    echo -e "systemctl status $NYXUSER.service"
    echo -e "less /var/log/syslog${NC}"
    exit 1
  fi
}

function ask_port() {
read -p "Nyx Port: " -i $DEFAULTNYXPORT -e NYXPORT
: ${NYXPORT:=$DEFAULTNYXPORT}
}

function ask_user() {
  read -p "Nyx user: " -i $DEFAULTNYXUSER -e NYXUSER
  : ${NYXUSER:=$DEFAULTNYXUSER}

  if [ -z "$(getent passwd $NYXUSER)" ]; then
    USERPASS=$(pwgen -s 12 1)
    useradd -m $NYXUSER
    echo "$NYXUSER:$USERPASS" | chpasswd

    NYXHOME=$(sudo -H -u $NYXUSER bash -c 'echo $HOME')
    DEFAULTNYXFOLDER="$NYXHOME/.nyx"
    read -p "Configuration folder: " -i $DEFAULTNYXFOLDER -e NYXFOLDER
    : ${NYXFOLDER:=$DEFAULTNYXFOLDER}
    mkdir -p $NYXFOLDER
    chown -R $NYXUSER: $NYXFOLDER >/dev/null
  else
    clear
    echo -e "${RED}User exits. Please enter another username: ${NC}"
    ask_user
  fi
}

function check_port() {
  declare -a PORTS
  PORTS=($(netstat -tnlp | grep $NODEIP | awk '/LISTEN/ {print $4}' | awk -F":" '{print $NF}' | sort | uniq | tr '\r\n'  ' '))
  ask_port

  while [[ ${PORTS[@]} =~ $NYXPORT ]] || [[ ${PORTS[@]} =~ $[NYXPORT-1] ]]; do
    clear
    echo -e "${RED}Port in use, please choose another port:${NF}"
    ask_port
  done
}

function create_config() {
  RPCUSER=$(pwgen -s 8 1)
  RPCPASSWORD=$(pwgen -s 15 1)
  cat << EOF > $NYXFOLDER/$CONFIG_FILE
rpcuser=$RPCUSER
rpcpassword=$RPCPASSWORD
rpcallowip=127.0.0.1
listen=1
server=1
bind=$NODEIP
daemon=1
port=$NYXPORT
EOF
}

function create_key() {
  echo -e "Enter your ${RED}Masternode Private Key${NC}. Leave it blank to generate a new ${RED}Masternode Private Key${NC} for you:"
  read -e NYXKEY
  if [[ -z "$NYXKEY" ]]; then
  su $NYXUSER -c "$NYX_DAEMON -conf=$NYXFOLDER/$CONFIG_FILE -datadir=$NYXFOLDER"
  sleep 10
  if [ -z "$(ps axo user:15,cmd:100 | egrep ^$NYXUSER | grep $NYX_DAEMON)" ]; then
   echo -e "${RED}Nyx server couldn't start. Check /var/log/syslog for errors.{$NC}"
   exit 1
  fi
  NYXKEY=$(su $NYXUSER -c "$NYX_CLI -conf=$NYXFOLDER/$CONFIG_FILE -datadir=$NYXFOLDER masternode genkey")
  su $NYXUSER -c "$NYX_CLI -conf=$NYXFOLDER/$CONFIG_FILE -datadir=$NYXFOLDER stop"
fi
}

function update_config() {
  sed -i 's/daemon=1/daemon=0/' $NYXFOLDER/$CONFIG_FILE
  cat << EOF >> $NYXFOLDER/$CONFIG_FILE
maxconnections=256
masternode=1
externalip=$NODEIP
masternodeprivkey=$NYXKEY
EOF
  chown -R $NYXUSER: $NYXFOLDER >/dev/null
}


function install_sentinel() {
  echo -e "${GREEN}Install sentinel.${NC}"
  apt-get install virtualenv >/dev/null 2>&1
  git clone $SENTINEL_REPO $NYXHOME/sentinel >/dev/null 2>&1
  cd $NYXHOME/sentinel 
  virtualenv ./venv >/dev/null 2>&1
  ./venv/bin/pip install -r requirements.txt >/dev/null 2>&1
  echo  "* * * * * cd $NYXHOME/sentinel && ./venv/bin/python bin/sentinel.py >> ~/sentinel.log 2>&1" > $NYXHOME/nyx_cron
  chown -R $NYXUSER: $NYXHOME/sentinel >/dev/null 2>&1
  crontab -u $NYXUSER $NYXHOME/nyx_cron >/dev/null 2>&1
  rm $NYXHOME/nyx_cron >/dev/null 2>&1
}

function important_information() {
 echo
 echo -e "================================================================================================================================"
 echo -e "Nyx Masternode is up and running as user ${GREEN}$NYXUSER${NC} and it is listening on port ${GREEN}$NYXPORT${NC}."
 echo -e "${GREEN}$NYXUSER${NC} password is ${RED}$USERPASS${NC}"
 echo -e "Configuration file is: ${RED}$NYXFOLDER/$CONFIG_FILE${NC}"
 echo -e "Start: ${RED}systemctl start $NYXUSER.service${NC}"
 echo -e "Stop: ${RED}systemctl stop $NYXUSER.service${NC}"
 echo -e "VPS_IP:PORT ${RED}$NODEIP:$NYXPORT${NC}"
 echo -e "MASTERNODE PRIVATEKEY is: ${RED}$NYXKEY${NC}"
 echo -e "Please check Nyx is running with the following command: ${GREEN}systemctl status $NYXUSER.service${NC}"
 echo -e "================================================================================================================================"
}

function setup_node() {
  get_ip
  ask_user
  check_port
  create_config
  create_key
  update_config
  enable_firewall
  install_sentinel
  configure_systemd
  important_information
}


##### Main #####
clear

checks
if [[ ("$NEW_NYX" == "y" || "$NEW_NYX" == "Y") ]]; then
  setup_node
  exit 0
elif [[ "$NEW_NYX" == "new" ]]; then
  prepare_system
  compile_node
  setup_node
else
  echo -e "${GREEN}Nyx already running.${NC}"
  exit 0
fi

