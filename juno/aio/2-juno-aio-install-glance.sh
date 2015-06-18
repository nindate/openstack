#!/bin/bash -ex 

source config.cfg

# Create database
echo "########## CREATING DATABASE ##########"
cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS glance;
CREATE DATABASE glance;
#
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'$MANAGEMENT' IDENTIFIED BY '$MYSQL_PASS';
#
FLUSH PRIVILEGES;
EOF
#

echo "########## CREATING glance service credentials and endpoint ##########"
export OS_SERVICE_TOKEN="$TOKEN_PASS"
export OS_SERVICE_ENDPOINT="http://$MANAGEMENT:35357/v2.0"
export SERVICE_ENDPOINT="http://$MANAGEMENT:35357/v2.0"


get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

GLANCE_USER=$(get_id keystone user-create --name=glance --pass="$SERVICE_PASSWORD" --email=glance@example.com)
keystone user-role-add --tenant $SERVICE_TENANT_NAME --user-id $GLANCE_USER --role $ADMIN_ROLE_NAME

echo "########## CREATING GLANCE SERVICE ##########"
keystone service-create --name=glance --type=image --description="OpenStack Image Service"
echo "########## CREATING GLANCE ENDPOINT ##########"
keystone endpoint-create \
--region regionOne \
--service-id=$(keystone service-list | awk '/ image / {print $2}') \
--publicurl=http://$MANAGEMENT:9292/v2 \
--internalurl=http://$MANAGEMENT:9292/v2 \
--adminurl=http://$MANAGEMENT:9292/v2


echo "########## INSTALLING GLANCE PACKAGES ##########"
apt-get install -y glance python-glanceclient

#sleep 5 
# Backup glance-api.conf
fileglanceapicontrol=/etc/glance/glance-api.conf
test -f $fileglanceapicontrol.orig || cp $fileglanceapicontrol $fileglanceapicontrol.orig

#Editing file /etc/glance/glance-api.conf

crudini --set $fileglanceapicontrol '' rabbit_host $MANAGEMENT
crudini --set $fileglanceapicontrol '' qpid_hostname $MANAGEMENT
crudini --set $fileglanceapicontrol '' rabbit_userid guest
crudini --set $fileglanceapicontrol '' rabbit_password $RABBIT_PASS


crudini --set $fileglanceapicontrol database backend sqlalchemy
crudini --set $fileglanceapicontrol database connection mysql://glance:$MYSQL_PASS@$MANAGEMENT/glance

crudini --del $fileglanceapicontrol database sqlite_db

crudini --set $fileglanceapicontrol keystone_authtoken auth_uri http://$MANAGEMENT:5000/v2.0
crudini --set $fileglanceapicontrol keystone_authtoken identity_uri http://$MANAGEMENT:35357
crudini --set $fileglanceapicontrol keystone_authtoken admin_tenant_name service
crudini --set $fileglanceapicontrol keystone_authtoken admin_user glance
crudini --set $fileglanceapicontrol keystone_authtoken admin_password $SERVICE_PASSWORD

crudini --del $fileglanceapicontrol keystone_authtoken auth_host
crudini --del $fileglanceapicontrol keystone_authtoken auth_port
crudini --del $fileglanceapicontrol keystone_authtoken auth_protocol

crudini --set $fileglanceapicontrol paste_deploy flavor keystone

chown glance:glance $fileglanceapicontrol
#
#sleep 5

echo "########## CONFIGURING GLANCE REGISTER ##########"
fileglanceregcontrol=/etc/glance/glance-registry.conf
test -f $fileglanceregcontrol.orig || cp $fileglanceregcontrol $fileglanceregcontrol.orig

crudini --set $fileglanceregcontrol '' rabbit_host $MANAGEMENT
crudini --set $fileglanceregcontrol '' qpid_hostname $MANAGEMENT
crudini --set $fileglanceregcontrol '' rabbit_userid guest
crudini --set $fileglanceregcontrol '' rabbit_password $RABBIT_PASS

crudini --set $fileglanceregcontrol database backend sqlalchemy
crudini --set $fileglanceregcontrol database connection mysql://glance:$MYSQL_PASS@$MANAGEMENT/glance

crudini --del $fileglanceregcontrol database sqlite_db

crudini --set $fileglanceregcontrol keystone_authtoken auth_uri http://$MANAGEMENT:5000/v2.0
crudini --set $fileglanceregcontrol keystone_authtoken identity_uri http://$MANAGEMENT:35357
crudini --set $fileglanceregcontrol keystone_authtoken admin_tenant_name service
crudini --set $fileglanceregcontrol keystone_authtoken admin_user glance
crudini --set $fileglanceregcontrol keystone_authtoken admin_password $SERVICE_PASSWORD

crudini --del $fileglanceregcontrol keystone_authtoken auth_host
crudini --del $fileglanceregcontrol keystone_authtoken auth_port
crudini --del $fileglanceregcontrol keystone_authtoken auth_protocol

crudini --set $fileglanceregcontrol paste_deploy flavor keystone

chown glance:glance $fileglanceregcontrol

#sleep 5

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

#echo "########## IMPORT CIRROS IMAGE TO GLANCE ##########"
#wget http://cdn.download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img
#source admin-openrc.sh
#glance image-create --name cirros-0.3.2-x86_64 --is-public True --disk-format qcow2 --container-format bare --file ./cirros-0.3.2-x86_64-disk.img 

echo "########## FINISHED GLANCE SETUP ##########"
