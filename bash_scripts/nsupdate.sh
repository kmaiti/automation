#!/bin/bash
#################################################################
#Purpose : Dynamically update DNS records using nsupdate	#
#By : kamal.maiti@XXXX					#
#Prerequities : kerberos keytab, DNS server IP, host		#
#History: 							#
#								#
#								#
#################################################################
MYTESTFILE=`mktemp`
KTAB='/root/nsupdateusergru2.keytab'
KUSER='nsupdate@site1.example.net'  #replace domain
SERVER='<DNS server IP>'	#Put dns server IP
HOST="mytest-host.site1.example.net"
echo "update delete $HOST ">> $MYTESTFILE			#for deleting record
#echo "update add $HOST 86400 a 10.150.129.22">>$MYTESTFILE   #for adding record

if [ -s "$MYTESTFILE" ]; then
   if [ $(id -u) == 0 ]; then
       # Use the Kerberos key tab to authenticate against AD
       /usr/bin/kinit -k -t $KTAB $KUSER

       echo "server $SERVER" >> $MYTESTFILE
       echo "send" >> $MYTESTFILE
          /usr/bin/nsupdate -g $MYTESTFILE
       #echo "DNS cleanup"
       cat $MYTESTFILE
       cache_key=`/usr/bin/klist -l|grep -i nsupdate|awk '{print $NF}'`
       /usr/bin/kdestroy -c $cache_key
       #kdestroy

   fi
fi
rm -f $MYTESTFILE

