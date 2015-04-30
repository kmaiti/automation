#!/bin/bash
#########################################################################################################
#Description : It'll clean up unused semaphore on linux server                                          #
#Developed By Kamal maiti                                                                               #
#History :                                                                                              #
#                                                                                                       #
#########################################################################################################

#TEMFILE1="/tmp/.tempid1.txt"
#TEMFILE2="/tmp/.tempid2.txt"
#>$TEMFILE1
#>$TEMFILE2
  for SEMID in `ipcs -s|egrep -v -e "Semaphore|key"|sed '/^$/d'|awk '{print $2}'|sort -u`
     do
     #GETPID
   PID=`ipcs -s -i $SEMID|tail -2|head -1|awk '{print $NF}'`
     #GETPROCESS
    #Ignore process ID 0
#echo $PID;
if [ $PID -gt 0 ]; then

  if ps -p $PID > /dev/null
    then
  #running process are
     echo "$SEMID   $PID" &>/dev/null   #>> $TEMFILE1

   else
# dead process are
    echo "$SEMID   $PID" &>/dev/null #>> $TEMFILE2
  #cleaning semaphore of dead process :
  ipcrm -s $SEMID
 fi
fi
 done
<<MSG
echo "=====DEAD PID are ===="
echo
echo "SEMID   PID"
cat $TEMFILE2

echo "=====RUNNING PID are ===="
echo
echo "SEMID   PID"
cat $TEMFILE1

rm -f $TEMFILE1 $TEMFILE2
MSG

