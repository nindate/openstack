#!/bin/bash -ex

source config.cfg


echo "########## INSTALLING AND CONFIGURING Open-vSwitch ##########"
apt-get install -y neutron-server neutron-plugin-ml2 \
  neutron-plugin-linuxbridge-agent neutron-l3-agent neutron-dhcp-agent \
  neutron-metadata-agent python-neutronclient conntrack


#NOVA_TENANT_ID=$(keystone tenant-get service | awk '$2~/^id/{print $4}')

# If AIO server does not have additional network interface for Linux Bridge
# If NETWORK_LINUX_BR_IFACE defined as tap0 then create a tuntap interface
if [[ $NETWORK_LINUX_BR_IFACE = "tap0" ]] ; then
 ip tuntap add name tap0 mode tap
 ifconfig tap0 10.100.0.254/24
fi


echo "########## MODIFYING neutron.conf ##########"
######## BACK UP NEUTRON.CONF IN CONTROLLER##################"
#
controlneutron=/etc/neutron/neutron.conf
test -f $controlneutron.orig || cp $controlneutron $controlneutron.orig
#rm $controlneutron

crudini --set $controlneutron database connection mysql+pymysql://neutron:$MYSQL_PASS@$DATABASE_VIP/neutron

crudini --set $controlneutron '' core_plugin ml2
crudini --set $controlneutron '' service_plugins router
crudini --set $controlneutron '' allow_overlapping_ips True

crudini --set $controlneutron '' rpc_backend rabbit

crudini --set $controlneutron oslo_messaging_rabbit rabbit_hosts $MESSAGING_VIP
crudini --set $controlneutron oslo_messaging_rabbit rabbit_userid $RABBIT_USER
crudini --set $controlneutron oslo_messaging_rabbit rabbit_password $RABBIT_PASS

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


crudini --set $controlneutron '' notify_nova_on_port_status_changes True
crudini --set $controlneutron '' notify_nova_on_port_data_changes True
crudini --set $controlneutron '' nova_url http://$CONTROLLER_VIP:8774/v2

crudini --set $controlneutron nova auth_url http://$CONTROLLER_VIP:35357
crudini --set $controlneutron nova auth_plugin password
crudini --set $controlneutron nova project_domain_name default
crudini --set $controlneutron nova user_domain_name default
crudini --set $controlneutron nova region_name RegionOne
crudini --set $controlneutron nova project_name service
crudini --set $controlneutron nova username nova
crudini --set $controlneutron nova password $SERVICE_PASSWORD

crudini --set $controlneutron '' verbose True


######## BACK-UP ML2 CONFIG IN CONTROLLER##################"
echo "########## MODIFYING ml2_conf.ini ##########"

controlML2=/etc/neutron/plugins/ml2/ml2_conf.ini
test -f $controlML2.orig || cp $controlML2 $controlML2.orig
#rm $controlML2

crudini --set $controlML2 ml2 type_drivers flat,vlan,vxlan
crudini --set $controlML2 ml2 tenant_network_types vxlan
crudini --set $controlML2 ml2 mechanism_drivers linuxbridge,l2population

crudini --set $controlML2 ml2 extension_drivers port_security
crudini --set $controlML2 ml2_type_flat flat_networks public
crudini --set $controlML2 ml2_type_vxlan vni_ranges 1:1000

crudini --set $controlML2 securitygroup enable_ipset True
crudini --set $controlML2 securitygroup enable_security_group True
crudini --set $controlML2 securitygroup firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver


echo "######### Configuring Linux Bridge agent ini ########"
linuxbridgeini=/etc/neutron/plugins/ml2/linuxbridge_agent.ini
crudini --set $linuxbridgeini linux_bridge physical_interface_mappings public:$NETWORK_LINUX_BR_IFACE
crudini --set $linuxbridgeini vxlan enable_vxlan True
crudini --set $linuxbridgeini vxlan local_ip $CONTROLLER_MANAGEMENT_IP
crudini --set $linuxbridgeini vxlan l2_population True

crudini --set $linuxbridgeini agent prevent_arp_spoofing True

echo "######### Configuring L3 agent ini ########"
l3ini=/etc/neutron/l3_agent.ini
crudini --set $l3ini '' interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
crudini --set $l3ini '' external_network_bridge 
crudini --set $l3ini '' verbose True

echo "######### Configuring DHCP agent ini ########"
dhcpini=/etc/neutron/dhcp_agent.ini 
crudini --set $dhcpini '' interface_driver neutron.agent.linux.interface.BridgeInterfaceDriver
crudini --set $dhcpini '' dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
crudini --set $dhcpini '' enable_isolated_metadata True
crudini --set $dhcpini '' verbose True
crudini --set $dhcpini '' dnsmasq_config_file /etc/neutron/dnsmasq-neutron.conf


echo "######### Configuring Metadata agent ini ########"
metadataini=/etc/neutron/metadata_agent.ini
crudini --set $metadataini '' nova_metadata_ip $CONTROLLER_MANAGEMENT_IP
crudini --set $metadataini '' metadata_proxy_shared_secret $METADATA_SECRET
crudini --set $metadataini '' verbose True

crudini --set $metadataini '' auth_uri http://$CONTROLLER_VIP:5000
crudini --set $metadataini '' auth_url http://$CONTROLLER_VIP:35357
crudini --set $metadataini '' auth_region RegionOne
crudini --set $metadataini '' auth_plugin password
crudini --set $metadataini '' project_domain_name default
crudini --set $metadataini '' user_domain_name default
crudini --set $metadataini '' project_name service
crudini --set $metadataini '' username neutron
crudini --set $metadataini '' password $SERVICE_PASSWORD



echo "######### Configuring Nova conf ########"
novaconf=/etc/nova/nova.conf
crudini --set $novaconf neutron url http://$CONTROLLER_VIP:9696
crudini --set $novaconf neutron auth_url http://$CONTROLLER_VIP:35357
crudini --set $novaconf neutron auth_plugin password
crudini --set $novaconf neutron project_domain_name default
crudini --set $novaconf neutron user_domain_name default
crudini --set $novaconf neutron region_name RegionOne
crudini --set $novaconf neutron project_name service
crudini --set $novaconf neutron username neutron
crudini --set $novaconf neutron password $SERVICE_PASSWORD

crudini --set $novaconf '' service_metadata_proxy True
crudini --set $novaconf '' metadata_proxy_shared_secret $METADATA_SECRET

#chown -R root:neutron /etc/neutron/*
#chown root:neutron $controlML2


#echo "########## RESTARTING NEUTRON SERVICE ##########"
#service neutron-server restart


echo "########## Installation and Configuration completed ##########"
