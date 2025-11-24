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

# URL for ETCMC Version check
URL="https://raw.githubusercontent.com/Nowalski/ETCMC_Client-2.0/main/version.json"

# Fetch the webpage content
CONTENT=$(curl -s $URL)

# Extract the version number
VERSION=$(echo "$CONTENT" | jq -r '.Version')

## MAIN
echo
echo "${NAME^^} - Node updater"
echo ""
echo "Welcome to the ${NAME} Node update script."
echo "Node v${VERSION}"
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
  NODEVERSION=$(jq -r '.Version' ${NODECONFDIR}/version.json)

  # Compare the versions using dpkg
  if dpkg --compare-versions "$NODEVERSION" lt "$VERSION"; then
    echo "$NODEALIAS is running a lower node version $NODEVERSION, updating this node to the latest version $VERSION."
  elif [ "$NODEVERSION" = "$VERSION" ]; then
    echo "$NODEALIAS is already running the latest version $VERSION. Skipping this node."
    break
  else
    echo "$NODEALIAS is running $NODEVERSION, this version is unknown or not supported yet."
    break
  fi

  GETHPID=$(ps -ef | grep -i ${NAME} | grep -i -w ${NAME}_${NODEALIAS} | grep -i -w geth | grep -v grep | grep -v bash | awk '{print $2}')
  if [ "$GETHPID" ]; then
    echo "Stopping Geth of Node $NODEALIAS. Please wait ..."
    kill -INT $GETHPID

    # Wait for the process to exit
    while ps -p "$GETHPID" > /dev/null; do
      #echo "Please wait ..."
      sleep 2
    done
  fi

  NODEPID=$(ps -ef | grep -i ${NAME} | grep -i -w ${NAME}_${NODEALIAS} | grep -i -w ETCMC_GETH | grep -v grep | awk '{print $2}' | head -1) # Since version 2.7.0 there are multiple processes, get the first match.
  dpkg --compare-versions $(jq -r '.Version' "$NODECONFDIR/version.json") lt "2.7.0" && NODEPID=$(ps -ef | grep -i ${NAME} | grep -i -w ETCMC_GETH | grep -v grep | awk '{print $2}')
  if [ "$NODEPID" ]; then
    echo "Stopping $NODEALIAS. Please wait ..."
    systemctl stop ${NAME}_$NODEALIAS.service

    # Wait for the process to exit
    while ps -p "$NODEPID" > /dev/null; do
      #echo "Please wait ..."
      sleep 2
    done
  fi

  # Configure config folder
  cd $NODECONFDIR

  echo "Copying files to $NODECONFDIR."
  if [ -d "$CONF_DIR_TMP/update_files_linux" ]; then
    cp -rT $CONF_DIR_TMP/update_files_linux $NODECONFDIR
  else
    cp -rT $CONF_DIR_TMP $NODECONFDIR
  fi

  #Remove update_files_linux folder, sometimes created before applying a fix
  #rm -rf update_files_linux &> /dev/null # Not needed anymore, can be removed on the next cleanup.

  #echo "Checking requirements.txt for new or updated modules."
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
ExecStart=$NODECONFDIR/ETCMC_GETH --port 5000
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
  systemctl enable ${NAME}_$NODEALIAS.service

  GETHPID=$(ps -ef | grep -i ${NAME} | grep -i -w ${NAME}_${NODEALIAS} | grep -i -w geth | grep -v grep | grep -v bash | awk '{print $2}')
  NODEPID=$(ps -ef | grep -i ${NAME} | grep -i -w ${NAME}_${NODEALIAS} | grep -i -w ETCMC_GETH | grep -v grep | awk '{print $2}' | head -1) # Since version 2.7.0 there are multiple processes, get the first match.
  if [ -z "$NODEPID" ]; then
    echo "Starting $NODEALIAS."
    systemctl start ${NAME}_$NODEALIAS.service
  fi
  sleep 2 # wait 2 seconds
done

# Remove Temp folder
rm -rfd $CONF_DIR_TMP

echo "Your nodes are now updated!"
