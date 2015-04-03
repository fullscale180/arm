#!/bin/bash

########################################################
# This script will install Redis from sources
########################################################
help()
{
	echo "HELP!"
}

log()
{
    curl -X POST -H "content-type:text/plain" --data-binary "$(date) | $1" https://logs-01.loggly.com/inputs/681451c7-fb5e-409b-a263-b06b29c9560f/tag/redis-extension,${HOSTNAME}
}

log "Begin execution of Redis installation script extension"

if [ "$(whoami)" != "root" ]; then
	log "ERROR: User is not authorized"
	echo "ERROR : You must be root to run this program"
	exit 1
fi

# Parse script parameters
while getopts :n:v:p:h FLAGS; do
  log "Flag ${FLAGS} passed with ${OPTARG}"
  
  case $FLAGS in
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

# installing build essentials if it is missing
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

log "Redis package was downloaded and built successfully"

# create service user and configure autostart
useradd -r -s /bin/false redis
wget -O /etc/init.d/redis-server https://fs180.blob.core.windows.net/public/redis-server-startup.sh
touch /var/run/redis.pid
chown redis:redis /var/run/redis.pid
chmod 755 /etc/init.d/redis-server

log "Redis service was created successfully"

# perform autostart
update-rc.d redis-server defaults

log "Redis service was configured for auto-start"