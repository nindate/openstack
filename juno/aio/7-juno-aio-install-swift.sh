#!/bin/bash -ex
source config.cfg

## Configuring Swift
source admin-openrc.sh

echo "########## CREATING swift service credentials and endpoint ##########"
export OS_SERVICE_TOKEN="$TOKEN_PASS"
export OS_SERVICE_ENDPOINT="http://$MANAGEMENT:35357/v2.0"
export SERVICE_ENDPOINT="http://$MANAGEMENT:35357/v2.0"

get_id () {
    echo `$@ | awk '/ id / { print $4 }'`
}

SWIFT_USER=$(get_id keystone user-create --name=swift --pass="$SERVICE_PASSWORD" --email=swift@example.com)
keystone user-role-add --tenant $SERVICE_TENANT_NAME --user-id $SWIFT_USER --role $ADMIN_ROLE_NAME

NOVA_USER=$(get_id keystone user-get nova)
RESELLER_ROLE=$(get_id keystone role-create --name=ResellerAdmin)
keystone user-role-add --tenant $SERVICE_TENANT_NAME --user-id $NOVA_USER --role-id $RESELLER_ROLE

keystone service-create --name swift --type object-store \
  --description "OpenStack Object Storage"


keystone endpoint-create \
  --service-id $(keystone service-list | awk '/ object-store / {print $2}') \
  --publicurl "http://$MANAGEMENT:8080/v1/AUTH_%(tenant_id)s" \
  --internalurl "http://$MANAGEMENT:8080/v1/AUTH_%(tenant_id)s" \
  --adminurl http://$MANAGEMENT:8080 \
  --region regionOne

echo "########## INSTALLING SWIFT PACKAGES ##########"
apt-get install -y swift swift-proxy python-swiftclient python-keystoneclient \
  python-keystonemiddleware memcached

mkdir /etc/swift

# Obtain the proxy service configuration file from the Object Storage source repository
#curl -o /etc/swift/proxy-server.conf \
  #https://raw.githubusercontent.com/openstack/swift/stable/juno/etc/proxy-server.conf-sample
cp proxy-server.conf-sample /etc/swift/proxy-server.conf

# Update proxy-server.conf
crudini --set /etc/swift/proxy-server.conf '' bind_ip $MANAGEMENT
crudini --set /etc/swift/proxy-server.conf '' bind_port 8080
crudini --set /etc/swift/proxy-server.conf '' user swift
crudini --set /etc/swift/proxy-server.conf '' swift_dir /etc/swift

crudini --set /etc/swift/proxy-server.conf pipeline:main pipeline "authtoken cache healthcheck keystoneauth proxy-logging proxy-server"

crudini --set /etc/swift/proxy-server.conf app:proxy-server allow_account_management true
crudini --set /etc/swift/proxy-server.conf app:proxy-server account_autocreate true

crudini --set /etc/swift/proxy-server.conf filter:keystoneauth use egg:swift#keystoneauth
crudini --set /etc/swift/proxy-server.conf filter:keystoneauth operator_roles admin,_member_,swiftoperator

crudini --set /etc/swift/proxy-server.conf filter:authtoken paste.filter_factory keystonemiddleware.auth_token:filter_factory
crudini --set /etc/swift/proxy-server.conf filter:authtoken auth_uri http://$MANAGEMENT:5000/v2.0
crudini --set /etc/swift/proxy-server.conf filter:authtoken identity_uri http://$MANAGEMENT:35357
crudini --set /etc/swift/proxy-server.conf filter:authtoken admin_tenant_name service
crudini --set /etc/swift/proxy-server.conf filter:authtoken admin_user swift
crudini --set /etc/swift/proxy-server.conf filter:authtoken admin_password openstack
crudini --set /etc/swift/proxy-server.conf filter:authtoken delay_auth_decision true
crudini --del /etc/swift/proxy-server.conf filter:authtoken auth_host
crudini --del /etc/swift/proxy-server.conf filter:authtoken auth_port
crudini --del /etc/swift/proxy-server.conf filter:authtoken auth_protocol
crudini --set /etc/swift/proxy-server.conf filter:cache memcache_servers 127.0.0.1:11211

# Install packages
apt-get install -y swift swift-proxy swift-account swift-container swift-object memcached xfsprogs curl python-swiftclient rsync


###Create Loop devices for storing objects
dd if=/dev/zero of=/srv/swift-disk bs=1024 count=0 seek=1000000
mkfs.xfs -i size=1024 /srv/swift-disk
cat >> /etc/fstab <<EOF
/srv/swift-disk /mnt/sdb1 xfs loop,noatime,nodiratime,nobarrier,logbufs=8 0 0
EOF
mkdir /mnt/sdb1
mount /mnt/sdb1
mkdir /mnt/sdb1/1 /mnt/sdb1/2 /mnt/sdb1/3 /mnt/sdb1/4
for x in {1..4}; do ln -s /mnt/sdb1/$x /srv/$x; done
mkdir -p /srv/1/node/sdb1 /srv/2/node/sdb2 /srv/3/node/sdb3 /srv/4/node/sdb4 /var/run/swift

sleep 2
echo Loop devices created
###SETUP Rsyncd###
echo "[Setting up Rsyncd]"

cat >  /etc/rsyncd.conf <<EOF
uid = swift
gid = swift
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
address = $MANAGEMENT

[account6012]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/account6012.lock

[account6022]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/account6022.lock

[account6032]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/account6032.lock

[account6042]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/account6042.lock

[container6011]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/container6011.lock

[container6021]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/container6021.lock

[container6031]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/container6031.lock

[container6041]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/container6041.lock

[object6010]
max connections = 25
path = /srv/1/node/
read only = false
lock file = /var/lock/object6010.lock
[object6020]
max connections = 25
path = /srv/2/node/
read only = false
lock file = /var/lock/object6020.lock

[object6030]
max connections = 25
path = /srv/3/node/
read only = false
lock file = /var/lock/object6030.lock

[object6040]
max connections = 25
path = /srv/4/node/
read only = false
lock file = /var/lock/object6040.lock

EOF

sed 's/RSYNC_ENABLE=false/RSYNC_ENABLE=true/g' /etc/default/rsync  -i
service rsync restart


sleep 1
echo Setup rsync completed


# Below lines commented because we will create/simulate multiple storage nodes on same server
#curl -o /etc/swift/account-server.conf \
#  https://raw.githubusercontent.com/openstack/swift/stable/juno/etc/account-server.conf-sample

#curl -o /etc/swift/container-server.conf \
#  https://raw.githubusercontent.com/openstack/swift/stable/juno/etc/container-server.conf-sample

#curl -o /etc/swift/object-server.conf \
#  https://raw.githubusercontent.com/openstack/swift/stable/juno/etc/object-server.conf-sample


###Generate Configuration File##
echo "[Generate Configuration Files]"

mkdir -p /etc/swift/account-server /etc/swift/container-server /etc/swift/object-server


mv /etc/swift/account-server.conf /etc/swift/account-server.conf.orig
mv /etc/swift/object-server.conf /etc/swift/object-server.conf.orig
mv /etc/swift/container-server.conf /etc/swift/container-server.conf.orig


# Account server conf
echo "                  |.....Account Server conf"
for ((i=1;i<=4;i=i+1))
do
port=$((6002+i*10))
cat > /etc/swift/account-server/$((i)).conf << EOF
[DEFAULT]
devices = /srv/$((i+1))/node
mount_check = false
bind_port = $port
bind_ip = $MANAGEMENT
user = swift
swift_dir = /etc/swift

[pipeline:main]
pipeline = healthcheck recon account-server

[app:account-server]
use = egg:swift#account

[account-replicator]
vm_test_mode = yes

[account-auditor]

[account-reaper]

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

EOF
done

sleep 1
echo "                  |"

# Container server conf
echo "                  |.....Container Server Confs"
for ((i=1;i<=4;i=i+1))
do
port=$((6001+i*10))
cat > /etc/swift/container-server/$((i)).conf << EOF
[DEFAULT]
devices = /srv/$((i))/node
mount_check = false
bind_ip = $MANAGEMENT
bind_port = $port
user = swift
swift_dir = /etc/swift

[pipeline:main]
pipeline = healthcheck recon container-server

[app:container-server]
use = egg:swift#container

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

[container-replicator]
vm_test_mode = yes

[container-updater]

[container-auditor]

[container-sync]

EOF
done

sleep 1
echo "                  |"



# Object server conf
echo "                  |.....Object server Confs"
for ((i=1;i<=4;i=i+1))
do
port=$((6000+i*10))
cat > /etc/swift/object-server/$((i)).conf << EOF
[DEFAULT]
devices = /srv/$((i))/node
mount_check = false
bind_ip = $MANAGEMENT
bind_port = $port
user = swift
swift_dir = /etc/swift

[pipeline:main]
pipeline = healthcheck recon object-server

[app:object-server]
use = egg:swift#object

[filter:healthcheck]
use = egg:swift#healthcheck

[filter:recon]
use = egg:swift#recon
recon_cache_path = /var/cache/swift

[object-replicator]
vm_test_mode = yes

[object-updater]

[object-auditor]

EOF
done
sleep 1
echo

chown -R swift:swift /srv/*/node
mkdir -p /var/cache/swift
chown -R swift:swift /var/cache/swift


#Starting Ring

echo "             ------------ ***** Staring the Ring ***** ------------"

SCRIPTSDIR=$(pwd)
cd /etc/swift

rm -f *.builder *.ring.gz backups/*.builder backups/*.ring.gz

swift-ring-builder object.builder create 18 3 1
swift-ring-builder object.builder add z1-${MANAGEMENT_IP}:6010/sdb1 100
swift-ring-builder object.builder add z2-${MANAGEMENT_IP}:6020/sdb2 100
swift-ring-builder object.builder add z3-${MANAGEMENT_IP}:6030/sdb3 100
swift-ring-builder object.builder add z4-${MANAGEMENT_IP}:6040/sdb4 100
swift-ring-builder object.builder rebalance
swift-ring-builder container.builder create 18 3 1
swift-ring-builder container.builder add z1-${MANAGEMENT_IP}:6011/sdb1 100
swift-ring-builder container.builder add z2-${MANAGEMENT_IP}:6021/sdb2 100
swift-ring-builder container.builder add z3-${MANAGEMENT_IP}:6031/sdb3 100
swift-ring-builder container.builder add z4-${MANAGEMENT_IP}:6041/sdb4 100
swift-ring-builder container.builder rebalance
swift-ring-builder account.builder create 18 3 1
swift-ring-builder account.builder add z1-${MANAGEMENT_IP}:6012/sdb1 100
swift-ring-builder account.builder add z2-${MANAGEMENT_IP}:6022/sdb2 100
swift-ring-builder account.builder add z3-${MANAGEMENT_IP}:6032/sdb3 100
swift-ring-builder account.builder add z4-${MANAGEMENT_IP}:6042/sdb4 100
swift-ring-builder account.builder rebalance

sleep 2
echo
echo

#curl -o /etc/swift/swift.conf \
  #https://raw.githubusercontent.com/openstack/swift/stable/juno/etc/swift.conf-sample
cd $SCRIPTSDIR
cp swift.conf-sample /etc/swift/swift.conf

crudini --set /etc/swift/swift.conf swift-hash swift_hash_path_suffix aJzx
crudini --set /etc/swift/swift.conf swift-hash swift_hash_path_prefix Doig

crudini --set /etc/swift/swift.conf storage-policy:0 name Policy-0
crudini --set /etc/swift/swift.conf storage-policy:0 default yes

chown -R swift:swift /etc/swift

service memcached restart
service swift-proxy restart

echo "             ------------ ***** Staring all the Swift service ***** ------------"
sleep 1
echo
echo

##Start all the services###
echo "Starting all swift service "
echo
echo
swift-init all start
