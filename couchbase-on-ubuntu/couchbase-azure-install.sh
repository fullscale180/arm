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

#Loop through options passed
while getopts :n:p: optname; do
    log "Option $optname set with value ${OPTARG}"
  case $optname in
    n)  #set cluster name
      CLUSTER_NAME=${OPTARG}
      ;;
    p) #Couchbase package name
      PACKAGE_NAME=${OPTARG}
      ;;
    i) #Static IPs of the cluster members
      IP_LIST=${OPTARG}
      ;;      
  esac
done

# Install couchbase
install_cb()
{
	# First prepare the environment as per http://blog.couchbase.com/often-overlooked-linux-os-tweaks

	# We may not reboot, disable with the running system
	# Set the value for the running system
	echo 0 > /proc/sys/vm/swappiness

	# Backup sysctl.conf
	cp -p /etc/sysctl.conf /etc/sysctl.conf.`date +%Y%m%d-%H:%M`

	# Set the value in /etc/sysctl.conf so it stays after reboot.
	echo '' >> /etc/sysctl.conf
	echo '#Set swappiness to 0 to avoid swapping' >> /etc/sysctl.conf
	echo 'vm.swappiness = 0' >> /etc/sysctl.conf

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

DATA_DIRECTORY="$DATA_DISKS/couchbase"


install_cb