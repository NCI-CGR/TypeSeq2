

.. _Ion_Torrent: https://www.thermofisher.com/order/catalog/product/A27212#/A27212


.. _Installation-Installation: 

=============================
Requirements
=============================

The TypeSeqHPV Ion Torrent Version has the following requirements prior to installation -

1. Ion_torrent_ S5 system connected to a server 
2. Latest Torrent Suite Software installed on the server (5.1 or higher)
3. Ubuntu 16.04 (Xenial/Bionic/Cosmic/Disco) or higher
4. Docker needs to be installed before running the plugin. Steps 1-3 are required to support docker.

   Install Docker on S5 server - https://docs.docker.com/engine/install/ubuntu/


   Uninstall previous version

It may be required to uninstall previous version of docker. Skip this step if no previous version of docker installed.

.. code-block:: console

  $ sudo apt-get remove docker docker-engine docker.io
  $ Update Package Index and Install

  $ sudo apt-get update
  $ sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

  $ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

  $ sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"

  $ sudo apt-get update

  $ sudo apt-get install -y docker-ce
  $ Post Installation Setup

Give plugin access to docker.

.. code-block:: console
  
  $ sudo usermod -aG docker ionadmin
  $ sudo usermod -aG docker ionian


Try a hello world install test.

.. code-block:: console
  
  $ docker run hello-world
  $ Make Docker storage more robust on torrent server

Docker doesn't always clean up after itself. Changing were docker keeps it's image layers will prevent critical partitions from filling up. If this step is skipped after several runs of a docker plugin the Torrent Service job scheduler will stop working.


.. code-block:: console

  $ sudo service docker stop
  $ sudo rm -rf  /var/lib/docker
  $ sudo vim /etc/default/docker


Modify this line

 #DOCKER_OPTS="--dns 8.8.8.8 --dns 8.8.4.4"
 Changing it to this

 DOCKER_OPTS="--dns 8.8.8.8 --dns 8.8.4.4 -g /results/plugins/scratch/docker"


Restart Docker

.. code-block:: console

   $ sudo service docker start 



Pull the docker image from docker hub

.. code-block:: console

   $ docker pull cgrlab/typeseqhpv:final_190104


Note to developer -- to be removed later
The docker container is already built and saved in our image library. If you make a new image, please use proper tags, the tag should indicate date in yy/mm/dd format
docker and github repos are synced. If you want to build docker container, you can trigger a build directly on docker hub. It takes around 15 mins there
Never mess with the base container. Only change stuff in the developemnt docker image.












