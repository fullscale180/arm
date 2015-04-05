#!/bin/bash


log()
{
    curl -X POST -H "content-type:text/plain" --data-binary "${HOSTNAME}| $1" https://logs-01.loggly.com/inputs/d17b3933-b2ed-439c-827c-c7047d992745/tag/es-extension,${HOSTNAME}
}

log "Begin execution of elasticsearch script extension on $(hostname)"

if [ "${UID}" -ne 0 ];
then
    log "Script executed without root permissions"
    echo "You must be root to run this program." >&2
    exit 3
fi

# TEMP FIX 
# This is an interim fix for hostname resolution in preview VM
grep -q "$(hostname)" /etc/hosts
if [ $? -eq $SUCCESS ]
then
  echo "$(hostname)found in /etc/hosts"
else
  echo "$(hostname) not found in /etc/hosts"
  # Append it to the hsots file if not there
  echo "127.0.0.1 $(hostname)" >> /etc/hosts
  log "hostname $(hostname) added to /etchosts"
fi

#Script Parameters
# ClusterName
# RoleTypes
# Default Shards
# Default Replicas
# Node Name Prefix
# Is Durable
# Install Marvel
CLUSTER_NAME="elasticsearch"
DISCOVERY_ENDPOINTS=""
INSTALL_MARVEL=0
CLIENT_ONLY_NODE=0
DATA_NODE=0
MASTER_ONLY_NODE=0

while getopts :n:d:v:lxyzsh optname; do
    log "Option $optname set with value ${OPTARG}"
  case $optname in
    n)  #set clsuter name
      CLUSTER_NAME=${OPTARG}
      ;;
    d) #Static dicovery endpoints
      DISCOVERY_ENDPOINTS=${OPTARG}
      ;;
    v)  #elasticsearch version number
      ES_VERSION=${OPTARG}
      ;;
    l)  #install marvel
      INSTALL_MARVEL=1
      ;;
    x)  #master node
      MASTER_ONLY_NODE=1
      ;;
    y)  #client node
      CLIENT_ONLY_NODE=1
      ;;
    z)  #client node
      DATA_NODE=1
      ;;
    s) #use OS striped disk volumes
	  OS_STRIPED_DISK=1
      ;;
    d) #place data on local resource disk
      NON_DURABLE=1
      ;;
    h)  #show help
      help
      exit 2
      ;;
    \?) #unrecognized option - show help
      echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
      help
      exit 2
      ;;
  esac
done

help()
{
    #TODO: Add help text here
	echo "HELP!"
}

#Validate Configurations

#A set of disks to ignore from partitioning and formatting
BLACKLIST="/dev/sda|/dev/sdb"

# Base path for data disk mount points
DATA_BASE="/datadisks"

usage() {
    echo "Some udate details: $(basename $0)"
}

is_partitioned() {
# Checks if there is a valid partition table on the
# specified disk
    OUTPUT=$(sfdisk -l ${1} 2>&1)
    grep "No partitions found" <<< "${OUTPUT}" >/dev/null 2>&1
    if [ "${?}" -eq 0 ];
    then
        return 1
    else
        return 0
    fi
}

has_filesystem() {
    DEVICE=${1}
    OUTPUT=$(file -L -s ${DEVICE})
    grep filesystem <<< "${OUTPUT}" > /dev/null 2>&1
    return ${?}
}

scan_for_new_disks() {
    # Looks for unpartitioned disks
    declare -a RET
    DEVS=($(ls -1 /dev/sd*|egrep -v "${BLACKLIST}"|egrep -v "[0-9]$"))
    for DEV in "${DEVS[@]}";
    do
        # The disk will be considered a candidate for partitioning
        # and formatting if it does not have a sd?1 entry or
        # if it does have an sd?1 entry and does not contain a filesystem
        is_partitioned "${DEV}"
        if [ ${?} -eq 0 ];
        then
            has_filesystem "${DEV}1"
            if [ ${?} -ne 0 ];
            then
                RET+=" ${DEV}"
            fi
        else
            RET+=" ${DEV}"
        fi
    done
    echo "${RET}"
}

get_next_mountpoint() {
    DIRS=$(ls -1d ${DATA_BASE}/disk* 2>/dev/null| sort --version-sort)
    MAX=$(echo "${DIRS}"|tail -n 1 | tr -d "[a-zA-Z/]")
    if [ -z "${MAX}" ];
    then
        echo "${DATA_BASE}/disk1"
        return
    fi
    IDX=1
    while [ "${IDX}" -lt "${MAX}" ];
    do
        NEXT_DIR="${DATA_BASE}/disk${IDX}"
        if [ ! -d "${NEXT_DIR}" ];
        then
            echo "${NEXT_DIR}"
            return
        fi
        IDX=$(( ${IDX} + 1 ))
    done
    IDX=$(( ${MAX} + 1))
    echo "${DATA_BASE}/disk${IDX}"
}

add_to_fstab() {
    UUID=${1}
    MOUNTPOINT=${2}
    grep "${UUID}" /etc/fstab >/dev/null 2>&1
    if [ ${?} -eq 0 ];
    then
        echo "Not adding ${UUID} to fstab again (it's already there!)"
    else
        LINE="UUID=\"${UUID}\"\t${MOUNTPOINT}\text4\tnoatime,nodiratime,nodev,noexec,nosuid\t1 2"
        echo -e "${LINE}" >> /etc/fstab
    fi
}

do_partition() {
# This function creates one (1) primary partition on the
# disk, using all available space
    DISK=${1}
    echo "n
p
1


w"| fdisk "${DISK}" > /dev/null 2>&1

#
# Use the bash-specific $PIPESTATUS to ensure we get the correct exit code
# from fdisk and not from echo
if [ ${PIPESTATUS[1]} -ne 0 ];
then
    echo "An error occurred partitioning ${DISK}" >&2
    echo "I cannot continue" >&2
    exit 2
fi
}
#end do_partition

scan_partition_format()
{
    log "Begin scanning and formatting data disks"

    DISKS=($(scan_for_new_disks))

	if [ "${#DISKS}" -eq 0 ];
	then
	    log "No unpartitioned disks without filesystems detected"
	    return
	fi
	echo "Disks are ${DISKS[@]}"
	for DISK in "${DISKS[@]}";
	do
	    echo "Working on ${DISK}"
	    is_partitioned ${DISK}
	    if [ ${?} -ne 0 ];
	    then
	        echo "${DISK} is not partitioned, partitioning"
	        do_partition ${DISK}
	    fi
	    PARTITION=$(fdisk -l ${DISK}|grep -A 1 Device|tail -n 1|awk '{print $1}')
	    has_filesystem ${PARTITION}
	    if [ ${?} -ne 0 ];
	    then
	        echo "Creating filesystem on ${PARTITION}."
	#        echo "Press Ctrl-C if you don't want to destroy all data on ${PARTITION}"
	#        sleep 10
	        mkfs -j -t ext4 ${PARTITION}
	    fi
	    MOUNTPOINT=$(get_next_mountpoint)
	    echo "Next mount point appears to be ${MOUNTPOINT}"
	    [ -d "${MOUNTPOINT}" ] || mkdir -p "${MOUNTPOINT}"
	    read UUID FS_TYPE < <(blkid -u filesystem ${PARTITION}|awk -F "[= ]" '{print $3" "$5}'|tr -d "\"")
	    add_to_fstab "${UUID}" "${MOUNTPOINT}"
	    echo "Mounting disk ${PARTITION} on ${MOUNTPOINT}"
	    mount "${MOUNTPOINT}"
	done
}

setup_data_disk()
{
    log "Configuring disk $1/elasticsearch/data"

    mkdir -p "$1/elasticsearch/data"
    chown -R elasticsearch:elasticsearch "$1/elasticsearch"
    chmod 755 "$1/elasticsearch"
}

install_java()
{
    log "Installing Java"
    add-apt-repository -y ppa:webupd8team/java
    apt-get -y update 
    echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
    echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
    apt-get -y install oracle-java7-installer
}

install_es()
{
    log "Installing Elaticsearch"
    # apt-get install approach
    # This has the added benefit that is simplifies upgrades (user)
    # Using the debian package because it's easier to explicitly control version and less changes of nodes with different versions
    #wget -qO - https://packages.elasticsearch.org/GPG-KEY-elasticsearch | sudo apt-key add -
    #add-apt-repository "deb http://packages.elasticsearch.org/elasticsearch/1.5/debian stable main"
    #apt-get update && apt-get install elasticsearch

    # DPKG Install Approach
    # Simple aproach
    if [ -n "$ES_VERSION" ]; then
        ES_VERSION="1.5.0"
    fi
    sudo wget -q "https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-$ES_VERSION.deb -O elasticsearch.deb"
    sudo dpkg -i elasticsearch.deb
}

#########################
#########################

#NOTE: These first three could be changed to run in parallel (export the functions and use background/wait)
#Install Oracle Java
#------------------------
install_java

#
#Install Elasticsearch
#-----------------------
install_es

#Format data disks
#------------------------
# Find data disks then partition, format, and mount them as seperate drives
scan_partition_format

#
#Configure permissions on data disks for elasticsearch user:group
#--------------------------
DATAPATH_CONFIG=""
for D in `find /datadisks/ -mindepth 1 -maxdepth 1 -type d`
do
    setup_data_disk ${D}
    # Add to list for elasticsearch configuration
    DATAPATH_CONFIG+="$D/elasticsearch/data,"
done
#Remove the extra trailing comma
DATAPATH_CONFIG="${DATAPATH_CONFIG%?}"

#D=`find ~ -mindepth 1 -maxdepth 1 -type d`
#DISKS=$(echo "$D" | tr '\n' ',')

#Get a list of my local IP addresses to trim my own out of the list of discovery IPs passed
MY_IPS=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`

#Format the static host endpooints for elasticsearch configureion ["",""] format
HOSTS_CONFIG="[\"${DISCOVERY_ENDPOINTS//-/\",\"}\"]"

#Configure Elasticsearch
#---------------------------
#Set elasticsearch.yml configuration settings
mv /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.bak

# Set cluster and machine names - just use hostname for the node.name
echo "cluster.name: $CLUSTER_NAME" >> /etc/elasticsearch/elasticsearch.yml
echo "node.name: $(hostname)" >> /etc/elasticsearch/elasticsearch.yml

# If we have data disks defined then use those in elasticsearch.yml
if [ -n "$DATAPATH_CONFIG" ]; then
    log "Update configuration with data path list of $DATAPATH_CONFIG"
    echo "path.data: $DATAPATH_CONFIG" >> /etc/elasticsearch/elasticsearch.yml
fi

# Set mlockall to true
echo "bootstrap.mlockall: true" >> /etc/elasticsearch/elasticsearch.yml

# Set to static node discovery and add static hosts
log "Update configuration with hosts configuration of $HOSTS_CONFIG"
echo "discovery.zen.ping.multicast.enabled: false" >> /etc/elasticsearch/elasticsearch.yml
echo "discovery.zen.ping.unicast.hosts: $HOSTS_CONFIG" >> /etc/elasticsearch/elasticsearch.yml

log "Configure master/client/data node type"
# Configure elaticsearch node type
if [$MASTER_ONLY_NODE -ne 0 ]; then
    log "Configure node as master only"
    echo "node.master: true" >> /etc/elasticsearch/elasticsearch.yml
    echo "node.data: false" >> /etc/elasticsearch/elasticsearch.yml
else if [$DATA_NODE -ne 0 ]; then
    log "Configure node as data only"
    echo "node.master: false" >> /etc/elasticsearch/elasticsearch.yml
    echo "node.data: true" >> /etc/elasticsearch/elasticsearch.yml
else
    log "Configure node for master and data"
    echo "node.master: true" >> /etc/elasticsearch/elasticsearch.yml
    echo "node.data: true" >> /etc/elasticsearch/elasticsearch.yml
fi

#---------------
#Updating the properties in the existing configuraiton has been a bit sensitve and requires more testing
#sed -i -e "/cluster\.name/s/^#//g;s/^\(cluster\.name\s*:\s*\).*\$/\1${CLUSTER_NAME}/" /etc/elasticsearch/elasticsearch.yml
#sed -i -e "/bootstrap\.mlockall/s/^#//g;s/^\(bootstrap\.mlockall\s*:\s*\).*\$/\1true/" /etc/elasticsearch/elasticsearch.yml
#sed -i -e "/path\.data/s/^#//g;s/^\(path\.data\s*:\s*\).*\$/\1${DATAPATH_CONFIG}/" /etc/elasticsearch/elasticsearch.yml

#Disable multicast and set master node endpoints
#sed -i -e "/discovery\.zen\.ping\.multicast\.enabled/s/^#//g;s/^\(discovery\.zen\.ping\.multicast\.enabled\s*:\s*\).*\$/\1false/" /etc/elasticsearch/elasticsearch.yml
#sed -i -e "/discovery\.zen\.ping\.unicast\.hosts/s/^#//g;s/^\(discovery\.zen\.ping\.unicast\.hosts\s*:\s*\).*\$/\1${HOSTS_CONFIG}/" /etc/elasticsearch/elasticsearch.yml

# Minimum master nodes nodes/2+1
# These can be configured via API as well - (requires cluster size)
# discovery.zen.minimum_master_nodes: 2
# gateway.expected_nodes: 10
# gateway.recover_after_time: 5m
#----------------

# Configure Environment
#TODO

#/etc/default/elasticseach
#Update HEAP Size in this configuration or in upstart service
#Set Elasticsearch heap size to 50% of system memory
#TODO: Move this to an init.d script so we can handle instance size increases
log "Configure elasticsearch heap size"
ES_HEAP=`free -m |grep Mem | awk '{if ($2/2 >31744)  print 31744;else print $2/2;}'`
sed -i -e "/ES_HEAP_SIZE/s/^#//g;s/^\(ES_HEAP_SIZE\s*=\s*\).*\$/\1${ES_HEAP}/" /etc/default/elasticseach

#Optionally Install Marvel
if [ $INSTALL_MARVEL -ne 0 ];
    then
    /usr/share/elasticsearch/bin/plugin -i elasticsearch/marvel/latest
fi

#Install Monit
#TODO

#and... start the service
log "Starting Elasticsearch on $(hostname)"
update-rc.d elasticsearch defaults 95 10
sudo service elasticsearch start
