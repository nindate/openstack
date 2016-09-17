#!/bin/bash -ex

source config.cfg

echo "##### START INSTALLING KEYSTONE ##### "
#sleep 3

# Disable the keystone service from starting automatically after installation.
# In Kilo, the keystone project deprecates Eventlet in favor of a WSGI server. This guide uses the Apache HTTP server with mod_wsgi to serve keystone requests on ports 5000 and 35357. By default, the keystone service still listens on ports 5000 and 35357. Therefore, this guide disables the keystone service.
echo "manual" > /etc/init/keystone.override

# Install packages
apt-get install -y keystone apache2 libapache2-mod-wsgi 

# Back up before editing keystone.conf
filekeystone=/etc/keystone/keystone.conf
test -f $filekeystone.orig || cp $filekeystone $filekeystone.orig

echo " ##### EDITING CONFIG FILE /etc/keystone/keystone.conf ##### "
#sleep 3

crudini --set $filekeystone '' admin_token $ADMIN_TOKEN
#crudini --set $filekeystone '' public_bind_host $CONTROLLER_MANAGEMENT_IP
#crudini --set $filekeystone '' admin_bind_host $CONTROLLER_MANAGEMENT_IP
#crudini --set $filekeystone '' compute_port 8774
#crudini --set $filekeystone '' admin_port 35357
#crudini --set $filekeystone '' public_port 5000
crudini --set $filekeystone '' verbose True
#crudini --set $filekeystone '' log_dir /var/log/keystone

#crudini --set $filekeystone database connection mysql://keystone:$MYSQL_PASS@$DATABASE_VIP/keystone
crudini --set $filekeystone database connection mysql+pymysql://keystone:$MYSQL_PASS@$DATABASE_VIP/keystone 
#crudini --set $filekeystone database idle_timeout 3600

#crudini --set $filekeystone memcache servers localhost:11211

#crudini --set $filekeystone extra_headers Distribution Ubuntu

crudini --set $filekeystone token provider uuid
crudini --set $filekeystone token driver memcached

crudini --set $filekeystone revoke driver sql


echo "ServerName $CONTROLLER_MANAGEMENT_NAME" >> /etc/apache2/apache2.conf


cat > /etc/apache2/sites-available/wsgi-keystone.conf << EOF
Listen $CONTROLLER_MANAGEMENT_IP:5000
Listen $CONTROLLER_MANAGEMENT_IP:35357

<VirtualHost $CONTROLLER_MANAGEMENT_IP:5000>
    WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-public
    WSGIScriptAlias / /usr/bin/keystone-wsgi-public
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    <IfVersion >= 2.4>
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog /var/log/apache2/keystone.log
    CustomLog /var/log/apache2/keystone_access.log combined

    <Directory /usr/bin>
        <IfVersion >= 2.4>
            Require all granted
        </IfVersion>
        <IfVersion < 2.4>
            Order allow,deny
            Allow from all
        </IfVersion>
    </Directory>
</VirtualHost>

<VirtualHost $CONTROLLER_MANAGEMENT_IP:35357>
    WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-admin
    WSGIScriptAlias / /usr/bin/keystone-wsgi-admin
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    <IfVersion >= 2.4>
      ErrorLogFormat "%{cu}t %M"
    </IfVersion>
    ErrorLog /var/log/apache2/keystone.log
    CustomLog /var/log/apache2/keystone_access.log combined

    <Directory /usr/bin>
        <IfVersion >= 2.4>
            Require all granted
        </IfVersion>
        <IfVersion < 2.4>
            Order allow,deny
            Allow from all
        </IfVersion>
    </Directory>
</VirtualHost>

EOF

###cat > /etc/apache2/sites-available/wsgi-keystone.conf << EOF
###Listen $CONTROLLER_MANAGEMENT_IP:5000
###Listen $CONTROLLER_MANAGEMENT_IP:35357

###<VirtualHost $CONTROLLER_MANAGEMENT_IP:5000>
    ###WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone display-name=%{GROUP}
    ###WSGIProcessGroup keystone-public
    ###WSGIScriptAlias / /var/www/cgi-bin/keystone/main
    ###WSGIApplicationGroup %{GLOBAL}
    ###WSGIPassAuthorization On
    ###<IfVersion >= 2.4>
      ###ErrorLogFormat "%{cu}t %M"
    ###</IfVersion>
    ###LogLevel info
    ###ErrorLog /var/log/apache2/keystone-error.log
    ###CustomLog /var/log/apache2/keystone-access.log combined
###</VirtualHost>
###
###<VirtualHost $CONTROLLER_MANAGEMENT_IP:35357>
    ###WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone display-name=%{GROUP}
    ###WSGIProcessGroup keystone-admin
    ###WSGIScriptAlias / /var/www/cgi-bin/keystone/admin
    ###WSGIApplicationGroup %{GLOBAL}
    ###WSGIPassAuthorization On
    ###<IfVersion >= 2.4>
      ###ErrorLogFormat "%{cu}t %M"
    ###</IfVersion>
    ###LogLevel info
    ###ErrorLog /var/log/apache2/keystone-error.log
    ###CustomLog /var/log/apache2/keystone-access.log combined
###</VirtualHost>
###
###EOF

# Enable the Identity service virtual hosts
ln -s /etc/apache2/sites-available/wsgi-keystone.conf /etc/apache2/sites-enabled

# Create the directory structure for the WSGI components
#mkdir -p /var/www/cgi-bin/keystone


# Copy the WSGI components from the upstream repository into this directory
#curl http://git.openstack.org/cgit/openstack/keystone/plain/httpd/keystone.py?h=stable/kilo \
  #| tee /var/www/cgi-bin/keystone/main /var/www/cgi-bin/keystone/admin

# Adjust ownership and permissions on this directory and the files in it
#chown -R keystone:keystone /var/www/cgi-bin/keystone
#chmod 755 /var/www/cgi-bin/keystone/*


# Restart the Apache HTTP server
service apache2 restart

