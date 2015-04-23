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

#### Install Java
apt-get -y install openjdk-7-jre
apt-get -y install openjdk-7-jdk

#### Install Jemkins
wget -q -O - http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key | sudo apt-key add -
apt-get -y update 
echo deb http://pkg.jenkins-ci.org/debian binary/ > /etc/apt/sources.list.d/jenkins.list
apt-get -y install jenkins
