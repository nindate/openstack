#!/bin/bash -ex 

source config.cfg


echo "########## REMOVING glance.sqlite ##########"
if [[ $(ls /var/lib/glance/glance.sqlite >/dev/null 2>&1 | wc -l) != 0 ]] ; then
   rm /var/lib/glance/glance.sqlite
fi

#sleep 5
echo "########## SYNCING GLANCE DB ##########"
su -s /bin/sh -c "glance-manage db_sync" glance

#sleep 5
echo "########## RESTARTING GLANCE SERVICE ##########"
service glance-registry restart
service glance-api restart

#
#sleep 7


echo "########## FINISHED GLANCE SETUP ##########"
