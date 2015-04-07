#!/bin/bash

########################################################
# This script will install Redis from sources
########################################################
help()
{
	echo "This script installs a Redis cluster on the Ubuntu virtual machine image"
	echo "Available parameters:"
	echo "-n Cluster_Name"
	echo "-v Redis_Version_Number"
}

log()
{
	# If you want to enable this logging add a un-comment the line below and add your account key 
    curl -X POST -H "content-type:text/plain" --data-binary "$(date) | ${HOSTNAME} | $1" https://logs-01.loggly.com/inputs/681451c7-fb5e-409b-a263-b06b29c9560f/tag/redis-extension,${HOSTNAME}
	echo "$1"
}

log "Begin execution of Redis installation script extension on ${HOSTNAME}"

if [ "${UID}" -ne 0 ];
then
    log "Script executed without root permissions"
    echo "You must be root to run this program." >&2
    exit 3
fi

# Parse script parameters
while getopts :n:v:p:h optname; do
  log "Option $optname set with value ${OPTARG}"
  
  case $optname in
    n)  # Cluster name
      CLUSTER_NAME=${OPTARG}
      ;;
    v)  # Version to be installed
      VERSION=${OPTARG}
      ;;
    p)  # Persistence option
      ENABLE_PERSISTENCE=true
      ;;
    h)  # Helpful hints
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

log "Installing Redis v${VERSION}... "

# Installing build essentials (if missing)
apt-get install build-essential

wget http://download.redis.io/releases/redis-$VERSION.tar.gz
tar xzf redis-$VERSION.tar.gz
cd redis-$VERSION
make
make install prefix=/usr/local/bin/
cp redis.conf /etc/redis.conf
cd ..
rm redis-$VERSION -R
rm redis-$VERSION.tar.gz

log "Redis package v${VERSION} was downloaded and built locally"

# Configure the general settings
sed -i "s/^daemonize no$/daemonize yes/g" /etc/redis/redis.conf
sed -i 's/^logfile ""/logfile \/var\/log\/redis.log/g' /etc/redis/redis.conf
sed -i "s/^loglevel verbose$/loglevel notice/g" /etc/redis/redis.conf
sed -i "s/^dir \.\//dir \/var\/lib\/redis\//g" /etc/redis/redis.conf 

# Enable the AOF persistence
sed -i "s/^appendonly no$/appendonly yes/g" /etc/redis/redis.conf

# Tune the RDB persistence
sed -i "s/^save.*$/# save/g" /etc/redis/redis.conf
echo "save 3600 1" >> /etc/redis/redis.conf

# Add cluster configuration (expected to be commented out in the default configuration file)
echo "cluster-enabled yes" >> /etc/redis/redis.conf
echo "cluster-node-timeout 5000" >> /etc/redis/redis.conf
echo "cluster-config-file ${CLUSTER_NAME}.conf" >> /etc/redis/redis.conf

log "Redis cluster configuration was applied successfully"

# Create service user and configure for auto-start
useradd -r -s /bin/false redis
cp redis-server-startup.sh /etc/init.d/redis-server
touch /var/run/redis.pid
chown redis:redis /var/run/redis.pid
chmod 755 /etc/init.d/redis-server

log "Redis service was created successfully"

# Perform auto-start
update-rc.d redis-server defaults

log "Redis service was configured for auto-start"