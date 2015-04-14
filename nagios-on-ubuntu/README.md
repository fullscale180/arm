# Install Nagios Core on Ubuntu Virtual Machines using Custom Script Linux Extension

<a href="https://azuredeploy.net/" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>

This template deploys Nagios Core, a host/service/network monitoring solution released under the GNU General Public License. This template also provisions a storage account, virtual network, public IP addresses and network interfaces required by the installation.

Visit the Nagios homepage at http://www.nagios.org for documentation, new releases, bug reports, information on discussion forums, and more.

The template expects the following parameters:

| Name   | Description    |
|:--- |:---|
| storageAccountName  | Unique DNS Name for the storage account where the virtual machine's disks will be placed |
| adminUsername  | Admin user name for the virtual machine  |
| adminPassword  | Admin password for the virtual machine  |
| region | Region name where the corresponding Azure artifacts will be created |
| virtualNetworkName | Name of virtual network |
| vmSize | Size of the virtual machine running Nagios Core |
| subnetName | Name of the virtual network subnet |
| addressPrefix | The IP address mask used by the virtual network |
| subnetPrefix | The subnet mask used by the virtual network subnet |

##Known Issues and Limitations
- A single instance installation Nagios Core is performed by the template
- This template does not install any monitoring targets