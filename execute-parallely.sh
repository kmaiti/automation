#!/bin/bash
#################################################################################################################
# Description : Script will be used to parallelly run command on screen on multiple linux hosts.                #
# As an example you want to patch system using "yum update -y" command on multiple hosts paralley on screen.    #
#                                                                                                               #
# Developed By : Kamal Maiti. E-mail : kamal.maiti@gmail.com                                                    #
# Prerequisites :                                                                                               #
#       1. You must create expect-screen.sh in same directory where $0 is present.  content of expect-screen.sh #
# is mentioned at the end of this script inside HERE doc.                                                       #
#       2. user should have sudo access if he/she wants run command that requires sudo                          #
#       3. filename passed as argument should contain list of host with fqdn name or IP address                 #
# NOTE : Command runs on screen. Screen will be closed once command finishes its execution                      #                                                                                       #
#################################################################################################################

red='\033[0;31m'
green='\033[0;32m'
nc='\033[0m'
bold=`tput bold`
normal=`tput sgr0`

usage(){                                                        #Help function to provide details on how to use this script
echo -e "usage : $0 -f filename";
echo -e "example : using -c option :"
echo -e "-c \"sudo yum repolist all\""
echo -e "-c \"sudo yum update \""
example :
sh $0 -f filename-contains-list-of-hosts -c "sudo yum update"
}

OPTIND=1                                                        #Intitialize OPTIND variable for getopts
FILE=""
items=
while getopts "hf:c:" FLAG                                      #Processing all arguments
   do
    case "$FLAG" in
        h|\?)
                usage
                exit 0
                ;;
        f)
                FILE=$OPTARG                                    #Store filename
                ;;
        c)
                COMM="$items $OPTARG"                           #Store command with preserivng space using $items while arg passed with space. OPTARG is global variable
                ;;
   esac
  done
eval set -- $items
#echo ${COMM}                                                   #If command passed like "sudo yum repolist all", ${COMM} will print: sudo yum repolist all

username=$USER
echo -n "Enter ${username}'s Password: "                        #take password from loggedin user
read -s password
echo

IFS='%'                                                         #TO preserve space in variable, we set IFS a differnet value
shift $(( OPTIND - 1 ))                                         #Pointer of getopst is set to begining, OPTIND is global varibale while using getops
#<<HERE
grep -v ^# ${FILE} |while read host                                             #Processing each host of file
        do
                 ./expect-screen.sh $username $password $host ${COMM} &>/dev/null
                if [ $? == 0 ]
                then
                 echo -e "${bold}\"${COMM}\"${normal} ran in screen on ${bold}${host}${nromal} : ${green}SUCCESS${nc}";
                 else
                 echo -e "${bold}\"${COMM}\"${normal} ran in screen on ${bold}${host}${nromal} : ${red}FAILED${nc}";
                 fi
        done
#HERE
unset IFS


#######################################################################################
########################## CONTENT OF ./expect-screen.sh ##############################
<<HERE

############################ START ######################

#!/usr/bin/expect -f
        set timeout 20
        set Username [lindex $argv 0]
        set Password [lindex $argv 1]
        set IPaddress [lindex $argv 2]
        set Command  [lindex $argv 3]
       # set Directory DIRECTORY_PATH

        #log_file -a $Directory/session_$IPaddress.log
        #send_log "### /START-SSH-SESSION/ IP: $IPaddress @ [exec date] ###\r"
       spawn ssh -t -o StrictHostKeyChecking=no $Username@$IPaddress
        expect "*assword: "
        send "$Password\r"
        expect "$ "
        # screen -d -m bash -c " sudo yum list all"
        send "screen -d -m bash -c \"$Command\"\r"
        expect "$ "
        send "exit\r"
        #send_log "\r### /END-SSH-SESSION/ IP: $IPaddress @ [exec date] ###\r"
exit

############################## END ##########################
HERE
#######################################################################################


