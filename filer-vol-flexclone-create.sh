#!/bin/bash
#########################################################################################################
# Description  : Script will check source linux host's storage volumes(nas or san) & Create flex        #
#                volumes on filer. Then map to destination host. In case old flex volumes are           #
#                mounted, they will be destroyed. Same flex name will be used here. Applicable          #
#               environment is linux host and netapp filers.                                            #
# Pre-Requisites/Assumption :                                                                           #
#       1. sshpass needs to be installed on workstation                                                 #
#       2. Normal user will be used for host login. User should have sudo rights.                       #
#       3. Filer's  root password is required                                                           #
#       4. Script is applicable to veritas volume manager installed on destination host                 #
#       5. sanlun tool needs to be installed on source & destination host                               #
#       6. Igroup will be intelligently pulled out inside script for LUN mapping                        #
#       7. Export commands will be intelligently created and applied.                                   #
#       8.                              a                                                               #
# Developed By       : Kamal Maiti , kamal.maiti@gmail.com                                              #
# Revision By  : Kamal Maiti                                                                            #
# History :                                                                                             #
#       1. Added color, usage function. Dated 3rd May, 2015                                             #
#       2. Added multiple functions. dated 9th, 10th May, 2015                                          #
#       3. Unit & funtional test performed for few funtions, 16th May, 2015                             #
#       4. get_igroup_to_map_lun validated and test, 17th May, 2015                                     #
#       4. Rectified greedy ssh or read in while loop by passing -n to ssh                              #
#       5. Added algorithm section, dated 25th May, 2015                                                #
#       6. Cross checked value of FILER_FLEXVOL_AT_DEST for nfs flex vols and added sed in              #
#               validation function                                                                     #
#       7. Disabled get_igroup_to_map_lun, value of MYIGROUP passed from CLI - 21/07/2015               #
#       8. Testing Status: SAN type partially tested. NFS & SAN type need to be fully tested.21/07/2015 #
#                                                                                                       #
#                                                                                                       #
#########################################################################################################

red='\033[0;31m'
green='\033[0;32m'
nc='\033[0m'
bold=`tput bold`
normal=`tput sgr0`
NOW=$(date +"%d-%m-%Y-%H-%M-%S")
LOG="/tmp/$0-$NOW.log"
EXPORT_CMD_FILE="/tmp/exportcmdfile.txt"
CURUSER=$USER
SSHPASS=`which sshpass 2> /dev/null`
FILER_VOL_AT_SOURCE=""
FILER_FLEXVOL_AT_DEST=""
FLEX_PREFIX="dummy"                             #Assigned a garbage value
declare -a IGROUPARRAY
MYIGROUP=""
#MYIGROUP="pet1b_attpet_a"
#MYIGROUP="pet1a_attpet_a"
DG_LIST=""
HOST_USER=$CURUSER
USERPW=""
FILERROOTPW=""
FILER_USER="root"
MOUNT_POINT=""
usage(){                                                                        #Help function for user
cat << EOF
Options :
        -h      Help
        -t      Type of storage. Either "san" or "nas".
                LUN will processed in case of SAN. NFS volumes will be processed in case of NAS.
        -s      Source Hostname from where volumes will be cloned. Example : server1
        -d      Destination hostname to which flex volumes will be exported: example: server2
        -f      FQDN name of domain or domain name of environment: example: sea1.qpass.net
        -a      Application short name. It can be "dcm", "upm", "dcd", "rpt". Use comma(,) to pass multiple value. Like : "dcd,rp,cinprd,cinprds" or "dcd,ddi,dcm,prof"
        -p      Flex volume prefix. As an example, it can be "flex3b", "minipet" etc.

Example :

sh <script-name.sh> -t san -s  src-server -d dst-server -f example.net  -a "dcm,upm,rpt"  -p "flex3b"
EOF
}

validate_domain() {                                                             #validate domain name passed to script
        echo $1 | grep -P '(?=^.{5,254}$)(^(?:(?!\d+\.)[a-zA-Z0-9_\-]{1,63}\.?)+\.(?:[a-z]{2,})$)' &>/dev/null
        if [ $? -eq 0 ];then
                 return 0
         else
                echo
                echo -e "Domain \"$1\" IS NOT VALID: $red [FAILED] ${nc}" &> $LOG
                exit 0
        fi
}

OPTIND=1                                                        #Intitialize OPTIND variable for getopts
items=
while getopts "ht:s:d:f:p:a:g:" FLAG                                      #Processing all arguments
   do
    case "$FLAG" in
        h|\?)
                usage
                exit 0
                ;;
        t)
                TYPE=$OPTARG
                ;;
        s)
                SRCHOST=$OPTARG
                ;;
        d)
                DSTHOST=$OPTARG
                ;;

        f)
                DOM=$OPTARG
                ;;
        p)
                PREFIX="$OPTARG"
                ;;
        a)
                APP="$items $OPTARG"
                ;;
        g)
                MYIGROUP="$OPTARG"
                ;;

   esac
  done
eval set -- $items

TYPE=`echo $TYPE|tr '[A-Z]' '[a-z]'`                            #convert type to lowercase

if [[ -z "$TYPE" || -z "$SRCHOST" || -z "$DSTHOST" || -z "$DOM" || -z "$PREFIX" || -z "$APP" || -z "$MYIGROUP"]];then   #Check if variables has been set or not
 echo -e "Variables are not set properly :$red [FAILED]${nc}" >>$LOG
 usage && exit 0
        else
        echo -e "Variables are validated : $green [OK] $nc" >> $LOG
fi

#Process APP variable values. comma (,) is replaced by pipe (|). Then 2nd sed will remove space

APP=$(echo "$APP" |sed 's/,/|/g'|sed 's/ //g')
FLEX_PREFIX=$(echo "$PREFIX"|sed 's/ //g')

if validate_domain $DOM;                                                          #validate domainname
         then
        echo -e "Validating domain $DOM : $green [OK]$nc" >>$LOG
        else
        usage &&  exit 0
        echo -e "Validating domain $DOM : $red [FAILED]$nc" >> $LOG
fi

echo -n "Enter your normal user's Password: "                                   #Take user qpass password
read -s userpw
echo
echo -n "Enter Filer's root Password: "                                          #take root password of filer
read -s filerrootpw
echo

if [[ -z "$userpw" || -z "$filerrootpw" ]];then                                 #validate null value of above variables
echo -e "NULL password is provided : $red[FAILED]${nc}" >>$LOG
 exit 0
 else
        echo -e "Password validated...$green [OK] $nc" >> $LOG
        USERPW=${userpw}                                                        #Assign value to global variable
        FILERROOTPW=${filerrootpw}
fi

validate_sshpass(){
<<COMM
Purpose :  check if sshpass is installed on your workstation
COMM
        which sshpass &>/dev/null                                               #check if sshpass is installed or not
         if [ $? -ne 0 ]; then
                echo -e "sshpass is not installed on $HOSTNAME$ : $red [FAILED] $nc" >>$LOG
                echo -e "${green} Refer https://apps.fedoraproject.org/packages/sshpass to get & install it. ${nc}" >> $LOG
                exit 0
        else
                echo -e "sshpass is validated & found on $HOSTNAME: $green [OK] ${nc}"
        fi
}

validate_sanlun() {
<<COMM
Purpose : This will check if sanlun command is existing or not
COMM
        user=$1; password=$2; host_to_login=$3
        LOGIN_TO_MACHINE=$(echo "${SSHPASS} -p ${password} ssh -o StrictHostKeyChecking=no ${user}@${host_to_login}.${DOM}" )
        COM="sudo which /usr/sbin/sanlun"
        $LOGIN_TO_MACHINE $COM &>/dev/null
        if [ $? -ne 0 ]; then
                echo -e "sanlun command not found on $host_to_login : $red [FAILED] $nc" >>$LOG
                 exit 0
          else
                echo -e "sanlun tool validated & found on $host_to_login: $green[ OK ]${nc}" >> $LOG
        fi
}

validate_login() {
<<MSG
Purpose : Validate login access to host or filer
MSG
        user=$1; password=$2; host_to_login=$3
        LOGIN_TO_MACHINE=$(echo "${SSHPASS} -p ${password} ssh -o StrictHostKeyChecking=no ${user}@${host_to_login}.${DOM}" )
        COM="uptime"
        $LOGIN_TO_MACHINE $COM &>/dev/null
        if [ $? -ne 0 ]; then
                echo -e "Validating user login to $host_to_login :$red [FAILED] $nc" >> $LOG
                echo -e  "Either ${user} or password or ${host_to_login} is incorrect or ${host_to_login} doesn't allow to login " >>$LOG
                exit 0
        fi
}


validate_running_db(){
<<MSG
Purpose : Checks if oracle DB/ASM instance is running or not
MSG
        user=$1; password=$2; host_to_login=$3;
        check_stat=0
        LOGIN_TO_MACHINE=$(echo "${SSHPASS} -p ${password} ssh -o StrictHostKeyChecking=no ${user}@${host_to_login}.${DOM}" )
        COM1="sudo ps -ef|egrep -i 'pmon'|grep -v grep|wc -l"
        COM2="sudo ps -ef|egrep -i 'pmon'|grep -v grep"
        check_stat=$($LOGIN_TO_MACHINE $COM1)
        oracle_num=$(expr $check_stat)
        if [ $oracle_num -gt 0 ];
                then
                running_db=$($LOGIN_TO_MACHINE $COM2)
                echo -e "Either oracle DB instance or ASM is still running on ${host_to_login}:$red [FAILED] ${nc}" >> $LOG
                echo -e "Running DB instance/ASM are : " >> $LOG
                echo "$running_db" >> $LOG
           exit 0
        else
                echo -e "Running BD/ASM are validated : $green [OK] $nc" >>$LOG
        fi
}

get_dg_list() {
<<MSG
Purpose : Collects DG(disk group ) and saves in global variable DG_LIST
MSG
        user=$1; password=$2; host_to_login=$3;
        LOGIN_TO_MACHINE=$(echo "${SSHPASS} -p ${password} ssh -o StrictHostKeyChecking=no ${user}@${host_to_login}.${DOM}" )
        COM="sudo /sbin/vxdg list|egrep '$FLEX_PREFIX'|egrep -i '$APP'|egrep -vi 'arch|name'"
        get_dg=$($LOGIN_TO_MACHINE  $COM)
        DG_LIST=$(echo "$get_dg"|awk '{print $1}')      #setting value to a global variable
        echo -e "Following DG found on $host_to_login : ">>$LOG
        echo -e "================" >> $LOG
        echo -e "$DG_LIST" >> $LOG
        echo -e "================" >> $LOG
}

export_dg(){
<<MSG
Purpose : This is to export DG found in DG_LIST
MSG
        user=$1; password=$2; host_to_login=$3;
        LOGIN_TO_MACHINE=$(echo "${SSHPASS} -p ${password} ssh -n -o StrictHostKeyChecking=no ${user}@${host_to_login}.${DOM}" )
        #RUN loop on each DG and export them
        while read dg
          do
                stat=32645    #dummy value
                COM1="sudo /sbin/vxdg deport $dg"
                COM2="sudo /sbin/vxdg list|egrep -i '$dg'|egrep -vi 'arch|name'|wc -l"
                $LOGIN_TO_MACHINE $COM1
                stat=$($LOGIN_TO_MACHINE $COM2)
                stat=$(expr $stat)
                if [ $stat -eq 0 ];then
                 echo -e "Exporting DG $dg: $green [OK] $nc">>$LOG
                  else
                  echo -e "Exporting DG $dg: $red [FAILED] $nc" >>$LOG
                fi
          done <<< "$DG_LIST"
}

import_dg() {
<<MSG
Purpose : This is for importing DG available in DG_LIST
MSG
        user=$1; password=$2; host_to_login=$3;
        LOGIN_TO_MACHINE=$(echo "${SSHPASS} -p ${password} ssh -n -o StrictHostKeyChecking=no ${user}@${host_to_login}.${DOM}" )
        #scan disk
        COM1="sudo /sbin/vxdctl enable"
        COM2="sudo /sbin/vxdisk scandisks"                      #will scan for new disks

        $LOGIN_TO_MACHINE $COM1
        $LOGIN_TO_MACHINE $COM2
        while read dg
          do
                stat=32645                                      #dummy value is assigned
                original_dg=$(echo $dg|awk -F"$FLEX_PREFIX" '{print $2}'|sed 's/^_//');
                COM3="sudo /sbin/vxdg -C -n $dg import $original_dg"
                COM4="sudo /sbin/vxdg list|egrep -i '$dg'|egrep -vi 'arch|name'|wc -l"
                 $LOGIN_TO_MACHINE $COM3
                stat=$($LOGIN_TO_MACHINE $COM4)
                stat=$(expr $stat)
                if [ $stat -eq 0 ];then
                 echo -e "Importing DG $dg: $green [OK] $nc">>$LOG
                  else
                  echo -e "Importing DG $dg: $red [FAILED] $nc" >>$LOG
                fi
        done <<< "$DG_LIST"
}

get_list_source_volumes_asLUN() {
<<MSG
Purpose : This function collects source volumes and keeps them in global variable FILER_VOL_AT_SOURCE
Content of FILER_VOL_AT_SOURCE will look like :

filer1:source_volume_name1
filer2:source_volume_name2
MSG
        user=$1; password=$2; host_to_login=$3;
        #Change value of global variable SOURCE_FILER_AND_VOL. Will be reflected once this function is called. This variable must be processed in double inverted comma
        LOGIN_TO_MACHINE=$(echo "${SSHPASS} -p ${password} ssh -o StrictHostKeyChecking=no ${user}@${host_to_login}.${DOM}" )
        COM="sudo /usr/sbin/sanlun lun show"
        #echo $COM
        OP=$($LOGIN_TO_MACHINE $COM)
        #echo "$OP"
        FILER_VOL_AT_SOURCE=$(echo "$OP"| grep -iv arch | egrep -i "$APP" | awk -F/ '{print $1$3}' | sort -u | sed 's/\ //g')
#       FILER_VOL_AT_SOURCE=$(echo "$OP"| grep -iv arch | egrep -i '$APP' | awk -F/ '{print $1$3}' | sort -u | sed 's/\ //g')
#       echo "$FILER_VOL_AT_SOURCE"
        if [ -z "$FILER_VOL_AT_SOURCE" ];then
                echo -e "Collecting list of source volumes : $red [FAILED] ${nc}" >>$LOG
                 exit 0
          else
                echo -e "Collecting list of source volumes : ${green} [OK] ${nc}" >>$LOG
                echo -e "Source volumes found on $host_to_login are :" >>$LOG
                echo -e "=====================" >>$LOG
                echo -e "$FILER_VOL_AT_SOURCE" >>$LOG
                echo -e "=====================" >>$LOG
        fi
}

get_list_source_volumes_asNFS() {
<<MSG
Purpose : This function collects source volumes and keeps them in global variable FILER_VOL_AT_SOURCE
MSG
        FILER_VOL_AT_SOURCE=""
        user=$1; password=$2; host_to_login=$3;
        LOGIN_TO_MACHINE=$(echo "${SSHPASS} -p ${password} ssh -o StrictHostKeyChecking=no ${user}@${host_to_login}.${DOM}" )
        COMMAND="sudo df -h"
        OP=$($LOGIN_TO_MACHINE $COMMAND)
        FILER_VOL_AT_SOURCE=$(echo "$OP"|egrep -i "$APP"|egrep -v "$FLEX_PREFIX"|egrep -v 'arch'|awk '{print $1}'|grep -i filer|sed 's/\/vol\///g')

        if [ -z "$FILER_VOL_AT_SOURCE" ];then
                echo -e "Collecting list of source volumes : $red [FAILED] ${nc}" >>$LOG
                 exit 0
        else
                echo -e "Collecting list of source volumes : ${green} [OK] ${nc}" >>$LOG
                echo -e "Source volumes found on $host_to_login are :" >>$LOG
                echo -e "=====================" >>$LOG
                echo -e "$FILER_VOL_AT_SOURCE" >>$LOG
                echo -e "=====================" >>$LOG
        fi
}

validate_existing_flex_vols_asNFS() {
<<MSG
Purpose : Will validate if nsf flex volumes are present or not
AS an example variable FILER_FLEXVOL_AT_DEST will store value like :
for dst host : amx-pet-oracle-1.sea1.qpass.net
[...]
XXX-pet-sea1afiler-1a:flex_XXXddip1_a_u01
XXX-pet-sea1afiler-1b:flex_XXXddip1_a_u02
[...]
MSG
        user=$1; password=$2; host_to_login=$3;
        FILER_FLEXVOL_AT_DEST=""
        LOGIN_TO_MACHINE=$(echo "${SSHPASS} -p ${password} ssh -o StrictHostKeyChecking=no ${user}@${host_to_login}.${DOM}" )
        COM="sudo df -h"
        OP=$($LOGIN_TO_MACHINE $COM)
        FILER_FLEXVOL_AT_DEST=$(echo "$OP"|egrep -i "$APP"|egrep -i "$FLEX_PREFIX"|egrep -v 'arch'|awk '{print $1}'|egrep -i "filer"|sed 's/\/vol\///g')
        if [ -z "$FILER_FLEXVOL_AT_DEST" ]; then
                echo -e "Checking existing flex volumes starting with ${FLEX_PREFIX} on ${host_to_login}: $red [FAILED] ${nc}" >>$LOG
                return 1
        else
                echo -e "Checking existing flex volumes starting with ${FLEX_PREFIX} on ${host_to_login}: $green [OK] ${nc}">>$LOG
                echo -e "===FLEX VOLS ARE ====" >>$LOG
                echo -e "$FILER_FLEXVOL_AT_DEST"   >>$LOG
                echo -e "=====================" >>$LOG
                return 0
        fi

}


validate_existing_flex_vols_asLUN(){
<<MSG
Purpose : Will validate if lun based flex volumes are present or not on destination ?
AS an example variable FILER_FLEXVOL_AT_DEST will store value like :

[...]
XXX-pet-sea1afiler-1a:flex3b_XXX_PET_CINPRD_DATA00
XXX-pet-sea1afiler-1a:flex3b_XXX_PET_CINPRDS_DATA00
XXX-pet-sea1afiler-1a:flex3b_XXX_PET_DCD_DATA00
[...]
MSG
        user=$1; password=$2; host_to_login=$3
        FILER_FLEXVOL_AT_DEST=""
        LOGIN_TO_MACHINE=$(echo "${SSHPASS} -p ${password} ssh -o StrictHostKeyChecking=no ${user}@${host_to_login}.${DOM}" )
        COM="sudo /usr/sbin/sanlun lun show"
        OP=$($LOGIN_TO_MACHINE $COM)
        FILER_FLEXVOL_AT_DEST=$(echo "$OP"| grep -iv arch |egrep -i "$APP"| egrep -i ${FLEX_PREFIX} | awk -F/ '{print $1$3}' | sort -u | sed 's/\ //g')

        if [ -z "$FILER_FLEXVOL_AT_DEST" ]; then
                echo -e "Checking existing flex volumes starting with ${FLEX_PREFIX} on $host_to_login: $red [FAILED] ${nc}" >>$LOG
                return 1
        else
                echo -e "Checking existing flex volumes starting with ${FLEX_PREFIX} on $host_to_login: $green [OK] ${nc}" >>$LOG
                echo -e "===FLEX VOLS ARE ====" >>$LOG
                echo "$FILER_FLEXVOL_AT_DEST"   >>$LOG
                echo -e "=====================" >>$LOG
                return 0
        fi
}

destroy_flex_volumes() {
<<MSG
Purpose : This will destroy flex volumes. will use content of "$FILER_VOL_AT_SOURCE" with prefix to destroy the volumes. Value of this variable is now globally available. Will not modify it.
MSG
         user=$1; password=$2;
        if [ "$FLEX_PREFIX" == "dummy" ];then                           #If dummy value is still set that we didn't receive any value. We have another sanity ie check null value.
                echo -e "Verifying Flex prefix , current value is : $FLEX_PREFIX :$red [FAILED] $nc " >>$LOG
                exit 0
                else
                echo -e "Verifying Flex prefix , current value is : $FLEX_PREFIX :$green [OK] $nc" >>$LOG
        fi
        #Starting LOOP for each volume, extracting filer & volume. Then making offline and destroying it
         while read line
           do
            filer=$(echo $line | cut -d : -f 1)
            src_volume=$(echo $line | cut -d : -f 2)
               FILER_TO_SSH=$( echo "${SSHPASS} -p ${password} ssh -n ${user}@${filer}.${DOM}")
                COM1="vol offline ${FLEX_PREFIX}_${src_volume}"
                COM2="vol destroy  ${FLEX_PREFIX}_${src_volume} -f"
                $FILER_TO_SSH $COM1
                        if [ $? -eq 0 ]; then
                                echo -e "Making Volume Offline : ${FLEX_PREFIX}_${src_volume} :$green[OK] $nc" >> $LOG
                              else
                                echo -e "Making Volume Offline : ${FLEX_PREFIX}_${src_volume} :$red [FAILED] $nc" >> $LOG
                         fi

                echo -e "Destroying Volume: ${FLEX_PREFIX}_${src_volume} : $green [OK] $nc" >>$LOG
                $FILER_TO_SSH $COM2
                        if [ $? -eq 0 ]; then
                                echo -e "Destroying Volume: ${FLEX_PREFIX}_${src_volume} : $green [OK] $nc" >>$LOG
                            else
                                echo -e "Destroying Volume: ${FLEX_PREFIX}_${src_volume} : $red [FAILED] $nc" >>$LOG
                         fi

        #NOTE: at below line only "src_volume" is passed. Becuase flex volume is destroyed, to get snap list of orginal volume, we are passing this src_volume
                COM3="snap list ${src_volume}"
                OP=$($FILER_TO_SSH $COM3)
                SNAPSHOT_TOBE_DELETED=$( echo "$OP"  | egrep -i "$FLEX_PREFIX"|egrep -vi 'busy' | awk '{print $NF}')
                echo -e "Found snapshot for ${FLEX_PREFIX}_${src_volume} is : $SNAPSHOT_TOBE_DELETED" >>$LOG
                if [ -z "$SNAPSHOT_TOBE_DELETED" ]; then
                        echo -e "$red No snapshot found for ${FLEX_PREFIX}_${src_volume} $nc " >> $LOG
                else
                #starting loop to delete multiple snapshot with same flex_prefix
                        while read snap
                                do
                                COM4="snap delete ${src_volume} $snap"
                                $FILER_TO_SSH $COM4
                                        if [ $? -eq 0 ]; then
                                                echo -e "Deleting Spapshot $snap : $green [OK] $nc "  >> $LOG
                                                else
                                                echo -e "Deleting Spapshot $snap : $red [FAILED $nc "  >> $LOG
                                        fi
                        done <<< "$SNAPSHOT_TOBE_DELETED"
                fi
         done <<< "$FILER_VOL_AT_SOURCE"

}

get_igroup_to_map_lun() {
<<MSG
Purpose : Function is used to pull wwpn from filer and dst host. Then compare each and extract igroup that belongs to matched wwpn. Save it to global variable MYIGROUP
MSG
        #call this function like : get_igroup_to_map_lun $1 $2 $3 $4 $5 $6
        user=$1; password=$2; host_to_login=$3;fileruser=$4; filerpassword=$5; filer=$6
         REGEX="^[a-f0-9]*$"                                         #Following REGX will test WWPN number which is combination of decimal number and a to f
        #took an array to keep igroup and corresponding WWPN. Function is applicable to two port HBA card
        declare -a array
        igroup_file="/tmp/igroup_file1"
        tmpf="/tmp/igroup.txt"
        >$tmpf
        >$igroup_file
        LOGIN_TO_MACHINE=$(echo "${SSHPASS} -p ${password} ssh -o StrictHostKeyChecking=no ${user}@${host_to_login}.${DOM}" )
        FILER_TO_SSH=$( echo "${SSHPASS} -p ${filerpassword} ssh ${fileruser}@${filer}.${DOM}")
        HOST_COM="sudo systool -c fc_host -v"
        FILER_COM="igroup show"
        HOST_OP=$($LOGIN_TO_MACHINE $HOST_COM)                  #Collecting WWPN from Linux hosts and saved in port_wwpn
        port_wwpn=$(echo "$HOST_OP"|grep port_name|tr -d ' '|sed -e 's/0x//g' -e 's/\"//g'|sort -u)
        if [ -z "$port_wwpn" ]; then
                echo -e "Checking WWPN on host $host_to_login : $red [FAILED] $nc " >>$LOG
        else
                echo -e "Checking WWPN on host $host_to_login :$green [OK] $nc " >>$LOG
                echo -e "$port_wwpn" >> $LOG
        fi

        $FILER_TO_SSH $FILER_COM 1> $igroup_file                #collecting WWPN from filer now. Took output only not any error

#Process wwpn found on filer side and extract appropriate igroup
# BUILD ARRAY with key and values
<<MSG
Value in file $igroup_file were similar like below :

    XXXpet_a (FCP) (ostype: linux):
        21:00:00:XXX (not logged in)
        21:00:00:XXX (not logged in)
    migfv1_XXXpet_a (FCP) (ostype: linux):
        21:00:00:XXX (not logged in)
        21:00:00:XXX (not logged in)
    migfv2_XXXpet_a (FCP) (ostype: linux):
        21:00:00:XXX (not logged in)
        21:00:00:XXX (not logged in)
    mini_pet (FCP) (ostype: linux):
    minipet3d_XXXpet_a (FCP) (ostype: linux):
        50:01:43:XXX (logged in on: vtic, 0d)
        WWPN Alias(es): oracle-3d_host1
        50:01:43:XXX (logged in on: vtic, 0b)
        WWPN Alias(es): oracle-3d_host2
 [...]
As an example : array will contain like : [Note : client name is replaced by XXX]

XXXpet_a 210000XXX 210000XXX migfv1_XXXpet_a 210000XXX 210000XXX migfv2_XXXpet_a 210000XXX 210000XXX mini_pet minipet3d_XXXpet_a 500143XXX 500143XXX pet1a_XXXpet_a 500143XXX 500143XXX pet1b_XXXpet_a 5001XXX 500143XXX pet5a_XXXpet_a 500143XXX 500143XXX pet_standbys 500143XXX 500143XXX

MSG
i=0
#Building array. Took first column and removed lines containing "WWPN". Removed symbol ":" too
echo -e "$green Building array using filer wwpn :$nc "  >>$LOG
        for  line in $(cat $igroup_file |awk '{print $1}'|grep -vi WWPN|sed 's/://g')
          do
                array[$i]=$line
                i=$(expr $i + 1 )
          done
#Below logic will process array key and value & format it properly. This is done to processing igroup in better way
        total=${#array[@]}              #count total item in array
        i=0
        while [ $i -lt $total  ]
           do
        #Below logic will  extract WWPN from each igroup and save in file
                igroup=${array[$i]}
                val1=${array[ $i + 1 ]}
                val2=${array[ $i + 2 ]}
                if [[ $val1 =~ $REGEX  ]] && [[ $val2 =~ $REGEX ]] ; then
                echo "$igroup:$val1:$val2" >>$tmpf                      #Building better format
                i=$(expr $i + 3 )
                else
                i=$(expr $i + 1 )
                fi
        done
#echo "content of  $tmpf: "
#cat $tmpf
<<MSG
Below logic will test wwpn of host & filer and extract igroup.
Then they will be stored in array ie IGROUPARRAY which is global array declared at the begining of script.

NOTE: Note that we are not using any pipe in loop while we are assigning global variable. Global variable is treated as local while using pipe(expected pipe spawns new shell)
 In below loop we use redirection ( ie <<< ) to fetch value from variable.

port_wwpn contains value like :

port_name=210000XXX
port_name=210002XXX

MSG
i=0     #reset i
        while read oline
                #oline  contains port_name:<wwpn num> of host
          do
                #extracted host wwpn in below line
                 host_wwpn=$(echo "$oline"|awk -F"=" '{print $2}')
                 while read iline
                 do
                        #iline contains line fetched from file $tmpf
                        echo $iline|grep -i "$host_wwpn" &>/dev/null
                        if [ $? -eq 0 ]; then
                        igroup=$(echo "$iline"|awk -F":" '{print $1}')
                        #Assigning all matched igroup that maps to host
                        IGROUPARRAY[$i]=${igroup}
        #               echo "IGROUP_ARRAY[[$i]=${igroup}"
                        i=$(expr $i + 1 )
                        #break
                        fi
                 done < "$tmpf"
        done <<< "$port_wwpn"

        TOTAL_IGROUP=${#IGROUPARRAY[@]}
        #If TOTAL_IGROUP is zero, that means we didn't find out any igroup
        if [ "$TOTAL_IGROUP" -eq "0" ];then
                      echo -e "Finding out igroup : $red [FAILED] $nc" >> $LOG
                        exit 0
        fi
<<MSG
# We assume that same named igroup is existed on each filer. Will check if igroup stored in array IGROUPARRAY is same or or not & keep it in global variable
# Check next igroup value is same to current one in IGROUPARRAY or not.
# Note that LOOPLIMIT is less than TOTAL_IGROUP. Because array index starts from 0. As an example of TOTAL_IGROUP=2, then j=0, 1. So when j is 1, next value of array index is 2 which will not be existing
# Thus logic will fail. hence, we run loop till (TOTAL_IGROUP-1)
MSG
local j=0
        LOOPLIMIT=$(expr $TOTAL_IGROUP - 1 )
        while [ $j -lt $LOOPLIMIT ]
                do
                if [[ ${IGROUPARRAY[$j]} == ${IGROUPARRAY[ $(expr $j + 1 ) ]} ]];then
                   MYIGROUP=${IGROUPARRAY[$j]}                  #Assigning explored igroup in global variable MYIGROUP
                else
                echo -e "exiting" && exit 0
                fi
                j=$(expr $j + 1 )
        done
#echo "after changed by fun in fun : ${IGROUPARRAY[@]}"
}

create_flexclone(){
<<MSG
Purpose : To create flex clone, we need filer, source volume, prefix. Will get these information from global variable : FILER_VOL_AT_SOURCE & arguments passed to function
MSG
        user=$1; password=$2;
        # will use content of "$FILER_VOL_AT_SOURCE" with prefix to create flex clone of volumes.  Will not modify it.
         while read line
           do
            filer=$(echo $line | cut -d : -f 1)
            src_volume=$(echo $line | cut -d : -f 2)
            FILER_TO_SSH=$( echo "${SSHPASS} -p ${password} ssh -t -n ${user}@${filer}.${DOM}")
            COM="vol clone create ${FLEX_PREFIX}_${src_volume} -b ${src_volume}"
                $FILER_TO_SSH $COM                              #This creates flex volume
                if [ $? -eq 0 ];then
                        echo -e "Creating Flex clone ${FLEX_PREFIX}_${src_volume}: $green [OK] $nc " >> $LOG
                   else
                        echo -e "Creating Flex clone ${FLEX_PREFIX}_${src_volume}: $red [FAILED] $nc " >> $LOG
                fi
        done <<< "$FILER_VOL_AT_SOURCE"
            echo "Flex Clone Creattion is completed "  >> $LOG
}

map_flex_volume_luns(){
<<MSG
Purpose : This will map new LUNs  to igroup available in MYIGROUP.
MSG
        user=$1; password=$2;
        LUN_SHOW_COM="lun show"
         while read line
            do
                filer=$(echo $line | cut -d : -f 1)
                FILER_TO_SSH=$( echo "${SSHPASS} -p ${password} ssh -n ${user}@${filer}.${DOM}")
                ALL_LUNS=$($FILER_TO_SSH $LUN_SHOW_COM)                         #Collecting all luns
                ACTUAL_LUNS=$(echo "$ALL_LUNS"|egrep -i "${FLEX_PREFIX}"|egrep -i "offline"|awk '{print $1}')  #process luns which are offline & has flex_prefix
                        #Now will make online & map lun to MYIGROUP that we retrieved earlier
                             while read lun
                                do
                                        LUN_ONLINE_COM="lun online ${lun}"
                                        LUN_MAP_COM="lun map ${lun} ${MYIGROUP}"
                                        $FILER_TO_SSH $LUN_ONLINE_COM           #log to file
                                        if [ $? -eq 0 ];then
                                                echo -e "Making Lun $lun online: $green [OK] $nc " >> $LOG
                                           else
                                                echo -e "Making Lun $lun: $red [FAILED] $nc " >> $LOG
                                        fi
                                        $FILER_TO_SSH $LUN_MAP_COM                      #log to file
                                        if [ $? -eq 0 ];then
                                                echo -e "Mapping LUN $lun to igroup $MYIGROUP: $green [OK] $nc " >> $LOG
                                                   else
                                                echo -e "Mapping LUN $lun to igroup $MYIGROUP: $red [FAILED] $nc " >> $LOG
                                        fi

                             done <<< "$ACTUAL_LUNS"

        done <<< "$FILER_VOL_AT_SOURCE"

}

check_mounted_flex_nfs_volumes() {
<<MSG
Purpose : Function will check if flex volumes are mounted on dst or not. Then return 1 or 0
MSG
        user=$1; password=$2; host_to_login=$3
        OP=""
        LOGIN_TO_MACHINE=$(echo "${SSHPASS} -p ${password} ssh -n -o StrictHostKeyChecking=no ${user}@${host_to_login}.${DOM}" )
        COM="sudo mount"
        OP=$($LOGIN_TO_MACHINE $COM)
        MOUNT_POINT=$(echo "$OP"|egrep -i "$FLEX_PREFIX"|egrep -i "$APP"|awk '{print $3}')
        if [ -z "$MOUNT_POINT" ]; then
                return 0
                else
                return 1
        fi
}

unmount_flex_nfs_volumes()
{
<<MSG
Purpose : This will unmount flex nfs volumes
MSG
        user=$1; password=$2; host_to_login=$3
        LOGIN_TO_MACHINE=$(echo "${SSHPASS} -p ${password} ssh -n -o StrictHostKeyChecking=no ${user}@${host_to_login}.${DOM}" )
        if check_mounted_flex_nfs_volumes $user $password $host_to_login;                                        #validate domainname
         then
                return 0

        else
<<MSG
        #On consideration of performance penalty, I don't like to perform "lsof" on any FS.
MSG
        while read mountdir
                do
                COM="sudo umount $mountdir"
                $LOGIN_TO_MACHINE $COM
                if [ $? -eq 0 ]; then
                        echo -e "Unmount dir $mountdir : $green [OK] $nc" >> $LOG
                        else
                        echo -e "Unmount dir $mountdir : $green [FAILED] $nc" >> $LOG
                fi
        done <<< "$MOUNT_POINT"
        return 0
        fi
}

get_export_flex_nfs_volumes() {
<<MSG
Purpose : Function will generate export comamnds using exisitng flex volumes. We assume that existing flex prefix name is same to new one
MSG
        user=$1; password=$2
        >$EXPORT_CMD_FILE                               #clear file
        while read line
           do
            filer=$(echo $line |cut -d:  -f1)
            flex_volume=$(echo $line |cut -d: -f2)
            FILER_TO_SSH="${SSHPASS} -p ${password} ssh -n ${user}@${filer}.${DOM} "   #Note that -n is passed to ssh to avoid greedy ssh problem
            COM="exportfs"
            OP=$($FILER_TO_SSH $COM )
            OPP=$(echo "$OP"|egrep -i "$flex_volume")
            vol_to_be_exported=$(echo "$OPP"|awk '{print $1}')
            options=$(echo "$OPP"|awk '{print $2}')
            options=$(echo "$options"|sed 's/-sec/sec/g')
            command_to_export="exportfs -p $options $vol_to_be_exported"
            echo "$filer#$command_to_export" >> $EXPORT_CMD_FILE
        done <<< "$FILER_FLEXVOL_AT_DEST"
}

set_export_flex_nfs_volumes() {
<<MSG
Purpose : Function is used to export new nfs flex volume to existing destination. Will use content of $EXPORT_CMD_FILE
MSG
         user=$1; password=$2
        while read line
                do
                  filer=$(echo $line |awk -F"#" '{print $1}')
                  COM=$(echo $line |awk -F"#" '{print $2}')
                  FILER_TO_SSH="${SSHPASS} -p ${password} ssh -n ${user}@${filer}.${DOM} "  #Note that -n is passed to ssh to avoid greedy ssh problem
                  $FILER_TO_SSH $COM
                         if [ $? -eq 0 ]; then
                          echo -e "Executing command \"$COM\" on $filer : $green [OK] $nc" >> $LOG
                        else
                          echo -e "Executing command \"$COM\" on $filer : $red [FAILED] $nc" >> $LOG
                        fi
                done < $EXPORT_CMD_FILE
}

mount_flex_nfs_volumes(){
<<MSG
Purpose : Will check if mounted flex volumes are same as per their entry in fstab.
MSG
        user=$1; password=$2; host_to_login=$3
        LOGIN_TO_MACHINE=$(echo "${SSHPASS} -p ${password} ssh -o StrictHostKeyChecking=no ${user}@${host_to_login}.${DOM}" )
        COM="sudo mount -a"
        $LOGIN_TO_MACHINE $COM
         if check_mounted_flex_nfs_volumes $user $password $host_to_login;
         then
                $LOGIN_TO_MACHINE $COMMAND
                        if [ $? -eq 0 ]; then
                          echo -e "Mounting all flex volumes : $green [OK] $nc" >> $LOG
                        else
                          echo -e "Mounting all flex volumes : $red [FAILED] $nc" >> $LOG
                        fi

        else
        COM="sudo mount -o remount -a"
        $LOGIN_TO_MACHINE $COM
                if [ $? -eq 0 ]; then
                          echo -e "Re-Mounting all flex volumes : $green [OK] $nc" >> $LOG
                        else
                          echo -e "Re-Mounting all flex volumes : $red [FAILED] $nc" >> $LOG
                 fi
        fi
}

#UNIT & FUNCTIONAL TEST IS DONE FOR ABOVE FUNCTION & LOGIC

<<MSG
===========================================================
List of function we created above:

usage                                                   # for usage of script
validate_domain $1                                      # checks validity of domain
validate_sshpass                                        # checks if sshpass is installed locally
validate_sanlun $1 $2 $3                                # for linux host
validate_login  $1 $2 $3                                # for linux host & filer
validate_running_db $1 $2 $3                            # for linux host
get_dg_list  $1 $2 $3                                   # for linux host, assigns global var: DG_LIST
export_dg    $1 $2 $3                                   # for linux host, uses global var: DG_LIST
import_dg    $1 $2 $3                                   # for linux host, uses global var: DG_LIST
get_list_source_volumes_asLUN $1 $2 $3                  # for linux host, assigns global var : FILER_VOL_AT_SOURCE
get_list_source_volumes_asNFS $1 $2 $3                  # for linux host, assigns global var : FILER_VOL_AT_SOURCE
validate_existing_flex_vols_asNFS $1 $2 $3              # for linux host, assigns global var:  FILER_FLEXVOL_AT_DEST
validate_existing_flex_vols_asLUN $1 $2 $3              # for linux host, assigns global var:  FILER_FLEXVOL_AT_DEST
destroy_flex_volumes $1 $2                              # for netapp filer, uses global var: FILER_VOL_AT_SOURCE
get_igroup_to_map_lun $1 $2 $3 $4 $5 $6                 # For linux host & netapp filer. Assigns global var : MYIGROUP
create_flexclone    $1 $2                               # For netapp filer, uses global var: FILER_VOL_AT_SOURCE
map_flex_volume_luns    $1 $2                           # For netapp filer, uses global var: FILER_VOL_AT_SOURCE
check_mounted_flex_nfs_volumes $1 $2 $3                 # for linux host, assigns global var: MOUNT_POINT
unmount_flex_nfs_volumes $1 $2 $3                       # for linux host,  uses global var: MOUNT_POINT
mount_flex_nfs_volumes   $1 $2 $3                       # for linux host,  uses global var: MOUNT_POINT
export_flex_nfs_volumes  $1 $2                          # For netapp filer, uses global var: FILER_VOL_AT_SOURCE

$1 = is normal user or root user
$2 = password of normal user or root password of filer
$3 = hostname[source or destination linux host]

$4 = filer user, ie root
$5 = filer password
$6 = filername

Used Global Variables :

FILER_VOL_AT_SOURCE
FILER_FLEXVOL_AT_DEST
FLEX_PREFIX
SRCHOST
DSTHOST
IGROUPARRAY
MYIGROUP
DG_LIST
HOST_USER
USERPW
FILER_USER
FILERROOTPW
MOUNT_POINT
LOG
TYPE
DOM
APP

============================================================

ALGORITHM : Summary how we'll perform flex clone creation task on san or nas based on netapp volumes :

1. Check if TYPE is san
        1. If yes, then
                call :  1. validate_sshpass > validate_login >  validate_sanlun > validate_running_db
                        2. get_dg_list
                        3. get_list_source_volumes_asLUN
                        4. validate_existing_flex_vols_asLUN
                        5. get_igroup_to_map_lun
                        6. export_dg
                        7. destroy_flex_volumes
                        8. create_flexclone
                        9. map_flex_volume_luns
                        10. import_dg
                        11. report/verification : validate_existing_flex_vols_asLUN
  If TYPE is not san, then check if it's nas :
        1. elif nas is yes, then
                call:   1. validate_sshpass > validate_login > validate_running_db
                        2. get_list_source_volumes_asNFS
                        3. validate_existing_flex_vols_asNFS
                        4. check_mounted_flex_nfs_volumes
                        5. unmount_flex_nfs_volumes
                        6. get_export_flex_nfs_volumes
                        7. destroy_flex_volumes
                        8. create_flexclone
                        9. set_export_flex_nfs_volumes
                        10. mount_flex_nfs_volumes
                        11. report/verification :validate_existing_flex_vols_asNFS

  else
        1. Report invalid TYPE & exit
===========================================================

MSG
        if [ "$TYPE" == "san" ]; then
#SAN stuffs go here
         echo SAN;
                validate_sshpass
                for host in $SRCHOST $DSTHOST
                        do
                          validate_login $HOST_USER $USERPW $host
                        done
                for host in $SRCHOST $DSTHOST
                        do
                        validate_sanlun   $HOST_USER $USERPW $host
                        done
                for host in $SRCHOST $DSTHOST
                        do
                          validate_running_db $HOST_USER $USERPW $host
                     done
                        get_dg_list $HOST_USER $USERPW $DSTHOST
                        get_list_source_volumes_asLUN $HOST_USER $USERPW $SRCHOST
   #Disabled auto igroup search
   #Get one filer and pass to get_igroup_to_map_lun to retrieve igroup. Other filer can be passed in loop. We assume that igroup name is same on all filer for dst host
   #                    filer=$(echo "$FILER_FLEXVOL_AT_DEST"|head -1 |awk -F":" '{print $1}')
                        #get_igroup_to_map_lun $HOST_USER $USERPW $DSTHOST $FILER_USER $FILERROOTPW $filer

                        if validate_existing_flex_vols_asLUN $HOST_USER $USERPW $DSTHOST; then
                                export_dg $HOST_USER $USERPW $DSTHOST
                                destroy_flex_volumes $FILER_USER $FILERROOTPW
                           else
                                echo -e "Retrieving exisitng flex volumes: $red[FAILED]$nc" && exit 0
                        fi
                        create_flexclone $FILER_USER $FILERROOTPW
                        map_flex_volume_luns $FILER_USER $FILERROOTPW
                        import_dg HOST_USER $USERPW $DSTHOST
                        #Generate a report
                        echo -e "Clearing global variable : FILER_FLEXVOL_AT_DEST"
                        unset FILER_FLEXVOL_AT_DEST
                        echo -e "Validating new flex volumes : " >> $LOG
                        validate_existing_flex_vols_asLUN $HOST_USER $USERPW $DSTHOST
                        echo -e "Flex operation is completed " >> $LOG

        elif [ "$TYPE" == "nas" ];then
          echo NAS;
                validate_sshpass
                for host in $SRCHOST $DSTHOST
                        do
                          validate_login $HOST_USER $USERPW $host
                        done
                for host in $SRCHOST $DSTHOST
                        do
                          validate_running_db $HOST_USER $USERPW $host
                     done
                get_list_source_volumes_asNFS $HOST_USER $USERPW $SRCHOST
                check_mounted_flex_nfs_volumes $HOST_USER $USERPW $DSTHOST
                validate_existing_flex_vols_asNFS $HOST_USER $USERPW $DSTHOST
                get_export_flex_nfs_volumes $FILER_USER $FILERROOTPW
                if validate_existing_flex_vols_asNFS $HOST_USER $USERPW $DSTHOST; then
                        unmount_flex_nfs_volumes $HOST_USER $USERPW $DSTHOST
                        destroy_flex_volumes $FILER_USER $FILERROOTPW
                 else
                        echo -e "Retrieving exisitng flex volumes: $red[FAILED]$nc" && exit 0
                fi
                  create_flexclone $FILER_USER $FILERROOTPW
                  set_export_flex_nfs_volumes   $FILER_USER $FILERROOTPW
                  mount_flex_nfs_volumes $HOST_USER $USERPW $DSTHOST
                #Generate a report
                       #echo -e "Clearing global variable : FILER_FLEXVOL_AT_DEST"
                        unset FILER_FLEXVOL_AT_DEST
                        echo -e "Validating new flex volumes : " >> $LOG
                        validate_existing_flex_vols_asNFS $HOST_USER $USERPW $DSTHOST
                        echo -e "Flex operation is completed " >> $LOG
        else
            echo -e "Input type \"$TYPE\" is INVALID : $red [FAILED] $nc" && exit 0
        fi

exit 0      #END

