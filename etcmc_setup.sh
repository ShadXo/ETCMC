#!/bin/bash

RED='\033[1;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
BROWN='\033[0;34m'
NC='\033[0m' # No Color

# CONFIGURATION
NAME=$1

# Execute getopt
ARGS=$(getopt -o "p:" -l "project:" -n "$0" -- "$@");

eval set -- "$ARGS";

while true; do
    case "$1" in
        -p |--project)
            shift;
                    if [ -n "$1" ];
                    then
                        NAME="$1";
                        shift;
                    fi
            ;;
        --)
            shift;
            break;
            ;;
    esac
done

# Check required arguments
if [ -z "$NAME" ]; then
    echo "You need to specify a project, use -p or --project to do so."
    echo "Example: $0 -p etcmc"
    exit 1
fi

# GET CONFIGURATION
SETUP_CONF_FILE="./projects/${NAME}/${NAME}.env"
#if [ `wget --spider -q https://raw.githubusercontent.com/ShadXo/ETCMC/master/projects/${NAME}/${NAME}.env` ]; then
mkdir -p ./projects/${NAME}
wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/projects/${NAME}/${NAME}.env -O $SETUP_CONF_FILE > /dev/null 2>&1
chmod 777 $SETUP_CONF_FILE &> /dev/null
#dos2unix $SETUP_CONF_FILE > /dev/null 2>&1
#fi

if [ -f ${SETUP_CONF_FILE} ] && [ -s ${SETUP_CONF_FILE} ]; then
  echo "Using setup env file: ${SETUP_CONF_FILE}"
  source "${SETUP_CONF_FILE}"
else
  echo "No setup env file found, create one at the following location: ./project/${NAME}/${NAME}.env"
  exit 1
fi

# URL for ETCMC Version check
URL="https://raw.githubusercontent.com/Nowalski/ETCMC_Client-2.0/main/version.json"

# Fetch the webpage content
CONTENT=$(curl -s $URL)

# Extract the version number
VERSION=$(echo "$CONTENT" | jq -r '.Version')

cd ~
echo "******************************************************************************"
echo "* Ubuntu 22.04 or newer operating system is recommended for this install.    *"
echo "*                                                                            *"
echo "* This script will install and configure your ${NAME^^} nodes (v${VERSION}).*"
echo "******************************************************************************"
echo && echo && echo
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "!                                                 !"
echo "! Make sure you double check before hitting enter !"
echo "!                                                 !"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo && echo && echo

# Set to non interactive mode and auto restart services if needed
export NEEDRESTART_MODE=a
export DEBIAN_FRONTEND=noninteractive

#if [[ $(lsb_release -d) != *16.04* ]]; then
#   echo -e "${RED}The operating system is not Ubuntu 16.04. You must be running on Ubuntu 16.04! Do you really want to continue? [y/n]${NC}"
#   read OS_QUESTION
#   if [[ ${OS_QUESTION,,} =~ "y" ]] ; then
#      echo -e "${RED}You are on your own now!${NC}"
#   else
#      exit -1
#   fi
#fi

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}$0 must be run as root.${NC}"
   exit 1
fi

# Refuse to run if a node already exists on this host
EXISTING_NODE=$(ls -d ~/.${NAME}_* 2>/dev/null | head -1)
if [ -n "$EXISTING_NODE" ]; then
  echo -e "${RED}A ${NAME^^} node already exists at $EXISTING_NODE.${NC}"
  echo -e "${RED}Only one node per server is supported. Use the remove script first if you want to reinstall.${NC}"
  exit 1
fi

function get_ip() {
  declare -a NODE_IPS
  for ips in $(netstat -i | awk '!/Kernel|Iface|lo/ {print $1," "}')
  do
    NODE_IPS+=($(ip addr show dev $ips | grep inet | awk -F '[ \t]+|/' '{print $3}' | grep -v ^fe80 | grep -v ^::1 | grep -v ^1.2.3 | sort -V))
    #NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s4 icanhazip.com))
    #NODE_IPS+=($(curl --interface $ips --connect-timeout 2 -s6 icanhazip.com))
  done

  if [ ${#NODE_IPS[@]} -gt 1 ]; then
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

apt-get install -y net-tools > /dev/null # Needed by netstat used in get_ip function

get_ip
#IP="[${NODEIP}]"
echo "Trying to detect Public IP ..."
PUBIPv4=$( timeout --signal=SIGKILL 10s wget -4qO- -T 10 -t 2 -o- "--bind-address=${NODEIP}" http://v4.ident.me )
PUBIPv6=$( timeout --signal=SIGKILL 10s wget -6qO- -T 10 -t 2 -o- "--bind-address=${NODEIP}" http://v6.ident.me )
if [[ $NODEIP =~ .*:.* ]]; then
  #INTIP=$(ip -4 addr show dev $ips | grep inet | awk -F '[ \t]+|/' '{print $3}' | head -1)
  #IP=${INTIP}
  IP="[${NODEIP}]"
  EXTERNALIP="[${PUBIPv6}]"
  else
  IP=${NODEIP}
  EXTERNALIP=${PUBIPv4}
fi

if [ -z "$EXTERNALIP" ]; then
  echo "Public IP NOT detected, exiting installer."
  exit 1
else
  echo "PUBLIC IP: $EXTERNALIP"
fi

echo -e "${YELLOW}Do you want to install all needed dependencies (no if you did it before, yes if you are installing your first node)? [y/n]${NC}"
read DOSETUP
DOSETUP="y" # For now always do setup, for ETCMC Nodes.

if [[ ${DOSETUP,,} =~ "y" ]]; then
  apt-get update
  apt-get -y upgrade
  apt-get -y dist-upgrade
  #apt-get install -y python3 python3-pip # Not needed anymore since version 2.7.0, can be removed on the next cleanup.
  apt-get install -y nano htop git
  #apt-get install -y dos2unix
  apt-get install -y unzip
  apt-get install -y jq curl wget

   if [ $(free | awk '/^Swap:/ {exit !$2}') ] || [ ! -f "/var/swap.img" ]; then
     echo "No proper swap, creating it"
     touch /var/swap.img
     chmod 600 /var/swap.img
     dd if=/dev/zero of=/var/swap.img bs=1024k count=2000
     mkswap /var/swap.img
     swapon /var/swap.img
     free
     echo "/var/swap.img none swap sw 0 0" >> /etc/fstab
   else
     echo "All good, we have a swap"
   fi

   ## COMPILE AND INSTALL
   if [ -d "$CONF_DIR_TMP" ]; then
      rm -rfd $CONF_DIR_TMP
   fi

   # Create Temp folder
   mkdir -p $CONF_DIR_TMP

   cd $CONF_DIR_TMP
   echo "Downloading the latest files"
   if [[ $SETUPURL == *.tar.gz ]]; then
     wget ${SETUPURL} -O setup.tar.gz
     WGET=$?
   elif [[ $SETUPURL == *.zip ]]; then
     wget ${SETUPURL} -O setup.zip
     WGET=$?
   fi

   if [ $WGET -ne 0 ]; then
     echo -e "${RED}Setup download failed, check the SETUPURL.${NC}"
     rm -rfd $CONF_DIR_TMP
     exit 1
  fi

   #chmod 775 ${WALLETDL}
   if [[ $SETUPURL == *.tar.gz ]]; then
     tar -xvzf setup.tar.gz
   elif [[ $SETUPURL == *.zip ]]; then
     unzip -o setup.zip
   fi

   chmod 775 *
   #find . -type f -exec mv -t . {} + &> /dev/null # Some coins have files in subfolders
   #mv ./bin/${NAME}* /usr/bin
   #mv ./bin/${NAME}* /usr/local/bin # previous /usr/bin should be /usr/local/bin
   rm setup.tar.gz setup.zip &> /dev/null
   #mv * $CONF_DIR # Copy files from temp folder to config folder

   # Remove Temp folder
   #rm -rfd $CONF_DIR_TMP # Removed the temp folder removal

   apt-get install -y ufw
   ufw allow ssh/tcp
   ufw limit ssh/tcp
   ufw logging on
   echo "y" | ufw enable
   ufw status

   mkdir -p ~/bin
   echo 'export PATH=~/bin:$PATH' >> ~/.bash_aliases
   source ~/.bashrc
fi

## Setup conf
mkdir -p ~/bin
rm ~/bin/node_config.txt &> /dev/null
COUNTER=1

MNCOUNT="1"
#REBOOTRESTART=""
re='^[0-9]+$'
while ! [[ $MNCOUNT =~ $re ]]; do
  echo -e "${YELLOW}How many nodes do you want to create on this server?, followed by [ENTER]:${NC}"
  read MNCOUNT
  #echo -e "${YELLOW}Do you want to use TOR, additional dependencies needed (no if you dont know what this does)? [y/n]${NC}"
  #read TOR
  #echo -e "${YELLOW}Do you want the wallet to restart on reboot? [y/n]${NC}"
  #read REBOOTRESTART
done

if [[ ${TOR,,} =~ "y" ]]; then
  if (service --status-all | grep -w "tor" &> /dev/null); then
    echo ""
  else
    apt install -y tor
    echo -e 'ControlPort 9051\nLongLivedPorts 56740' >> /etc/tor/torrc
    systemctl stop tor
    systemctl start tor
  fi
fi

REBOOTRESTART="y"
#echo -e "${YELLOW}Do you want the wallet to restart on reboot? [y/n]${NC}"
#read REBOOTRESTART

for (( ; ; ))
do
  #echo "************************************************************"
  #echo ""
  echo "Enter alias for new node. Name must be unique! (Don't use same names as for previous nodes on old chain if you didn't delete old chain folders!)"
  echo -e "${YELLOW}Enter alphanumeric alias for new nodes.[default: n]${NC}"
  read ALIAS1

  if [ -z "$ALIAS1" ]; then
    ALIAS1="n"
  fi

  ALIAS1=${ALIAS1,,}

  if [[ "$ALIAS1" =~ [^0-9A-Za-z]+ ]]; then
    echo -e "${RED}$ALIAS1 has characters which are not alphanumeric. Please use only alphanumeric characters.${NC}"
  elif [ -z "$ALIAS1" ]; then
    echo -e "${RED}$ALIAS1 in empty!${NC}"
  else
    CONF_DIR=~/.${NAME}_$ALIAS1
    if [ -d "$CONF_DIR" ]; then
         echo -e "${RED}$ALIAS1 is already used. $CONF_DIR already exists!${NC}"
    else
      # OK !!!
      break
    fi
  fi
done

# Removed the temp folder removal
#if [ -d "$CONF_DIR_TMP" ]; then
  #rm -rfd $CONF_DIR_TMP
#fi

#mkdir -p $CONF_DIR_TMP

for STARTNUMBER in `seq 1 1 $MNCOUNT`; do
   for (( ; ; ))
   do
      echo "************************************************************"
      echo ""
      EXIT='NO'
      ALIAS="$ALIAS1$STARTNUMBER"
      ALIAS0="${ALIAS1}0${STARTNUMBER}"
      ALIAS=${ALIAS,,}
      echo $ALIAS
      echo ""

      # check ALIAS
      if [[ "$ALIAS" =~ [^0-9A-Za-z]+ ]]; then
        echo -e "${RED}$ALIAS has characters which are not alphanumeric. Please use only alphanumeric characters.${NC}"
        EXIT='YES'
	    elif [ -z "$ALIAS" ]; then
	      echo -e "${RED}$ALIAS in empty!${NC}"
        EXIT='YES'
      else
	      CONF_DIR=~/.${NAME}_${ALIAS}
        CONF_DIR0=~/.${NAME}_${ALIAS0}

        if [ -d "$CONF_DIR" ]; then
          echo -e "${RED}$ALIAS is already used. $CONF_DIR already exists!${NC}"
          STARTNUMBER=$((STARTNUMBER + 1))
        elif [ -d "$CONF_DIR0" ]; then
          echo -e "${RED}$ALIAS is already used. $CONF_DIR0 already exists!${NC}"
          STARTNUMBER=$((STARTNUMBER + 1))
        else
          # OK !!!
          break
        fi
      fi
   done

   if [ $EXIT == 'YES' ]
   then
      exit 1
   fi

  echo "IP "$IP

  if [[ ${TOR,,} =~ "y" ]]; then
    TORPORT=$RPCPORT
    TORPORT1=""
    for (( ; ; ))
    do
      TORPORT1=$(netstat -tlnp 2>/dev/null | awk '{print $4}' | grep -E "[:.]${TORPORT}$")
      if [ -z "$TORPORT1" ]; then
        break
      else
        TORPORT=$((TORPORT + 1))
      fi
    done
    echo "TORPORT "$TORPORT
  fi

  PORT1=""
  for (( ; ; ))
  do
    PORT1=$(netstat -tlnp 2>/dev/null | awk '{print $4}' | grep -E "[:.]${PORT}$")
    if [ -z "$PORT1" ]; then
      echo "PORT "$PORT
      break
    else
      PORT=$((PORT + 1))
    fi
  done

  RPCPORT1=""
  for (( ; ; ))
  do
    RPCPORT1=$(netstat -tlnp 2>/dev/null | awk '{print $4}' | grep -E "[:.]${RPCPORT}$")
    if [ -z "$RPCPORT1" ]; then
      echo "RPCPORT "$RPCPORT
      break
    else
      RPCPORT=$((RPCPORT + 1))
    fi
  done

  PRIVKEY=""
  echo ""

  echo "ALIAS="$ALIAS

  # Create config folder
  mkdir -p $CONF_DIR
  cd $CONF_DIR

  echo "Copying files to $CONF_DIR."
  #mv $CONF_DIR_TMP/* $CONF_DIR_TMP/.* $CONF_DIR &> /dev/null # Copy files from temp folder to config folder, Added $CONF_DIR_TMP/.* because its missing hidden files.
  cp -rT $CONF_DIR_TMP $CONF_DIR # Copy files from temp folder to config folder.

  # Open firewall port
  ufw allow $PORT/tcp
  ufw allow $RPCPORT/tcp

  # Install required packages
  #echo "Installing required packages..."
  #pip3 install -r requirements.txt --break-system-packages --ignore-installed # Added --ignore-installed, latest Ubuntu patches adds cryptography 41.0.7, which you cant uninstall. Not needed anymore since update 2.7.0 (One file, which includes all the prereqs), can be removed on the next cleanup.

  # Set permissions for files
  echo "Setting permissions for files..."
  chmod +x Linux.py ETCMC_GETH geth

  # Set login required to false
  echo "Setting login required to false"
  if [ ! -f login.json ]; then
    echo '{"login_required": false}' > login.json
  else
    jq '.login_required = false' login.json > login_temp.json && mv login_temp.json login.json
  fi

  # Set Auto-Start Node to true
  echo "Setting Auto-Start Node to true"
  if [ ! -f auto_start_status.json ]; then
    echo '{"auto_start_enabled": true}' > auto_start_status.json
  else
    jq '.auto_start_enabled = true' auto_start_status.json > auto_start_status_temp.json && mv auto_start_status_temp.json auto_start_status.json
  fi

  if [[ ${REBOOTRESTART,,} =~ "y" ]] ; then
    #DAEMONSYSTEMDFILE="/etc/systemd/system/${NAME}_$ALIAS.service"
    #if [[ ! -f "${DAEMONSYSTEMDFILE}" ]]; then
    #fi
    echo "Creating systemd service for ${NAME}_$ALIAS to shutdown geth"
    cat << EOF > /etc/systemd/system/${NAME}_$ALIAS-geth.service
[Unit]
Description=Service for ${NAME}_$ALIAS to shutdown geth
After=${NAME}_$ALIAS.service
BindsTo=${NAME}_$ALIAS.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
ExecStop=/usr/bin/pkill -SIGINT -f ${NAME}_$ALIAS/geth
ExecStop=/bin/sh -c 'while pgrep -f "${NAME}_${ALIAS}[/]geth" >/dev/null; do sleep 1; done'
TimeoutStopSec=60s

[Install]
WantedBy=${NAME}_$ALIAS.service
EOF

    echo "Creating systemd service for ${NAME}_$ALIAS"
    cat << EOF > /etc/systemd/system/${NAME}_$ALIAS.service
[Unit]
Description=Node Service for ${NAME}_$ALIAS
After=network.target

[Service]
User=root
Group=root
Type=simple
WorkingDirectory=$CONF_DIR
ExecStart=$CONF_DIR/ETCMC_GETH --port 5000
Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=10s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  sleep 2 # wait 2 seconds
  systemctl enable ${NAME}_$ALIAS-geth.service
  systemctl enable ${NAME}_$ALIAS.service
  #systemctl enable --now ${NAME}_$ALIAS.service
  fi

  GETHPID=$(ps -ef | grep -i ${NAME} | grep -i -w ${NAME}_${ALIAS} | grep -i -w geth | grep -v grep | grep -v bash | awk '{print $2}')
  NODEPID=$(ps -ef | grep -i ${NAME} | grep -i -w ${NAME}_${ALIAS} | grep -i -w ETCMC_GETH | grep -v grep | awk '{print $2}' | head -1) # Since version 2.7.0 there are multiple processes, get the first match.
  if [ -z "$NODEPID" ]; then
    # start node
    echo "Starting $ALIAS."
    #sh ~/bin/${NAME}d_$ALIAS.sh
    systemctl start ${NAME}_$ALIAS.service
    sleep 2 # wait 2 seconds
  fi

  if [[ $IP =~ .*:.* ]]; then
    MNCONFIG=$(echo Node Alias:$ALIAS Geth:[$IP]:$RPCPORT Node Portal:"http://$IP:$PORT")
  else
    MNCONFIG=$(echo Node Alias:$ALIAS Geth:$IP:$RPCPORT Node Portal:"http://$IP:$PORT")
  fi
  echo $MNCONFIG >> ~/bin/node_config.txt

  COUNTER=$((COUNTER + 1))
done

if [ -d "$CONF_DIR_TMP" ]; then
  rm -rfd $CONF_DIR_TMP
fi

echo ""
echo ""
echo -e "${YELLOW}******************************************************************"
echo -e "**Installation complete.                                                 **"
echo -e "**Happy earnings                                                         **"
echo -e "**Dont forget to start the node using the webportal                      **"
echo -e "**Tutorial: https://etcmc.org                                            **"
echo -e "**********************************************************************${NC}"
echo -e "${RED}"
cat ~/bin/node_config.txt
echo -e "${NC}"
echo "******************************************************************************"
echo ""
rm ~/bin/node_config.txt &> /dev/null
