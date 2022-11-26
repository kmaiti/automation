#!/usr/bin/python3
import argparse
import requests
import json
import validators
import sys
from requests.auth import HTTPBasicAuth
'''
This program will take inputs from command line and delete docker images present in sonatype nexus 3.
History :
16/02/208 - 1.0.1 - This version will not use any proxy, will not validate URL. You should run blobs compaction after this.

'''
__author__ = "Kamal Maiti"
__copyright__ = "Copyright 2017, Automation Project"
__credits__ = ["Kamal Maiti"]
__license__ = "GPL"
__version__ = "1.0.1"
__maintainer__ = "kamal Maiti"
__email__ = "kamal.maiti@gmail.com"
__status__ = "Staging"

class NexusRegistryCleanup:
    '''This is main class'''
    headers = {'Accept': 'application/vnd.docker.distribution.manifest.v2+json'}

    def __init__(self, baseurl, username, password, minimage):
        '''Initialization of instance variables.'''
        self.baseurl = baseurl + '/' + 'v2'
        self.username = username
        self.password = password
        self.minimage = minimage

    def _get_repositories(self):
        '''Retrives all repositories once.'''
        uri = '_catalog'
        actual_url = self.baseurl + '/' + uri
        response = requests.get(actual_url,  headers = NexusRegistryCleanup.headers, auth = HTTPBasicAuth(self.username, self.password))

        dict_repositories = json.loads(response.text)
        list_repositories = dict_repositories['repositories']
        return list_repositories

    def _get_tags_of_repository(self, reponame):
        '''This wil return list of tags of repository passed to this method.'''
        uri = 'tags/list'
        actual_url = self.baseurl + '/' + reponame + '/' + uri
        response = requests.get(actual_url,  headers = NexusRegistryCleanup.headers, auth = HTTPBasicAuth(self.username, self.password))
        dict_tags = json.loads(response.text)
        list_tags = dict_tags['tags']
        return list_tags

    def _get_tags_to_be_deleted(self, list_tags):
        '''This method will return list of tags those will be deleted.'''
        list_tags_to_be_deleted = []
        if len(list_tags) > self.minimage:
            list_tags_to_be_deleted = [x for x in list_tags if x not in list_tags[-self.minimage:]]
        return list_tags_to_be_deleted

    def _get_config_digest_of_tag(self, reponame, tag):
        '''This method will return config digest of a tag of a repository.'''
        uri = 'manifests'
        actual_url = self.baseurl + '/' + reponame + '/' + uri +  '/' + tag
        response = requests.get(actual_url,  headers = NexusRegistryCleanup.headers, auth = HTTPBasicAuth(self.username, self.password))
        digests = json.loads(response.text)
        config_digests = digests['config']['digest']
        return config_digests

    def _get_layer_digest_of_tag(self, reponame, tag):
        '''This method will retrieve layer digests of a tag of a repositry.'''
        uri = 'manifests'
        actual_url = self.baseurl + '/' + reponame + '/' + uri +  '/' + tag
        response = requests.get(actual_url,  headers = NexusRegistryCleanup.headers, auth = HTTPBasicAuth(self.username, self.password))
        digests = json.loads(response.text)
        layer_digests = digests['layers']
        list_layer_digests = []
        for i in layer_digests:
            list_layer_digests.append(i['digest'])
        return list_layer_digests

    def _get_docker_content_digest(self, reponame, tag):
        ''''This method will retrieve docker content digest of a tag of a repositry.'''
        uri = 'manifests'
        actual_url = self.baseurl + '/' + reponame + '/' + uri +  '/' + tag
        response = requests.get(actual_url,  headers = NexusRegistryCleanup.headers, auth = HTTPBasicAuth(self.username, self.password))
        docker_content_digest = response.headers['Docker-Content-Digest']
        return docker_content_digest


    def _delete_image_by_docker_or_config_digest(self, reponame, digest):
        '''This method will delete image using docker or config digest.'''
        uri = 'manifests'
        actual_url = self.baseurl + '/' + reponame + '/' + uri +  '/' + digest
        response = requests.delete(actual_url,  headers = NexusRegistryCleanup.headers, auth = HTTPBasicAuth(self.username, self.password))
        return response.status_code

    def _delete_image_by_layer_digest(self, reponame, digest):
        '''This method will delete image using layer digests.'''
        uri = 'blobs'
        actual_url = self.baseurl + '/' + reponame + '/' + uri +  '/' + digest
        response = requests.delete(actual_url,  headers = NexusRegistryCleanup.headers, auth = HTTPBasicAuth(self.username, self.password))
        return response.status_code

    def _get_current_tags(self, repolist):
        '''This method will display currently available tags of repositories.'''
        for reponame in repolist:
            print("=====================")
            print("Retrieving tags of repo: %s" % reponame)
            print(self._get_tags_of_repository(reponame))
            print("=====================")


def main():
    '''Main logic of the program and which methods will be called are mentioned here.'''
    parser = argparse.ArgumentParser(description = "Program cleans up docker images from sonatype nexus 3 docker repository")
    parser.add_argument('-b','--base-url', type=str, metavar='Nexus 3 REST API URL', dest='baseurl', default = 'http://localhost:5000')
    parser.add_argument('-u','--user', type=str, metavar='Registry Username', dest='username', default = 'admin')
    parser.add_argument('-p','--password',type=str, metavar='Registry Password', dest='password', default = 'admin')
    parser.add_argument('-n','--minimage', type=int, metavar='Minimum number of images to keep', dest='minimage', default = 9)
    parser.add_argument('-r','--repolist', nargs='*', type=str, metavar = 'List of repositories', dest='repolist', default = 'all')

    args = parser.parse_args()

    #Validate if repolist is NULL.
    if args.repolist:
        pass
    else:
        print("Repolist is NULL. Exiting...")
        sys.exit()

    #Pass arguments to actual varialbles.
    baseurl = args.baseurl
    username = args.username
    password = args.password
    minimage = args.minimage
    repolist = args.repolist
    '''
    #Dummy values for testing.
    baseurl = 'https://registry.domain.com'
    username = 'registry-functional'
    password = "XXXXX"
    minimage = 9
    repolist = ['service1']
    repolist5 = ['all']
    repolist2 = ['account-service-test', 'admintool-service-test', 'authentication-service-test']
    '''

    #Created instance of class NexusRegistryCleanup.
    instance = NexusRegistryCleanup(baseurl, username, password, minimage)

    #'''
    #======= LOGIC ========
    #will retrieve all repositories from
    all_repositories  = instance._get_repositories()
    #Get if input repolist is valid and present in nexus.
    input_repolist = repolist
    #input_repolist = args.repolist
    if len(input_repolist) is 1 and input_repolist[0] == 'all' or input_repolist[0] == 'ALL' or input_repolist[0] == 'All':
        input_repolist = all_repositories
    actual_repolist = list(set(input_repolist) & set(all_repositories))
    print("Actual repository list is to be processed: %s" % actual_repolist)
    #Available tags before processing
    instance._get_current_tags(actual_repolist)

    #Process actual_repolist
    if not actual_repolist:
        print('Empty repository list is found.')
    else:
        #Loop through all repository.
        for repo in actual_repolist:
            print("================== PROCESSING REPOSITORY: %s" % repo + " ===================\n")
            all_tags = instance._get_tags_of_repository(repo)
            list_of_tags_to_be_deleted = instance._get_tags_to_be_deleted(all_tags)
            print("List of tags to be deleted: %s" % list_of_tags_to_be_deleted + "\n=======================\n")
            #Get config and docker digest, dlayer digest  of each tag
            if not list_of_tags_to_be_deleted:
                print("No tags found of repository %s to be deleted. Probably repository has minimum number of tags you want to keep" % repo)
            else:
                for each_tag in list_of_tags_to_be_deleted:
                    #For each tag, get config, docker and layer digests
                    print("Processing tag %s" % each_tag + "\n=======================\n")

                    #Processing Config Digests

                    config_digests = instance._get_config_digest_of_tag(repo, each_tag)
                    #print("Config digests of tag: %s" % each_tag + "\n=======================\n")
                    #print(config_digests)
                    print("Deleting Config digest... %s" % config_digests)
                    status = 0
                    #Delete API call. Enable below line if you want to delete digest.
                    status = instance._delete_image_by_docker_or_config_digest(repo, config_digests)
                    #print("Deleting dcoker digest, status code %s" % status)
                    if status is 200 or 202:
                        print('OK..DELETED')
                    elif  status is 404:
                        print('Config digest is NOT found. Probably it is deleted earlier.')
                    else:
                        print('Unexpected http_status %s' % status)

                    #Processing Layer Digests

                    layer_digests = instance._get_layer_digest_of_tag(repo, each_tag)
                    #print("Layer digests of tag: %s" % each_tag + "\n=======================\n")
                    #print(layer_digests)
                    if not layer_digests:
                        print("No layer digests found.")
                    else:
                        for ldigest in layer_digests:
                            print("Deleting layer digest... %s" % ldigest)
                            status = 0
                            #Delete API call. Enable below line if you want to delete digest.
                            status = instance._delete_image_by_layer_digest(repo, ldigest)
                            #print("Deleting dcoker digest, status code %s" % status)
                            if status is 200 or 202:
                                print('OK..DELETED')
                            elif  status is 404:
                                print('Layer digest is NOT found. Probably it is deleted earlier.')
                            else:
                                print('Unexpected http_status %s' % status)
                    #Processing Docker Digests


                    docker_digest = instance._get_docker_content_digest(repo, each_tag)
                    print("Docker digests of tag: %s" % each_tag + "\n=======================\n")

                    print(docker_digest)
                    print("Deleting Docker digest... %s" % docker_digest)
                    status = 0
                    #Delete API call. Enable below line if you want to delete digest.
                    status =  instance._delete_image_by_docker_or_config_digest(repo, docker_digest)
                    #print("Deleting dcoker digest, status code %s" % status)
                    if status is 200 or 202:
                        print('OK..DELETED')
                    elif  status is 404:
                        print('Docker digest is NOT found. Probably it is deleted earlier.')
                    else:
                        print('Unexpected http_status %s' % status)
    #Available tags after processing
    instance._get_current_tags(actual_repolist)
    #'''
if __name__ == "__main__":
    main()

