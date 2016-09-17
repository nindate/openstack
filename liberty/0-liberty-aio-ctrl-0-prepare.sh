#!/bin/bash -ex 

source config.cfg

echo "########## INSTALL & CONFIG NTP ##########"
apt-get install -y chrony

#sed -i "s/server.*iburst/server 1.asia.pool.ntp.org iburst/g" /etc/chrony/chrony.conf

echo "########## RESTARTING NTP SERVICE ##########"
service chrony restart

echo "######### Verify NTP ###########"
chronyc sources




echo "########## ADDING Mitaka's REPO ##########"

apt-get install -y software-properties-common
add-apt-repository -y cloud-archive:liberty

sudo apt-get -y update #&& sudo apt-get -y dist-upgrade 

apt-get install -y python-openstackclient

# Install crudini which is a command line utility to update configuration files
apt-get install -y crudini 

echo "########## NOW REBOOTING SERVER, BYE BYE ##########"
sleep 3
#init 6 

