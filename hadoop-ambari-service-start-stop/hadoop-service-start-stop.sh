#!/bin/bash
#################################################################################
#Purpose : Script will stop and start hortonworks hadoops services using ambari #
# Intial Development by :  manoj.babu.malapati                                  #
# Improvment By : kamal.maiti                                                   #
# Maintained By : DIS DEVOPS Team.                                              #
#Change log :                                                                   #                                                                #
#################################################################################

#Take in put from CLI : amabari host,port, ambari admin username and password, cluster name.
red='\033[0;31m'
green='\033[0;32m'
nc='\033[0m'
bold=`tput bold`
normal=`tput sgr0`
PORT=8080
#Take some global variable
declare -a NODELIST
declare -a ALLSERVICES
MASTERNODE="dummy"
usage(){             #Help function to provide details on how to use this script
cat << EOF
options :
        -a  action You'll perform. ie status, check start, stop, restart
        -n  Ambari host. Only fqdn name or IP address
        -u  Amabari admin user. Default admin
        -p  Ambari Admin password. Default is admin
        -c  Cluster Name. Name of cluster name.
example :
sh <scriptname.sh> -a status -n localhost -u admin -p admin -c mytest
EOF
}

#Process argument
OPTIND=1                                                        #Intitialize OPTIND variable for getopts
while getopts "ha:n:u:p:c:" FLAG                                      #Processing all arguments
   do
    case "$FLAG" in
        h|\?)
                usage
                exit 0
                ;;
        a)
                ACTION=$OPTARG
                ;;
        n)
                AMBARIHOST=$OPTARG
                ;;
        u)
                ADMINUSER="$OPTARG"
                ;;
        p)
                ADMINPW=$OPTARG
                ;;
        c)
                CLUSTER="$OPTARG"
                ;;
        *)
                usage
                exit 0
                ;;
   esac
  done

if [[ -z "$ACTION" || -z "$AMBARIHOST"  || -z "$CLUSTER" ]];then                           #validate variables. Exit if not passed value
usage && exit 0
fi

if [ -z $ADMINUSER ]; then
  ADMINUSER=admin
fi
if [ -z $ADMINPW ]; then
  ADMINPW=admin
fi

get_all_nodes() {
op=$(curl --silent -u ${ADMINUSER}:${ADMINPW} http://${AMBARIHOST}:${PORT}/api/v1/clusters/${CLUSTER}/hosts|jq '.items[].Hosts.host_name'|sed 's/"//g')

 j=0;
 for i in `echo $op`
  do
   NODELIST[$j]=$i
   j=$(( j + 1 ))
 done
}

get_all_services() {

services=$(curl --silent -u ${ADMINUSER}:${ADMINPW} -X GET http://${AMBARIHOST}:${PORT}/api/v1/clusters/${CLUSTER}/services|jq '.items[].ServiceInfo.service_name'|sed 's/"//g')
 j=0;
 for i in `echo $services`
  do
   ALLSERVICES[$j]=$i
   j=$(( j + 1 ))
 done
}

check_services(){
 get_all_services
 j=0;
 for SERVICE in "${ALLSERVICES[@]}"
  do
        STATUS=$(curl --silent -u ${ADMINUSER}:${ADMINPW} -X GET  http://${AMBARIHOST}:${PORT}/api/v1/clusters/${CLUSTER}/services/${SERVICE}?fields=ServiceInfo|jq '.ServiceInfo.state'|sed 's/"//g')
        if [ $STATUS == "STARTED" ] ; then
           echo -e "$SERVICE : $green$STATUS$nc\n"
        else
           echo -e "$SERVICE : $red$STATUS$nc\n"
         fi
        j=$(( j + 1 ))
 done
}

start_services_on_node() {
 get_all_nodes
j=0;
for NODE in "${NODELIST[@]}"
 do
  if  egrep -q "edge|master|hname1" <<<$NODE; then
   MASTERNODE=$NODE
  fi
done

 start_services_on_master
 sleep 600
 j=0;
 for NODE in "${NODELIST[@]}"
 do
  if ! egrep -q "edge|master|hname1" <<<$NODE; then
   start $NODE
  fi
  j=$(( j + 1 ))
 done
}

stop_services_on_node() {
 get_all_nodes
 j=0;
 for NODE in "${NODELIST[@]}"
  do
   if ! egrep -q "edge|master|hname1" <<<$NODE; then
    stop $NODE
   else
   MASTERNODE=$NODE
   fi;
   j=$(( j + 1 ))
  done
  sleep 600
  stop_services_on_master
}

start() {

HOST_NAME=$1
#echo "GOT: $HOST_NAME"
curl --silent -u ${ADMINUSER}:${ADMINPW} -H "X-Requested-By: ambari" -X PUT -d '{"RequestInfo":{"context":"Start All Host Compnents","operation_level": {"level":"HOST","cluster_name":"'${CLUSTER}'", "host_names":"'${HOST_NAME}'"},"query":"HostRoles/component_name/*"}, "Body": {"HostRoles": {"state":"STARTED"}}}' http://${AMBARIHOST}:${PORT}/api/v1/clusters/${CLUSTER}/hosts/${HOST_NAME}/host_components

}

stop() {
HOST_NAME=$1
#echo "GOT: $HOST_NAME"
curl --silent -u ${ADMINUSER}:${ADMINPW}  -H "X-Requested-By: ambari" -X PUT -d '{"RequestInfo":{"context":"Stopping All Host Components","operation_level": {"level":"HOST","cluster_name":"'${CLUSTER}'", "host_names":"'${HOST_NAME}'"},"query":"HostRoles/component_name/*"}, "Body": {"HostRoles": {"state":"INSTALLED"}}}' http://${AMBARIHOST}:${PORT}/api/v1/clusters/${CLUSTER}/hosts/${HOST_NAME}/host_components

}

start_services_on_master() {
start $MASTERNODE
}
stop_services_on_master() {
stop $MASTERNODE
}


case "$ACTION" in
    start)
       start_services_on_node
       ;;
    stop)
       stop_services_on_node
       ;;
    restart)
       stop_services_on_node
       start_services_on_node
       ;;
    check)
       check_services
        ;;
    status)
       check_services
        ;;
    *)
       echo "Usage: $0 {start|stop|status|check|restart}"
esac

exit 0
