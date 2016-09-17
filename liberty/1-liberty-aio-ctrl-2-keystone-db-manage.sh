#!/bin/bash -ex

source config.cfg

echo "##### START INSTALLING KEYSTONE ##### "
#sleep 3



echo " ##### SETUP KEYSTONE DB ##### "
#sleep 3
# Populate the Identity service database
su -s /bin/sh -c "keystone-manage db_sync" keystone


echo "##### DELETE KEYSTONE DEFAULT DB ##### "
#sleep 3
[[ -f  /var/lib/keystone/keystone.db ]] && rm -f /var/lib/keystone/keystone.db


echo "########## KEYSTONE SETUP FINISHED ! ##########"

