#!/bin/bash -ex 

source config.cfg


echo "########## INSTALLING MEMCACHED SERVICE ##########"
apt-get install -y memcached python-memcache

echo "########## SETTING LISTEN ADDRESS ##########"
sed -i "s/-l 127.0.0.1/-l $CONTROLLER_VIP/g" /etc/memcached.conf

echo "########## RESTARTING MEMCACHED ##########"
service memcached restart
