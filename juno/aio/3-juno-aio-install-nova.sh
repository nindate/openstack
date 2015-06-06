#!/bin/bash -ex
source config.cfg

# Create database
echo "########## CREATING DATABASE ##########"
cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS nova;
#
CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'$MANAGEMENT' IDENTIFIED BY '$MYSQL_PASS';
#
FLUSH PRIVILEGES;
EOF
#

echo "########## CREATING nova service credentials and endpoint ##########"
export OS_SERVICE_TOKEN="$TOKEN_PASS"
export OS_SERVICE_ENDPOINT="http://$MANAGEMENT:35357/v2.0"
export SERVICE_ENDPOINT="http://$MANAGEMENT:35357/v2.0"


get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

NOVA_USER=$(get_id keystone user-create --name=nova --pass="$SERVICE_PASSWORD" --email=nova@example.com)
keystone user-role-add --tenant $SERVICE_TENANT_NAME --user-id $NOVA_USER --role $ADMIN_ROLE_NAME

echo "########## CREATING NOVA SERVICE ##########"
keystone service-create --name=nova --type=compute --description="OpenStack Compute"
echo "########## CREATING NOVA ENDPOINT ##########"
keystone endpoint-create \
--region regionOne \
--service-id=$(keystone service-list | awk '/ compute / {print $2}') \
--publicurl=http://$MANAGEMENT:8774/v2/%\(tenant_id\)s \
--internalurl=http://$MANAGEMENT:8774/v2/%\(tenant_id\)s \
--adminurl=http://$MANAGEMENT:8774/v2/%\(tenant_id\)s


echo "########## INSTALLING NOVA IN CONTROLLER NODE ################"
apt-get install -y nova-api nova-cert nova-conductor nova-consoleauth \
nova-novncproxy nova-scheduler python-novaclient \
nova-compute-kvm python-guestfs sysfsutils

echo "########## BACKUP NOVA CONFIGURATION ##################"
controlnova=/etc/nova/nova.conf
test -f $controlnova.orig || cp $controlnova $controlnova.orig

crudini --set $controlnova '' volumes_path /var/lib/nova/volumes
crudini --set $controlnova '' glance_host $MANAGEMENT
crudini --set $controlnova '' verbose True


crudini --set $controlnova '' rpc_backend rabbit
crudini --set $controlnova '' rabbit_host $MANAGEMENT
crudini --set $controlnova '' rabbit_userid guest
crudini --set $controlnova '' rabbit_password $RABBIT_PASS

crudini --set $controlnova '' my_ip $MANAGEMENT_IP
crudini --set $controlnova '' vncserver_listen $MANAGEMENT
crudini --set $controlnova '' vncserver_proxyclient_address $MANAGEMENT_IP
crudini --set $controlnova '' auth_strategy keystone
crudini --set $controlnova '' novncproxy_base_url http://$MANAGEMENT_IP:6080/vnc_auto.html

# Start VM after reboot of Compute node 
crudini --set $controlnova '' resume_guests_state_on_host_boot True

# Configure for resize of instance
crudini --set $controlnova '' allow_resize_to_same_host True
crudini --set $controlnova '' allow_migrate_to_same_host True
crudini --set $controlnova '' resize_confirm_window 5
crudini --set $controlnova '' scheduler_default_filters AllHostsFilter

# Configure for injection of password into instance
crudini --set $controlnova '' libvirt_inject_password True
crudini --set $controlnova '' enable_instance_password True
crudini --set $controlnova '' libvirt_inject_partition -1

crudini --set $controlnova '' network_api_class nova.network.neutronv2.api.API
crudini --del $controlnova '' neutron_url
crudini --del $controlnova '' neutron_auth_strategy
crudini --del $controlnova '' neutron_admin_tenant_name
crudini --del $controlnova '' neutron_admin_username
crudini --del $controlnova '' neutron_admin_password
crudini --del $controlnova '' neutron_admin_auth_url

crudini --set $controlnova '' linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
crudini --set $controlnova '' firewall_driver nova.virt.firewall.NoopFirewallDriver
crudini --set $controlnova '' security_group_api neutron

crudini --del $controlnova '' service_neutron_metadata_proxy
crudini --del $controlnova '' neutron_metadata_proxy_shared_secret

crudini --set $controlnova neutron service_metadata_proxy True
crudini --set $controlnova neutron metadata_proxy_shared_secret $METADATA_SECRET
crudini --set $controlnova neutron url http://$MANAGEMENT:9696
crudini --set $controlnova neutron auth_strategy keystone
crudini --set $controlnova neutron admin_auth_url http://$MANAGEMENT:35357/v2.0
crudini --set $controlnova neutron admin_tenant_name service
crudini --set $controlnova neutron admin_username neutron
crudini --set $controlnova neutron admin_password $SERVICE_PASSWORD
 
crudini --set $controlnova database connection mysql://nova:$MYSQL_PASS@$MANAGEMENT/nova
 
crudini --set $controlnova keystone_authtoken auth_uri http://$MANAGEMENT:5000/v2.0
crudini --set $controlnova keystone_authtoken identity_uri http://$MANAGEMENT:35357
crudini --set $controlnova keystone_authtoken admin_tenant_name service
crudini --set $controlnova keystone_authtoken admin_user nova
crudini --set $controlnova keystone_authtoken admin_password $SERVICE_PASSWORD

crudini --del $controlnova keystone_authtoken auth_host
crudini --del $controlnova keystone_authtoken auth_port
crudini --del $controlnova keystone_authtoken auth_protocol

crudini --set $controlnova glance host $MANAGEMENT

chown nova:nova $controlnova

echo "########## REMOVE DEFAULT NOVA DB ##########"
#sleep 7
if [[ $(ls /var/lib/nova/nova.sqlite >/dev/null 2>&1 | wc -l) != 0 ]] ; then
   rm /var/lib/nova/nova.sqlite
fi

echo "########## SYNCING NOVA DB ##########"
#sleep 7 
nova-manage db sync


echo " "
echo "########## FIX BUG CONFIGURING NOVA ##########"
#sleep 5
dpkg-statoverride --update --add root root 0644 /boot/vmlinuz-$(uname -r)

cat > /etc/kernel/postinst.d/statoverride <<EOF
#!/bin/sh
version="\$1"
# passing the kernel version is required
[ -z "\${version}" ] && exit 0
dpkg-statoverride --update --add root root 0644 /boot/vmlinuz-\${version}
EOF

chmod +x /etc/kernel/postinst.d/statoverride

# fix bug libvirtError: internal error: no supported architecture for os type 'hvm'
echo 'kvm_intel' >> /etc/modules
#sleep 10

# Set virt_type to kvm/qemu 
crudini --set /etc/nova/nova-compute.conf libvirt virt_type $VIRT_TYPE

## Fix for bug which fails creating new instance saying could not allocate network
crudini --set /etc/nova/nova.conf '' vif_plugging_is_fatal false
crudini --set /etc/nova/nova.conf '' vif_plugging_timeout 0

#sleep 10

echo "########## RESTARTING NOVA SERVICE ##########"
service nova-conductor restart
service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-novncproxy restart
service nova-compute restart

echo "########## TESTING NOVA SETUP ##########"
sleep 10
nova-manage service list

echo "########## FINISHED NOVA SETUP ##########"
