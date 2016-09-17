#!/bin/bash -ex 

source config.cfg

echo "########## INSTALLING GLANCE PACKAGES ##########"
apt-get install -y glance python-glanceclient

#sleep 5 
# Backup glance-api.conf
fileglanceapicontrol=/etc/glance/glance-api.conf
test -f $fileglanceapicontrol.orig || cp $fileglanceapicontrol $fileglanceapicontrol.orig
#rm $fileglanceapicontrol

#Editing file /etc/glance/glance-api.conf

#crudini --del $fileglanceapicontrol '' rabbit_host 
#crudini --set $fileglanceapicontrol '' rabbit_hosts $MESSAGING_VIP
#crudini --set $fileglanceapicontrol '' qpid_hostname $MESSAGING_VIP
#crudini --set $fileglanceapicontrol '' rabbit_userid $RABBIT_USER
#crudini --set $fileglanceapicontrol '' rabbit_password $RABBIT_PASS
#crudini --set $fileglanceapicontrol '' bind_host $CONTROLLER_MANAGEMENT_IP
#crudini --set $fileglanceapicontrol '' registry_host $CONTROLLER_MANAGEMENT_IP
crudini --set $fileglanceapicontrol '' notification_driver noop
crudini --set $fileglanceapicontrol '' verbose True


#crudini --set $fileglanceapicontrol database backend sqlalchemy
#crudini --set $fileglanceapicontrol database connection mysql://glance:$MYSQL_PASS@$DATABASE_VIP/glance
crudini --set $fileglanceapicontrol database connection mysql+pymysql://glance:$MYSQL_PASS@$DATABASE_VIP/glance

#crudini --del $fileglanceapicontrol database sqlite_db

crudini --set $fileglanceapicontrol keystone_authtoken auth_uri http://$CONTROLLER_VIP:5000
#crudini --del $fileglanceapicontrol keystone_authtoken identity_uri 
crudini --set $fileglanceapicontrol keystone_authtoken auth_url http://$CONTROLLER_VIP:35357
#crudini --set $fileglanceapicontrol keystone_authtoken memcached_servers $CONTROLLER_VIP:11211
crudini --set $fileglanceapicontrol keystone_authtoken auth_plugin password
crudini --set $fileglanceapicontrol keystone_authtoken project_domain_name default
crudini --set $fileglanceapicontrol keystone_authtoken user_domain_name default
crudini --set $fileglanceapicontrol keystone_authtoken project_name service
crudini --set $fileglanceapicontrol keystone_authtoken username glance
crudini --set $fileglanceapicontrol keystone_authtoken password $SERVICE_PASSWORD

#crudini --del $fileglanceapicontrol keystone_authtoken admin_tenant_name 
#crudini --del $fileglanceapicontrol keystone_authtoken admin_user 
#crudini --del $fileglanceapicontrol keystone_authtoken admin_password 

#crudini --del $fileglanceapicontrol keystone_authtoken auth_host
#crudini --del $fileglanceapicontrol keystone_authtoken auth_port
#crudini --del $fileglanceapicontrol keystone_authtoken auth_protocol

crudini --set $fileglanceapicontrol paste_deploy flavor keystone

crudini --set $fileglanceapicontrol glance_store stores file,http
crudini --set $fileglanceapicontrol glance_store default_store file
crudini --set $fileglanceapicontrol glance_store filesystem_store_datadir /var/lib/glance/images/

chown glance:glance $fileglanceapicontrol
#
#sleep 5

echo "########## CONFIGURING GLANCE REGISTER ##########"
fileglanceregcontrol=/etc/glance/glance-registry.conf
test -f $fileglanceregcontrol.orig || cp $fileglanceregcontrol $fileglanceregcontrol.orig
#rm $fileglanceregcontrol

crudini --set $fileglanceregcontrol database connection mysql+pymysql://glance:$MYSQL_PASS@$DATABASE_VIP/glance

crudini --set $fileglanceregcontrol keystone_authtoken auth_uri http://$CONTROLLER_VIP:5000
crudini --set $fileglanceregcontrol keystone_authtoken auth_url http://$CONTROLLER_VIP:35357
#crudini --set $fileglanceregcontrol keystone_authtoken memcached_servers $CONTROLLER_VIP:11211
crudini --set $fileglanceregcontrol keystone_authtoken auth_plugin password
crudini --set $fileglanceregcontrol keystone_authtoken project_domain_name default
crudini --set $fileglanceregcontrol keystone_authtoken user_domain_name default
crudini --set $fileglanceregcontrol keystone_authtoken project_name service
crudini --set $fileglanceregcontrol keystone_authtoken username glance
crudini --set $fileglanceregcontrol keystone_authtoken password $SERVICE_PASSWORD

crudini --set $fileglanceregcontrol paste_deploy flavor keystone

crudini --set $fileglanceregcontrol '' notification_driver noop
crudini --set $fileglanceregcontrol '' verbose True

chown glance:glance $fileglanceregcontrol


echo "########## RESTARTING GLANCE SERVICE ##########"
service glance-registry restart
service glance-api restart

#
#sleep 7


echo "########## FINISHED GLANCE SETUP ##########"
