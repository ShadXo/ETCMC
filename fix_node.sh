#!/bin/bash

# Execute getopt
ARGS=$(getopt -o "p:n:" -l "project:,node:" -n "$0" -- "$@");

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
        -n |--node)
            shift;
                    if [ -n "$1" ];
                    then
                        ALIAS="$1";
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

if [ -z "$ALIAS" ]; then
  ALIAS="*"
else
  ALIAS=${ALIAS,,}
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
  echo "No setup env file found, create one at the following location: ./projects/${NAME}/${NAME}.env"
  exit 1
fi

## MAIN
echo
echo "${NAME^^} - Node updater"
echo ""
echo "Welcome to the ${NAME} Node update script."
echo "Wallet v${NODEVERSION}"
echo

for FILE in $(ls -d ~/.${NAME}_$ALIAS | sort -V); do
  NODEALIAS=$(echo $FILE | awk -F'[_]' '{print $2}')

  GETHPID=`ps -ef | grep -i ${NAME} | grep -i -w ${NAME}_${NODEALIAS} | grep -v grep | awk '{print $2}'`
  if [ "$GETHPID" ]; then
    echo "Stopping Geth of Node $NODEALIAS. Please wait ..."
    kill -SIGINT $GETHPID
  fi

  # Wait for the process to exit
  while ps -p "$GETHPID" > /dev/null; do
    #echo "Please wait ..."
    sleep 2
  done

  NODEPID=`ps -ef | grep -i ${NAME} | grep -i -w ETCMC_GETH | grep -v grep | awk '{print $2}'`
  if [ "$NODEPID" ]; then
    echo "Stopping $NODEALIAS. Please wait ..."
    systemctl stop ${NAME}_$NODEALIAS.service
  fi

  # Wait for the process to exit
  while ps -p "$NODEPID" > /dev/null; do
    #echo "Please wait ..."
    sleep 2
  done
done

# Create Temp folder
mkdir -p $CONF_DIR_TMP
cd $CONF_DIR_TMP

echo "Downloading Geth v1.12.19 "
GETHURL="https://github.com/etclabscore/core-geth/releases/download/v1.12.19/core-geth-linux-v1.12.19.zip"
if [[ $GETHURL == *.tar.gz ]]; then
  wget ${GETHURL} -O geth.tar.gz
  WGET=$?
elif [[ $GETHURL == *.zip ]]; then
  wget ${GETHURL} -O geth.zip
  WGET=$?
fi

if [ $WGET -ne 0 ]; then
  echo -e "${RED}Wallet download failed, check the WALLETURL.${NC}"
  rm -rfd $CONF_DIR_TMP
  exit 1
fi

if [[ $GETHURL == *.tar.gz ]]; then
  #tar -xvzf ${WALLETDL} #-C ${WALLETDLFOLDER}
  tar -xvzf geth.tar.gz
elif [[ $GETHURL == *.zip ]]; then
  #unzip ${WALLETDL} #-d ${WALLETDLFOLDER}
  unzip -o geth.zip
fi

chmod 775 *
#find . -type f -exec mv -t . {} + &> /dev/null # Some coins have files in subfolders
#mv ./bin/${NAME}* /usr/bin
#mv ./bin/${NAME}* /usr/local/bin # previous /usr/bin should be /usr/local/bin
rm setup.tar.gz setup.zip &> /dev/null

for FILE in $(ls -d ~/.${NAME}_$ALIAS | sort -V); do
  NODEALIAS=$(echo $FILE | awk -F'[_]' '{print $2}')
  NODECONFDIR=~/.${NAME}_${NODEALIAS}

  echo "Copying geth to $NODECONFDIR."
  cp geth $NODECONFDIR

  GETHPID=`ps -ef | grep -i ${NAME} | grep -i -w ${NAME}_${NODEALIAS} | grep -v grep | awk '{print $2}'`
  NODEPID=`ps -ef | grep -i ${NAME} | grep -i -w ETCMC_GETH | grep -v grep | awk '{print $2}'`
  if [ -z "$NODEPID" ]; then
    echo "Starting $NODEALIAS."
    systemctl start ${NAME}_$NODEALIAS.service
  fi
  sleep 2 # wait 2 seconds
done

# Remove Temp folder
rm -rfd $CONF_DIR_TMP

echo "Your nodes are now updated!"
