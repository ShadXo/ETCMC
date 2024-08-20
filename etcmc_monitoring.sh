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
  echo "You need to specify node alias, use -n or --node to do so."
  echo "Example: $0 -p etcmc -n n1"
  exit -1
fi

# GET CONFIGURATION
SETUP_CONF_FILE="./projects/${NAME}/${NAME}.env"
#if [ `wget --spider -q https://raw.githubusercontent.com/ShadXo/DogeCashScripts/master/projects/${NAME}/${NAME}.env` ]; then
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

for FILE in $(ls -d ~/.${NAME}_$ALIAS | sort -V); do
  echo "*******************************************"
  echo "FILE: $FILE"

  echo -e "${YELLOW}Provide the Monitoring ID for node $ALIAS, followed by [ENTER]:${NC}"
  read MONITORINGID

  NODEALIAS=$(echo $FILE | awk -F'[_]' '{print $2}')
  NODECONFDIR=~/.${NAME}_${NODEALIAS}

  mkdir $CONF_DIR_TMP
  cd $CONF_DIR_TMP

  wget ${MONITORSETUPURL} -O setup.tar.gz
  tar -xvf setup.tar.gz

  #HOSTNAME=$(hostname)
  echo "Adding ${MONITORINGID} to etcmcnodemonitoringid.txt"
  echo "${MONITORINGID}" | tr a-z A-Z > Etcmcnodecheck/etcmcnodemonitoringid.txt

  rm setup.tar.gz
  cp -r $CONF_DIR_TMP/* $NODECONFDIR &> /dev/null # Copy files from temp folder to config folder
  rm -rf $CONF_DIR_TMP

  echo "Creating systemd monitoring service for ${NAME}_$NODEALIAS"
  cat << EOF > /etc/systemd/system/${NAME}_$NODEALIAS-monitoring.service
[Unit]
Description=Monitoring Service for ${NAME}_$NODEALIAS
After=network.target
[Service]
User=root
Group=root
Type=simple
WorkingDirectory=$NODECONFDIR/Etcmcnodecheck
ExecStart=sh check-node.sh
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
  systemctl enable ${NAME}_$NODEALIAS-monitoring.service
  echo "Starting systemd monitoring service"
  systemctl start ${NAME}_$NODEALIAS-monitoring.service
done
