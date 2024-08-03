#!/bin/bash

##
##
##

RED='\033[1;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
BROWN='\033[0;33m'
CYAN='\033[0;36m'
LIGHTCYAN='\033[1;36m'
NC='\033[0m' # No Color

## Black        0;30     Dark Gray     1;30
## Red          0;31     Light Red     1;31
## Green        0;32     Light Green   1;32
## Brown/Orange 0;33     Yellow        1;33
## Blue         0;34     Light Blue    1;34
## Purple       0;35     Light Purple  1;35
## Cyan         0;36     Light Cyan    1;36
## Light Gray   0;37     White         1;37

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

PROJECT=$NAME
if [ -z "$PROJECT" ]; then
  PROJECT="etcmc"
fi

if [ "$PROJECT" == "etcmc" ]; then
  MAINCOLOR=$GREEN
  ACCENTCOLOR=$GREEN
else
  MAINCOLOR=$RED
  ACCENTCOLOR=$LIGHTCYAN
fi

# Run upgrade service
#wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/upgrade_service.sh -O upgrade_service.sh > /dev/null 2>&1
#chmod 777 upgrade_service.sh
#dos2unix upgrade_service.sh > /dev/null 2>&1
#/bin/bash ./upgrade_service.sh -p $PROJECT

center() {
  #termwidth="$(tput cols)"
  termwidth=51
  padding="$(printf '%0.1s' *{1..500})"
  printf '%*.*s %s %*.*s\n' 0 "$(((termwidth-2-${#1})/2))" "$padding" "$1" 0 "$(((termwidth-1-${#1})/2))" "$padding"
}

echo && echo
#echo "******** Powered by the DogeCash Community ********"
echo "*************** Powered by ETCMC ******************"
echo "*************** https://etcmc.org *****************"
echo "***************************************** v0.1.0 **"
#echo "******************** ${PROJECT^^} *********************"
center ${PROJECT^^}
echo "******************** MAIN MENU ********************"
echo ""
echo -e "${MAINCOLOR}1) LIST ALL NODES" # -> etcmc_LIST.SH" # OK
echo -e "2) CHECK NODES SYNC (NOTDONEYET)" #  -> etcmc_CHECK_SYNC.SH" # OK
echo -e "3) RESYNC NODES THAT ARE OUT OF SYNC (NOTDONEYET)" #  -> etcmc_CHECK_RESYNC_ALL.SH" # OK
echo -e "4) (RE-)START NODES" #  -> etcmc_RESTART.SH" # OK
echo -e "5) STOP NODES" #  -> etcmc_STOP.SH" # OK
echo -e "6) INSTALL NEW NODES" #  -> etcmc_SETUP.SH" # OK
echo -e "7) CHECK NODES STATUS (NOTDONEYET)" #  -> etcmc_CHECK_STATUS.SH" # OK
echo -e "8) RESYNC SPECIFIC NODE (useful if node is stopped) (NOTDONEYET)" # -> etcmc_RESYNC.sh # OK
echo -e "9) REMOVE SPECIFIC NODE (NOTDONEYET)" # -> etcmc_REMOVE.sh # OK
echo -e "10) UPDATE NODE WALLET (NOTDONEYET)" # -> UPDATE_WALLET.sh # OK
echo -e "11) UPDATE WALLET ADDNODES (NOTDONEYET)" # -> UPDATE_ADDNODES.sh # OK
echo -e "12) NODE INFO (DO NOT SHARE WITHOUT REMOVING PRIVATE INFO) (NOTDONEYET)" # -> etcmc_info.sh # OK
echo -e "13) FORK FINDER (NOTDONEYET)" # -> find_fork.sh # OK
echo -e "14) SETUP ETCMC NODECHECK" # -> etcmc_MONITORING.sh # OK
echo -e "15) CALCULATE FREE MEMORY AND CPU FOR NEW NODES" # -> memory_cpu_sysinfo.sh # OK
echo -e "${ACCENTCOLOR}16) ETCMC LOGO (NOTDONEYET)" # DOGECASH LOGO
echo -e "${MAINCOLOR}0) EXIT${NC}" # OK
echo "---------------------------------------------------"
echo "Choose an option:"
read OPTION
# echo ${OPTION}
ALIAS=""

clear

case $OPTION in
    1)
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/etcmc_list.sh -O etcmc_list.sh > /dev/null 2>&1
        chmod 777 etcmc_list.sh
        dos2unix etcmc_list.sh > /dev/null 2>&1
        /bin/bash ./etcmc_list.sh -p $PROJECT
        ;;
    2)
        echo -e "${MAINCOLOR}Which node do you want to check if synced? Enter alias (if empty it will run on all nodes)${NC}"
        read ALIAS
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/etcmc_check_sync.sh -O etcmc_check_sync.sh > /dev/null 2>&1
        chmod 777 etcmc_check_sync.sh
        dos2unix etcmc_check_sync.sh > /dev/null 2>&1
        /bin/bash ./etcmc_check_sync.sh -p $PROJECT -n $ALIAS
        ;;
    3)
        echo -e "${MAINCOLOR}Which node do you want to check sync and resync? Enter alias (if empty it will run on all nodes)${NC}"
        read ALIAS
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/etcmc_check_resync_all.sh -O etcmc_check_resync_all.sh > /dev/null 2>&1
        chmod 777 etcmc_check_resync_all.sh
        dos2unix etcmc_check_resync_all.sh > /dev/null 2>&1
        /bin/bash ./etcmc_check_resync_all.sh -p $PROJECT -n $ALIAS
        ;;
    4)
        echo -e "${MAINCOLOR}Which node do you want to (re-)start? Enter alias (if empty it will run on all nodes)${NC}"
        read ALIAS
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/etcmc_restart.sh -O etcmc_restart.sh > /dev/null 2>&1
        chmod 777 etcmc_restart.sh
        dos2unix etcmc_restart.sh > /dev/null 2>&1
        /bin/bash ./etcmc_restart.sh -p $PROJECT -n $ALIAS
        ;;
    5)
        echo -e "${MAINCOLOR}Which node do you want to stop? Enter alias (if empty it will run on all nodes)${NC}"
        read ALIAS
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/etcmc_stop.sh -O etcmc_stop.sh > /dev/null 2>&1
        chmod 777 etcmc_stop.sh
        dos2unix etcmc_stop.sh > /dev/null 2>&1
        /bin/bash ./etcmc_stop.sh -p $PROJECT -n $ALIAS
        ;;
    6)
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/etcmc_setup.sh -O etcmc_setup.sh > /dev/null 2>&1
        chmod 777 etcmc_setup.sh
        dos2unix etcmc_setup.sh > /dev/null 2>&1
        /bin/bash ./etcmc_setup.sh -p $PROJECT
        ;;
    7)
        echo -e "${MAINCOLOR}For which node do you want to check masternode status? Enter alias (if empty it will run on all nodes)${NC}"
        read ALIAS
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/etcmc_check_status.sh -O etcmc_check_status.sh > /dev/null 2>&1
        chmod 777 etcmc_check_status.sh
        dos2unix etcmc_check_status.sh > /dev/null 2>&1
        /bin/bash ./etcmc_check_status.sh -p $PROJECT -n $ALIAS
        ;;
    8)
        echo -e "${MAINCOLOR}Which node do you want to resync? Enter alias (mandatory!)${NC}"
        read ALIAS
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/etcmc_resync.sh -O etcmc_resync.sh > /dev/null 2>&1
        chmod 777 etcmc_resync.sh
        dos2unix etcmc_resync.sh > /dev/null 2>&1
        /bin/bash ./etcmc_resync.sh -p $PROJECT -n $ALIAS
        ;;
    9)
        echo -e "${MAINCOLOR}Which node do you want to remove? Enter alias (mandatory!)${NC}"
        read ALIAS
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/etcmc_remove.sh -O etcmc_remove.sh > /dev/null 2>&1
        chmod 777 etcmc_remove.sh
        dos2unix etcmc_remove.sh > /dev/null 2>&1
        /bin/bash ./etcmc_remove.sh -p $PROJECT -n $ALIAS
        ;;
    10)
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/update_node.sh -O update_node.sh > /dev/null 2>&1
        chmod 777 update_node.sh
        dos2unix update_node.sh > /dev/null 2>&1
        /bin/bash ./update_node.sh -p $PROJECT
        ;;
    11)
        echo -e "${MAINCOLOR}For which node do you want the addnodes updated? Enter alias (if empty it will run on all nodes)${NC}"
        read ALIAS
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/update_addnodes.sh -O update_addnodes.sh > /dev/null 2>&1
        chmod 777 update_addnodes.sh
        dos2unix update_addnodes.sh > /dev/null 2>&1
        /bin/bash ./update_addnodes.sh -p $PROJECT -n $ALIAS
        ;;
    12)
        echo -e "${MAINCOLOR}For which node do you want to get info? Enter alias (if empty it will run on all nodes)${NC}"
        read ALIAS
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/etcmc_info.sh -O etcmc_info.sh > /dev/null 2>&1
        chmod 777 etcmc_info.sh
        dos2unix etcmc_info.sh > /dev/null 2>&1
        /bin/bash ./etcmc_info.sh -p $PROJECT -n $ALIAS
        ;;
    13)
        echo -e "${MAINCOLOR}On which node do you want to check for a fork? Enter alias (mandatory!)${NC}"
        read NODE
        echo -e "${MAINCOLOR}Start checking from block? (mandatory!)${NC}"
        read BLOCK
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/find_fork.sh -O find_fork.sh > /dev/null 2>&1
        chmod 777 find_fork.sh
        dos2unix find_fork.sh > /dev/null 2>&1
        /bin/bash ./find_fork.sh -p $PROJECT -n $NODE -b $BLOCK
        ;;
    14)
        echo -e "${MAINCOLOR}For which node do you want to setup the ETCMC Nodecheck? Enter alias (mandatory!)${NC}"
        read NODE
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/etcmc_monitoring.sh -O etcmc_monitoring.sh > /dev/null 2>&1
        chmod 777 etcmc_monitoring.sh
        dos2unix etcmc_monitoring.sh > /dev/null 2>&1
        /bin/bash ./etcmc_monitoring.sh -p $PROJECT -n $NODE
        ;;
    15)
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/memory_cpu_sysinfo.sh -O memory_cpu_sysinfo.sh > /dev/null 2>&1
        chmod 777 memory_cpu_sysinfo.sh
        dos2unix memory_cpu_sysinfo.sh > /dev/null 2>&1
        /bin/bash ./memory_cpu_sysinfo.sh
        ;;
    16)
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/etcmc_logo.sh -O etcmc_logo.sh > /dev/null 2>&1
        chmod 777 etcmc_logo.sh
        dos2unix etcmc_logo.sh > /dev/null 2>&1
        /bin/bash ./etcmc_logo.sh
        ;;
    0)
        exit 0
        ;;
    50)
        wget https://raw.githubusercontent.com/ShadXo/ETCMC/master/etcmc_setupv1-f.sh -O etcmc_setupv1-f.sh > /dev/null 2>&1
        chmod 777 etcmc_setupv1-f.sh
        dos2unix etcmc_setupv1-f.sh > /dev/null 2>&1
        /bin/bash ./etcmc_setupv1-f.sh
        ;;
    *) echo "Invalid option $OPTION";;
esac

###
read -n 1 -s -r -p "***** Press any key to go back to the ${PROJECT^^} MAIN MENU *****"
/bin/bash ./etcmc.sh -p $PROJECT
