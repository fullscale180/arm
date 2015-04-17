# Deploy a multi-server highly available MongoDB installation on Ubuntu and CentOS virtual machines

<a href="https://azuredeploy.net/" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

This template creates a multi-server MongoDB deployment on Ubuntu and CentOS virtual machines, and configures the MongoDB installation for high availability using replication.
The template also provisions storage accounts, virtual network, availability set, network interfaces, VMs, disks and other infrastructure and runtime resources required by the installation.
In addition, the template can create one publicly accessible "jumpbox" VM allowing to ssh into the MongoDB nodes for diagnostics or troubleshooting purposes.

The template expects the following parameters:

| Name   | Description    |
|:--- |:---|
| storageAccountName  | Unique DNS Name for the Storage Account where the Virtual Machine's disks will be placed |
| adminUsername  | Admin user name for the Virtual Machines  |
| adminPassword  | Admin password for the Virtual Machine  |
| region | Region name where the corresponding Azure artifacts will be created |
| virtualNetworkName | Name of Virtual Network |
| subnetName | Name of the Virtual Network subnet |
| addressPrefix | The IP address mask used by the Virtual Network |
| subnetPrefix | The subnet mask used by the Virtual Network subnet |
| mongodbVersion | The version of the MongoDB packages to be deployed |
| jumpbox | The flag allowing to enable or disable provisioning of the jumpbox VM |
| tshirtSize | The t-shirt size of the MongoDB deployment (XSmall, Small, Medium, Large, XLarge, XXLarge) |
| osFamily | The target OS for the virtual machines running MongoDB (Ubuntu or CentOS) |

Topology
--------

The deployment topology is comprised of a predefined (as per t-shirt sizing) number MongoDB nodes running as a replica set, along with the optional
arbiter instance. Replica sets are the preferred replication mechanism in MongoDB in small-to-medium installations. However, in a large deployment 
with more than 50 nodes, a master/slave replication will be enforced by the template. 
Since MongoDB replication operates in the single-master mode, only one primary node can exist and accept write operations at a time.

The following table outlines the deployment topology characteristics for each supported t-shirt size:

| T-Shirt Size | Master/Slave VM Size | CPU Cores | Memory | Arbiter VM Size | # of Replicas | # of Arbiters | Total # of Members
|:--- |:---|:---|:---|:---|:---|:---|:---|
| XSmall | Standard_D1 | 1 | 3.5 GB | Standard_A1 | 1 | 1 | 3 |
| Small | Standard_D1 | 1 | 3.5 GB | Standard_A1 | 2 | 0 | 3 |
| Medium | Standard_D2 | 2 | 7 GB | Standard_A1 | 3 | 1 | 5 |
| Large | Standard_D2 | 2 | 7 GB | Standard_A1 | 7 | 1 | 9 |
| XLarge | Standard_D3 | 4 | 14 GB | Standard_A1 | 15 | 1 | 17 |
| XXLarge | Standard_D3 | 4 | 14 GB | Standard_A1 | 50 | 0 | 51 |

NOTE: A single primary node is provisioned in addition to the number of replicas stated above, thus increasing the total number of member nodes running MongoDB by 1.

##Notes, Known Issues & Limitations
- To access the individual MongoDB nodes, you need to use the publicly accessible jumpbox VM and ssh from it into the individual MongoDB instances
- The minimum architecture of a replica set has 3 members. A typical 3-member replica set can have either 3 members that hold data, or 2 members that hold data and an arbiter
- The deployment script is not yet idempotent and cannot handle updates (although it currently works for initial provisioning only)
- SSH key is not yet implemented and the template currently takes a password for the admin user
- MongoDB version 3.0.0 and above is recommended in order to take advantage of high-scale deployments offered by this template
