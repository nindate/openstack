#!/bin/bash -ex
source config.cfg

echo "########## Configuring Dashboard ##########"
# Install packages
apt-get -y install openstack-dashboard 


sed -i "s/OPENSTACK_HOST =.*/OPENSTACK_HOST = \"$CONTROLLER_VIP\"/g" /etc/openstack-dashboard/local_settings.py
sed -i "s/ALLOWED_HOSTS =.*/ALLOWED_HOSTS = ['*', ]/g" /etc/openstack-dashboard/local_settings.py
#sed -i "s/'LOCATION':.*/'LOCATION': '$CONTROLLER_VIP:11211',/g" /etc/openstack-dashboard/local_settings.py
#sed -i "s/OPENSTACK_KEYSTONE_URL =.*/OPENSTACK_KEYSTONE_URL = \"http:\/\/%s:5000\/v3\" % OPENSTACK_HOST/g" /etc/openstack-dashboard/local_settings.py
sed -i "s/.*OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT =.*/OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True/g" /etc/openstack-dashboard/local_settings.py
#sed -i "s/.*OPENSTACK_KEYSTONE_DEFAULT_DOMAIN =.*/OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = \"default\"/g" /etc/openstack-dashboard/local_settings.py
sed -i "s/.*OPENSTACK_KEYSTONE_DEFAULT_ROLE.*/OPENSTACK_KEYSTONE_DEFAULT_ROLE = \"user\"/g" /etc/openstack-dashboard/local_settings.py

cat << EOF >> /etc/openstack-dashboard/local_settings.py
OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 2,
}
EOF

# To be able to set password for instance when launching or rebuilding
sed -i "s/'can_set_password': False/'can_set_password': True/g" /etc/openstack-dashboard/local_settings.py

# Enable cinder backup in dashboard
sed -i -e "s/enable_backup.*$/enable_backup\'\: True\,/" /etc/openstack-dashboard/local_settings.py

# Enable lbaas in dashboard
sed -i -e "s/enable_lb.*$/enable_lb\'\: True\,/" /etc/openstack-dashboard/local_settings.py

# Enable firewall in dashboard
sed -i -e "s/enable_firewall.*$/enable_firewall\'\: True\,/" /etc/openstack-dashboard/local_settings.py

# Enable vpn in dashboard
#nnn#sed -i -e "s/enable_vpn.*$/enable_vpn\'\: True\,/" /etc/openstack-dashboard/local_settings.py

# Purge dashboard theme for Ubuntu 
#apt-get remove --auto-remove openstack-dashboard-ubuntu-theme
###dpkg --purge openstack-dashboard-ubuntu-theme

## Restart apache 
service apache2 reload

echo "########## Details of login to Openstack dashboard ##########"
echo "URL: http://$CONTROLLER_VIP/horizon"
echo "User: admin"
echo "Password:" $ADMIN_PASS

echo "User: demo"
echo "Password:" $DEMO_PASS
