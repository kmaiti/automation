#!/usr/bin/bash
######################################################################################
#Purpose : To take AWS EBS volume snapshot and delete them after a retention period. #
# Prereq: Volume list file will have volume-id:Volume-name format                    #
#By kamal.maiti@gmail.com                                                            #
#Project : Data Intelligence Suite, Data on Cloud                                    #
######################################################################################

VOLUMES_LIST=$HOME/volumes-list
SNAPSHOT_INFO=$HOME/snapshot_info
DATE=`date +%Y-%m-%d`
REGION="ap-south-1"
MAIL_REPORT=$HOME/mail_report
# Snapshots Retention Period for each volume snapshot
RETENTION=30
PROFILE=default

SNAP_CREATION=$HOME/snap_creation
SNAP_DELETION=$HOME/snap_deletion

#EMAIL_LIST = abc@domain.com

echo "List of Snapshots Creation Status" > ${SNAP_CREATION}
echo "List of Snapshots Deletion Status" > ${SNAP_DELETION}

# Check whether the volumes list file is available or not?

if [ -f ${VOLUMES_LIST} ]; then

    # Creating Snapshot for each volume using for loop
    for VOL_INFO in `cat ${VOLUMES_LIST}`
      do
        # Getting the Volume ID and Volume Name into the Separate Variables.
        VOL_ID=`echo $VOL_INFO | awk -F":" '{print $1}'`
        VOL_NAME=`echo $VOL_INFO | awk -F":" '{print $2}'`
        # Creating the Snapshot of the Volumes with Proper Description.
        DESCRIPTION="${VOL_NAME}_${DATE}"
       /usr/local/bin/aws ec2 create-snapshot --volume-id ${VOL_ID} --description "$DESCRIPTION" --region $REGION  --profile $PROFILE &>> ${SNAP_CREATION}
      done
else
    echo "Volumes list file is not available : $VOLUMES_LIST Exiting."
    exit 1
fi

echo >> ${SNAP_CREATION}
echo >> ${SNAP_CREATION}


# Deleting the Snapshots which are 10 days old.
for VOL_INFO in `cat $VOLUMES_LIST`
    do
      # Getting the Volume ID and Volume Name into the Separate Variables.
      VOL_ID=`echo $VOL_INFO | awk -F":" '{print $1}'`
      VOL_NAME=`echo $VOL_INFO | awk -F":" '{print $2}'`
      # Getting the Snapshot details of each volume.
      /usr/local/bin/aws ec2 describe-snapshots --query Snapshots[*].[SnapshotId,VolumeId,Description,StartTime] --output text --filters "Name=status,Values=completed" "Name=volume-id,Values=$VOL_ID"  --profile $PROFILE| grep -v "CreateImage" > ${SNAPSHOT_INFO}
      # Snapshots Retention Period Checking and if it crosses delete them.
      while read SNAP_INFO
        do
           SNAP_ID=`echo ${SNAP_INFO} | awk '{print $1}'`
           #echo ${SNAP_ID}
           SNAP_DATE=`echo ${SNAP_INFO} | awk '{print $4}' | awk -F"T" '{print $1}'`
           #echo ${SNAP_DATE}
           # Getting the no.of days difference between a snapshot and present day.
           RETENTION_DIFF=`echo $(($(($(date -d "$DATE" "+%s") - $(date -d "${SNAP_DATE}" "+%s"))) / 86400))`
           echo "SNAPSHOT ${SNAP_ID} is ${RETENTION_DIFF} days old."
           # Deleting the Snapshots which are older than the Retention Period
           if [ ${RETENTION} -lt ${RETENTION_DIFF} ];
             then
                           echo "Deleting SNAPSHOT ${SNAP_ID}"
               /usr/local/bin/aws ec2 delete-snapshot --snapshot-id ${SNAP_ID} --region $REGION --output text --profile $PROFILE > /tmp/snap_del
               echo "DELETING ${SNAP_INFO}" >> ${SNAP_DELETION}
           fi
        done < ${SNAPSHOT_INFO}
done

echo >> ${SNAP_DELETION}
# Merging the Snap Creation and Deletion Data
cat ${SNAP_CREATION} ${SNAP_DELETION} > ${MAIL_REPORT}
# Sending the mail Update
#cat /var/log/mail_report | mail -s "Volume Snapshots Status" $EMAIL_LIST
