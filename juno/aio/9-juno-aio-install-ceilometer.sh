#!/bin/bash -ex
source config.cfg

## Configuring Ceilometer
echo "########## Configuring Ceilometer ##########"

# Install mongodb packages
echo "########## Installing mongodb ##########"
apt-get install -y mongodb-server mongodb-clients python-pymongo


crudini --set /etc/mongodb.conf '' bind_ip $MANAGEMENT
crudini --set /etc/mongodb.conf '' smallfiles True

# Remove initial journal files as we have changed the journalling config above
service mongodb stop
if [[ $(ls /var/lib/mongodb/journal/prealloc.* >/dev/null 2>&1 | wc -l) != 0 ]] ; then
   rm /var/lib/mongodb/journal/prealloc.*
fi
service mongodb start

service mongodb restart

# Sleep for service to restart 
sleep 10

CMD="mongo --host $MANAGEMENT --eval 'db = db.getSiblingDB(\"ceilometer\"); db.addUser({user: \"ceilometer\", pwd: \"$MYSQL_PASS\", roles: [ \"readWrite\", \"dbAdmin\" ]})'"

eval $CMD


echo "########## CREATING ceilometer service credentials and endpoint ##########"
export OS_SERVICE_TOKEN="$TOKEN_PASS"
export OS_SERVICE_ENDPOINT="http://$MANAGEMENT:35357/v2.0"
export SERVICE_ENDPOINT="http://$MANAGEMENT:35357/v2.0"

get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

CEILOMETER_USER=$(get_id keystone user-create --name=ceilometer --pass="$SERVICE_PASSWORD" --email=heat@example.com)
keystone user-role-add --tenant $SERVICE_TENANT_NAME --user ceilometer --role $ADMIN_ROLE_NAME
keystone user-role-add --tenant $SERVICE_TENANT_NAME --user ceilometer --role $(keystone role-list | awk '/ResellerAdmin/' | awk '{print $2}')

echo "########## CREATING CEILOMETER SERVICE ##########"
keystone service-create --name ceilometer --type metering --description "Telemetry"
echo "########## CREATING CEILOMETER ENDPOINT ##########"
keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ metering / {print $2}') \
  --publicurl http://$MANAGEMENT:8777 \
  --internalurl http://$MANAGEMENT:8777 \
  --adminurl http://$MANAGEMENT:8777 \
  --region regionOne

# Install packages
echo "########## Installing packages ##########"
apt-get install -y ceilometer-api ceilometer-collector ceilometer-agent-central \
  ceilometer-agent-notification ceilometer-alarm-evaluator ceilometer-alarm-notifier \
  python-ceilometerclient



echo "########## Updating config ##########"
crudini --set /etc/ceilometer/ceilometer.conf database connection mongodb://ceilometer:$MYSQL_PASS@$MANAGEMENT:27017/ceilometer

crudini --set /etc/ceilometer/ceilometer.conf '' rpc_backend rabbit
crudini --set /etc/ceilometer/ceilometer.conf '' rabbit_host $MANAGEMENT
crudini --set /etc/ceilometer/ceilometer.conf '' rabbit_password $RABBIT_PASS

crudini --set /etc/ceilometer/ceilometer.conf '' auth_strategy keystone
 
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_uri http://$MANAGEMENT:5000/v2.0
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken identity_uri http://$MANAGEMENT:35357
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_tenant_name service
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_user ceilometer
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_password $SERVICE_PASSWORD

crudini --del /etc/ceilometer/ceilometer.conf keystone_authtoken auth_host
crudini --del /etc/ceilometer/ceilometer.conf keystone_authtoken auth_port
crudini --del /etc/ceilometer/ceilometer.conf keystone_authtoken auth_protocol 

crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_auth_url http://$MANAGEMENT:5000/v2.0
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_username ceilometer
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_tenant_name service
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_password $SERVICE_PASSWORD

crudini --set /etc/ceilometer/ceilometer.conf publisher metering_secret $METERING_SECRET

crudini --set /etc/ceilometer/ceilometer.conf '' verbose True


sed -i -e 's/interval: 600/interval: 60/g' /etc/ceilometer/pipeline.yaml

echo "########## Restarting services ##########"
service ceilometer-agent-central restart
service ceilometer-agent-notification restart
service ceilometer-api restart
service ceilometer-collector restart
service ceilometer-alarm-evaluator restart
service ceilometer-alarm-notifier restart

# Configure the compute service
echo "########## Configure the compute service ##########"
apt-get install -y ceilometer-agent-compute

echo "########## Updating config ##########"
crudini --set /etc/ceilometer/ceilometer.conf publisher metering_secret openstack

crudini --set /etc/ceilometer/ceilometer.conf '' rabbit_host $MANAGEMENT
crudini --set /etc/ceilometer/ceilometer.conf '' rabbit_password $RABBIT_PASS

crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken auth_uri http://$MANAGEMENT:5000/v2.0
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken identity_uri http://$MANAGEMENT:35357
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_tenant_name service
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_user ceilometer
crudini --set /etc/ceilometer/ceilometer.conf keystone_authtoken admin_password $SERVICE_PASSWORD

crudini --del /etc/ceilometer/ceilometer.conf keystone_authtoken auth_host
crudini --del /etc/ceilometer/ceilometer.conf keystone_authtoken auth_port
crudini --del /etc/ceilometer/ceilometer.conf keystone_authtoken auth_protocol

crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_auth_url http://$MANAGEMENT:5000/v2.0
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_username ceilometer
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_tenant_name service
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_password $SERVICE_PASSWORD
crudini --set /etc/ceilometer/ceilometer.conf service_credentials os_region_name regionOne

crudini --set /etc/ceilometer/ceilometer.conf '' verbose True

crudini --set /etc/nova/nova.conf '' instance_usage_audit True
crudini --set /etc/nova/nova.conf '' instance_usage_audit_period hour
crudini --set /etc/nova/nova.conf '' notify_on_state_change vm_and_task_state
crudini --set /etc/nova/nova.conf '' notification_driver messagingv2


echo "########## Restarting services ##########"
service ceilometer-agent-compute restart

service nova-compute restart


# Configure Image service
echo "########## Configure Image service ##########"

echo "########## Updating config ##########"
crudini --set /etc/glance/glance-api.conf '' notification_driver messagingv2
crudini --set /etc/glance/glance-api.conf '' rpc_backend rabbit
crudini --set /etc/glance/glance-api.conf '' rabbit_host $MANAGEMENT
crudini --set /etc/glance/glance-api.conf '' rabbit_password $RABBIT_PASS

crudini --set /etc/glance/glance-registry.conf '' notification_driver messagingv2
crudini --set /etc/glance/glance-registry.conf '' rpc_backend rabbit
crudini --set /etc/glance/glance-registry.conf '' rabbit_host $MANAGEMENT
crudini --set /etc/glance/glance-registry.conf '' rabbit_password $RABBIT_PASS

echo "########## Restarting services ##########"
service glance-registry restart
service glance-api restart


# Configure Block Storage service
echo "########## Updating config ##########"
crudini --set /etc/cinder/cinder.conf '' control_exchange cinder
crudini --set /etc/cinder/cinder.conf '' notification_driver messagingv2

# Restart the Block Storage services on the controller node
echo "########## Restarting services ##########"
service cinder-api restart
service cinder-scheduler restart


# Restart the Block Storage services on the storage nodes
service cinder-volume restart

# Configure the Object Storage service
echo "########## Configure the Object Storage service ##########"

# Update proxy server
EXISTING_OPERATOR_ROLES=$(crudini --get /etc/swift/proxy-server.conf filter:keystoneauth operator_roles)
if [[ $(echo $EXISTING_OPERATOR_ROLES | grep ResellerAdmin | wc -l) = 0 ]] ; then
   NEW_OPERATOR_ROLES=${EXISTING_OPERATOR_ROLES}",ResellerAdmin"
   crudini --set /etc/swift/proxy-server.conf filter:keystoneauth operator_roles $NEW_OPERATOR_ROLES
fi

echo "########## Updating config ##########"
crudini --set /etc/swift/proxy-server.conf pipeline:main pipeline "authtoken cache healthcheck keystoneauth proxy-logging ceilometer proxy-server"

crudini --set /etc/swift/proxy-server.conf filter:ceilometer use "egg:ceilometer#swift"
crudini --set /etc/swift/proxy-server.conf filter:ceilometer log_level WARN

# Add user ceilometer to group swift
usermod -a -G ceilometer swift

# Faced this issue of swift-proxy not being able to start as it did not have permissions on /var/log/ceilometer to create a log file
# Hence adding below lines
chgrp ceilometer /var/log/ceilometer
chmod g+w /var/log/ceilometer

# Restart swift-proxy
echo "########## Restarting swift-proxy ##########"
service swift-proxy restart

# Configure the Object Storage service
echo "########## Configure the Object Storage service ##########"
echo "########## Updating config ##########"
crudini --set /etc/neutron/neutron.conf '' notification_driver messagingv2

echo "########## Restarting neutron services ##########"
service neutron-server restart

service neutron-dhcp-agent restart
service neutron-l3-agent restart
service neutron-metadata-agent restart
service neutron-plugin-openvswitch-agent restart
