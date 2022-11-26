# hadoop-service-start-stop
## Overview
 This script will be used to start and stop or check all services running in hortonworks hadoop cluster at once.
### Installation
```sh
$ git clone https://github.com/kmaiti/hadoop-ambari-service-start-stop.git
```
### Execution
- Status Check
```sh
$ ./hadoop-service-start-stop.sh -a status -n amabariIP -u admin -p admin -c clustername
```
- Stop Services
```sh
$ ./hadoop-service-start-stop.sh -a stop -n amabariHOST or IP -u admin -p admin -c clustername
```
- Start Services
```sh
$ ./hadoop-service-start-stop.sh -a start -n amabariIP -u admin -p admin -c clustername
```
### Example
```sh
$ cd automation-scripts/hadoop-service-start-stop
$  ./hadoop-service-start-stop.sh -a status -n 10.0.1.11 -u admin -p XXX -c DIS_CORE_HDEV
ACCUMULO : STARTED
AMBARI_INFRA : STARTED
AMBARI_METRICS : STARTED
ATLAS : STARTED
FALCON : STARTED
HBASE : STARTED
HDFS : STARTED
HIVE : STARTED
KAFKA : STARTED
KNOX : STARTED
MAHOUT : INSTALLED
[...]
```
