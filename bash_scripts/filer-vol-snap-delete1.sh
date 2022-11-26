#!/bin/bash
#################################################################################################################
# Description : Script will be used to delete snap of volumes on netapp filer. This will create                 #
# "expect4filer.sh" if doesn't exist & validate content.                                                        #
# Developed By : Kamal Maiti. E-mail : kamal.maiti@gmail.com                                                    #
# Prerequisites :                                                                                               #
#               1. expect should be installed.                                                                  #
#               2. users should be able to directly connect to Netapp filer from local linux workstattion       #
#HISTORY/Revesion : 1.                                                                                          #
#                                                                                                               #
#################################################################################################################

red='\033[0;31m'
green='\033[0;32m'
nc='\033[0m'
bold=`tput bold`
normal=`tput sgr0`
expect_file="expect4filer.sh"
temp_expect_file="/tmp/temp_expect_file.sh"

usage(){                                                        #Help function to provide details on how to use this script
cat << EOF

options :
        -h   Help
        -f   filename containing filername without domain name:volname
                content may look like :
                example :filer1:vol1
                         filer2:vol2
                         #filer3:vol3
        -d  domain name

example :
sh filer-vol-snap-status.sh -f filename-contains-list-of-hosts -d sea1.example.net
EOF
}

validate_domain() {
echo $1 | grep -P '(?=^.{5,254}$)(^(?:(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+\.(?:[a-z]{2,})$)' &>/dev/null
if [ $? -eq 0 ];then
 return 0
 else
echo
echo -e "${red}${bold} FAILED : \"$1\" IS NOT VALID DOMAIN ${normal} ${nc}"
echo
 exit 1
fi
}

create_expect_script_dynamically(){
(
cat <<EOF
#!/usr/bin/expect -f
        set timeout 20
        set Username [lindex \$argv 0]
        set Password [lindex \$argv 1]
        set IPaddress [lindex \$argv 2]
        set Command  [lindex \$argv 3]
       # set Directory DIRECTORY_PATH

        #log_file -a \$Directory/session_\$IPaddress.log
        #send_log "### /START-SSH-SESSION/ IP: \$IPaddress @ [exec date] ###\r"
       spawn ssh -t -o StrictHostKeyChecking=no \$Username@\$IPaddress
        expect "*assword: "
        send "\$Password\r"
        expect "*> "
        # screen -d -m bash -c " sudo yum list all"
        send "\$Command\r"
        expect "*> "
        send "exit\r"
        #send_log "\r### /END-SSH-SESSION/ IP: \$IPaddress @ [exec date] ###\r"
exit

EOF
) >${temp_expect_file}
}
create_expect_script_dynamically
if [[ -e "${expect_file}" ]];then
        diff ${expect_file} ${temp_expect_file} &>/dev/null
        if [ $? -ne 0 ];then
        cp -arpf ${temp_expect_file} ${expect_file}
        chmod +x ${expect_file}
        fi
  else
  cp -arpf ${temp_expect_file} ./${expect_file}
  chmod +x ${expect_file}
fi
rm -f ${temp_expect_file}

OPTIND=1                                                        #Intitialize OPTIND variable for getopts
FILE=""

while getopts "hf:d:" FLAG                                      #Processing all arguments
   do
    case "$FLAG" in
        h|\?)
                usage
                exit 0
                ;;
        f)
                FILE=$OPTARG                                    #Store filename
                ;;
        d)
                DOM="$OPTARG"                                   #Stores domain name
                ;;
   esac
  done
#echo -e "file - $FILE : dom - $DOM"
#eval set -- $items
#echo ${COMM}                                                   #
if [[ -z "$FILE" || -z "$DOM" ]];then                           #validate variables. Exit if not passed value
usage && exit 0
fi
if [[ -e "$FILE" && -s "$FILE" ]];then
continue
else
echo
 echo -e "${red}${bold} FAILED: Either file \"$FILE\" doesn't exist or doesn't have content ${normal} ${nc}" && exit 0
echo
fi

if validate_domain $DOM;                                        #validate domainname
 then
continue
else
usage ;  exit 0
fi

username="root"
echo -n "SSESE Ticket: "
read PRE
echo -n "Enter filer root's Password: "                        #take password from loggedin user
read -s password
echo

IFS='%'                                                         #TO preserve space in variable, we set IFS a differnet value
shift $(( OPTIND - 1 ))                                         #Pointer of getopst is set to begining, OPTIND is global varibale while using getops
#<<HERE
grep -v ^# ${FILE} |while read LINE                                            #Processing each line of file
        do
        FILER=`echo $LINE | awk -F":" '{print $1}'`
        VOL=`echo $LINE | awk -F":" '{print $2}'`
        COMM="snap delete ${VOL} ${PRE}_${VOL}"
        EFILER=${FILER}.${DOM}
                    ./expect4filer.sh $username $password ${EFILER} ${COMM}
        done
#HERE
unset IFS
exit 0
