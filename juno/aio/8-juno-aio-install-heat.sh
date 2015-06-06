#!/bin/bash -ex
source config.cfg

## Configuring Heat
source admin-openrc.sh

# Create database
echo "########## CREATING DATABASE ##########"
cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS heat;
#
CREATE DATABASE heat;
GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'%' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'$MANAGEMENT' IDENTIFIED BY '$MYSQL_PASS';
#
FLUSH PRIVILEGES;
EOF
#

echo "########## CREATING heat service credentials and endpoint ##########"
export OS_SERVICE_TOKEN="$TOKEN_PASS"
export OS_SERVICE_ENDPOINT="http://$MANAGEMENT:35357/v2.0"
export SERVICE_ENDPOINT="http://$MANAGEMENT:35357/v2.0"


get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

HEAT_USER=$(get_id keystone user-create --name=heat --pass="$SERVICE_PASSWORD" --email=heat@example.com)
keystone user-role-add --tenant $SERVICE_TENANT_NAME --user-id $HEAT_USER --role $ADMIN_ROLE_NAME

HEATSTACKOWNER_ROLE=$(get_id keystone role-create --name="$HEATSTACKOWNER_ROLE_NAME")
HEATSTACKUSER_ROLE=$(get_id keystone role-create --name="$HEATSTACKUSER_ROLE_NAME")

keystone user-role-add --tenant $SERVICE_TENANT_NAME --user-id $HEAT_USER --role $HEATSTACKOWNER_ROLE_NAME

echo "########## CREATING HEAT SERVICE ##########"
keystone service-create --name heat --type orchestration --description "Orchestration"
echo "########## CREATING HEAT ENDPOINT ##########"
keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ orchestration / {print $2}') \
  --publicurl http://$MANAGEMENT:8004/v1/%\(tenant_id\)s \
  --internalurl http://$MANAGEMENT:8004/v1/%\(tenant_id\)s \
  --adminurl http://$MANAGEMENT:8004/v1/%\(tenant_id\)s \
  --region regionOne

echo "########## CREATING HEAT CLOUD FORMATION SERVICE ##########"
keystone service-create --name heat-cfn --type cloudformation --description "Orchestration"
echo "########## CREATING HEAT CLOUD FORMATION ENDPOINT ##########"
keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ cloudformation / {print $2}') \
  --publicurl http://$MANAGEMENT:8000/v1 \
  --internalurl http://$MANAGEMENT:8000/v1 \
  --adminurl http://$MANAGEMENT:8000/v1 \
  --region regionOne



# Install packages
echo "########## INSTALLING HEAT PACKAGES ##########"
apt-get install -y heat-api heat-api-cfn heat-engine python-heatclient

# Update heat.conf
crudini --set /etc/heat/heat.conf database connection mysql://heat:$MYSQL_PASS@$MANAGEMENT/heat
crudini --set /etc/heat/heat.conf '' rpc_backend rabbit
crudini --set /etc/heat/heat.conf '' rabbit_host $MANAGEMENT
crudini --set /etc/heat/heat.conf '' rabbit_password $RABBIT_PASS

crudini --set /etc/heat/heat.conf keystone_authtoken auth_uri http://$MANAGEMENT:5000/v2.0
crudini --set /etc/heat/heat.conf keystone_authtoken identity_uri http://$MANAGEMENT:35357
crudini --set /etc/heat/heat.conf keystone_authtoken admin_tenant_name service
crudini --set /etc/heat/heat.conf keystone_authtoken admin_user heat
crudini --set /etc/heat/heat.conf keystone_authtoken admin_password $SERVICE_PASSWORD
crudini --del /etc/heat/heat.conf keystone_authtoken auth_host
crudini --del /etc/heat/heat.conf keystone_authtoken auth_port
crudini --del /etc/heat/heat.conf keystone_authtoken auth_protocol

crudini --set /etc/heat/heat.conf ec2authtoken auth_uri http://$MANAGEMENT:5000/v2.0
crudini --del /etc/heat/heat.conf ec2authtoken auth_host
crudini --del /etc/heat/heat.conf ec2authtoken auth_port
crudini --del /etc/heat/heat.conf ec2authtoken auth_protocol


crudini --set /etc/heat/heat.conf '' heat_metadata_server_url http://$MANAGEMENT:8000
crudini --set /etc/heat/heat.conf '' heat_waitcondition_server_url http://$MANAGEMENT:8000/v1/waitcondition

crudini --set /etc/heat/heat.conf keystone_authtoken insecure true

# Sync db
su -s /bin/sh -c "heat-manage db_sync" heat

##Restart all the services###
echo "Restarting all services"
echo
service heat-api restart
service heat-api-cfn restart
service heat-engine restart

# Remove sqlite database
echo "Removing sqlite database"
rm -f /var/lib/heat/heat.sqlite

# Completed
echo "Heat configuration completed"
