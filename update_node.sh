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

# URL of ETCMC
URL="https://etcmc.org"

# Fetch the webpage content
CONTENT=$(curl -s $URL)

# Extract the version number
NODEVERSION=$(echo "$CONTENT" | grep -oP '(?<=class="softwareVersion">)[^<]+' | sed 's/Client version //')

## MAIN
echo
echo "${NAME^^} - Node updater"
echo ""
echo "Welcome to the ${NAME} Node update script."
echo "Node v${NODEVERSION}"
echo

# Create Temp folder
mkdir -p $CONF_DIR_TMP
cd $CONF_DIR_TMP

echo "Downloading the latest update files"
UPDATEURL="https://github.com/Nowalski/ETCMC_Software/releases/download/Setup%2FWindows/update_files_linux.zip"
if [[ $UPDATEURL == *.tar.gz ]]; then
  wget ${UPDATEURL} -O update.tar.gz
  WGET=$?
elif [[ $UPDATEURL == *.zip ]]; then
  wget ${UPDATEURL} -O update.zip
  WGET=$?
fi

if [ $WGET -ne 0 ]; then
  echo -e "${RED}Download failed, check the UPDATEURL.${NC}"
  rm -rfd $CONF_DIR_TMP
  exit 1
fi

if [[ $UPDATEURL == *.tar.gz ]]; then
  #tar -xvzf ${WALLETDL} #-C ${WALLETDLFOLDER}
  tar -xvzf update.tar.gz --exclude="config.toml"
elif [[ $UPDATEURL == *.zip ]]; then
  #unzip ${WALLETDL} #-d ${WALLETDLFOLDER}
  unzip -o update.zip -x "config.toml"
fi

chmod 775 *
#find . -type f -exec mv -t . {} + &> /dev/null # Some coins have files in subfolders
#mv ./bin/${NAME}* /usr/bin
#mv ./bin/${NAME}* /usr/local/bin # previous /usr/bin should be /usr/local/bin
rm update.tar.gz update.zip &> /dev/null

for FILE in $(ls -d ~/.${NAME}_$ALIAS | sort -V); do
  NODEALIAS=$(echo $FILE | awk -F'[_]' '{print $2}')
  NODECONFDIR=~/.${NAME}_${NODEALIAS}
  VERSION=$(jq -r '.Version' ${NODECONFDIR}/version.json)

  # Compare the versions using dpkg
  if dpkg --compare-versions "$VERSION" lt "$NODEVERSION"; then
    echo "$NODEALIAS is running a lower node version $VERSION, updating this node to the latest version $NODEVERSION."
  elif [ "$VERSION" = "$NODEVERSION" ]; then
    echo "$NODEALIAS is already running the latest version $VERSION. Skipping this node."
    break
  else
    echo "$NODEALIAS is running $VERSION, this version is unknown or not supported yet."
    break
  fi

  GETHPID=`ps -ef | grep -i ${NAME} | grep -i -w ${NAME}_${NODEALIAS} | grep -v grep | awk '{print $2}'`
  if [ "$GETHPID" ]; then
    echo "Stopping Geth of Node $NODEALIAS. Please wait ..."
    kill -SIGINT $GETHPID

    # Wait for the process to exit
    while ps -p "$GETHPID" > /dev/null; do
      #echo "Please wait ..."
      sleep 2
    done
  fi

  NODEPID=`ps -ef | grep -i ${NAME} | grep -i -w ETCMC_GETH | grep -v grep | awk '{print $2}'`
  if [ "$NODEPID" ]; then
    echo "Stopping $NODEALIAS. Please wait ..."
    systemctl stop ${NAME}_$NODEALIAS.service

    # Wait for the process to exit
    while ps -p "$NODEPID" > /dev/null; do
      #echo "Please wait ..."
      sleep 2
    done
  fi

  echo "Copying update files to $NODECONFDIR."
  if [ -d "update_files_linux" ]; then
    cp -r update_files_linux/* $NODECONFDIR
  else
    cp -r * $NODECONFDIR
  fi

  #Remove update_files_linux folder, sometimes created before applying a fix
  rm -rf $NODECONFDIR/update_files_linux &> /dev/null

  echo "Checking requirements.txt for new or updated modules."
  pip3 install -r $NODECONFDIR/requirements.txt --break-system-packages

  # Set permissions for files
  echo "Setting permissions for files..."
  chmod +x $NODECONFDIR/Linux.py $NODECONFDIR/ETCMC_GETH.py $NODECONFDIR/updater.py $NODECONFDIR/geth

  echo "Creating systemd service for ${NAME}_$NODEALIAS to shutdown geth"
  cat << EOF > /etc/systemd/system/${NAME}_$NODEALIAS-geth.service
[Unit]
Description=Service for ${NAME}_$NODEALIAS to shutdown geth
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=pkill -SIGINT -f ${NAME}_$NODEALIAS/geth

[Install]
WantedBy=halt.target reboot.target shutdown.target
EOF

echo "Updating systemd service for ${NAME}_$NODEALIAS"
cat << EOF > /etc/systemd/system/${NAME}_$NODEALIAS.service
[Unit]
Description=Node Service for ${NAME}_$NODEALIAS
After=network.target

[Service]
User=root
Group=root
Type=simple
WorkingDirectory=$NODECONFDIR
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
  systemctl enable ${NAME}_$NODEALIAS-geth.service

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
