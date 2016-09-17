#!/bin/bash -ex

source config.cfg

echo "########## INSTALLING AND CONFIGURING Linux bridge agent ##########"
apt-get install -y neutron-plugin-linuxbridge-agent conntrack


#NOVA_TENANT_ID=$(keystone tenant-get service | awk '$2~/^id/{print $4}')


######## BACK UP NEUTRON.CONF IN CONTROLLER##################"
echo "########## MODIFYING neutron.conf ##########"
#
controlneutron=/etc/neutron/neutron.conf
test -f $controlneutron.orig || cp $controlneutron $controlneutron.orig
#rm $controlneutron

crudini --set $controlneutron '' rpc_backend rabbit

crudini --set $controlneutron oslo_messaging_rabbit rabbit_host $MESSAGING_VIP
crudini --set $controlneutron oslo_messaging_rabbit rabbit_userid openstack
crudini --set $controlneutron oslo_messaging_rabbit rabbit_password $RABBIT_PASS
crudini --set $controlneutron '' verbose True

crudini --set $controlneutron '' auth_strategy keystone

crudini --set $controlneutron keystone_authtoken auth_uri http://$CONTROLLER_VIP:5000
crudini --set $controlneutron keystone_authtoken auth_url http://$CONTROLLER_VIP:35357
#crudini --set $controlneutron keystone_authtoken memcached_servers $CONTROLLER_VIP:11211
crudini --set $controlneutron keystone_authtoken auth_plugin password
crudini --set $controlneutron keystone_authtoken project_domain_name default
crudini --set $controlneutron keystone_authtoken user_domain_name default
crudini --set $controlneutron keystone_authtoken project_name service
crudini --set $controlneutron keystone_authtoken username neutron
crudini --set $controlneutron keystone_authtoken password $SERVICE_PASSWORD


######## BACK-UP ML2 CONFIG IN CONTROLLER##################"
echo "########## MODIFYING ml2_conf.ini ##########"
#sleep 7


linuxbridgeini=/etc/neutron/plugins/ml2/linuxbridge_agent.ini

crudini --set $linuxbridgeini linux_bridge physical_interface_mappings provider:$NETWORK_LINUX_BR_IFACE
crudini --set $linuxbridgeini vxlan enable_vxlan True
crudini --set $linuxbridgeini vxlan local_ip $CONTROLLER_MANAGEMENT_IP
crudini --set $linuxbridgeini vxlan l2_population True
crudini --set $linuxbridgeini securitygroup enable_security_group True
crudini --set $linuxbridgeini securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver

crudini --set $linuxbridgeini agent prevent_arp_spoofing True



controlnova=/etc/nova/nova.conf

crudini --set $controlnova neutron url http://$CONTROLLER_VIP:9696
crudini --set $controlnova neutron auth_url http://$CONTROLLER_VIP:35357
crudini --set $controlnova neutron auth_plugin password
crudini --set $controlnova neutron project_domain_name default
crudini --set $controlnova neutron user_domain_name default
crudini --set $controlnova neutron region_name RegionOne
crudini --set $controlnova neutron project_name service
crudini --set $controlnova neutron username neutron
crudini --set $controlnova neutron password $SERVICE_PASSWORD

echo "########## Restart services   ##########"
service nova-compute restart
service neutron-plugin-linuxbridge-agent restart

sleep 5
source admin-openrc.sh
neutron agent-list


