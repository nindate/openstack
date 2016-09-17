#!/bin/bash -ex
source config.cfg


echo "########## INSTALLING NOVA IN CONTROLLER NODE ################"
apt-get install -y nova-api nova-cert nova-conductor nova-consoleauth \
  nova-novncproxy nova-scheduler python-novaclient

echo "########## BACKUP NOVA CONFIGURATION ##################"
controlnova=/etc/nova/nova.conf
test -f $controlnova.orig || cp $controlnova $controlnova.orig
#rm $controlnova

crudini --set $controlnova '' enabled_apis osapi_compute,metadata

#crudini --set $controlnova api_database connection mysql+pymysql://nova:$MYSQL_PASS@$DATABASE_VIP/nova_api
crudini --set $controlnova database connection mysql+pymysql://nova:$MYSQL_PASS@$DATABASE_VIP/nova

crudini --set $controlnova '' rpc_backend rabbit
crudini --set $controlnova oslo_messaging_rabbit rabbit_hosts $MESSAGING_VIP
crudini --set $controlnova oslo_messaging_rabbit rabbit_userid openstack
crudini --set $controlnova oslo_messaging_rabbit rabbit_password $RABBIT_PASS

crudini --set $controlnova '' auth_strategy keystone

crudini --set $controlnova keystone_authtoken auth_uri http://$CONTROLLER_VIP:5000
crudini --set $controlnova keystone_authtoken auth_url http://$CONTROLLER_VIP:35357
#crudini --set $controlnova keystone_authtoken memcached_servers $CONTROLLER_VIP:11211
crudini --set $controlnova keystone_authtoken auth_plugin password
crudini --set $controlnova keystone_authtoken project_domain_name default
crudini --set $controlnova keystone_authtoken user_domain_name default
crudini --set $controlnova keystone_authtoken project_name service
crudini --set $controlnova keystone_authtoken username nova
crudini --set $controlnova keystone_authtoken password $SERVICE_PASSWORD

crudini --set $controlnova '' my_ip $CONTROLLER_MANAGEMENT_IP

crudini --set $controlnova vnc vncserver_listen $CONTROLLER_MANAGEMENT_IP
crudini --set $controlnova vnc vncserver_proxyclient_address $CONTROLLER_VIP

#crudini --set $controlnova '' use_neutron True
crudini --set $controlnova '' network_api_class nova.network.neutronv2.api.API
crudini --set $controlnova '' security_group_api neutron
crudini --set $controlnova '' linuxnet_interface_driver nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver
crudini --set $controlnova '' firewall_driver nova.virt.firewall.NoopFirewallDriver

#crudini --set $controlnova '' verbose True
crudini --set $controlnova glance host $CONTROLLER_VIP
#crudini --set $controlnova glance api_servers http://$CONTROLLER_VIP:9292

crudini --set $controlnova oslo_concurrency lock_path /var/lib/nova/tmp

#crudini --del $controlnova '' logdir 


chown nova:nova $controlnova


echo "########## RESTARTING NOVA SERVICE ##########"
service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart

echo "########## FINISHED NOVA SETUP ##########"

