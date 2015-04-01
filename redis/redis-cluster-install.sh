#!/bin/bash

########################################################
# This script will install Redis from sources
########################################################

if [ "$(whoami)" != "root" ]; then
	echo "ERROR : You must be root to run this program"
	exit 1
fi

# Parse script parameters
while getopts :n:v:p:h FLAGS; do
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

help()
{
	echo "HELP!"
}

echo 'Installing redis v.'$VERSION' ... '

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

# create service user and configure autostart
useradd -r -s /bin/false redis
wget -O /etc/init.d/redis-server https://gist.github.com/iJackUA/5336459/raw/4d7e4adfc08899dc7b6fd5d718f885e3863e6652/redis-server-for-init.d-startup
touch /var/run/redis.pid
chown redis:redis /var/run/redis.pid
chmod 755 /etc/init.d/redis-server

# perform autostart
update-rc.d redis-server defaults


