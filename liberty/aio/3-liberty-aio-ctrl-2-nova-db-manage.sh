#!/bin/bash -ex
source config.cfg


echo "########## REMOVE DEFAULT NOVA DB ##########"
#sleep 7
if [[ $(ls /var/lib/nova/nova.sqlite >/dev/null 2>&1 | wc -l) != 0 ]] ; then
   rm /var/lib/nova/nova.sqlite
fi

echo "########## SYNCING NOVA DB ##########"
#sleep 7 
su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage db sync" nova

sleep 5

echo "########## RESTARTING NOVA SERVICE ##########"
service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart

echo "########## FINISHED NOVA SETUP ##########"

