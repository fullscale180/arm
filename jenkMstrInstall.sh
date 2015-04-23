#!/bin/bash

#########################################################
# Script Name: jenkMstrInstall.sh
# Author: Dennis Angeline - Full Scale 180 Inc 
# Version: 0.1
# Last Modified By:       Dennis Angeline
# Description:
#  This script install Jenkins master on an Ubuntu VM image
# Parameters :
# Note : 
# This script has only been tested on Ubuntu 14.04 LTS and must be root
######################################################### 

grep -q "${HOSTNAME}" /etc/hosts

if [ $? == 0];
then
  echo "%{HOSTNAME} found in /etc/hosts"
else
  echo "${HOSTNAME} not found in  /etc/hosts"
  sudo echo "127.0.0.1 ${HOSTNAME}" >> /etc/hosts
  log "hostname %{HOSTNAME} added to /etc/hosts"
fi


#### Install Java
apt-get -y update 
apt-get -y install openjdk-7-jdk

#### Install Jemkins
wget -q -O - https://jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
sh -c 'echo deb http://pkg.jenkins-ci.org/debian binary/ > /etc/apt/sources.list.d/jenkins.list'
apt-get update
apt-get -y install jenkins
