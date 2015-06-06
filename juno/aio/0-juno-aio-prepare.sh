#!/bin/bash -ex 

source config.cfg


echo "########## ADDING JUNO's REPO ##########"

echo deb http://ubuntu-cloud.archive.canonical.com/ubuntu trusty-updates/juno main > /etc/apt/sources.list.d/ubuntu-cloud-archive-juno-trusty.list
apt-get install -y ubuntu-cloud-keyring
 
sudo apt-get -y update && sudo apt-get -y dist-upgrade 

# Enable IP forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.rp_filter=0" >> /etc/sysctl.conf
echo "net.ipv4.conf.default.rp_filter=0" >> /etc/sysctl.conf
sysctl -p


# Install crudini which is a command line utility to update configuration files
apt-get install -y crudini

echo "########## INSTALL & CONFIG NTP ##########"
#sleep 3
apt-get install -y ntp

## Config NTP in JUNO
sed -i 's/server ntp.ubuntu.com/ \
server 0.vn.pool.ntp.org iburst \
server 1.asia.pool.ntp.org iburst \
server 2.asia.pool.ntp.org iburst/g' /etc/ntp.conf

sed -i 's/restrict -4 default kod notrap nomodify nopeer noquery/ \
#restrict -4 default kod notrap nomodify nopeer noquery/g' /etc/ntp.conf

sed -i 's/restrict -6 default kod notrap nomodify nopeer noquery/ \
restrict -4 default kod notrap nomodify \
restrict -6 default kod notrap nomodify/g' /etc/ntp.conf

if [[ $(ls -l /var/lib/ntp/ntp.conf.dhcp >/dev/null 2>&1 | wc -l) != 0 ]] ; then
   rm /var/lib/ntp/ntp.conf.dhcp
fi

echo "########## RESTARTING NTP SERVICE ##########"
#sleep 3
service ntp restart



#Start installing mysql
echo "########## INSTALLING MYSQL ##########"
echo mysql-server mysql-server/root_password password $MYSQL_ADMIN_PASS | debconf-set-selections
echo mysql-server mysql-server/root_password_again password $MYSQL_ADMIN_PASS | debconf-set-selections

#sleep 3
apt-get -y install mysql-server python-mysqldb curl expect


mysql_install_db
SECURE_MYSQL=$(expect -c "

set timeout 10
spawn mysql_secure_installation

expect \"Enter current password for root (enter for none):\"
send \"$MYSQL_ADMIN_PASS\r\"

expect \"Change the root password?\"
send \"n\r\"

expect \"Remove anonymous users?\"
send \"y\r\"

expect \"Disallow root login remotely?\"
send \"y\r\"

expect \"Remove test database and access to it?\"
send \"n\r\"

expect \"Reload privilege tables now?\"
send \"y\r\"

expect eof
")

echo "$SECURE_MYSQL"
apt-get remove --purge -y expect

echo "########## CONFIGURING MYSQL ##########"
#sleep 5
# Not using crudini here but standard sed because the config file has some patterns which are not recognised by crudini
sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mysql/my.cnf
#
sed -i "/bind-address/a\default-storage-engine = innodb\n\
collation-server = utf8_general_ci\n\
init-connect = 'SET NAMES utf8'\n\
character-set-server = utf8" /etc/mysql/my.cnf
#

echo "########## RESTARTING MYSQL ##########"
#sleep 5
service mysql restart


echo "########## INSTALLING RABBITMQ SERVICE ##########"
#sleep 3
apt-get -y install rabbitmq-server

echo "########## SETTING UP PASSWORD FOR RABBITMQ ##########"
sleep 10   # Kept this sleep else below command to change password fails
rabbitmqctl change_password guest $RABBIT_PASS

echo "########## RESTARTING RABBITMQ ##########"
service rabbitmq-server restart
#sleep 3



echo "########## IT IS BETTER THAT YOU REBOOT THIS SERVER NOW ############"
echo "########## if any upgrade to kernel packages done by apt-get dist-upgrade ##########"
echo ""
echo "Please reboot the server manually using command init 6"
#init 6
