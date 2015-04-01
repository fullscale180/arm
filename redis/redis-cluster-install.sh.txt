#!/bin/bash

#########################################
# This script will install redis,
# and download a pre-configured config
#########################################

# Redis Defaults
REDIS_URL="http://redis.googlecode.com/files/redis-2.6.14.tar.gz"
REDIS_TGZ="redis-2.6.14.tar.gz"
REDIS_DIR="redis-2.6.14"

# Download and unpack Nginx
wget -q $REDIS_URL
tar zxf $REDIS_TGZ

# Move into the directory and build
cd $REDIS_DIR
make

# Copy the executables to the /opt/redis directory
cp src/redis-benchmark /usr/local/bin
cp src/redis-cli /usr/local/bin
cp src/redis-server /usr/local/bin
cp src/redis-check-aof /usr/local/bin
cp src/redis-check-dump /usr/local/bin

# Download the pre-defined config
curl -sL http://git.io/pu0alA > /etc/default/redis

# Download the init script, and make executable
curl -sL http://git.io/w4GcUg > /etc/init.d/redis
chmod +x /etc/init.d/redis

# Start redis
/etc/init.d/redis start

