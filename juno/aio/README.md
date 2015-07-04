# Openstack Juno All-in-one setup on Ubuntu 14.04 x64 server


### 1. Purpose:
The purpose of these scripts is to install all Openstack components on a single server to be able to use this Openstack setup for learning/demo/testing. This is known as All-in-one (AIO) setup and lets call this server as AIO server. The scripts will install Openstack Juno version.

The scripts have been tested on a VirtualBox virtual machine (VM) as the AIO server, but they should work on physical server or VM on any other virtualization software as well.
Following Openstack components will be installed by these scripts:
Keystone, Glance, Nova, Neutron (including LBaaS and FWaaS), Horizon, Cinder, Swift, Heat and Ceilometer

### 2. Setup explanation:
It is better that I explain a little bit on some generic stuff of Openstack in the context of this setup. In Openstack,
  * There are mainly the following types of nodes: Controller node, Network node, Compute node, Block Storage node, Object Storage node. In the AIO setup all these functions are performed on/by the AIO server.
  * There are various types of network traffic flowing based on which we have the following networks:
      * Management network : Openstack nodes communicate with each other on this network. Thus all Openstack nodes need to have connectivity with this network
      * Data/Tunnel network : The instances (virtual machines) launched on the Compute nodes talk to each other and to the Network node (for advanced networking like router, firewall, load balancer etc.) on this network. Thus only Network node and all the Compute nodes need to have connectivity with this network
      * External network : The instances on the Compute nodes communicate with servers / services outside Openstack setup via this network. Typically the instances can communicate outside only via the L3 services on the Network node and hence Network node needs to have connectivity with this network (Although since Juno release features like DVR allow this communication directly from compute nodes - am not considering that for this setup)

   In the AIO setup all these networks will be connected to the single server we will be having - our AIO server. Following figure shows this connectivity

Connectivity for Openstack AIO setup



       
        
    ---MANAGEMENT NW---------------
                                  |
                              eth0|
                               -------Controller
                          eth2 |     |   +             +
    ---EXTERNAL NW-------------|     | Network     Block Storage
                               |     |   +             +
                               ------- Compute    Object Storage
                              eth1|
                                  |
    ---DATA/TUNNEL NW--------------
        
        
        
        Once you have completed the AIO node setup, you may optionally want to add more compute nodes
        to this setup. The connectivity for the additional compute nodes should be as shown below
        
    ---MANAGEMENT NW-----------------(Optional additional compute nodes)---
                                  |                                       |
                              eth0|                                   eth0|
                               -------Controller                       -------ComputeX
                          eth2 |     |   +             +               |     |
    ---EXTERNAL NW-------------|     | Network     Block Storage       |     |
                               |     |   +             +               |     |
                               ------- Compute   Object Storage        -------
                              eth1|                                   eth1|
                                  |                                       |
    ---DATA/TUNNEL NW------------------------------------------------------




### 3. Setup requirements:
Following are the requirements for the AIO server.
  * In case you are using a Virtual Machine you would need to create a VM with atleast 2 CPUs, 5 GB memory, 40 GB hard disk. This configuration should be enough for basic demo/testing with cirros cloud image to deploy instances in Openstack cloud. However, if you want to use any other OS (like Ubuntu, CentOS, Fedora etc.) inside Openstack you would need more CPU/Memory for the AIO server.
  * For network, it is ideal to have atleast 3 network interfaces for the AIO server as explained in Section 2 above. However if you have less number of interfaces, the scripts will still work - you just need to update the config.cfg file appropriately.
  * Install Ubuntu 14.04 x64 server with Openssh package installed (so that you can ssh to this server). 
  * Update the packages on the server with following command:

        $ sudo apt-get update -y


### 4. Install Openstack:
After you have Ubuntu 14.04 server installed on the AIO server, perform the following steps to install Openstack

Create a directory to place the Openstack installation scripts.

    $ mkdir scripts
    $ cd scripts

Download the scripts. Either you can clone the entire git repo or simply downloads the necessary scripts, using below commands:

    $ wget https://raw.githubusercontent.com/nindate/openstack/master/juno/aio/0-juno-aio-prepare.sh
    $ wget https://raw.githubusercontent.com/nindate/openstack/master/juno/aio/1-juno-aio-install-keystone.sh
    $ wget https://raw.githubusercontent.com/nindate/openstack/master/juno/aio/2-juno-aio-install-glance.sh
    $ wget https://raw.githubusercontent.com/nindate/openstack/master/juno/aio/3-juno-aio-install-nova.sh
    $ wget https://raw.githubusercontent.com/nindate/openstack/master/juno/aio/4-juno-aio-install-neutron.sh
    $ wget https://raw.githubusercontent.com/nindate/openstack/master/juno/aio/5-juno-aio-install-horizon.sh
    $ wget https://raw.githubusercontent.com/nindate/openstack/master/juno/aio/6-juno-aio-install-cinder.sh
    $ wget https://raw.githubusercontent.com/nindate/openstack/master/juno/aio/7-juno-aio-install-swift.sh
    $ wget https://raw.githubusercontent.com/nindate/openstack/master/juno/aio/8-juno-aio-install-heat.sh
    $ wget https://raw.githubusercontent.com/nindate/openstack/master/juno/aio/9-juno-aio-install-ceilometer.sh
    $ wget https://raw.githubusercontent.com/nindate/openstack/master/juno/aio/config.cfg
    $ wget https://raw.githubusercontent.com/nindate/openstack/master/juno/aio/proxy-server.conf-sample
    $ wget https://raw.githubusercontent.com/nindate/openstack/master/juno/aio/swift.conf-sample

Become root user:

    $ sudo -s

Update the config.cfg file with appropriate details for the installation e.g. which interface will be used for Management network, Tunnel network, External network; what will be the IP addresses for Management, Tunnel, External interfaces etc.

After you have updated the config.cfg file, you need to run the following scripts in the listed order. (For a detailed explanation about each script, what it does you can go through the next Section [5. Detailed explanation about the scripts](https://github.com/nindate/openstack/blob/master/juno/aio/README.md#5-detailed-explanation-about-the-scripts)

Run the script 0-juno-aio-prepare.sh to prepare the AIO server for Openstack installation.

    # ./0-juno-aio-prepare.sh 

One of the things this script does is updates and upgrades packages. Hence, after the script has ran successfully, restart the server using init 6

Run the script 1-juno-aio-install-keystone.sh to install and configure the Openstack Identity service (Keystone).

    # ./1-juno-aio-install-keystone.sh

Run the script 2-juno-aio-install-glance.sh to install and configure the Openstack Image service (Glance).

    # ./2-juno-aio-install-glance.sh

Run the script 3-juno-aio-install-nova.sh to install and configure the Openstack Compute service (Nova)

    # ./3-juno-aio-install-nova.sh

Run the script 4-juno-aio-install-neutron.sh to install and configure the Openstack Networking service (Neutron)

    # ./4-juno-aio-install-neutron.sh

Run the script 5-juno-aio-install-horizon.sh to install and configure the Openstack Dashboard service (Horizon)

    # ./5-juno-aio-install-horizon.sh

At this stage, the Openstack dashboard is installed and you can access it using the admin or demo username and password that you have set in config.cfg file. The URL for dashboard and the user/password will be displayed when the 5-juno-aio-install-horizon.sh script completes execution.

Run the script 6-juno-aio-install-cinder.sh to install and configure the Openstack Block storage service (Cinder)

    # ./6-juno-aio-install-cinder.sh

Run the script 7-juno-aio-install-swift.sh to install and configure the Openstack Object storage service (Swift)

    # ./7-juno-aio-install-swift.sh

Run the script 8-juno-aio-install-heat.sh to install and configure the Openstack Orchestration service (Heat)

    # ./8-juno-aio-install-heat.sh

Run the script 9-juno-aio-install-ceilometer.sh to install and configure the Openstack Metering service (Ceilometer)

    # ./9-juno-aio-install-ceilometer.sh

This completes installation of the Openstack components on your Openstack AIO server.


### 5. Detailed explanation about the scripts:
0-juno-aio-prepare.sh
This script will prepare the server for Openstack installation. Following will be done:

    - Install the Ubuntu Cloud archive keyring and repository. Update and Upgrade the packages on the system
    - Configure ip forwarding for ipv4
    - Install and configure NTP server
    - Install MySQL database and secure the mysql installation
    - Install RabbitMQ messaging server and create guest user (which will be used by openstack services)


1-juno-aio-install-keystone.sh

This script will install and configure the Identity service for Openstack which is Keystone. Following will be done:

    - Create database and database user for keystone in MySQL
    - Install packages for keystone and python client for keystone
    - Configure keystone
    - Restart keystone service
    - Create a cron job for flushing tokens every hour
    - Create cloud administrator tenant and user (admin)
    - Create tenant and user for a demo cloud user 
    - Create role for cloud administrator and for a normal user and attach these roles to the admin and the demo users respectively
    - Create a tenant for Openstack services (For each Openstack service a user will then be created in keystone and made a member of this service tenant)
    - Create a keystone endpoint
    - Create environment files for admin and demo users


2-juno-aio-install-glance.sh

This script will install and configure the Image service for Openstack which is Glance. Following will be done:

    - Create database and database user for glance in MySQL
    - Create a user for glance in keystone, give admin role to this user and add to service tenant
    - Create service for Imaging service in keystone and define an endpoint for this service
    - Install packages for glance and python client for glance
    - Configure glance-api and glance-registry
    - Restart glance services (glance-api, glance-registry)

3-juno-aio-install-nova.sh

This script will install and configure the Compute service for Openstack which is Nova. Following will be done:

    - Create database and database user for nova in MySQL
    - Create a user for nova in keystone, give admin role to this user and add to service tenant
    - Create service for Compute service in keystone and define an endpoint for this service
    - Install packages for nova (nova-api nova-cert nova-conductor nova-consoleauth  nova-novncproxy nova-scheduler), for KVM (nova-compute-kvm python-guestfs sysfsutils) and python client for nova (python-novaclient)
    - Configure nova (nova.conf), set virtualization type, configure settings to allow resize of instance, configure for neutron networking
    - Restart nova services (nova-conductor, nova-api, nova-cert, nova-consoleauth, nova-scheduler, nova-novncproxy, nova-compute)

4-juno-aio-install-neutron.sh

This script will install and configure the Networking service for Openstack which is Neutron. Following will be done:

    - Create database and database user for neutron in MySQL
    - Create a user for neutron in keystone, give admin role to this user and add to service tenant
    - Create service for Networking service in keystone and define an endpoint for this service
    - Install packages for neutron (openvswitch-controller, openvswitch-switch, neutron-server, neutron-plugin-ml2, neutron-plugin-openvswitch-agent, neutron-l3-agent, neutron-dhcp-agent conntrack)
    - Configure neutron
    - Restart neutron services (neutron-server, neutron-l3-agent, neutron-dhcp-agent, neutron-metadata-agent, openvswitch-switch, neutron-plugin-openvswitch-agent)
    - Create OVS bridge for External bridge
    - Update the /etc/network/interface file with configurations for the various ethernet interfaces and external bridge and bring up the interfaces with these settings
    - Install package for Load balancer as a service (LBaaS) plugin (neutron-lbaas-agent)
    - Configure LBaaS
    - Configure Firewall as a service (FWaaS)
    - Presently the section of the script which can install VPN as a service (VPNaaS) is commented out because installation of VPN agent causes neutron l3 agent to be uninstalled. When proper fix is released, this section can be uncommented.
    - Restart the neutron services (neutron-server, neutron-lbaas-agent, neutron-l3-agent)

5-juno-aio-install-horizon.sh

This script will install and configure the Dashboard service for Openstack which is Horizon. Following will be done:

    - Install packages for Openstack dashboard and remove the Ubuntu theme for dashboard
    - Configure apache2 to listen on IP address and ports for Dashboard
    - Enable lbaas, fwaas, cinder-backup to be visible via dashboard and restart apache2 service

6-juno-aio-install-cinder.sh

This script will install and configure the Block storage service for Openstack which is Cinder. Following will be done:

    - Create database and database user for cinder in MySQL
    - Create a user for cinder in keystone, give admin role to this user and add to service tenant
    - Create service for Block Storage service in keystone and define an endpoint for this service
    - Install packages for cinder (cinder-api cinder-scheduler, cinder-volume, cinder-backup, python-cinderclient), iSCSI (iscsitarget open-iscsi iscsitarget-dkms) and LVM (lvm2)
    - Configure cinder
    - Create a loopback device to be used as a PV for volume group for cinder. The volume group will be created by the name cinder-volumes
    - Restart services (cinder-api, cinder-scheduler, tgt, cinder-volume, cinder-backup)


7-juno-aio-install-swift.sh

This script will install and configure the Object storage service for Openstack which is Swift. Following will be done:

    - Create database and database user for swift in MySQL
    - Create a user for swift in keystone, give admin role to this user and add to service tenant
    - Create service for Object storage service in keystone and define an endpoint for this service 
    - Install packages for swift (swift, swift-proxy, python-swiftclient, python-keystoneclient, python-keystonemiddleware, memcached, swift-account, swift-container, swift-object) and some additional required packages (xfsprogs, curl, rsync)
    - Create a loopback device and format as an xfs filesystem to be used for swift.
    - Create multiple directories inside this loopback filesystem to simulate multiple Storage nodes for swift
    - Configure rsync to replicate across these directories to simulate replication across the swift Storage nodes
    - Configure swift proxy, account server, container server and object server
    - Build rings for swift
    - Restart swift services

8-juno-aio-install-heat.sh

This script will install and configure the Orchestration service for Openstack which is Heat. Following will be done:

    - Create database and database user for heat in MySQL
    - Create a user for heat in keystone, give admin role to this user and add to service tenant
    - Create service for Orchestration service in keystone and define an endpoint for this service  
    - Install packages for heat (heat-api, heat-api-cfn, heat-engine, python-heatclient)
    - Configure heat
    - Restart services (heat-api, heat-api-cfn, heat-engine)

9-juno-aio-install-ceilometer.sh

This script will install and configure the Metering service for Openstack which is Ceilometer. Following will be done:

    - Create database and database user for ceilometer in MySQL
    - Create a user for ceilometer in keystone, give admin role to this user and add to service tenant
    - Create service for Metering service in keystone and define an endpoint for this service  
    - Install mongodb database and create user for ceilometer. This mongodb database will be used for storing all the ceilometer collected metrics, alarms, events etc.
    - Install packages for ceilometer (ceilometer-api, ceilometer-collector, ceilometer-agent-central, ceilometer-agent-notification, ceilometer-alarm-evaluator, ceilometer-alarm-notifier, python-ceilometerclient)
    - Configure ceilometer
    - Restart ceilometer services (ceilometer-agent-central, ceilometer-agent-notification, ceilometer-api, ceilometer-collector, ceilometer-alarm-evaluator, ceilometer-alarm-notifier)
    - Install ceilometer agent packages to monitor compute (ceilometer-agent-compute)
    - Configure ceilometer to monitor compute (nova) and restart services (ceilometer-agent-compute, nova-compute)
    - Configure ceilometer to monitor image (glance)and restart services (glance-registry, glance-api)
    - Configure ceilometer to monitor block storage (cinder)and restart services (cinder-api, cinder-scheduler, cinder-volume)
    - Configure ceilometer to monitor object storage (swift), add ceilometer to group swift and restart services (swift-proxy)
    - Configure ceilometer to monitor networking (neutron) and restart services (neutron-server, neutron-dhcp-agent, neutron-l3-agent, neutron-metadata-agent, neutron-plugin-openvswitch-agent)

