#!/bin/bash
#################################################################################################
#Purpose : This script will install & setup mrepo in aws cloud env,                             #
#                                                                                               #
#Prerequisites : 1. Node should have internet connectivity.                                     #
#History :                                                                                      #
#                                                                                               #
# Developed By : Kamal Maiti                                                                    #
#################################################################################################
red='\033[0;31m'
green='\033[0;32m'
nc='\033[0m'
scriptname=$0
LOG="/var/log/${scriptname}_.log"
MREPO=""
HIERA=""
INSTALL=""
UNINSTALL=""
usage(){                                                        #Help function to provide details on how to use this script
cat << EOF

options :
        -h   Help
        -i   install, Installation
        -u   uninstall ; Un-Installation
        -m   mrepo   ; for Installation & Un-installation of easy mrepo
        -d   hiera  ; for Installation & Un-installation of hiera data binding plugin

example :
sh scriptname.sh -i install -m mrepo
sh scriptname.sh -i install -m mrepo  -d hiera
sh scriptname.sh -u uninstall -m mrepo
sh scriptname.sh -u uninstall -m mrepo -d hiera
EOF
}


while getopts "hi:u:m:s:d:" FLAG                                      #Processing all arguments
   do
    case "$FLAG" in
        h|\?)
                usage
                exit 0
                ;;
        i)
                INSTALL=$OPTARG
                ;;
        u)
                UNINSTALL="$OPTARG"
                ;;
        m)
                MREPO=$OPTARG
                ;;
        d)
                HIERA=$OPTARG
                ;;
        *)
                usage
                ;;

   esac
  done


# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

#Function to validate internet access.
check_internet_access()
{
    local host=${1}
    local port=${2}
    if nc -w 5 -z ${host-ip} ${port} &>/dev/null
    then
   #echo -e "\a\n => Port ${port} at ${host} is open"
return 0;
    else
  #echo -e "\a\n => Port ${port} at ${host} is closed"
return 1;
    fi
}
if ! check_internet_access google.com 80; then
  echo "Machine doesn't have internet access ...exiting"
   exit 1
 fi

install_mrepo() {

if rpm -q --quiet httpd && rpm -q --quiet puppet; then
        if ! rpm -q --quiet mrepo ; then

#Easy mrepo setup will be used.
#Download rhpl python packages and install it.
echo -e "$green Downloading rhpl package ... $nc"
        ls|grep -q rhpl-0.221-2
        if [ $? = 0 ]; then
          rm -f rhpl-0.221-2*
        fi
wget http://pkgs.repoforge.org/rhpl/rhpl-0.221-2.el6.rf.x86_64.rpm >>$LOG
[[ $? -eq 0  ]] && echo "Successfully download..." || echo "Download Failed",

echo -e "$green Installing rhpl ... $nc"
yum update python glibc -y >>$LOG
rpm -Uvh rhpl-0.221-2.el6.rf.x86_64.rpm >>$LOG

echo -e "$green Installing createrepo & mrepo packages ... $nc"
 yum install createrepo http://pkgs.repoforge.org/mrepo/mrepo-0.8.8-0.pre1.el6.rft.noarch.rpm -y >>$LOG

echo -e "$green Creating mrepo config for puppet ... $nc"
(
cat << EOF
[puppet]
name = PuppetLabs Yum Repository
release = 6
arch = x86_64
updates = reposync://yum.puppetlabs.com/el/\$release/products/\$arch/
dependencies = reposync://yum.puppetlabs.com/el/\$release/dependencies/\$arch/
EOF
) >/etc/mrepo.conf.d/puppetlabs.conf

echo -e "$green Creating mrepo config for rsyslog ... $nc"
(
cat <<EOF
[rsyslog-v7]
name = Rsyslog Packages (v7)
arch = i386 x86_64
#rhel5 = http://rpms.adiscon.com/v7-stable/epel-5/\$arch/RPMS
rhel6 = http://rpms.adiscon.com/v7-stable/epel-6/\$arch/RPMS
EOF
)> /etc/mrepo.conf.d/rsyslog.conf


echo -e "$green Creating mrepo config for svn ... $nc "

(
cat <<EOF
[wandisco-rhel6-svn]
name = Wandisco Subversion Repository
release = 6
arch = x86_64
updates = http://opensource.wandisco.com/rhel/\${release}Server/svn-1.8/RPMS/\${arch}
EOF
)>/etc/mrepo.conf.d/wandisco-svn.conf

echo -e "$green Creating mrepo config for EPEL-6 ... $nc"

(
cat <<EOF
[epel-6]
name = Extra Packages for Enterprise Linux \$release (\$arch)
release = 6
arch = x86_64
updates = http://dl.fedoraproject.org/pub/epel/\$release/\$arch/
EOF
)> /etc/mrepo.conf.d/epel-6_x86_64.conf

sed -i 's/arch = i386/arch = x86_64/g' /etc/mrepo.conf
echo -e "Updating all configured mrepos..."
mrepo -uvvv >>$LOG
echo -e "Updating all metadata of configured mrepos ..."
mrepo -gvvv >>$LOG

echo -e "$green Please copy public GPG key from above source links and put them inside /var/www/mrepo/pub directory. $nc"
echo -e "$green You can refer your exisitng environment where such mrepo is already setup & copy all GPG key from there $nc"

echo -e "$green Setting up mrepo for synching periodically ... $nc"

(
cat <<EOF
### Enable this if you want mrepo to daily synchronize
#30 2 * * * root /usr/bin/mrepo -q -ug
17 1 * * * root /usr/bin/mrepo -ugvv >> /var/log/mrepo.log 2>&1
EOF
)> /etc/cron.d/mrepo
/etc/init.d/crond reload

echo -e "Mrepo setup is complete"
  else
        "Looks mrepo is already installed"

        fi
  else
        echo -e "$red httpd & puppet need to be installed prior to installing mrepo $nc"
fi

}

uninstall_mrepo(){
if  rpm -q --quiet mrepo ; then
        echo -e "$green Removing mrepo ... $nc"
        yum remove creatrepo mrepo -y
fi
if  rpm -q --quiet rhpl; then
        echo -e "$green Removing rhpl... $nc"
        rpm -e --nodeps rhpl
fi
for file in /etc/mrepo.conf.d/puppetlabs.conf /etc/mrepo.conf.d/rsyslog.conf  /etc/mrepo.conf.d/epel-6_x86_64.conf /etc/mrepo.conf.d/wandisco-svn.conf /etc/cron.d/mrepo
        do
                if [ -f $file ]; then
                        rm -f $file
                fi
        done
 echo -e "$green Removing content inside /var/www/mrepo/ &/var/mrepo/ $nc "
rm -rf /var/www/mrepo/*
rm -rf /var/mrepo/*
}

install_hiera() {
#hiera plugin comes by default with puppt 3.x, don't need to install package seperately
FILE="/etc/puppet/hiera.yaml"
if [ ! -f $FILE ];then

echo -e "$green Configuring Hiera... $nc"
(
cat <<EOF
---
:backends:
  - yaml
:hierarchy:
  - "%{::fqdn}"
  - common
  - global
:yaml:
  :datadir: "/etc/puppet/environments/%{::environment}/hiera"
EOF
) >/etc/puppet/hiera.yaml
ln -s /etc/puppet/hiera.yaml /etc/hiera.yaml
echo -e "$green create FQDN based, common & global .yaml file inside above mentioned datadir and put valid values $nc"
else
  echo "hiera is already configured"
fi
}

uninstall_hiera() {
FILE="/etc/puppet/hiera.yaml"

if [[ -f $FILE || -f /etc/hiera.yaml ]];then
echo -e "$green Removing hiera config files... $nc"
rm -f /etc/hiera.yaml /etc/puppet/hiera.yaml
fi
}

########################### Start calling function above ###############

if [[ ! -z "$INSTALL" && "$INSTALL" == "install" ]]; then
                if [[ ! -z "$MREPO" && "$MREPO" == "mrepo" ]]; then
                        install_mrepo
                fi
                if [[ ! -z "$HIERA"  &&  "$HIERA" == "hiera" ]]; then
                        install_hiera
                fi

        elif [[ ! -z "$UNINSTALL"  &&  "$UNINSTALL" == "uninstall" ]];then
                if [[ ! -z "$MREPO"  &&  "$MREPO" == "mrepo" ]]; then
                        uninstall_mrepo
                fi
                if [[ ! -z "$HIERA"  &&  "$HIERA" == "hiera" ]]; then
                        uninstall_hiera
                fi
        else
                usage
                exit 1

fi

#######################################################################


