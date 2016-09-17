#!/bin/bash -ex

source config.cfg

echo "##### CREATE DATABASE FOR KEYSTONE ##### "
cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS keystone;
#
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
#GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'$DATABASE_VIP' IDENTIFIED BY '$MYSQL_PASS';
#
FLUSH PRIVILEGES;
EOF
#


echo "##### CREATE DATABASE FOR GLANCE ##### "
cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS glance;
CREATE DATABASE glance;
#
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
#GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'$DATABASE_VIP' IDENTIFIED BY '$MYSQL_PASS';
#
FLUSH PRIVILEGES;
EOF
#


echo "##### CREATE DATABASE FOR NOVA ##### "
cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS nova;
#
CREATE DATABASE nova;
CREATE DATABASE nova_api;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
#
FLUSH PRIVILEGES;
EOF
#



echo "##### CREATE DATABASE FOR NEUTRON ##### "
cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS neutron;
#
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
#GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'$DATABASE_VIP' IDENTIFIED BY '$MYSQL_PASS';
#
FLUSH PRIVILEGES;
EOF
#




echo "##### CREATE DATABASE FOR CINDER ##### "
cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS cinder;
#
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
#GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'$DATABASE_VIP' IDENTIFIED BY '$MYSQL_PASS';
#
FLUSH PRIVILEGES;
EOF
#



echo "##### CREATE DATABASE FOR HEAT ##### "
cat << EOF | mysql -uroot -p$MYSQL_PASS
DROP DATABASE IF EXISTS heat;
#
CREATE DATABASE heat;
GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'%' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'localhost' IDENTIFIED BY '$MYSQL_PASS';
#GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'$DATABASE_VIP' IDENTIFIED BY '$MYSQL_PASS';
#
FLUSH PRIVILEGES;
EOF
#



#echo "##### CREATE MONGODB DATABASE FOR CEILOMETER ##### "
#
## Install mongodb packages
#echo "########## Installing mongodb ##########"
#apt-get install -y mongodb-server mongodb-clients python-pymongo
#crudini --set /etc/mongodb.conf '' bind_ip 0.0.0.0
#crudini --set /etc/mongodb.conf '' smallfiles True
#
## Remove initial journal files as we have changed the journalling config above
#service mongodb stop
#
#if [[ $(ls /var/lib/mongodb/journal/prealloc.* >/dev/null 2>&1 | wc -l) != 0 ]] ; then
   #rm /var/lib/mongodb/journal/prealloc.*
#fi
#
#service mongodb start
#service mongodb restart
#
## Sleep for service to restart 
#sleep 10
#
#CMD="mongo --host $MONGODB_DATABASE_VIP --eval 'db = db.getSiblingDB(\"ceilometer\"); db.addUser({user: \"ceilometer\", pwd: \"$MYSQL_PASS\", roles: [ \"readWrite\", \"dbAdmin\" ]})'"
#
#eval $CMD
