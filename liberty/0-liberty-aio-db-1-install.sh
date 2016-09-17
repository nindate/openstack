#!/bin/bash -ex 

source config.cfg


# Install crudini which is a command line utility to update configuration files
apt-get install -y crudini 


# Installing SQL Database

#Start installing mysql
echo "########## INSTALLING MYSQL ##########"
echo mariadb-server mysql-server/root_password password $MYSQL_ADMIN_PASS | debconf-set-selections
echo mariadb-server mysql-server/root_password_again password $MYSQL_ADMIN_PASS | debconf-set-selections

apt-get -y install mariadb-server expect python-pymysql

echo "########## CONFIGURING MYSQL ##########"
# Not using crudini here but standard sed because the config file has some patterns which are not recognised by crudini
sed -i 's/^bind-address.*$/#bind-address=127.0.0.1/g' /etc/mysql/my.cnf
#
cat > /etc/mysql/conf.d/mysqld_openstack.cnf <<EOF
[mysqld]
bind-address = $DATABASE_VIP
default-storage-engine = innodb
innodb_file_per_table
collation-server = utf8_general_ci
init-connect = 'SET NAMES utf8'
character-set-server = utf8

EOF

echo "########## RESTARTING MYSQL ##########"
#sleep 5
service mysql restart


SECURE_MYSQL=$(expect -c "

set timeout 10
spawn mysql_secure_installation

expect \"Enter current password for root (enter for none):\"
send \"$MYSQL_ADMIN_PASS\r\"

expect \"Change the root password?\"
send \"n\r\"

expect \"Remove anonymous users?\"
send \"y\r\"

expect \"Disallow root login remotely?\"
send \"y\r\"

expect \"Remove test database and access to it?\"
send \"y\r\"

expect \"Reload privilege tables now?\"
send \"y\r\"

expect eof
")

echo "$SECURE_MYSQL"
apt-get remove --purge -y expect



# Installing NoSQL Database

apt-get install -y mongodb-server mongodb-clients python-pymongo

crudini --set /etc/mongodb.conf '' bind_ip $DATABASE_VIP

crudini --set /etc/mongodb.conf '' smallfiles True

service mongodb stop

if [[ $(ls /var/lib/mongodb/journal/prealloc.* >/dev/null 2>&1 | wc -l) != 0 ]] ; then
  rm /var/lib/mongodb/journal/prealloc.*
fi

service mongodb start

