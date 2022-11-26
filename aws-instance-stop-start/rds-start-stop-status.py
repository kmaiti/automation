#!/usr/bin/python
import argparse
import sys
import boto3
'''
This program will take inputs from command line and start or stop aws DB instances.
History :

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
    parser.add_argument('-a','--action', type=str, metavar='Action to be Performed', dest='action', default = 'start')
    #list if instance id to be passed with comma separated. like: -i bsandbox-db, pt-db
    parser.add_argument('-i','--db_instance_ids', type=str, metavar='DB Instance IDs', dest='db_instance_ids', default = '')
    parser.add_argument('-p','--profile',type=str, metavar='AWS cli profile for programetic access.', dest='profile', default = '')

    args = parser.parse_args()

    #Validate if repolist is NULL.

    action = args.action.upper()
    if action == 'START' or action == 'STOP':
        if args.db_instance_ids and args.profile:
            pass
        else:
            print("Either DB instance name or aws profile is missing")
            sys.exit()
    elif action == 'STATUS':
        if args.profile:
            pass
        else:
            print(" aws profile is missing")
            sys.exit()

    #Pass arguments to actual varialbles.
    db_instance_ids = args.db_instance_ids
    profile = args.profile

    list_db_instance_ids = db_instance_ids.split(",")

    session = boto3.Session(profile_name=profile)
    rds_client=session.client('rds')
    db_instance_info = rds_client.describe_db_instances()

    if action == 'START':
        for each_db in db_instance_info['DBInstances']:
            db=each_db['DBInstanceIdentifier']
            status=each_db['DBInstanceStatus']
            if db in list_db_instance_ids:
                if status == 'available':
                    print(db + " " + "does not require to be started. It is already available.")
                else:
                    response = rds_client.start_db_instance(DBInstanceIdentifier=db)
                    print(response)

    elif action == 'STOP':
        for each_db in db_instance_info['DBInstances']:
            db=each_db['DBInstanceIdentifier']
            status=each_db['DBInstanceStatus']
            if db in list_db_instance_ids:
                if status == 'available':
                    response = rds_client.stop_db_instance(DBInstanceIdentifier=db)
                    print(response)
                else:
                    print(db + " " + " is already stopped.")

    elif action == 'STATUS':
        for each_db in db_instance_info['DBInstances']:
            db=each_db['DBInstanceIdentifier']
            status=each_db['DBInstanceStatus']
            print(db + " status : "+ status)

    else:
        print("Wrong Action is passed")


if __name__ == "__main__":
    main()

