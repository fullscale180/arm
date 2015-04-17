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

log "Begin setting up couchbase on ${HOSTNAME}"
 
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
IP_LIST=""
ADMINISTRATOR="couchbaseadmin"
PASSWORD="P@ssword1"
# Minimum VM size we are assuming is A2, which has 3.5GB, 2800MB is about 80% as recommended
RAM_FOR_COUCHBASE=2800

#Loop through options passed
while getopts :n:i:a:pw:r: optname; do
    log "Option $optname set with value ${OPTARG}"
  case $optname in
    n)  #set cluster name
      CLUSTER_NAME=${OPTARG}
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

DATA_DISKS="/datadisks"
DATA_MOUNTPOINT="$DATA_DISKS/disk1"
COUCHBASE_DATA="$DATA_MOUNTPOINT/couchbase"


# If IP_LIST is non-empty, we are on the first node
if [ -n "${IP_LIST}" ]; then

  IFS='-' read -a HOST_IPS <<< "$IP_LIST"

  #Get the IP Addresses on this machine
  declare -a MY_IPS=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
  MY_IP=""
  declare -a MEMBER_IP_ADDRESSES=()
  for (( n=0 ; n<("${HOST_IPS[1]}"+0) ; n++))
  do
      HOST="${HOST_IPS[0]}${n}"
      if ! [[ "${MY_IPS[@]}" =~ "${HOST}" ]]; then
          MEMBER_IP_ADDRESSES+=($HOST)
      else
  		MY_IP="${HOST}"
      fi
  done

  log "Initializing the first node."
  /opt/couchbase/bin/couchbase-cli node-init -c "$MY_IP":8091 --node-init-data-path="${COUCHBASE_DATA}" -u "${ADMINISTRATOR}" -p "${PASSWORD}"
  log "Setting up cluster"
  /opt/couchbase/bin/couchbase-cli cluster-init -c "$MY_IP":8091  -u "${ADMINISTRATOR}" -p "${PASSWORD}" --cluster-init-port=8091 --cluster-init-ramsize="${RAM_FOR_COUCHBASE}"
  log "Setting autofailover"
  /opt/couchbase/bin/couchbase-cli setting-autofailover  -c "$MY_IP":8091  -u "${ADMINISTRATOR}" -p "${PASSWORD}" --enable-auto-failover=1 --auto-failover-timeout=30

  for (( i = 0; i < ${#MEMBER_IP_ADDRESSES[@]}; i++ )); do
    log "Adding node ${MEMBER_IP_ADDRESSES[$i]} to cluster"
    /opt/couchbase/bin/couchbase-cli server-add -c "$MY_IP":8091 -u "${ADMINISTRATOR}" -p "${PASSWORD}" --server-add="${MEMBER_IP_ADDRESSES[$i]}" 
  done

  log "Reblancing the cluster"
  /opt/couchbase/bin/couchbase-cli rebalance -c "$MY_IP":8091 -u "${ADMINISTRATOR}" -p "${PASSWORD}"
 
fi
