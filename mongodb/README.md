#MongoDB ARM Template

##Parameters
(include all the standard, location, VNET, etc...)

- Version (Include this?)
- Server Nodes # (Do we remove this and simply do primary/secondary?)
- Server VM Type
- Data Disk Type
- Number of Data Disks (>1 implies Striped? Do we also offer local?)
- Arbiter Nodes # (default to 1 or fixed?)
- Server VM Type
- Server Node Name Prefix
- Arbiter Node Name Prefix
- Replica set Name
- Replica set Key

##Notes:
We need to decide if we deploy this with 2 server nodes primary/secondary and one arbiter or allow for multiple secondaries and arbiters.  It would simplify the ARM template, and the dependencies in the setup. My thought is that we take this approach for v1, then move to a more advanced setup.

### Server Deployment Steps
Download MongoDB
Install MongoDB
Format and mount the data disks
Increase the open files limit for MongoDB
Move the MongoDB data, journal, and log files to the data disk
Update the MongoDB configuration file with the new paths to the files
Store the replica set shared key, if specified, and update the configuration
Set the replica set name in the config

#### Primary Instance
Add all database/arbiter instances to the replica set

### Arbiter Deployment
Download MongoDB
Install MongoDB
Store the replica set shared key
Set the replica set name in the config

