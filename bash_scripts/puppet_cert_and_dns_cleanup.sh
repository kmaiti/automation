#!/bin/bash
#################################################################################
#Purpose: This script will periodically clean up dead host from puppet master   #
#        remove DNS entries from its AD DNS server. Script compares signed host #
#       in puppet with available instances in aws in a particular region.       #
#       If host is listed in aws, then it does nothing else it does cleanup job #
#Running Environment: Puppet Master in aws                                      #
#Prequisites :  1. Puppet master will have https connectivity to ec2 endpoint.  #
#               2. Read-only access credentials for aws account. This is        #
#               mentioned in /root/.aws/credentials under default               #
#History:                                                                       #
#       Adam Glasman: 08/Sept/2015: v2: added Kerberos ktab for nsupdate user.  #
#       kamal maiti:14/Dec/2015: v3 : 1. Added REGION, INSTANCES to fetch       #
#       instances from aws. Added comparion logic using echo "$INSATNCES"       #
#       kamal maiti: 22/Dec/2015: v4: Added Email Alerting option.              #
#       kamal maiti: 24/Dec/2015: v4: Added cache key var to delete proper key  #
#                                instead all key.                               #
#       kamal maiti: 28/Dec/2015: v5: Added functions for dynamically look 4    #
#               AD_DNS                                                          #
#################################################################################

SIGNED='/var/lib/puppet/ssl/ca/signed'
DNSFILE=`mktemp`
TODAY=`date +\%Y\%m\%d`
LOG_FILE="/var/log/puppet/cleanupdata.$TODAY.log"
KTAB='/root/utilscripts/nsupdateuserdub1.keytab'
#Dynamically take value of SERVER and KUSER. Only statically put keytab file

AD_USER="nsupdate"
DNS_SERVER=""
DNSDOMAIN=`/bin/dnsdomainname`
if [ -z $DNSDOMAIN ]
 then
        exit 1
 else
CAPDNSDOMAIN=`echo $DNSDOMAIN|/usr/bin/tr '[a-z0-9]' '[A-Z0-9]'`
fi
KUSER="$AD_USER@$CAPDNSDOMAIN"
REGION=""
INSTANCES=""
AWS_BIN="/usr/local/bin/aws"
#/usr/local/bin/aws
MAIL_FROM="syseng@example.com"
#MAIL_TO_SENT="kamal.maiti@example.com"
MAIL_TO_SENT="syseng@example.com"
MAIL_BIN=$(which mail)
MESSAGE_FILE=`mktemp`
HOST=$(hostname -f)
MAIL_SUBJECT="Cleaning up following host from puppet & DNS - script ran on ${HOST}"

#Function for sending alerts
send_alert() {
#usage :
#send_alert <from> <to> <subject> <messagefile>
FROM=$1
TO=$2
SUBJECT=$3
MESSAGE_FILE=$4

if [ $# -ne 4 ]; then
  echo "Please pass correct number of arguments to send_alert " >> $LOG_FILE
         exit 10
 fi

(
echo "From: $FROM "
echo "To: $TO "
echo "MIME-Version: 1.0"
echo "Subject: $SUBJECT"
echo "Content-Type: text/html"
cat $MESSAGE_FILE
) | /usr/sbin/sendmail -t
}  ## END OF SEND_ALERT ##

#Function for validating domain names
function validate_domain() {                                                             #validate domain name passed to script
        echo $1 | grep -P '(?=^.{5,254}$)(^(?:(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+\.(?:[a-z]{2,})$)' &>/dev/null
        if [ $? -eq 0 ];then
                 return 0
         else
                echo
                echo -e "Domain \"$1\" IS NOT VALID: $red [FAILED] ${nc}" |tee -a $LOG
                return 1
        fi
}

#Function to find out available AD DNS server.
function available_dnsserver() {

        if [ $# -ne 1 ]; then
                echo -e "Number of argument passed to function is not matched" |tee -a $LOG
                exit 10
        else
                DOMAIN=$1
                DOMAIN_IPS=$(dig $DOMAIN +short -t A +time=5 +retry=3)
                if [[ ! -z $DOMAIN_IPS ]]; then
                        while read ip
                                do
                                        check_ping $ip
                                        if [ $? -eq 0 ]; then
                                            DNS_SERVER=$ip
                                            echo -e "Got available DNS server IP: $DNS_SERVER"|tee -a $LOG
                                            break;
                                        else
                                          continue

                                        fi
                                done <<< "$DOMAIN_IPS"
                fi
        fi


}

#Function to check if AD DNS is pinging or not
function check_ping() {

        if [ $# -ne 1 ]; then
                echo -e "Number of argument passed to function is not matched" |tee -a $LOG
                exit 10
        else
                IP=$1
                validate_ip $IP
                if [[ $? -eq 0 ]]; then
                  ping -c1 $IP >/dev/null
                     if [ $? -eq 0 ]; then
                          return 0
                        else
                           echo -e "Unable to ping IP address $IP"|tee -a $LOG
                           return 1
                     fi
                 else
                   echo -e "$IP address is not valid" |tee -a $LOG
                   return 1

                fi
        fi

}
#Function to validate IP address
function validate_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}



if validate_domain $DNSDOMAIN;                                                          #validate domainname
    then
       echo -e "Validating domain $DOM :  [OK]" |tee -a $LOG
       ##call available_dnsserver
        available_dnsserver $DNSDOMAIN
#        echo -e "IP : $DNS_SERVER"
        if [[ -z $DNS_SERVER ]]; then
                echo -e "I couldnt find DNS server IP. Current value is :$DNS_SERVER"|tee -a $LOG
                exit 1
         else
                echo -e "FOUND Aavailable DNS Server. It is : $DNS_SERVER"|tee -a $LOG
                SERVER=$DNS_SERVER
        fi

   else

        echo -e "Validating domain $DOM : [FAILED]" |tee -a $LOG
        exit 1;
fi


#Get Region Name
REGION=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document|grep region|awk -F\" '{print $4}'`
#Get all running or stopped instances including csr, windows, linux etc that run as instances
INSTANCES=$(${AWS_BIN} ec2 describe-instances --output text --region $REGION |  egrep  "^TAG.*.Name"|awk '{print $NF}')
echo -e "\n=======================================  "`date`"  =======================================" >> $LOG_FILE

if [[ -z ${REGION} ||  -z ${INSTANCES} || -z $SERVER ]]; then
   echo -e "Either Region, Instances or AD_DNS_SERVERS are not found" >> $LOG_FILE
    exit 1;
 else

for HOST in $(ls $SIGNED|egrep -vi "prod-util-|uat-util" | /bin/cut  -d . -f -4)
    do
   #Check if HOST has any value.
     if [[ -z ${HOST} ]]; then
        echo -e "Variable HOST doesn't have any value"|tee -a $LOG
        exit 1;
     else
        echo "$INSTANCES"|egrep -iq $HOST
        if [[ $? -ne '0' ]]
            then
                  #Instance does not exist on AWS. We'll clean this instance.
#               echo " HOST NOT FOUND $HOST"

                echo "Puppet Cert CLEAN: $HOST" | tee -a  $LOG_FILE
             #    /usr/bin/puppet cert clean $HOST
                 #Clean know host entry from local cache
              #   /usr/bin/ssh-keygen -R $HOST
                 echo "update delete $HOST" >> $DNSFILE
                echo "<br>Host NOT Found in AWS : <font color="red">$HOST </font></br>" >>$MESSAGE_FILE
            else
#                  echo "Host Found: $HOST"
#               echo "<br>Host  Found in AWS : <font color="red">$HOST </font></br>" >>$MESSAGE_FILE
                   echo "Host Found: $HOST" | tee -a  $LOG_FILE
       fi
    fi
 done
#Trigger Alert
                if [[ -f ${MESSAGE_FILE} && -s ${MESSAGE_FILE} ]];then
                        IFS='%'      #Used to preserve space in MAIL_SUBJECT
               #     send_alert $MAIL_FROM $MAIL_TO_SENT $MAIL_SUBJECT $MESSAGE_FILE
                        unset IFS    #unset variable

                     fi


fi
# Clean DNS Entry

if [ -s "$DNSFILE" ]; then
  if [ $(id -u) == 0 ]; then
       # Use the Kerberos key tab to authenticate against AD
       /usr/bin/kinit -k -t $KTAB $KUSER

       echo "server $SERVER" >> $DNSFILE
       echo "send" >> $DNSFILE
      # /usr/bin/nsupdate -g $DNSFILE
       echo "DNS cleanup:" >> $LOG_FILE
       cat $DNSFILE >> $LOG_FILE
        cache_key=`/usr/bin/klist -l|grep -i nsupdate|awk '{print $NF}'`
        /usr/bin/kdestroy -c $cache_key
      # kdestroy
   fi
fi


# Delete temp file
rm -f $DNSFILE
rm -f $MESSAGE_FILE
# Clean up 14 days old log files
find /var/log/puppet/ -name "cleanup*\.log" -mtime +14 -exec rm -f {} \;
################################## EOF ######################################
