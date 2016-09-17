#!/bin/bash -ex 

source config.cfg


echo "########## INSTALLING RABBITMQ SERVICE ##########"
#sleep 3
apt-get -y install rabbitmq-server

echo "########## SETTING UP PASSWORD FOR RABBITMQ ##########"
sleep 10   # Kept this sleep else below command may fail
# Add openstack user
rabbitmqctl add_user $RABBIT_USER $RABBIT_PASS

#Permit configuration, write, and read access for the openstack user
rabbitmqctl set_permissions $RABBIT_USER ".*" ".*" ".*"

#echo "########## RESTARTING RABBITMQ ##########"
#service rabbitmq-server restart
#sleep 3

