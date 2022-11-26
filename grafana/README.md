# Note
This is a custom Dockerfile of grafana docker image. Following bug has been fixed.

#Issues Fixed

## Permission denied 

### Problem 
While starting grafana container one can see container log like below
```
grafana         | GF_PATHS_CONFIG='/etc/grafana/grafana.ini' is not readable.
grafana         | You may have issues with file permissions, more information here: http://docs.grafana.org/installation/docker/#migration-from-a-previous-version-of-the-docker-container-to-5-1-or-later
grafana         | t=2019-04-24T12:49:57+0000 lvl=crit msg="Failed to parse /etc/grafana/grafana.ini, open /etc/grafana/grafana.ini: permission denied"
```
### grafana version 6.2.0
### solution
Environment variable GF_PATHS_CONFIGDIR is added and adjusted in various place in Dockerfile. You need to use this code and build docker image again like below

```
git clone https://github.com/kmaiti/grafana.git
cd grafana
docker build -t garafana-custom:latest  .
```

## Grafana DB is in Read Only mode
### Problem 
While you start container, it keeps restarting. You observe logs using below command
```
sudo docker logs <container ID>
```
Logs
```
grafana         | t=2019-04-24T13:03:21+0000 lvl=eror msg="Executing migration failed" logger=migrator id="Migrate all Read Only Viewers to Viewers" error="attempt to write a readonly database"
grafana         | t=2019-04-24T13:03:21+0000 lvl=eror msg="Exec failed" logger=migrator error="attempt to write a readonly database" sql="UPDATE org_user SET role = 'Viewer' WHERE role = 'Read Only Editor'"
grafana         | t=2019-04-24T13:03:21+0000 lvl=eror msg="Server shutdown" logger=server reason="Service init failed: Migration failed err: attempt to write a readonly database"
```
### Solution
Look for grafana storage on host:
```shell
 docker volume ls|grep grafana
```
check ownership/permission:
```
ls -lah $(docker volume inspect <grafana storage name>  --format "{{.Mountpoint}}")
```
Example :
```bash
ls -lah $(docker volume inspect dockprom_grafana_data --format "{{.Mountpoint}}") 
```
`
For me I was using this link
```
https://github.com/grafana/grafana-docker/blob/master/Dockerfile
```
and ownership is 472. They changed it as per
```
https://grafana.com/docs/installation/docker/#migration-from-a-previous-version-of-the-docker-container-to-5-1-or-later
```

So to fix it on host, execute following command.
```shell
chown 472:472 --recursive $(docker volume inspect dockprom_grafana_data --format "{{.Mountpoint}}")
```
