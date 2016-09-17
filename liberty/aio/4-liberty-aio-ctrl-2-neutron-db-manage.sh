#!/bin/bash -ex

source config.cfg

su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

echo "########## Restarting Compute API service #####"
service nova-api restart


echo "########## RESTARTING NEUTRON SERVICE ##########"
service neutron-server restart
service neutron-plugin-linuxbridge-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart
service neutron-l3-agent restart



echo "########## TESTING NEUTRON (WAIT 10s)   ##########"
# WAITING FOR NEUTRON BOOT-UP
sleep 10
#source admin-openrc.sh
#neutron ext-list
#neutron agent-list

echo "########## Installation and Configuration completed ##########"
