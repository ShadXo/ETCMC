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

cd ~
echo "******************************************************************************"
echo "* Ubuntu 22.04 or newer operating system is recommended for this install.    *"
echo "*                                                                            *"
echo "* This script will install and configure your ${NAME^^} nodes (v${NODEVERSION}).*"
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
  break
else
  echo "PUBLIC IP: $EXTERNALIP"
fi

echo -e "${YELLOW}Do you want to install all needed dependencies (no if you did it before, yes if you are installing your first node)? [y/n]${NC}"
read DOSETUP

if [[ ${DOSETUP,,} =~ "y" ]]; then
  apt-get update
  apt-get -y upgrade
  apt-get -y dist-upgrade
  apt-get install -y python3 python3-pip
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
   echo "Downloading wallet"
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
          STARTNUMBER=$[STARTNUMBER + 1]
        elif [ -d "$CONF_DIR0" ]; then
          echo -e "${RED}$ALIAS is already used. $CONF_DIR0 already exists!${NC}"
          STARTNUMBER=$[STARTNUMBER + 1]
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

   IP1=""
   for (( ; ; ))
   do
     IP1=$(netstat -peanut -W | grep -i listen | grep -i $NODEIP:$PORT)

     if [ -z "$IP1" ]; then
       break
     else
       echo -e "${RED}IP: $NODEIP is already used for port: $PORT.${NC}"
       if [[ ${TOR,,} =~ "y" ]] ; then
         echo "Using TOR"
         #NODEIP="127.0.0.1"
         break
       fi
       exit
       echo "Creating fake IP."
       BASEIP="1.2.3."
       IP=$BASEIP$STARTNUMBER
       cat > /etc/netplan/${NAME}_$ALIAS.yaml <<-EOF
# This is the network config written by 'subiquity'
network:
  ethernets:
    ens160:
      addresses:
      - $BASEIP$STARTNUMBER/24
  version: 2
EOF
    fi
    netplan apply
    break
  done
  echo "IP "$IP
  echo "PORT "$PORT

  if [[ ${TOR,,} =~ "y" ]]; then
    TORPORT=$PORT
    PORT1=""
    for (( ; ; ))
    do
      PORT1=$(netstat -peanut | grep -i listen | grep -i $TORPORT)

      if [ -z "$PORT1" ]; then
        break
      else
        TORPORT=$[TORPORT + 1]
      fi
    done
    echo "TORPORT "$TORPORT
  fi

  RPCPORT1=""
  for (( ; ; ))
  do
    RPCPORT1=$(netstat -peanut | grep -i listen | grep -i $RPCPORT)
    if [ -z "$RPCPORT1" ]; then
      echo "RPCPORT "$RPCPORT
      break
    else

      RPCPORT=$[RPCPORT + 1]
    fi
  done

  PRIVKEY=""
  echo ""

  echo "ALIAS="$ALIAS

  # Create config folder
  mkdir -p $CONF_DIR
  cd $CONF_DIR

  mv $CONF_DIR_TMP/* $CONF_DIR_TMP/.* $CONF_DIR &> /dev/null # Copy files from temp folder to config folder, Added $CONF_DIR_TMP/.* because its missing hidden files.

  # Open firewall port
  ufw allow $PORT/tcp
  ufw allow $RPCPORT/tcp

  # Install required packages
  echo "Installing required packages..."
  #pip3 install -r requirements.txt || pip3 install -r requirements.txt --break-system-packages
  pip3 install -r requirements.txt --break-system-packages

  # Set permissions for files
  echo "Setting permissions for files..."
  chmod +x Linux.py ETCMC_GETH.py geth

  if [[ ${REBOOTRESTART,,} =~ "y" ]] ; then
    #DAEMONSYSTEMDFILE="/etc/systemd/system/${NAME}_$ALIAS.service"
    #if [[ ! -f "${DAEMONSYSTEMDFILE}" ]]; then
    #fi
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
ExecStart=python3 ETCMC_GETH.py --port 5000
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
  systemctl enable ${NAME}_$ALIAS.service
  systemctl start ${NAME}_$ALIAS.service
  #systemctl enable --now ${NAME}_$ALIAS.service
  fi

  # Crontab to Backup Balance file every 6h
  #0 */6 * * * cp /home/ETCMC/etcpow_balance_backup.txt.enc.bak /home/
  GETHPID=`ps -ef | grep -i ${NAME} | grep -i -w ${NAME}_${ALIAS} | grep -v grep | awk '{print $2}'` # Correct for geth
  PID=`ps -ef | grep -i ${NAME} | grep -i -w ETCMC_GETH | grep -v grep | awk '{print $2}'` # Correct for ETCMC_GETH
  if [ -z "$PID" ]; then
    # start node
    echo "Starting $ALIAS."
    #sh ~/bin/${NAME}d_$ALIAS.sh
    systemctl start ${NAME}_$ALIAS.service
    sleep 2 # wait 2 seconds
  fi

  if [ -z "$PID" ] && [ "$ADDNODESURL" ]; then
    if [ "$EXPLORERAPI" == "BLOCKBOOK" ]; then
      if [ "$NAME" == "dogecash" ]; then
        ADDNODES=$( curl -s https://api.dogecash.org/api/v1/network/peers | jq -r ".result" | jq -r '.[]' )
      else
        echo "Not tried it yet"
      fi
    elif [ "$EXPLORERAPI" == "DOGECASH" ]; then
      #ADDNODES=$( wget -4qO- -o- ${ADDNODESURL} | grep 'addnode=' | shuf ) # If using Dropbox link
      ADDNODES=$( curl -s ${ADDNODESURL} | jq -r ".result" | jq -r '.[]' )
    elif [ "$EXPLORERAPI" == "DECENOMY" ]; then
      ADDNODES=$( curl -s ${ADDNODESURL} | jq -r --arg PORT "$PORT" '.response | .[].addr | select( . | contains($PORT))' )
    elif [ "$EXPLORERAPI" == "IQUIDUS" ]; then
      ADDNODES=$( curl -s ${ADDNODESURL} | jq -r --arg PORT "$PORT" '.[] | select( .port | contains($PORT)) | .address' )
    elif [ "$EXPLORERAPI" == "IQUIDUS-OLD" ]; then
      ADDNODES=$( curl -s ${ADDNODESURL} | jq -r --arg PORT "$PORT" '.[].addr | select( . | contains($PORT))' )
    else
      echo "Unknown coin explorer, we will continue without addnodes."
      break
    fi

    if [ "$ADDNODES" ]; then
      sed -i '/addnode=/d' $CONF_DIR/${NAME}.conf
      sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' $CONF_DIR/${NAME}.conf # Remove empty lines at the end
      #echo "${ADDNODES}" | tr " " "\\n" >> $CONF_DIR/${NAME}.conf # If using Dropbox link
      echo "${ADDNODES}" | sed "s/^/addnode=/g" >> $CONF_DIR/${NAME}.conf
      sed -i '/addnode=localhost:56740/d' $CONF_DIR/${NAME}.conf # Remove addnode=localhost:56740 line from config, api is giving localhost back as a peer
    else
      echo "Empty response from coin explorer, we will continue without addnodes."
      break
    fi
  fi

  if [ -z "$PID" ]; then
    CHECKNODE="*"
    echo "Checking available nodes to use for a faster sync."
    for FILE in $(ls -d ~/.${NAME}_$CHECKNODE | sort -V); do
      CHECKNODEALIAS=$(echo $FILE | awk -F'[_]' '{print $2}')
      CHECKNODECONFDIR=$(echo "$HOME/.${NAME}_$CHECKNODEALIAS")
      if [ "$CHECKNODEALIAS" != "$ALIAS" ]; then
        echo "Checking ${CHECKNODEALIAS}."
        if [ "$EXPLORERAPI" == "BLOCKBOOK" ]; then
          EXPLORERLASTBLOCK=$(curl -s $EXPLORER | jq -r ".backend.blocks")
          EXPLORERBLOCKHASH=$(curl -s $EXPLORER | jq -r ".backend.bestBlockHash")
          EXPLORERWALLETVERSION=$(curl -s $EXPLORER | jq -r ".backend.version")
        elif [ "$EXPLORERAPI" == "DOGECASH" ]; then
          #BLOCKHASHCOINEXPLORER=$(curl -s https://explorer.dogec.io/api/blocks | jq -r ".backend.bestblockhash")
          #BLOCKHASHCOINEXPLORER=$(curl -s https://dogec.flitswallet.app/api/blocks | jq -r ".backend.bestBlockHash")
          #BLOCKHASHCOINEXPLORER=$(curl -s https://api2.dogecash.org/info | jq -r ".result.bestblockhash")
          #LATESTWALLETVERSION=$(curl -s https://dogec.flitswallet.app/api/blocks | jq -r ".backend.version")
          EXPLORERLASTBLOCK=$(curl -s $EXPLORER/info | jq -r ".result.blocks")
          EXPLORERBLOCKHASH=$(curl -s $EXPLORER/info | jq -r ".result.bestblockhash")
          EXPLORERWALLETVERSION=0 # Can't get this from https://api2.dogecash.org
        elif [ "$EXPLORERAPI" == "DECENOMY" ]; then
          #BLOCKHASHCOINEXPLORER=$(curl -s https://explorer.trittium.net/coreapi/v1/coins/MONK/blocks | jq -r ".response[0].blockhash")
          #LATESTWALLETVERSION=$(curl -s https://https://explorer.decenomy.net/coreapi/v1/coins/DOGECASH?expand=overview | jq -r ".response.versions.wallet")
          EXPLORERLASTBLOCK=$(curl -s $EXPLORER/blocks | jq -r ".response[0].height")
          #EXPLORERLASTBLOCK=$(curl -s $EXPLORER | jq -r ".response.bestblockheight")
          EXPLORERBLOCKHASH=$(curl -s $EXPLORER/blocks | jq -r ".response[0].blockhash")
          EXPLORERWALLETVERSION=$(curl -s $EXPLORER?expand=overview | jq -r ".response.overview.versions.wallet")
        elif [ "$EXPLORERAPI" == "IQUIDUS" ]; then
          EXPLORERLASTBLOCK=$(curl -s $EXPLORER/getblockcount)
          EXPLORERBLOCKHASH=$(curl -s $EXPLORER/getblockhash?index=$EXPLORERLASTBLOCK)
          EXPLORERWALLETVERSION=$(curl -s $EXPLORER/getinfo | jq -r ".version")
        elif [ "$EXPLORERAPI" == "IQUIDUS-OLD" ]; then
          EXPLORERLASTBLOCK=$(curl -s $EXPLORER/getblockcount)
          EXPLORERBLOCKHASH=$(curl -s $EXPLORER/getblockhash?index=$EXPLORERLASTBLOCK | sed 's/"//g')
          EXPLORERWALLETVERSION=$(curl -s $EXPLORER/getinfo | jq -r ".version")
        else
          echo "Unknown coin explorer, we can't compare blockhash or walletversion."
          break
        fi

        WALLETLASTBLOCK=$($FILE getblockcount)
        WALLETBLOCKHASH=$($FILE getblockhash $WALLETLASTBLOCK)
        if [ "$EXPLORERBLOCKHASH" == "$WALLETBLOCKHASH" ]; then
          SYNCNODEALIAS=$CHECKNODEALIAS
          SYNCNODECONFDIR=$CHECKNODECONFDIR
          echo "*******************************************"
          echo "Using the following node to sync faster."
          echo "NODE ALIAS: "$SYNCNODEALIAS
          echo "CONF FOLDER: "$SYNCNODECONFDIR
          break
        else
          CHECKNODEALIAS=""
          CHECKNODECONFDIR=""
        fi
      fi
    done

    # Stopping the SYNCNODE is not needed, it will break when running the install script within the boot time of the node.
    : << 'STOPPROCESS'
    for (( ; ; ))
    do
      SYNCNODEPID=`ps -ef | grep -i -w ${NAME}_$SYNCNODEALIAS | grep -i ${NAME}d | grep -v grep | awk '{print $2}'`
      if [ -z "$SYNCNODEPID" ]; then
        echo ""
        break
      else
        #STOP
        echo "Stopping $SYNCNODEALIAS. Please wait ..."
        #~/bin/${NAME}-cli_$SYNCNODEALIAS.sh stop
        systemctl stop ${NAME}d_$SYNCNODEALIAS.service
      fi
      #echo "Please wait ..."
      sleep 2 # wait 2 seconds
    done
STOPPROCESS

    if [ -z "$PID" ] && [ "$SYNCNODEALIAS" ]; then
      # Copy this Daemon.
      echo "Copy BLOCKCHAIN from ~/.${NAME}_${SYNCNODEALIAS} to ~/.${NAME}_${ALIAS}."
      rm -R $CONF_DIR/database &> /dev/null
      rm -R $CONF_DIR/blocks	&> /dev/null
      rm -R $CONF_DIR/sporks &> /dev/null
      rm -R $CONF_DIR/chainstate &> /dev/null
      cp -r $SYNCNODECONFDIR/database $CONF_DIR &> /dev/null
      cp -r $SYNCNODECONFDIR/blocks $CONF_DIR &> /dev/null
      cp -r $SYNCNODECONFDIR/sporks $CONF_DIR &> /dev/null
      cp -r $SYNCNODECONFDIR/chainstate $CONF_DIR &> /dev/null
    elif [ -z "$PID" ] && [ "$BOOTSTRAPURL" ]; then
      cd $CONF_DIR_TMP
      if [ ! -f "bootstrap.tar.gz" ] && [[ $BOOTSTRAPURL == *.tar.gz ]]; then
        echo "Downloading bootstrap"
        wget ${BOOTSTRAPURL} -O bootstrap.tar.gz
        WGET=$?
      elif [ ! -f "bootstrap.zip" ] && [[ $BOOTSTRAPURL == *.zip ]]; then
        echo "Downloading bootstrap"
        wget ${BOOTSTRAPURL} -O bootstrap.zip
        WGET=$?
      else
        echo "Bootstrap already exists, skipping download"
      fi

      #if [ $? -eq 0 ]; then
      if [ $WGET -eq 0 ]; then
        echo "Downloading bootstrap successful"
        #cd ~
        cd $CONF_DIR
        echo "Copying BLOCKCHAIN from bootstrap without conf files"
  	    rm -R ./database &> /dev/null
  	    rm -R ./blocks	&> /dev/null
  	    rm -R ./sporks &> /dev/null
  	    rm -R ./chainstate &> /dev/null

        if [[ $BOOTSTRAPURL == *.tar.gz ]]; then
          #mv $CONF_DIR_TMP/blocks_n_chains.tar.gz .
          #tar -xvzf blocks_n_chains.tar.gz
          tar -xvzf $CONF_DIR_TMP/bootstrap.tar.gz -C $CONF_DIR --exclude="*.conf"
          #rm ./blocks_n_chains.tar.gz
        elif [[ $BOOTSTRAPURL == *.zip ]]; then
          #mv $CONF_DIR_TMP/bootstrap.zip .
          #unzip bootstrap.zip
          unzip -o $CONF_DIR_TMP/bootstrap.zip -d $CONF_DIR -x "*.conf"
          #rm ./bootstrap.zip
        fi
      fi

    fi
  fi

  # If stopping is not needed, there is no need to start.
  : << 'STARTPROCESS'
  SYNCNODEPID=`ps -ef | grep -i -w ${NAME}_$SYNCNODEALIAS | grep -i ${NAME}d | grep -v grep | awk '{print $2}'`
  if [ -z "$SYNCNODEPID" ] && [ "$SYNCNODEALIAS" ]; then
    # start node
    echo "Starting $SYNCNODEALIAS."
    #sh ~/bin/${NAME}d_$SYNCNODEALIAS.sh
    systemctl start ${NAME}d_$SYNCNODEALIAS.service
    sleep 2 # wait 2 seconds
  fi
STARTPROCESS

  GETHPID=`ps -ef | grep -i ${NAME} | grep -i -w ${NAME}_${ALIAS} | grep -v grep | awk '{print $2}'`
  PID=`ps -ef | grep -i ${NAME} | grep -i -w ETCMC_GETH | grep -v grep | awk '{print $2}'`
  if [ -z "$PID" ]; then
    # start node
    echo "Starting $ALIAS."
    #sh ~/bin/${NAME}d_$ALIAS.sh
    systemctl start ${NAME}_$ALIAS.service
    sleep 2 # wait 2 seconds
  fi

  if [[ $NODEIP =~ .*:.* ]]; then
    MNCONFIG=$(echo $ALIAS [$PUBIPv6]:$PORT "http://$PUBIPv6:$RPCPORT")
  else
    MNCONFIG=$(echo $ALIAS $PUBIPv4:$PORT "http://$PUBIPv4:$RPCPORT")
  fi
  echo $MNCONFIG >> ~/bin/node_config.txt

  COUNTER=$[COUNTER + 1]
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
