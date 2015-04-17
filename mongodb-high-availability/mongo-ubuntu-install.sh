#!/bin/bash

#--------------------------------------------------------------------------------------------------
# MongoDB Template for Azure Resource Manager (brought to you by Full Scale 180 Inc)
#
# This script installs MongoDB on each Azure virtual machine. The script will be supplied with
# runtime parameters declared from within the corresponding ARM template.
#--------------------------------------------------------------------------------------------------

#Parameters we need to take on the command line
MONGO_VERSION="3.0.2"
IS_PRIMARY=true
IS_ARBITER=false
DATA_PATH=/datadisks/disk1
REPLICASET_NAME="test1"
REPLICASET_KEY="/etc/mongo-replicaset-key"
MONGO_PORT=27017
MONGO_USERNAME="test"
MONGO_PASSWORD="Blue-2010"
REPLICASET_KEY_DATA="ThxC0t8R30l/ECnH4tvFluK5Ec6GGo5FTehTEBu+AH61cUWneAWR0VDAuKVoic5g
9CUeTvwK6yBxSNEiT0HWkhIwr+RcRRlQXQdkE2DXuLbMmoHS6gJTJZk963QBnYsl
SbMyflCW03AnhmhPQvFlh2AxvT27dE4g7zK/jk2wPvBzsfMlphS0W/+y5OR3vVS3
/5Or9Pf5cGH65gRS+6kFelP3UiL/Jmbr+ALrupPo/Y6P1GREvgHi8jNzmbBebk37
y34fmM/rZIRQnG0VwRkXvslnD8gSrTEm45v7qf0RDoHqIasIdznZcrS31k0JLdd/
OgAHnqTxeBBKL5W2ATjBlAF3clk3s2Odbbb43RZ+NM7HFJy3GskBg+5ca4g4yI1r
a2on50d9VVC+iY/yJLZ5CeHZt/JdWKqILIiTjw/0wM9qhSaUqCbmiwlE5woS0i0r
34kHtE1lsbbXIMUJCWUNg3gM6wdywTn3Px1ii3+1N54kTAnwzak3hkFSMyACkEZE
4Bbm9grZWlAfvJr6iGISuwHncNEJrIGKGjv+jM5NQwLiQvvhbwF/KFBU6IAZ9k8Z
gDYP/qWYZcL/yjmDe4VIwYzSrAZ1kJuidgNRPezkdFL5b2VQhhDU+CY4HqNFfH6q
Aigyqj1T/N/AONQOyP1psn32a+lPDgKTiIMutcC5an8XuEAI5+N9PLk7wekeBegQ
dEx5WlJiJR85D/KA+9D/Nlk/TckT2Img2n+r5urwWXP3eDYFEX4/aiIwHSPMYrlG
J0wH642QcIH+mzVJ72JiPWeoBG+02qY5tXkhMY7bKUhdqbTp1k99ImShmGr85PiC
ibYRRoehqpyfizodeaHckqKigp4wXtgMs4mBoSgrvabqN4sh7gw5ag/nzsoi7kFW
V3PVR9uQJFmTsWtD4QQZ/2bDYtZCf/5SZoncVInOmgTa3Upf/V0jp1vI1xFeTCmx
+FUYLxe4c7WsQMGvgKkBD+5cYqu4"

# Configure mongodb.list file with the correct location
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
echo "deb http://repo.mongodb.org/apt/ubuntu "$(lsb_release -sc)"/mongodb-org/3.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.0.list

# Install updates
sudo apt-get -y update

#Install Mongo DB
sudo apt-get install -y mongodb-org=3.0.2 mongodb-org-server=3.0.2 mongodb-org-shell=3.0.2 mongodb-org-tools=3.0.2

#Ping a specific version as we want to control this to ensure it's consistent across nodes
#echo "mongodb-org hold" | sudo dpkg --set-selections
#echo "mongodb-org-server hold" | sudo dpkg --set-selections
#echo "mongodb-org-shell hold" | sudo dpkg --set-selections
#echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
#echo "mongodb-org-tools hold" | sudo dpkg --set-selections

sudo mkdir "$DATA_PATH/log"
sudo mkdir "$DATA_PATH/db"
sudo chown -R mongodb:mongodb "$DATA_PATH"

#TODO: This seems to be necessary figure out if we can remove it
sudo mkdir /var/run/mongodb
sudo touch /var/run/mongodb/mongod.pid
sudo chmod 777 /var/run/mongodb/mongod.pid 


#Replicaset key
echo "$REPLICASET_KEY_DATA" | sudo tee "$REPLICASET_KEY" > /dev/null
sudo chown -R mongodb:mongodb "$REPLICASET_KEY"
sudo chmod 600 "$REPLICASET_KEY"

#===Configure Mongo
# NOTE: Disable journal on the arbiter
echo "Configure Mongo"
sudo tee /etc/mongod.conf > /dev/null <<EOF
systemLog:
    destination: file
    path: "/var/log/mongodb/mongod.log"
    quiet: true
    logAppend: true
processManagement:
    fork: true
    pidFilePath: "/var/run/mongodb/mongod.pid"
net:
    port: $MONGO_PORT
security:
    keyFile: "$REPLICASET_KEY"
    authorization: "enabled"
storage:
    dbPath: "$DATA_PATH/db"
    directoryPerDB: true
    journal:
        enabled: true
replication:
    replSetName: "$REPLICASET_NAME"
EOF

#Start MongoDB
sudo service mongod start


# Initialize replicaset


