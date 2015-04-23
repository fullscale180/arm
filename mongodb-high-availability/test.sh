#!/bin/bash

#--------------------------------------------------------------------------------------------------
# MongoDB Template for Azure Resource Manager (brought to you by Full Scale 180 Inc)
#
# This script installs MongoDB on each Azure virtual machine. The script will be supplied with
# runtime parameters declared from within the corresponding ARM template.
#--------------------------------------------------------------------------------------------------
help()
{
	echo "This script installs MongoDB on the Ubuntu virtual machine image"
	echo "Options:"
	echo "		-l Installation package URL"
	echo "		-i Installation package name"
	echo "		-r Replica set name"
	echo "		-k Replica set key"
	echo "		-u System administrator's user name"
	echo "		-p System administrator's password"
	echo "		-n Number of member nodes"	
	echo "		-a (arbiter indicator)"	
	echo "		-l (last member indicator)"	
}

log()
{
	echo "$1"
}

PACKAGE_URL=http://repo.mongodb.org/apt/ubuntu
PACKAGE_NAME=mongodb-org
REPLICA_SET_KEY_DATA=""
REPLICA_SET_NAME=""
REPLICA_SET_KEY_FILE="/etc/mongo-replicaset-key"
DATA_DISKS="/datadisks"
DATA_MOUNTPOINT="$DATA_DISKS/disk1"
MONGODB_DATA="$DATA_MOUNTPOINT/mongodb"
MONGODB_PORT=27017
IS_ARBITER=false
IS_LAST_MEMBER=false
JOURNAL_ENABLED=true
ADMIN_USER_NAME=""
ADMIN_USER_PASSWORD=""
INSTANCE_COUNT=1

# Parse script parameters
while getopts :l:i:r:k:u:p:n:alh optname; do

	# Log input parameters (except the admin password) to facilitate troubleshooting
	if [ ! "$optname" == "p" ] && [ ! "$optname" == "k" ]; then
		log "Option $optname set with value ${OPTARG}"
	fi
  
	case $optname in
	l) # Installation package location
		PACKAGE_URL=${OPTARG}
		;;
	i) # Installation package name
		PACKAGE_NAME=${OPTARG}
		;;
	r) # Replica set name
		REPLICA_SET_NAME=${OPTARG}
		;;	
	k) # Replica set key
		REPLICA_SET_KEY_DATA=${OPTARG}
		;;	
	u) # Administrator's user name
		ADMIN_USER_NAME=${OPTARG}
		;;		
	p) # Administrator's user name
		ADMIN_USER_PASSWORD=${OPTARG}
		;;	
	n) # Number of instances
		INSTANCE_COUNT=${OPTARG}
		;;		
	a) # Arbiter indicator
		IS_ARBITER=true
		JOURNAL_ENABLED=false
		;;		
	l) # Last member indicator
		IS_LAST_MEMBER=true
		;;		
    h)  # Helpful hints
		help
		exit 2
		;;
    \?) # Unrecognized option - show help
		echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
		help
		exit 2
		;;
  esac
done
