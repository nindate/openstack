#!/bin/bash -ex
source config.cfg


#
echo "########## INSTALLING LVM ##########"
#sleep 3
apt-get install -y lvm2


# Create a 20G loopback file at /cinder-volumes
echo "########## Creating loopback device for cinder-volumes ##########"
dd if=/dev/zero of=/cinder-volumes bs=1 count=0 seek=20G
echo;

# loop the file up
losetup /dev/loop2 /cinder-volumes

# create a rebootable remount of the file
echo "losetup /dev/loop2 /cinder-volumes; exit 0;" > /etc/init.d/cinder-setup-backing-file
chmod 755 /etc/init.d/cinder-setup-backing-file
ln -s /etc/init.d/cinder-setup-backing-file /etc/rc2.d/S10cinder-setup-backing-file

# create the physical volume and volume group
sudo pvcreate /dev/loop2
sudo vgcreate cinder-volumes /dev/loop2

# create storage type
#sleep 2
#cinder type-create Storage


echo "########## INSTALLING CINDER PACKAGES ##########"
#sleep 3
apt-get install -y cinder-volume #cinder-backup iscsitarget open-iscsi iscsitarget-dkms python-mysqldb

echo "########## CONFIGURING FOR CINDER ##########"

filecinder=/etc/cinder/cinder.conf
test -f $filecinder.orig || cp $filecinder $filecinder.orig
#rm $filecinder

crudini --set $filecinder database connection mysql+pymysql://cinder:$MYSQL_PASS@$DATABASE_VIP/cinder

#crudini --set $filecinder '' verbose True

crudini --set $filecinder '' rpc_backend rabbit
crudini --set $filecinder oslo_messaging_rabbit rabbit_host $MESSAGING_VIP
crudini --set $filecinder oslo_messaging_rabbit rabbit_userid openstack
crudini --set $filecinder oslo_messaging_rabbit rabbit_password $RABBIT_PASS

crudini --set $filecinder '' auth_strategy keystone
crudini --set $filecinder keystone_authtoken auth_uri http://$CONTROLLER_VIP:5000
crudini --set $filecinder keystone_authtoken auth_uri http://$CONTROLLER_VIP:35357
crudini --set $filecinder keystone_authtoken memcached_servers $CONTROLLER_VIP:11211
crudini --set $filecinder keystone_authtoken auth_type password
crudini --set $filecinder keystone_authtoken project_domain_name default
crudini --set $filecinder keystone_authtoken user_domain_name default
crudini --set $filecinder keystone_authtoken project_name service
crudini --set $filecinder keystone_authtoken username cinder
crudini --set $filecinder keystone_authtoken password $SERVICE_PASSWORD

crudini --set $filecinder '' my_ip $CONTROLLER_VIP

crudini --set $filecinder lvm volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
crudini --set $filecinder lvm volume_group cinder-volumes
crudini --set $filecinder lvm iscsi_protocol iscsi
crudini --set $filecinder lvm iscsi_helper tgtadm

crudini --set $filecinder '' enabled_backends lvm
crudini --set $filecinder '' glance_api_servers http://$CONTROLLER_VIP:9292
crudini --set $filecinder oslo_concurrency lock_path /var/lib/cinder/tmp

chown cinder:cinder $filecinder

echo "########## RESTART CINDER ##########"
service tgt restart
service cinder-volume restart

echo "# Verify Operations"
source admin-openrc.sh
cinder service-list

echo "########## FINISHED SETUP CINDER ##########"

