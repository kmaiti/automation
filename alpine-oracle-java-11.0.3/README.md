# Alpine Latest with Oracle Java 11.0.3
This contains Dockerfile for building alpine based image using Oracle java 11.0.3.
 
### Build Step
1. Create a Dockerfile using content of this Dockerfile at your build machine.
2. Download Oracle from below link
```sh
https://download.oracle.com/otn/java/jdk/11.0.3+12/37f5e150db5247ab9333b11c1dddcd30/jdk-11.0.3_linux-x64_bin.tar.gz
```
Note that you need to create your account in oracle before downloading it. If you try to download using any bworser, it'll take you to login/signup page. Earlier it was open to download. 

So manually download in current working directory. Files will look like below 

```sh
$ ls
Dockerfile  jdk-11.0.3_linux-x64_bin.tar.gz
```
3. Build it now
```sh
sudo docker build -t  alpine_oracle-java-11.0.3 .
```
## Test
```sh
[machine]$ sudo docker run -it alpine_oracle-java-11.0.3 /bin/sh
/ # java --version
java 11.0.3 2019-04-16 LTS
Java(TM) SE Runtime Environment 18.9 (build 11.0.3+12-LTS)
Java HotSpot(TM) 64-Bit Server VM 18.9 (build 11.0.3+12-LTS, mixed mode)
/ #
/ # cat /etc/alpine-release
3.9.4
/ #
```
# alpine-oracle-java-11.0.3
