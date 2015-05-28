# openstack
Scripts to install and configure Openstack 

These are various scripts I have developed to automate Openstack installation and make Openstack setup available quickly.
I use these for Openstack installations I do and thought of sharing these back to the community [I have learnt a lot from the community myself and want to contribute back]

There are various ways of installing Openstack, as well as there are numerous scripts written by many people to install and configure Openstack. I have tried many things myself so far and the top reasons for developing my own set of scripts were:
- I found packstack to be a very good tool to install Openstack, but it works only on RedHat OSes (RHEL, CentOS, Fedora) and many a times I found this to be slow (might be internet + availability of the mirror servers for repositories). So I wanted to install Openstack on Ubuntu (which I kind of like as I use Ubuntu on my laptop)
- There may be scripts around, but atleast I did not find these or had to look into multiple places - for installing Openstack components like Swift (Object storage), Heat (Orchestration) and Ceilometer (Metering)
- I wanted to further customize some of the things in the installation e.g. allow resizing of instance to another flavor, configure multiple cinder backend types, install LBaaS, FWaaS, VPNaaS of neutron.
