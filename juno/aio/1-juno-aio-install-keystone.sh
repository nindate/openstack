#!/bin/bash -ex

source config.cfg

echo "##### START INSTALLING KEYSTONE ##### "
#sleep 3


echo "##### CREATE DATABASE ##### "
cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS keystone;

#
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'$MANAGEMENT' IDENTIFIED BY '$MYSQL_PASS';
#
FLUSH PRIVILEGES;
EOF
#

# Install packages
apt-get install -y keystone python-keystoneclient

# Back up before editing keystone.conf
filekeystone=/etc/keystone/keystone.conf
test -f $filekeystone.orig || cp $filekeystone $filekeystone.orig

echo " ##### EDITING CONFIG FILE /etc/keystone/keystone.conf ##### "
#sleep 3

crudini --set $filekeystone '' admin_token $SERVICE_PASSWORD
crudini --set $filekeystone '' public_bind_host 0.0.0.0
crudini --set $filekeystone '' admin_bind_host 0.0.0.0
crudini --set $filekeystone '' compute_port 8774
crudini --set $filekeystone '' admin_port 35357
crudini --set $filekeystone '' public_port 5000
crudini --set $filekeystone '' verbose True
crudini --set $filekeystone '' log_dir /var/log/keystone

crudini --set $filekeystone database connection mysql://keystone:$MYSQL_PASS@$MANAGEMENT/keystone
crudini --set $filekeystone database idle_timeout 3600

crudini --set $filekeystone extra_headers Distribution Ubuntu

crudini --set $filekeystone token provider keystone.token.providers.uuid.Provider
crudini --set $filekeystone token driver keystone.token.persistence.backends.sql.Token

crudini --set $filekeystone revoke driver keystone.contrib.revoke.backends.sql.Revoke

echo " ##### SETUP KEYSTONE DB ##### "
#sleep 3
keystone-manage db_sync

echo "##### RESTARTING KEYSTONE ##### "
service keystone restart
#sleep 3

echo "##### DELETE KEYSTONE DEFAULT DB ##### "
#sleep 3
rm  /var/lib/keystone/keystone.db

(crontab -l -u keystone 2>&1 | grep -q token_flush) || \
echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' >> /var/spool/cron/crontabs/keystone

export OS_SERVICE_TOKEN="$TOKEN_PASS"
export OS_SERVICE_ENDPOINT="http://$MANAGEMENT:35357/v2.0"
export SERVICE_ENDPOINT="http://$MANAGEMENT:35357/v2.0"

echo "##### VALIDATE KEYSTONE SETUP ##### "
sleep 5
keystone user-list

echo "##### COMPLETE KEYSTONE INSTALLING & CONFIGURING #####"

get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

echo "########## Creating admin tenant, user and role ##########"
ADMIN_TENANT=$(get_id keystone tenant-create --name=$ADMIN_TENANT_NAME)
ADMIN_USER=$(get_id keystone user-create --name="$ADMIN_USER_NAME" --pass="$ADMIN_PASS" --email=admin@example.com)
ADMIN_ROLE=$(get_id keystone role-create --name="$ADMIN_ROLE_NAME")
keystone user-role-add --user-id $ADMIN_USER --role-id $ADMIN_ROLE --tenant-id $ADMIN_TENANT

echo "########## Creating demo tenant, user and role ##########"
DEMO_TENANT=$(get_id keystone tenant-create --name=$DEMO_TENANT_NAME)
DEMO_USER=$(get_id keystone user-create --name="$DEMO_USER_NAME" --pass="$DEMO_PASS" --email=demo@example.com)

echo "########## Creating service tenant ##########"
SERVICE_TENANT=$(get_id keystone tenant-create --name=$SERVICE_TENANT_NAME)

echo "########## CREATING KEYSTONE SERVICE ##########"
keystone service-create --name=keystone --type=identity --description="OpenStack Identity"

echo "########## CREATING KEYSTONE ENDPOINT ##########"
keystone endpoint-create \
--region regionOne \
--service-id=$(keystone service-list | awk '/ identity / {print $2}') \
--publicurl=http://$MANAGEMENT:5000/v2.0 \
--internalurl=http://$MANAGEMENT:5000/v2.0 \
--adminurl=http://$MANAGEMENT:35357/v2.0

# Roles
echo "##########  Creating Roles ##########"

# The Member role is used by Horizon and Swift
MEMBER_ROLE=$(get_id keystone role-create --name="$MEMBER_ROLE_NAME")
keystone user-role-add --user-id $DEMO_USER --role-id $MEMBER_ROLE --tenant-id $DEMO_TENANT

echo "########## CREATING ENVIRONMENT FILE for admin ##########"
echo "export OS_USERNAME=$ADMIN_USER_NAME" > admin-openrc.sh
echo "export OS_PASSWORD=$ADMIN_PASS" >> admin-openrc.sh
echo "export OS_TENANT_NAME=$ADMIN_TENANT_NAME" >> admin-openrc.sh
echo "export OS_AUTH_URL=http://$MANAGEMENT:35357/v2.0" >> admin-openrc.sh

echo "########## CREATING ENVIRONMENT FILE for demo ##########"
echo "export OS_USERNAME=$DEMO_USER_NAME" > demo-openrc.sh
echo "export OS_PASSWORD=$DEMO_PASS" >> demo-openrc.sh
echo "export OS_TENANT_NAME=$DEMO_TENANT_NAME" >> demo-openrc.sh
echo "export OS_AUTH_URL=http://$MANAGEMENT:35357/v2.0" >> demo-openrc.sh


echo "########## UNSET ENVIRONMENT ##########"
unset OS_SERVICE_TOKEN OS_SERVICE_ENDPOINT SERVICE_ENDPOINT
chmod +x admin-openrc.sh
chmod +x demo-openrc.sh

#sleep 5
echo "########## RUN ENVIRONMENT ##########"
cp  admin-openrc.sh /root/admin-openrc.sh
cp  demo-openrc.sh /root/demo-openrc.sh

# Verify
echo "########## User and Role list ##########"
keystone user-list
keystone role-list

echo "########## KEYSTONE SETUP FINISHED ! ##########"
