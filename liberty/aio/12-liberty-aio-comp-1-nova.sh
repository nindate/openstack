#!/bin/bash -ex
source config.cfg

echo "########## INSTALLING NOVA IN CONTROLLER NODE ################"
apt-get install -y nova-compute sysfsutils

echo "########## BACKUP NOVA CONFIGURATION ##################"
controlnova=/etc/nova/nova.conf
test -f $controlnova.orig || cp $controlnova $controlnova.orig
#rm $controlnova


crudini --set $controlnova '' rpc_backend rabbit

crudini --set $controlnova oslo_messaging_rabbit rabbit_host $MESSAGING_VIP
crudini --set $controlnova oslo_messaging_rabbit rabbit_userid openstack
crudini --set $controlnova oslo_messaging_rabbit rabbit_password $RABBIT_PASS

crudini --set $controlnova '' auth_strategy keystone
 
crudini --set $controlnova keystone_authtoken auth_uri http://$CONTROLLER_VIP:5000
crudini --set $controlnova keystone_authtoken identity_uri http://$CONTROLLER_VIP:35357
#crudini --set $controlnova keystone_authtoken memcached_servers $CONTROLLER_VIP:11211
crudini --set $controlnova keystone_authtoken auth_plugin password
crudini --set $controlnova keystone_authtoken project_domain_name default
crudini --set $controlnova keystone_authtoken user_domain_name default
crudini --set $controlnova keystone_authtoken project_name service
crudini --set $controlnova keystone_authtoken username nova
crudini --set $controlnova keystone_authtoken password $SERVICE_PASSWORD

crudini --set $controlnova '' my_ip $COMPUTE_MANAGEMENT_IP
#crudini --set $controlnova '' use_neutron True
crudini --set $controlnova '' network_api_class nova.network.neutronv2.api.API
crudini --set $controlnova '' security_group_api neutron
crudini --set $controlnova '' linuxnet_interface_driver nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver
crudini --set $controlnova '' firewall_driver nova.virt.firewall.NoopFirewallDriver

crudini --set $controlnova vnc vnc_enabled True
crudini --set $controlnova vnc vncserver_listen 0.0.0.0
crudini --set $controlnova vnc vncserver_proxyclient_address $COMPUTE_MANAGEMENT_IP
crudini --set $controlnova vnc novncproxy_base_url http://$CONTROLLER_VIP:6080/vnc_auto.html

#crudini --set $controlnova glance api_servers http://$CONTROLLER_VIP:9292
crudini --set $controlnova glance host $CONTROLLER_VIP

crudini --set $controlnova oslo_concurrency lock_path /var/lib/nova/tmp

crudini --set $controlnova '' verbose True

# Start VM after reboot of Compute node 
#crudini --set $controlnova '' resume_guests_state_on_host_boot True

# Configure for resize of instance
#crudini --set $controlnova '' allow_resize_to_same_host True
#crudini --set $controlnova '' allow_migrate_to_same_host True
#crudini --set $controlnova '' resize_confirm_window 5
#crudini --set $controlnova '' scheduler_default_filters AllHostsFilter

# Configure for injection of password into instance
#crudini --set $controlnova '' libvirt_inject_password True
#crudini --set $controlnova '' enable_instance_password True
#crudini --set $controlnova '' libvirt_inject_partition -1

# Set virt_type to kvm/qemu 
crudini --set /etc/nova/nova-compute.conf libvirt virt_type $VIRT_TYPE


chown nova:nova $controlnova

echo " "
#echo "########## FIX BUG CONFIGURING NOVA ##########"
#sleep 5
#dpkg-statoverride --update --add root root 0644 /boot/vmlinuz-$(uname -r)

#cat > /etc/kernel/postinst.d/statoverride <<EOF
##!/bin/sh
#version="\$1"
## passing the kernel version is required
#[ -z "\${version}" ] && exit 0
#dpkg-statoverride --update --add root root 0644 /boot/vmlinuz-\${version}
#EOF

#chmod +x /etc/kernel/postinst.d/statoverride

# fix bug libvirtError: internal error: no supported architecture for os type 'hvm'
#echo 'kvm_intel' >> /etc/modules
#sleep 10

## Fix for bug which fails creating new instance saying could not allocate network
#crudini --set /etc/nova/nova.conf '' vif_plugging_is_fatal false
#crudini --set /etc/nova/nova.conf '' vif_plugging_timeout 0

#sleep 10

echo "########## RESTARTING NOVA SERVICE ##########"
service nova-compute restart

echo "########## TESTING NOVA SETUP ##########"
sleep 10
source admin-openrc.sh
openstack compute service list

echo "########## FINISHED NOVA SETUP ##########"

