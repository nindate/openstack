#!/bin/bash -ex

source config.cfg

### NOTE - If you have setup HA and you have installed keystone on multiple
#   controllers before creating users tenants etc. then there are chances
#   that LB will direct you to another controller node than from where
#   you are running this script to create users and tenants etc.
#   This will cause authentication problem because at this stage the
#   authentication is local not via user admin.
#   In such a case temporarily make copy of this script and change the above
#   variables to point to IP of controller node on which you are running
#   this script and run the script from this controller node. 
#   Then proceed as regular
###

echo "##### CREATE ENDPOINTS, USERS, TENANTS and ROLES ##### "
#sleep 3


export OS_TOKEN=$ADMIN_TOKEN
export OS_URL=http://$CONTROLLER_VIP:35357/v3
export OS_IDENTITY_API_VERSION=3


echo "########## CREATING KEYSTONE SERVICE ##########"
openstack service create \
--name keystone --description "OpenStack Identity" identity

echo "########## CREATING KEYSTONE ENDPOINT ##########"
openstack endpoint create --region RegionOne \
  identity public http://$CONTROLLER_VIP:5000/v2.0

openstack endpoint create --region RegionOne \
  identity internal http://$CONTROLLER_VIP:5000/v2.0

openstack endpoint create --region RegionOne \
  identity admin http://$CONTROLLER_VIP:35357/v2.0


echo "########## Create default domain ##########"
openstack domain create --description "Default Domain" default

echo "Create admin project"
openstack project create --domain default \
  --description "Admin Project" admin

echo "Create admin user"
openstack user create --domain default \
  --password $ADMIN_PASS admin

echo "Create admin role"
openstack role create admin

echo "Add the admin role to the admin project and user"
openstack role add --project admin --user admin admin


echo "Create service project"
openstack project create --domain default \
  --description "Service Project" service


echo "Create demo project"
openstack project create --domain default \
  --description "Demo Project" demo

echo "Create demo user"
openstack user create --domain default \
  --password $DEMO_PASS demo


echo "Create user role"
openstack role create user


echo "Add the user role to the demo project and user"
openstack role add --project demo --user demo user



keystone_paste_file=/etc/keystone/keystone-paste.ini
test -f $keystone_paste_file.orig || cp $keystone_paste_file $keystone_paste_file.orig

ORG_PIPELINE=$(crudini --get $keystone_paste_file pipeline:public_api pipeline)
NEW_PIPELINE=$(echo $ORG_PIPELINE | sed "s/admin_token_auth//g")
crudini --set $keystone_paste_file pipeline:public_api pipeline "$NEW_PIPELINE"

ORG_PIPELINE=$(crudini --get $keystone_paste_file pipeline:admin_api pipeline)
NEW_PIPELINE=$(echo $ORG_PIPELINE | sed "s/admin_token_auth//g")
crudini --set $keystone_paste_file pipeline:admin_api pipeline "$NEW_PIPELINE"

ORG_PIPELINE=$(crudini --get $keystone_paste_file pipeline:api_v3 pipeline)
NEW_PIPELINE=$(echo $ORG_PIPELINE | sed "s/admin_token_auth//g")
crudini --set $keystone_paste_file pipeline:api_v3 pipeline "$NEW_PIPELINE"

echo "########## CREATING ENVIRONMENT FILE for admin ##########"
echo "export OS_PROJECT_DOMAIN_NAME=default" > admin-openrc.sh
echo "export OS_USER_DOMAIN_NAME=default" >> admin-openrc.sh
echo "export OS_PROJECT_NAME=$ADMIN_TENANT_NAME" >> admin-openrc.sh
echo "export OS_USERNAME=$ADMIN_USER_NAME" >> admin-openrc.sh
echo "export OS_PASSWORD=$ADMIN_PASS" >> admin-openrc.sh
echo "export OS_AUTH_URL=http://$CONTROLLER_VIP:35357/v3" >> admin-openrc.sh
echo "export OS_IDENTITY_API_VERSION=3" >> admin-openrc.sh
echo "export OS_IMAGE_API_VERSION=2" >> admin-openrc.sh


echo "########## CREATING ENVIRONMENT FILE for demo ##########"
echo "export OS_PROJECT_DOMAIN_NAME=default" > demo-openrc.sh
echo "export OS_USER_DOMAIN_NAME=default" >> demo-openrc.sh
echo "export OS_PROJECT_NAME=$DEMO_TENANT_NAME" >> demo-openrc.sh
echo "export OS_USERNAME=$DEMO_USER_NAME" >> demo-openrc.sh
echo "export OS_PASSWORD=$DEMO_PASS" >> demo-openrc.sh
echo "export OS_AUTH_URL=http://$CONTROLLER_VIP:5000/v3" >> demo-openrc.sh
echo "export OS_IDENTITY_API_VERSION=3" >> demo-openrc.sh
echo "export OS_IMAGE_API_VERSION=2" >> demo-openrc.sh

echo "########## UNSET ENVIRONMENT ##########"
chmod +x admin-openrc.sh
chmod +x demo-openrc.sh

echo "########## RUN ENVIRONMENT ##########"
cp  admin-openrc.sh /root/admin-openrc.sh
cp  demo-openrc.sh /root/demo-openrc.sh


unset OS_TOKEN OS_URL

# Verify
echo "Verify Operations"


echo "Verify token issue as admin user with keystone v3"

openstack --os-auth-url http://$CONTROLLER_MANAGEMENT_IP:35357/v3 \
  --os-project-domain-name default --os-user-domain-name default \
  --os-project-name admin --os-username admin \
  --os-password $ADMIN_PASS \
  token issue

echo "Verify token issue as demo user with keystone v3"
openstack --os-auth-url http://$CONTROLLER_MANAGEMENT_IP:5000/v3 \
  --os-project-domain-name default --os-user-domain-name default \
  --os-project-name demo --os-username demo \
  --os-password $DEMO_PASS \
  token issue






source admin-openrc.sh

echo "########## CREATING entities for GLANCE ##########"
echo "########## Creating glance user ##########"
openstack user create --domain default --password $SERVICE_PASSWORD --email glance@example.com --enable glance

echo "########## Adding admin role to glance user and service project ##########"
openstack role add --project service --user glance admin

echo "########## Creating glance service ##########"
openstack service create \
--name glance --description "OpenStack Image service" image

echo "########## Creating glance service API endpoint ##########"
openstack endpoint create --region RegionOne \
  image public http://$CONTROLLER_VIP:9292

openstack endpoint create --region RegionOne \
  image internal http://$CONTROLLER_VIP:9292

openstack endpoint create --region RegionOne \
  image admin http://$CONTROLLER_VIP:9292



echo "########## CREATING entities for NOVA ##########"
echo "########## Creating nova user ##########"
openstack user create --domain default --password $SERVICE_PASSWORD --email nova@example.com --enable nova

echo "########## Adding admin role to nova user and service project ##########"
openstack role add --project service --user nova admin

echo "########## Creating nova service ##########"
openstack service create \
--name nova --description "OpenStack Compute" compute

echo "########## Creating nova service API endpoint ##########"
openstack endpoint create --region RegionOne \
  compute public http://$CONTROLLER_VIP:8774/v2/%\(tenant_id\)s

openstack endpoint create --region RegionOne \
  compute internal http://$CONTROLLER_VIP:8774/v2/%\(tenant_id\)s

openstack endpoint create --region RegionOne \
  compute admin http://$CONTROLLER_VIP:8774/v2/%\(tenant_id\)s




echo "########## CREATING entities for NEUTRON ##########"
echo "########## Creating neutron user ##########"
openstack user create --domain default --password $SERVICE_PASSWORD --email neutron@example.com --enable neutron

echo "########## Adding admin role to neutron user and service project ##########"
openstack role add --project service --user neutron admin

echo "########## Creating neutron service ##########"
openstack service create \
--name neutron --description "OpenStack Networking" network

echo "########## Creating neutron service API endpoint ##########"
openstack endpoint create --region RegionOne \
  network public http://$CONTROLLER_VIP:9696

openstack endpoint create --region RegionOne \
  network internal http://$CONTROLLER_VIP:9696

openstack endpoint create --region RegionOne \
  network admin http://$CONTROLLER_VIP:9696



echo "########## CREATING entities for CINDER ##########"
echo "########## Creating cinder user ##########"
openstack user create --domain default --password $SERVICE_PASSWORD --email cinder@example.com --enable cinder

echo "########## Adding admin role to cinder user and service project ##########"
openstack role add --project service --user cinder admin

echo "########## Creating cinder service ##########"
openstack service create --name cinder \
  --description "OpenStack Block Storage" volume

openstack service create --name cinderv2 \
  --description "OpenStack Block Storage" volumev2

echo "########## Creating cinder service API endpoint ##########"
openstack endpoint create --region RegionOne \
  volume public http://$CONTROLLER_VIP:8776/v1/%\(tenant_id\)s

openstack endpoint create --region RegionOne \
  volume internal http://$CONTROLLER_VIP:8776/v1/%\(tenant_id\)s

openstack endpoint create --region RegionOne \
  volume admin http://$CONTROLLER_VIP:8776/v1/%\(tenant_id\)s

openstack endpoint create --region RegionOne \
  volumev2 public http://$CONTROLLER_VIP:8776/v2/%\(tenant_id\)s

openstack endpoint create --region RegionOne \
  volumev2 internal http://$CONTROLLER_VIP:8776/v2/%\(tenant_id\)s

openstack endpoint create --region RegionOne \
  volumev2 admin http://$CONTROLLER_VIP:8776/v2/%\(tenant_id\)s




##echo "########## CREATING SWIFT USER ##########"
##SWIFT_USER=$(get_id keystone user-create --name=swift --pass="$SERVICE_PASSWORD" --email=swift@example.com)

##keystone user-role-add --tenant $SERVICE_TENANT_NAME --user-id $SWIFT_USER --role $ADMIN_ROLE_NAME
##NOVA_USER=$(get_id keystone user-get nova)
##RESELLER_ROLE=$(get_id keystone role-create --name=ResellerAdmin)
##keystone user-role-add --tenant $SERVICE_TENANT_NAME --user-id $NOVA_USER --role-id $RESELLER_ROLE

##echo "########## CREATING SWIFT SERVICE ##########"
##keystone service-create --name swift --type object-store \
  ##--description "OpenStack Object Storage"

##echo "########## CREATING SWIFT ENDPOINT ##########"
##keystone endpoint-create \
  ##--service-id $(keystone service-list | awk '/ object-store / {print $2}') \
  ##--publicurl "http://$CONTROLLER_VIP:8080/v1/AUTH_%(tenant_id)s" \
  ##--internalurl "http://$CONTROLLER_VIP:8080/v1/AUTH_%(tenant_id)s" \
  ##--adminurl http://$CONTROLLER_VIP:8080 \
  ##--region regionOne



##echo "########## CREATING HEAT USER ##########"
##HEAT_USER=$(get_id keystone user-create --name=heat --pass="$SERVICE_PASSWORD" --email=heat@example.com)

##keystone user-role-add --tenant $SERVICE_TENANT_NAME --user-id $HEAT_USER --role $ADMIN_ROLE_NAME
##HEATSTACKOWNER_ROLE=$(get_id keystone role-create --name="$HEATSTACKOWNER_ROLE_NAME")
##HEATSTACKUSER_ROLE=$(get_id keystone role-create --name="$HEATSTACKUSER_ROLE_NAME")
##keystone user-role-add --tenant $SERVICE_TENANT_NAME --user-id $HEAT_USER --role $HEATSTACKOWNER_ROLE_NAME

##echo "########## CREATING HEAT SERVICE ##########"
##keystone service-create --name heat --type orchestration --description "Orchestration"

##echo "########## CREATING HEAT ENDPOINT ##########"
##keystone endpoint-create \
  ##--service-id $(keystone service-list | awk '/ orchestration / {print $2}') \
  ##--publicurl http://$CONTROLLER_VIP:8004/v1/%\(tenant_id\)s \
  ##--internalurl http://$CONTROLLER_VIP:8004/v1/%\(tenant_id\)s \
  ##--adminurl http://$CONTROLLER_VIP:8004/v1/%\(tenant_id\)s \
  ##--region regionOne

##echo "########## CREATING HEAT CLOUD FORMATION SERVICE ##########"
##keystone service-create --name heat-cfn --type cloudformation --description "Orchestration"

##echo "########## CREATING HEAT CLOUD FORMATION ENDPOINT ##########"
##keystone endpoint-create \
  ##--service-id $(keystone service-list | awk '/ cloudformation / {print $2}') \
  ##--publicurl http://$CONTROLLER_VIP:8000/v1 \
  ##--internalurl http://$CONTROLLER_VIP:8000/v1 \
  ##--adminurl http://$CONTROLLER_VIP:8000/v1 \
  ##--region regionOne



##echo "########## CREATING CEILOMETER ENDPOINT ##########"
##CEILOMETER_USER=$(get_id keystone user-create --name=ceilometer --pass="$SERVICE_PASSWORD" --email=heat@example.com)

##keystone user-role-add --tenant $SERVICE_TENANT_NAME --user ceilometer --role $ADMIN_ROLE_NAME
##keystone user-role-add --tenant $SERVICE_TENANT_NAME --user ceilometer --role $(keystone role-list | awk '/ResellerAdmin/' | awk '{print $2}')

##echo "########## CREATING CEILOMETER SERVICE ##########"
##keystone service-create --name ceilometer --type metering --description "Telemetry"

##echo "########## CREATING CEILOMETER ENDPOINT ##########"
##keystone endpoint-create \
  ##--service-id $(keystone service-list | awk '/ metering / {print $2}') \
  ##--publicurl http://$CONTROLLER_VIP:8777 \
  ##--internalurl http://$CONTROLLER_VIP:8777 \
  ##--adminurl http://$CONTROLLER_VIP:8777 \
  ##--region regionOne


echo "########## KEYSTONE SETUP FINISHED ! ##########"

