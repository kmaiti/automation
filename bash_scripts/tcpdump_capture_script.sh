#!/bin/sh
#By kamal maiti
#Purpose : TO capture tcpdump data
if [ -z "$1" ]
  then
    echo "Script will be running as root. No argument supplied: Usage : sh scriptname destination_hostname"
    exit 0
fi
echo "Script will be running at the background"
DEST=$1
DATE=$(date +%Y%m%d_%H:%M)
ping $DEST &> ping_${DEST}_${DATE}.log &
/usr/sbin/tcpdump -s0 -w /tmp/tcpdumpdata.${DATE}.pcap host ${DEST} &

