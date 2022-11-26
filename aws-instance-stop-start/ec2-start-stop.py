#!/usr/bin/python
import argparse
import sys
import boto3
from botocore.exceptions import ClientError
'''
This program will take inputs from command line and start or stop aws instances.
History :
Dependency : python2.7 and boto3
'''
__author__ = "Kamal Maiti"
__copyright__ = "Copyleft 2018, Automation Project"
__credits__ = ["Kamal Maiti"]
__license__ = "GPL"
__version__ = "1.0.1"
__maintainer__ = "kamal Maiti"
__email__ = "kamal.maiti@gmail.com"
__status__ = "Staging"

def main():
    '''Main functions'''
    parser = argparse.ArgumentParser(description = "Program start and stop aws ec2 instances.")
        #value on or off are allowed
    parser.add_argument('-a','--action', type=str, metavar='Action to be Performed', dest='action', default = 'on')
        #list if instance id to be passed with comma separated. like: -i inid1,inid2
    parser.add_argument('-i','--instance_ids', type=str, metavar='Instance IDs', dest='instance_ids', default = '')
    parser.add_argument('-p','--profile',type=str, metavar='AWS cli profile for programetic access.', dest='profile', default = '')

    args = parser.parse_args()

    #Validate if repolist is NULL.
    if args.instance_ids and args.profile:
        pass
    else:
        print("Null arguments are passed")
        sys.exit()

    #Pass arguments to actual varialbles.
    action = args.action.upper()
    instance_ids = args.instance_ids
    profile = args.profile

    list_instance_ids = instance_ids.split(",")
    print(action)
    print(list_instance_ids)
    print(profile)

    session = boto3.Session(profile_name=profile)
    ec2=session.client('ec2')

    if action == 'ON':
        # Do a dryrun first to verify permissions
        try:
            ec2.start_instances(InstanceIds=list_instance_ids, DryRun=True)
        except ClientError as e:
            if 'DryRunOperation' not in str(e):
                raise

        # Dry run succeeded, run start_instances without dryrun
        try:
            response = ec2.start_instances(InstanceIds=list_instance_ids, DryRun=False)
            print(response)
        except ClientError as e:
            print(e)
    elif action == 'OFF':
        # Do a dryrun first to verify permissions
        try:
            ec2.stop_instances(InstanceIds=list_instance_ids, DryRun=True)
        except ClientError as e:
            if 'DryRunOperation' not in str(e):
                raise

        # Dry run succeeded, call stop_instances without dryrun
        try:
            response = ec2.stop_instances(InstanceIds=list_instance_ids, DryRun=False)
            print(response)
        except ClientError as e:
            print(e)
    else:
        print("Wrong Action is passed")


if __name__ == "__main__":
    main()

