#!/bin/bash -ex
source config.cfg

echo "########## Configuring Dashboard ##########"
# Install packages
apt-get -y install openstack-dashboard memcached && dpkg --purge openstack-dashboard-ubuntu-theme


echo "########## fix apache2 for ubuntu 14.04 ##########"
#sleep 5
echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
sudo a2enconf servername 
# echo "ServerName localhost" >> /etc/apache2/httpd.conf


echo "########## redirect ##########"

filehtml=/var/www/html/index.html
test -f $filehtml.orig || cp $filehtml $filehtml.orig
rm $filehtml
touch $filehtml
cat << EOF >> $filehtml
<html>
<head>
<META HTTP-EQUIV="Refresh" Content="0.5; URL=http://$MANAGEMENT/horizon">
</head>
<body>
<center> <h1>OpenStack Dashboard</h1> </center>
</body>
</html>
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
#sed -i -e "s/enable_vpn.*$/enable_vpn\'\: True\,/" /etc/openstack-dashboard/local_settings.py

## Restart apache and  memcached
service apache2 restart
service memcached restart

echo "########## Details of login to Openstack dashboard ##########"
echo "URL: http://$MANAGEMENT/horizon"
echo "User: admin"
echo "Password:" $ADMIN_PASS

echo "User: demo"
echo "Password:" $DEMO_PASS
