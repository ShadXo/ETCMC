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

for FILE in $(ls -d ~/.${NAME}_$ALIAS | sort -V); do
  echo "*******************************************"
  echo "FILE: $FILE"

  NODEALIAS=$(echo $FILE | awk -F'[_]' '{print $2}')
  NODECONFDIR=~/.${NAME}_${NODEALIAS}
  echo CONF DIR: $NODECONFDIR

  echo "Node $NODEALIAS will be deleted when this timer reaches 0"
  seconds=10
  date1=$(( $(date -u +%s) + seconds));
  echo "Press ctrl-c to stop"
  while [ "${date1}" -ge "$(date -u +%s)" ]
  do
    echo -ne "$(date -u --date @$(( date1 - $(date -u +%s) )) +%H:%M:%S)\r";
  done

  GETHPID=`ps -ef | grep -i ${NAME} | grep -i -w ${NAME}_${NODEALIAS} | grep -v grep | awk '{print $2}'` # Correct for geth
  NODECHECKPID=`ps -ef | grep -i "sh check-node.sh" | grep -v grep | awk '{print $2}'` # Correct for ETCMC Nodecheck
  if [ "$NODECHECKPID" ]; then
    echo "Stopping $NODEALIAS monitoring. Please wait ..."
    systemctl stop ${NAME}_$NODEALIAS.service
  fi

  NODEPID=`ps -ef | grep -i ${NAME} | grep -i -w ETCMC_GETH | grep -v grep | awk '{print $2}'` # Correct for ETCMC_GETH
  if [ "$NODEPID" ]; then
    echo "Stopping $NODEALIAS. Please wait ..."
    systemctl stop ${NAME}_$NODEALIAS.service
  fi

  # Wait for the processes to exit
  while ps -p "$NODEPID" > /dev/null || ps -p "$NODECHECKPID" > /dev/null; do
    #echo "Please wait ..."
    sleep 2
  done

  echo "Removing conf folder"
  rm -rdf $NODECONFDIR

  echo "Removing systemd service"
  rm /etc/systemd/system/${NAME}_$NODEALIAS-monitoring.service
  rm /etc/systemd/system/${NAME}_$NODEALIAS.service
  systemctl daemon-reload

  echo "Node $NODEALIAS removed"
done
