#!/bin/bash
if [ "${UID}" -ne 0 ];
then
    echo "You must be root to run this program." >&2
    exit 3
fi

#Script Parameters
# ClusterName
# RoleTypes
# Default Shards
# Default Replicas
# Node Name Prefix
# Is Durable
# Install Marvel
while getopts :n:m:l:x:s:h FLAGS; do
  case $FLAGS in
    n)  #set clsuter name
        CLUSTER_NAME=${OPTARG}
      ;;
    m)  #machine name
      MACHINE_NAME= ${OPTARG}
      ;;
    l)  #install marvel
      INSTALL_MARVEL=true
      ;;
    x)  #master node
      MASTER_ONLY_NODE=true
      ;;
    y)  #client node
      CLIENT_ONLY_NODE=true
      ;;
    s) #striped disk volumes
	  OS_STRIPED_DISK=true
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
	echo "HELP!"
}

#Validate Configurations

#Prepare Disk Storage


#A set of disks to ignore from partitioning and formatting
BLACKLIST="/dev/sda|/dev/sdb"

# Base path for data disk mount points
DATA_BASE="/datadisks"

usage() {
    echo "Usage: $(basename $0)"
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
    DISKS=($(scan_for_new_disks))

	if [ "${#DISKS}" -eq 0 ];
	then
	    echo "No unpartitioned disks without filesystems detected"
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

#Format data disks
#------------------------
# Find data disks then partition, format, and mount them as seperate drives
scan_partition_format

#Install Oracle Java
#------------------------
add-apt-repository -y ppa:webupd8team/java
apt-get -y update 
echo debconf shared/accepted-oracle-license-v1-1 select true | sudo debconf-set-selections
echo debconf shared/accepted-oracle-license-v1-1 seen true | sudo debconf-set-selections
apt-get -y install oracle-java7-installer

#
#Install Elasticsearch
#-----------------------
# apt-get install approach
# This has the added benefit that is simplifies upgrades
wget -qO - https://packages.elasticsearch.org/GPG-KEY-elasticsearch | sudo apt-key add -
add-apt-repository "deb http://packages.elasticsearch.org/elasticsearch/1.5/debian stable main"
apt-get update && apt-get install elasticsearch
update-rc.d elasticsearch defaults 95 10

# DPKG Install Approach
# I like the simplicity in this approach
#sudo wget -q https://download.elasticsearch.org/elasticsearch/elasticsearch/elasticsearch-1.5.0.deb -O elasticsearch.deb
#sudo dpkg -i elasticsearch.deb

#
#Configure permissions on data disks for elasticsearch user:group
#--------------------------
mkdir -p /datadisks/disk1/elasticsearch/data /datadisks/disk2/elasticsearch/data
chown -R elasticsearch:elasticsearch /datadisks/disk1/elasticsearch /datadisks/disk2/elasticsearch
chmod 755 /datadisks/disk1/elasticsearch /datadisks/disk2/elasticsearch

#Configure Elasticsearch
#---------------------------
#Set elasticsearch.yml configuration settings
sed -i -e "/cluster\.name/s/^#//g;s/^\(cluster\.name\s*:\s*\).*\$/\1${CLUSTER_NAME}/" /etc/elasticsearch/elasticsearch.yml
sed -i -e "/bootstrap\.mlockall/s/^#//g;s/^\(bootstrap\.mlockall\s*:\s*\).*\$/\1true/" /etc/elasticsearch/elasticsearch.yml

# Configure Environment

#Install Monit
#TODO

#Install Marvel
# bin/plugin -i elasticsearch/marvel/latest

#and... start the service
sudo service elasticsearch start
