#!/bin/bash -ex

source config.cfg

# Create database
echo "########## CREATING DATABASE ##########"

cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS neutron;
#
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'$MANAGEMENT' IDENTIFIED BY '$MYSQL_PASS';
#
FLUSH PRIVILEGES;
EOF
#

echo "########## CREATING neutron service credentials and endpoint ##########"
export OS_SERVICE_TOKEN="$TOKEN_PASS"
export OS_SERVICE_ENDPOINT="http://$MANAGEMENT:35357/v2.0"
export SERVICE_ENDPOINT="http://$MANAGEMENT:35357/v2.0"


get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

NEUTRON_USER=$(get_id keystone user-create --name=neutron --pass="$SERVICE_PASSWORD" --email=neutron@example.com)
keystone user-role-add --tenant $SERVICE_TENANT_NAME --user-id $NEUTRON_USER --role $ADMIN_ROLE_NAME

echo "########## CREATING NEUTRON SERVICE ##########"
keystone service-create --name neutron --type network --description "OpenStack Networking"
echo "########## CREATING NEUTRON ENDPOINT ##########"
keystone endpoint-create \
--region regionOne \
--service-id $(keystone service-list | awk '/ network / {print $2}') --publicurl http://$MANAGEMENT:9696 \
--adminurl http://$MANAGEMENT:9696 \
--internalurl http://$MANAGEMENT:9696

echo "########## INSTALLING AND CONFIGURING Open-vSwitch ##########"
apt-get install -y openvswitch-controller openvswitch-switch \
neutron-server neutron-plugin-ml2 neutron-plugin-openvswitch-agent \
neutron-l3-agent neutron-dhcp-agent conntrack


######## BACK UP NEUTRON.CONF IN CONTROLLER##################"
echo "########## MODIFYING neutron.conf ##########"
NOVA_TENANT_ID=$(source admin-openrc.sh ; keystone tenant-get service | awk '$2~/^id/{print $4}')


#
controlneutron=/etc/neutron/neutron.conf
test -f $controlneutron.orig || cp $controlneutron $controlneutron.orig

crudini --set $controlneutron '' verbose True

crudini --set $controlneutron '' core_plugin ml2
crudini --set $controlneutron '' service_plugins router
crudini --set $controlneutron '' allow_overlapping_ips True
crudini --set $controlneutron '' auth_strategy keystone

crudini --set $controlneutron '' notify_nova_on_port_status_changes True
crudini --set $controlneutron '' notify_nova_on_port_data_changes True
crudini --set $controlneutron '' nova_url http://$MANAGEMENT:8774/v2
crudini --set $controlneutron '' nova_admin_auth_url http://$MANAGEMENT:35357/v2.0
crudini --set $controlneutron '' nova_region_name regionOne
crudini --set $controlneutron '' nova_admin_username nova
crudini --set $controlneutron '' nova_admin_tenant_id $NOVA_TENANT_ID
crudini --set $controlneutron '' nova_admin_password $SERVICE_PASSWORD

crudini --set $controlneutron '' rpc_backend rabbit
crudini --set $controlneutron '' rabbit_host $MANAGEMENT
crudini --set $controlneutron '' rabbit_userid guest
crudini --set $controlneutron '' rabbit_password $RABBIT_PASS

crudini --set $controlneutron keystone_authtoken auth_uri http://$MANAGEMENT:5000/v2.0
crudini --set $controlneutron keystone_authtoken identity_uri http://$MANAGEMENT:35357
crudini --set $controlneutron keystone_authtoken admin_tenant_name service
crudini --set $controlneutron keystone_authtoken admin_user neutron
crudini --set $controlneutron keystone_authtoken admin_password $SERVICE_PASSWORD

crudini --del $controlneutron keystone_authtoken auth_host
crudini --del $controlneutron keystone_authtoken auth_port
crudini --del $controlneutron keystone_authtoken auth_protocol

crudini --set $controlneutron database connection mysql://neutron:$SERVICE_PASSWORD@$MANAGEMENT/neutron




######## BACK-UP ML2 CONFIG IN CONTROLLER##################"
echo "########## MODIFYING ml2_conf.ini ##########"
#sleep 7

controlML2=/etc/neutron/plugins/ml2/ml2_conf.ini
test -f $controlML2.orig || cp $controlML2 $controlML2.orig

crudini --set $controlML2 ml2 type_drivers flat,gre,vxlan
crudini --set $controlML2 ml2 tenant_network_types gre
crudini --set $controlML2 ml2 mechanism_drivers openvswitch

crudini --set $controlML2 ml2_type_flat flat_networks external

crudini --set $controlML2 ml2_type_gre tunnel_id_ranges 1:1000

crudini --set $controlML2 securitygroup enable_security_group True
crudini --set $controlML2 securitygroup enable_ipset True
crudini --set $controlML2 securitygroup firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

crudini --set $controlML2 ovs local_ip $TUNNEL_IP
crudini --set $controlML2 ovs tunnel_type gre
crudini --set $controlML2 ovs enable_tunneling True
crudini --set $controlML2 ovs bridge_mappings external:br-ex

crudini --set $controlML2 agent tunnel_types gre


###################### BACK-UP L3 CONFIG ###########################"
echo "########## MODIFYING l3_agent.ini ##########"
#sleep 7


l3file=/etc/neutron/l3_agent.ini
test -f $l3file.orig || cp $l3file $l3file.orig

crudini --set $l3file '' verbose True
crudini --set $l3file '' interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
crudini --set $l3file '' use_namespaces True
crudini --set $l3file '' external_network_bridge br-ex
crudini --set $l3file '' router_delete_namespaces True


######## MODIFYING DHCP CONFIG ##################"
echo "########## MODIFYING DHCP CONFIG ##########"
#sleep 7

dhcpfile=/etc/neutron/dhcp_agent.ini
test -f $dhcpfile.orig || cp $dhcpfile $dhcpfile.orig

crudini --set $dhcpfile '' verbose True
crudini --set $dhcpfile '' interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
crudini --set $dhcpfile '' dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
crudini --set $dhcpfile '' use_namespaces True
crudini --set $dhcpfile '' dhcp_delete_namespaces True
crudini --set $dhcpfile '' dnsmasq_config_file /etc/neutron/dnsmasq-neutron.conf

touch /etc/neutron/dnsmasq-neutron.conf
crudini --set /etc/neutron/dnsmasq-neutron.conf '' dhcp-option-force 26,1454

echo "########## Killing existing dnsmasq ##########"
pkill dnsmasq




######## BACK-UP METADATA CONFIG IN CONTROLLER##################"
echo "########## MODIFYING metadata_agent.ini ##########"
#sleep 7

metadatafile=/etc/neutron/metadata_agent.ini
test -f $metadatafile.orig || cp $metadatafile $metadatafile.orig

crudini --set $metadatafile '' verbose True
crudini --set $metadatafile '' auth_url http://$MANAGEMENT:5000/v2.0
crudini --set $metadatafile '' auth_region regionOne
crudini --set $metadatafile '' admin_tenant_name service
crudini --set $metadatafile '' admin_user neutron
crudini --set $metadatafile '' admin_password $SERVICE_PASSWORD
crudini --set $metadatafile '' nova_metadata_ip $MANAGEMENT_IP
crudini --set $metadatafile '' metadata_proxy_shared_secret $METADATA_SECRET

chown -R root:neutron /etc/neutron/*

su -s /bin/sh -c "neutron-db-manage --config-file $controlneutron \
--config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade juno" neutron

echo "########## RESTARTING NEUTRON SERVICE ##########"
#sleep 5
service neutron-server restart
service neutron-l3-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart
service openvswitch-switch restart
service neutron-plugin-openvswitch-agent restart

# ADDING RESTARTING NEUTRON SERVICE COMMAND EACH TIME RESET OPENSTACK
sed -i "s/exit 0/# exit 0/g" /etc/rc.local
echo "service neutron-server restart"
echo "service neutron-l3-agent restart"
echo "service neutron-dhcp-agent restart"
echo "service neutron-metadata-agent restart"
echo "service openvswitch-switch restart"
echo "service neutron-plugin-openvswitch-agent restart"
echo "exit 0" >> /etc/rc.local


echo "########## TESTING NEUTRON (WAIT 20s)   ##########"
# WAITING FOR NEUTRON BOOT-UP

sleep 20
source admin-openrc.sh
neutron agent-list

echo "########## CONFIGURING br-int AND br-ex FOR OpenvSwitch ##########"
#sleep 5
ovs-vsctl add-br br-ex

# If Management interface (assuming the current connection is also on management) and External interface are not same then add interface to bridge, else connectivity will be lost
# External interface are same, then add exteral interface to br-ex manually in a controlled way later
if [[ ${MANAGEMENT_IFACE} != ${EXTERNAL_IFACE} ]] ; then
   # Check if External interface has IP address, bring it down else after adding the interface to br-ex bridge there will be connectivity issue
   if [[ $(ifconfig ${EXTERNAL_IFACE} | grep "inet addr" | wc -l) != 0 ]] ; then
      ifdown ${EXTERNAL_IFACE}
   fi
   ovs-vsctl add-port br-ex $EXTERNAL_IFACE
fi


echo "########## CONFIGURING IP FOR br-ex ##########"

ifaces=/etc/network/interfaces
test -f $ifaces.orig1 || cp $ifaces $ifaces.orig1
rm $ifaces

#Update Management interface details
cat << EOF > $ifaces
## The loopback network interface
auto lo
iface lo inet loopback

auto $MANAGEMENT_IFACE
iface $MANAGEMENT_IFACE inet static
address $MANAGEMENT_IP
netmask 255.255.255.0
gateway $GATEWAY_IP
dns-nameservers $DNS_NAMESERVERS

EOF

#Update Tunnel interface details
if [[ ${MANAGEMENT_IFACE} != ${TUNNEL_IFACE} ]] ; then
cat << EOF >> $ifaces
   
auto $TUNNEL_IFACE
iface $TUNNEL_IFACE inet static
address $TUNNEL_IP
netmask 255.255.255.0
   
EOF
fi

#Update External interface details
if [[ ${MANAGEMENT_IFACE} != ${EXTERNAL_IFACE} && ${TUNNEL_IFACE} != ${EXTERNAL_IFACE} ]] ; then
cat << EOF >> $ifaces
   
## The External bridge interface
auto br-ex
iface br-ex inet static
address $brex_address
netmask 255.255.255.0
   
## The External network interface
auto $EXTERNAL_IFACE
iface $EXTERNAL_IFACE inet manual
   up ifconfig \$IFACE 0.0.0.0 up
   up ip link set \$IFACE promisc on
   down ip link set \$IFACE promisc off
   down ifconfig \$IFACE down
EOF
else
   echo "Configure the $ifaces file with the following entries manually"
   
fi

# Bring up the br-ex and external interface after updating network config
echo "# Bringing up the br-ex and external interface after updating network config"
ifup br-ex
ifup $EXTERNAL_IFACE

sleep 10

echo "########## Installing and Configuring LBaas, FWaaS and VPNaaS ##########"

##Install and Configure LBaaS
echo "########## Installing and Configuring LBaas ##########"

# Install packages
apt-get install -y neutron-lbaas-agent

# Check if entry for load balancer service_provider is already there. Using wc -l because using grep -c FIREWALL was giving return status 1
# which was causing the script to exit due to use of -e with bash
LB_ENTRY_EXISTS=$(grep "service_provider" /etc/neutron/neutron.conf | grep -v "^#" | grep LOADBALANCER | wc -l)
if [[ ${LB_ENTRY_EXISTS} = 0 ]] ; then
   echo "service_provider=LOADBALANCER:Haproxy:neutron.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default" >> /etc/neutron/neutron.conf
fi

# Check if entry for load balancer service_plugin is already there
EXISTING_ENTRY=$(crudini --get /etc/neutron/neutron.conf DEFAULT service_plugins)
if [[ $(echo ${EXISTING_ENTRY} | grep -c lbaas) = 0 ]] ; then   
   NEW_ENTRY="${EXISTING_ENTRY},lbaas"
   crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins ${NEW_ENTRY}
fi

# Define device_driver for LBaaS
crudini --set /etc/neutron/lbaas_agent.ini '' device_driver neutron.services.loadbalancer.drivers.haproxy.namespace_driver.HaproxyNSDriver

# Define interface_driver for LBaaS
crudini --set /etc/neutron/lbaas_agent.ini '' interface_driver neutron.agent.linux.interface.OVSInterfaceDriver


##Install and Configure FWaaS
echo "########## Installing and Configuring FWaas ##########"

# Check if entry for firewall service_provider is already there. Using wc -l because using grep -c FIREWALL was giving return status 1
# which was causing the script to exit due to use of -e with bash
FW_ENTRY_EXISTS=$(grep "service_provider" /etc/neutron/neutron.conf | grep -v "^#" | grep FIREWALL | wc -l)
if [[ ${FW_ENTRY_EXISTS} = 0 ]] ; then
   echo "service_provider=FIREWALL:Iptables:neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver:default" >> /etc/neutron/neutron.conf
fi

# Check if entry for firewall service_plugin is already there
EXISTING_ENTRY=$(crudini --get /etc/neutron/neutron.conf DEFAULT service_plugins)
if [[ $(echo ${EXISTING_ENTRY} | grep -c firewall) = 0 ]] ; then   
   NEW_ENTRY="${EXISTING_ENTRY},firewall"
   crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins ${NEW_ENTRY}
fi

# Update fwaas_driver.ini 
crudini --set /etc/neutron/fwaas_driver.ini fwaas driver neutron.services.firewall.drivers.linux.iptables_fwaas.IptablesFwaasDriver
crudini --set /etc/neutron/fwaas_driver.ini fwaas enabled True


### Below VPNaaS section commented out because installation of VPN causes l3-agent to not work as it uninstalls neutron-l3-agent package
##Install and Configure VPNaaS
#nnn#echo "########## Installing and Configuring VPNaas ##########"

# Install neutron-vpn-agent
#nnn#echo "openswan openswan/install_x509_certificate boolean false" | debconf-set-selections
#nnn#apt-get install -y neutron-vpn-agent openswan

# Check if entry for vpn service_provider is already there
#nnn#VPN_ENTRY_EXISTS=$(grep "service_provider" /etc/neutron/neutron.conf | grep -v "^#" | grep -c VPN)
#nnn#if [[ ${VPN_ENTRY_EXISTS} = 0 ]] ; then
   #nnn#echo "service_provider=VPN:openswan:neutron.services.vpn.service_drivers.ipsec.IpsecVPNDriver:default" >> /etc/neutron/neutron.conf
#nnn#fi

# Check if entry for vpn service_plugin is already there
#nnn#EXISTING_ENTRY=$(crudini --get /etc/neutron/neutron.conf DEFAULT service_plugins)
#nnn#if [[ $(echo ${EXISTING_ENTRY} | grep -c vpnaas) = 0 ]] ; then   
   #nnn#NEW_ENTRY="${EXISTING_ENTRY},vpnaas"
   #nnn#crudini --set /etc/neutron/neutron.conf DEFAULT service_plugins ${NEW_ENTRY}
#nnn#fi


# Ensure below entries in file /etc/neutron/rootwrap.d/vpnaas.filters
#nnn#crudini --set /etc/neutron/rootwrap.d/vpnaas.filters Filters ip "IpFilter, ip, root"
#nnn#crudini --set /etc/neutron/rootwrap.d/vpnaas.filters Filters ip_exec "IpNetnsExecFilter, ip, root"
#nnn#crudini --set /etc/neutron/rootwrap.d/vpnaas.filters Filters openswan "CommandFilter, ipsec, root"

# Update vpn_agent.ini
#nnn#crudini --set /etc/neutron/vpn_agent.ini '' interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
#nnn#crudini --set /etc/neutron/vpn_agent.ini vpnagent vpn_device_driver neutron.services.vpn.device_drivers.ipsec.OpenSwanDriver
#nnn#crudini --set /etc/neutron/vpn_agent.ini ipsec ipsec_status_check_interval 60


echo "########## Installation and Configuration completed ##########"
echo "Restarting services"
# Restart services
service neutron-server restart
service neutron-lbaas-agent start
service neutron-l3-agent restart
#nnn#service neutron-vpn-agent restart

#echo "##########  RESTARTING AFTER CONFIGURING IP ADDRESS ##########"
#init 6
