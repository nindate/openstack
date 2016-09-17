#!/bin/bash -ex
source config.cfg


#
echo "########## INSTALLING CINDER PACKAGES ##########"
#sleep 3
apt-get install -y cinder-api cinder-scheduler 


echo "########## CONFIGURING FOR CINDER ##########"

filecinder=/etc/cinder/cinder.conf
test -f $filecinder.orig || cp $filecinder $filecinder.orig
#rm $filecinder

#crudini --set $filecinder '' rootwrap_config = /etc/cinder/rootwrap.conf
#crudini --set $filecinder '' api_paste_confg = /etc/cinder/api-paste.ini
#crudini --set $filecinder '' iscsi_helper = tgtadm
#crudini --set $filecinder '' volume_name_template = volume-%s
#crudini --set $filecinder '' volume_group = cinder-volumes
#crudini --set $filecinder '' state_path = /var/lib/cinder
#crudini --set $filecinder '' lock_path = /var/lock/cinder
#crudini --set $filecinder '' volumes_dir /var/lib/cinder/volumes

crudini --set $filecinder database connection mysql+pymysql://cinder:$MYSQL_PASS@$DATABASE_VIP/cinder

#crudini --set $filecinder '' verbose True

crudini --set $filecinder '' rpc_backend rabbit
crudini --set $filecinder oslo_messaging_rabbit rabbit_host $MESSAGING_VIP
crudini --set $filecinder oslo_messaging_rabbit rabbit_userid openstack
crudini --set $filecinder oslo_messaging_rabbit rabbit_password $RABBIT_PASS

crudini --set $filecinder '' auth_strategy keystone
crudini --set $filecinder keystone_authtoken auth_uri http://$CONTROLLER_VIP:5000
crudini --set $filecinder keystone_authtoken auth_url http://$CONTROLLER_VIP:35357
crudini --set $filecinder keystone_authtoken memcached_servers $CONTROLLER_VIP:11211

crudini --set $filecinder keystone_authtoken auth_type password
crudini --set $filecinder keystone_authtoken project_domain_name default
crudini --set $filecinder keystone_authtoken user_domain_name default
crudini --set $filecinder keystone_authtoken project_name service
crudini --set $filecinder keystone_authtoken username cinder
crudini --set $filecinder keystone_authtoken password $SERVICE_PASSWORD

crudini --set $filecinder '' my_ip $CONTROLLER_VIP

crudini --set $filecinder oslo_concurrency lock_path /var/lib/cinder/tmp


chown cinder:cinder $filecinder

echo "########## SYNCING FOR CINDER ##########"
#sleep 3
su -s /bin/sh -c "cinder-manage db sync" cinder

filenova="/etc/nova/nova.conf"
echo "#Configure Compute to use Block Storage"
crudini --set $filenova cinder os_region_name RegionOne

# Remove SQLite database file
if [[ $(ls /var/lib/cinder/cinder.sqlite >/dev/null 2>&1 | wc -l) != 0 ]] ; then
   rm -f /var/lib/cinder/cinder.sqlite
fi

echo "########## FINISHED SETUP CINDER ##########"

