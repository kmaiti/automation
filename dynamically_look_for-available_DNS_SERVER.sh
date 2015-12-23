#!/bin/bash
#########################################################################################
# Purpose: Script will dynamically lookup for available DNS server IP.                  #
# Prerequisites : Should be run on linux system.                                        #
# By : kamalma: dated : 23/Dec/2015                                                     #
# History :                                                                             #
#                                                                                       #
#########################################################################################
DNS_SERVER=""
DNSDOMAIN=`dnsdomainname`
ME=${0##*/}   # Returns script name
LOG="/tmp/mylog.log"

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
         else
                echo -e "FOUND Aavailable DNS Server. It is : $DNS_SERVER"|tee -a $LOG

        fi

   else

        echo -e "Validating domain $DOM : [FAILED]" |tee -a $LOG
fi

##Cleanup log file

rm -f $LOG

#############################  END OF SCRIPT ##########################

