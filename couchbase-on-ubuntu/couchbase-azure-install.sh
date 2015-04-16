#!/bin/bash

### Ercenk Keresteci (Full Scale 180 Inc)
### 
### Warning! This script partitions and formats disk information be careful where you run it
###          This script is currently under development and has only been tested on Ubuntu images in Azure
###          This script is not currently idempotent and only works for provisioning

# Log method to control/redirect log output
log()
{
    curl -X POST -H "content-type:text/plain" --data-binary "${HOSTNAME} - $1" https://logs-01.loggly.com/inputs/1ade465e-527c-40ab-a8b0-7c6f477af19a/tag/cb-extension,${HOSTNAME}
}

log "Begin execution of couchbase script extension on ${HOSTNAME}"
 
if [ "${UID}" -ne 0 ];
then
    log "Script executed without root permissions"
    echo "You must be root to run this program." >&2
    exit 3
fi

# TEMP FIX - Re-evaluate and remove when possible
# This is an interim fix for hostname resolution in current VM
if grep -q "${HOSTNAME}" /etc/hosts
then
  echo "${HOSTNAME}found in /etc/hosts"
else
  echo "${HOSTNAME} not found in /etc/hosts"
  # Append it to the hsots file if not there
  echo "127.0.0.1 $(hostname)" >> /etc/hosts
  log "hostname ${HOSTNAME} added to /etchosts"
fi

#Script Parameters
CLUSTER_NAME="couchbase"
PACKAGE_NAME="couchbase-server-enterprise_3.0.3-ubuntu12.04_amd64.deb"
IP_LIST=""
ADMINISTRATOR="couchbaseadmin"
PASSWORD="P@ssword1"
# Minimum VM size we are assuming is A2, which has 3.5GB, 2800MB is about 80% as recommended
RAM_FOR_COUCHBASE=2800

#Loop through options passed
while getopts :n:pn:i:a:pw:r: optname; do
    log "Option $optname set with value ${OPTARG}"
  case $optname in
    n)  #set cluster name
      CLUSTER_NAME=${OPTARG}
      ;;
    pn) #Couchbase package name
      PACKAGE_NAME=${OPTARG}
      ;;
    i) #Static IPs of the cluster members
      IP_LIST=${OPTARG}
      ;;    
    a) #Static IPs of the cluster members
      ADMINISTRATOR=${OPTARG}
      ;; 
	pw) #Static IPs of the cluster members
	  PASSWORD=${OPTARG}
	  ;;         
	r) #Static IPs of the cluster members
	  RAM_FOR_COUCHBASE=${OPTARG}
	  ;;         	  
  esac
done

# Install couchbase
install_cb()
{
	# First prepare the environment as per http://blog.couchbase.com/often-overlooked-linux-os-tweaks

	log "Disable swappiness"
	# We may not reboot, disable with the running system
	# Set the value for the running system
	echo 0 > /proc/sys/vm/swappiness

	# Backup sysctl.conf
	cp -p /etc/sysctl.conf /etc/sysctl.conf.`date +%Y%m%d-%H:%M`

	# Set the value in /etc/sysctl.conf so it stays after reboot.
	echo '' >> /etc/sysctl.conf
	echo '#Set swappiness to 0 to avoid swapping' >> /etc/sysctl.conf
	echo 'vm.swappiness = 0' >> /etc/sysctl.conf

	log "Disable THP"
	# Disble THP
	# We may not reboot yet, so disable for this time first
	# Disable THP on a running system
	echo never > /sys/kernel/mm/transparent_hugepage/enabled
	echo never > /sys/kernel/mm/transparent_hugepage/defrag

	# Backup rc.local
	cp -p /etc/rc.local /etc/rc.local.`date +%Y%m%d-%H:%M`
	sed -i -e '$i \ if test -f /sys/kernel/mm/transparent_hugepage/enabled; then \
 			 echo never > /sys/kernel/mm/transparent_hugepage/enabled \
		  fi \ \
		if test -f /sys/kernel/mm/transparent_hugepage/defrag; then \
		   echo never > /sys/kernel/mm/transparent_hugepage/defrag \
		fi \
		\n' /etc/rc.local
	

    log "Installing Couchbase package - $PACKAGE_NAME"    
	sudo dpkg -i ./$PACKAGE_NAME
}

DATA_DISKS="/datadisks"
# Stripe all of the data disks
bash ./vm-disk-utils-0.1.sh -b $DATA_DISKS -s

DATA_MOUNTPOINT="$DATA_DISKS/disk1"

install_cb

MEMBER_IP_ADDRESSES=($IP_LIST)
declare -a MY_IPS=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`

IS_FIRST_NODE=0

for (( i = 0; i < ${#MY_IPS[@]}; i++ )); do
	if [ "${MY_IPS[$i]}" = "${MEMBER_IP_ADDRESSES[0]}" ]; then
		IS_FIRST_NODE=1
	fi
done

if [ "${IS_FIRST_NODE}" = 1 ]; then
	/opt/couchbase/bin/couchbase-cli node-init -c "${MEMBER_IP_ADDRESSES[0]}":8091 --node-init-data-path="${DATA_MOUNTPOINT}" -u "${ADMINISTRATOR}" -p "${PASSWORD}"
	/opt/couchbase/bin/couchbase-cli cluster-init -c "${MEMBER_IP_ADDRESSES[0]}":8091  -u "${ADMINISTRATOR}" -p "${PASSWORD}" --cluster-init-port=8091 --cluster-init-ramsize="${RAM_FOR_COUCHBASE}"
	/opt/couchbase/bin/couchbase-cli setting-autofailover  -c "${MEMBER_IP_ADDRESSES[0]}":8091  -u "${ADMINISTRATOR}" -p "${PASSWORD}" --enable-auto-failover=1 --auto-failover-timeout=30

	for (( i = 1; i < ${#MEMBER_IP_ADDRESSES[@]}; i++ )); do
		/opt/couchbase/bin/couchbase-cli server-add -c "${MEMBER_IP_ADDRESSES[0]}":8091   -u "${ADMINISTRATOR}" -p "${PASSWORD}" —server-add="${MEMBER_IP_ADDRESSES[$i]}" 
	done
fi