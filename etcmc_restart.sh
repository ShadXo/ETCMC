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

for FILE in $(ls -d ~/.${NAME}_$ALIAS | sort -V); do
  echo "*******************************************"
  echo "FILE: $FILE"

  NODEALIAS=$(echo $FILE | awk -F'[_]' '{print $2}')

  GETHPID=`ps -ef | grep -i ${NAME} | grep -i -w ${NAME}_${NODEALIAS} | grep -v grep | grep -v bash | awk '{print $2}'`
  if [ "$GETHPID" ]; then
    echo "Stopping Geth of Node $NODEALIAS. Please wait ..."
    kill -INT $GETHPID

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

  NODEPID=`ps -ef | grep -i ${NAME} | grep -i -w ETCMC_GETH | grep -v grep | awk '{print $2}'`
  if [ -z "$NODEPID" ]; then
    echo "Starting $NODEALIAS."
    systemctl start ${NAME}_$NODEALIAS.service
  fi
  sleep 2 # wait 2 seconds

  #NODEPID=`ps -ef | grep -i -w ${NAME}_$NODEALIAS | grep -i ${NAME}d | grep -v grep | awk '{print $2}'`
  NODEPID=`ps -ef | grep -i -w ETCMC_GETH | grep -v grep | awk '{print $2}'`
  echo "NODEPID="$NODEPID
done
