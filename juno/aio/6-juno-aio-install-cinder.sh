#!/bin/bash -ex
source config.cfg

# Create database
echo "########## CREATING DATABASE ##########"
cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS cinder;
#
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'$MANAGEMENT' IDENTIFIED BY '$MYSQL_PASS';
#
FLUSH PRIVILEGES;
EOF
#


echo "########## CREATING cinder service credentials and endpoint ##########"
export OS_SERVICE_TOKEN="$TOKEN_PASS"
export OS_SERVICE_ENDPOINT="http://$MANAGEMENT:35357/v2.0"
export SERVICE_ENDPOINT="http://$MANAGEMENT:35357/v2.0"


get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

CINDER_USER=$(get_id keystone user-create --name=cinder --pass="$SERVICE_PASSWORD" --email=cinder@example.com)
keystone user-role-add --tenant $SERVICE_TENANT_NAME --user-id $CINDER_USER --role $ADMIN_ROLE_NAME

echo "########## CREATING CINDER V1 SERVICE ##########"
keystone service-create --name=cinder --type=volume --description="OpenStack Block Storage"
echo "########## CREATING CINDER V1 ENDPOINT ##########"
keystone endpoint-create \
--region regionOne \
--service-id=$(keystone service-list | awk '/ volume / {print $2}') \
--publicurl=http://$MANAGEMENT:8776/v1/%\(tenant_id\)s \
--internalurl=http://$MANAGEMENT:8776/v1/%\(tenant_id\)s \
--adminurl=http://$MANAGEMENT:8776/v1/%\(tenant_id\)s

echo "########## CREATING CINDER V2 SERVICE ##########"
keystone service-create --name=cinderv2 --type=volumev2 --description="OpenStack Block Storage v2"
echo "########## CREATING CINDER V2 ENDPOINT ##########"
keystone endpoint-create \
--region regionOne \
--service-id=$(keystone service-list | awk '/ volumev2 / {print $2}') \
--publicurl=http://$MANAGEMENT:8776/v2/%\(tenant_id\)s \
--internalurl=http://$MANAGEMENT:8776/v2/%\(tenant_id\)s \
--adminurl=http://$MANAGEMENT:8776/v2/%\(tenant_id\)s

#
echo "########## INSTALLING CINDER PACKAGES ##########"
#sleep 3
apt-get install -y cinder-api cinder-scheduler cinder-volume cinder-backup iscsitarget open-iscsi iscsitarget-dkms python-cinderclient lvm2


echo "########## CONFIGURING FOR CINDER ##########"

filecinder=/etc/cinder/cinder.conf
test -f $filecinder.orig || cp $filecinder $filecinder.orig


crudini --set $filecinder '' verbose True
crudini --set $filecinder '' auth_strategy keystone

crudini --set $filecinder '' rpc_backend cinder.openstack.common.rpc.impl_kombu
crudini --set $filecinder '' rabbit_host $MANAGEMENT
crudini --set $filecinder '' rabbit_port 5672
crudini --set $filecinder '' rabbit_userid guest
crudini --set $filecinder '' rabbit_password $RABBIT_PASS
crudini --set $filecinder '' my_ip $MANAGEMENT_IP

crudini --set $filecinder database connection mysql://cinder:$MYSQL_PASS@$MANAGEMENT/cinder

crudini --set $filecinder keystone_authtoken auth_uri http://$MANAGEMENT:5000
crudini --set $filecinder keystone_authtoken identity_uri http://$MANAGEMENT:35357

crudini --del $filecinder keystone_authtoken auth_host
crudini --del $filecinder keystone_authtoken auth_port
crudini --del $filecinder keystone_authtoken auth_protocol

crudini --set $filecinder keystone_authtoken admin_tenant_name service
crudini --set $filecinder keystone_authtoken admin_user cinder
crudini --set $filecinder keystone_authtoken admin_password $SERVICE_PASSWORD

crudini --set $filecinder '' glance_host $MANAGEMENT

chown cinder:cinder $filecinder

echo "########## SYNCING FOR CINDER ##########"
#sleep 3
cinder-manage db sync

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


echo "########## RESTART CINDER ##########"
#sleep 3
service cinder-api restart
service cinder-scheduler restart
service tgt restart
service cinder-volume restart
#sleep 3

# Remove SQLite database file
if [[ $(ls /var/lib/cinder/cinder.sqlite >/dev/null 2>&1 | wc -l) != 0 ]] ; then
   rm -f /var/lib/cinder/cinder.sqlite
fi

echo "########## FINISHED SETUP CINDER ##########"
