                     Openstack Juno All-in-one setup on Ubuntu 14.04 x64 server
                     ----------------------------------------------------------

1. Purpose:
The purpose of these scripts is to install all Openstack components on a single server to be able to use this Openstack setup for learning/demo/testing. This is known as All-in-one (AIO) setup and lets call this server as AIO server. The scripts will install Openstack Juno version.
The scripts have been tested on a VirtualBox virtual machine (VM) as the AIO server, but I believe that they should work on physical server or VM on any other virtualization software as well.
Following Openstack components will be installed by these scripts:
Keystone, Glance, Nova, Neutron (including LBaaS and FWaaS), Horizon, Cinder, Swift, Heat and Ceilometer

2. Setup explanation:
It is better that I explain a little bit on some generic stuff of Openstack in the context of this setup. In Openstack, 
- there are mainly the following types of nodes: Controller node, Network node, Compute node, Block Storage node, Object Storage node. In the AIO setup all these functions are performed on/by the AIO server.
- there are various types of network traffic flowing based on which we have the following networks:
  - Management network : Openstack nodes communicate with each other on this network. Thus all Openstack nodes need to have connectivity with this network
  - Data/Tunnel network : The instances (virtual machines) launched on the Compute nodes talk to each other and to the Network node (for advanced networking like router, firewall, load balancer etc.) on this network. Thus only Network node and all the Compute nodes need to have connectivity with this network
  - External network : The instances on the Compute nodes communicate with servers / services outside Openstack setup via this network. Typically the instances can communicate outside only via the L3 services on the Network node and hence Network node needs to have connectivity with this network (Although since Juno release features like DVR allow this communication directly from compute nodes - am not considering that for this setup)
  In the AIO setup all these networks will be connected to the single server we will be having - our AIO server. Following figure shows this connectivity

"---MANAGEMENT NW---------------"
"                             |"
"                         eth0|"
                           -------Controller
                      eth2 |     |   +             +
---EXTERNAL NW-------------|     | Network     Block Storage
                           |     |   +             +
                           ------- Compute    Object Storage
                          eth1|
                              |
---DATA/TUNNEL NW--------------

3. Setup requirements:
- In case you are using a Virtual Machine (and that's what I do usually) you would need to create a VM with atleast 2 CPUs and 5 GB memory (however if you want to run several instances inside Openstack you would need more CPU/Memory for your server)
- Install Ubuntu 14.04 x64 server with Openssh package installed (so that you can ssh to this server) and update the server with following command
apt-get update -y


