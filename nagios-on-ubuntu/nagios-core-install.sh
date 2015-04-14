#!/bin/bash

# Script parameters and their defaults
ADMIN_USERNAME="nagios"
ADMIN_PASSWORD="Zk8LgLeR4ZimcgipTNzJKUBXVABDpYH63B9bzMbh2uRm8gYwRFPhSz8AvYspz3vs" # Don't worry, this is not the actual password. The real password will be supplied by the ARM template.
CORE_VERSION="4.0.8"
PLUGINS_VERSION="2.0.3"

########################################################
# This script will install and configure Nagios Core
########################################################
help()
{
	echo "This script installs and configures Nagios Core on the Ubuntu virtual machine image"
	echo "Available parameters:"
	echo "-u Admin_User_Name"
}

log()
{
	# If you want to enable this logging add a un-comment the line below and add your account key 
    curl -X POST -H "content-type:text/plain" --data-binary "$(date) | ${HOSTNAME} | $1" https://logs-01.loggly.com/inputs/681451c7-fb5e-409b-a263-b06b29c9560f/tag/redis-extension,${HOSTNAME}
	echo "$1"
}

log "Begin execution of Nagios Core installation script on ${HOSTNAME}"

if [ "${UID}" -ne 0 ];
then
    log "Script executed without root permissions"
    echo "You must be root to run this program." >&2
    exit 3
fi

# Parse script parameters
while getopts :u:p:h optname; do
  log "Option $optname set with value ${OPTARG}"
  
  case $optname in
	u) # Admin user name
		#ADMIN_USERNAME=${OPTARG}
		;;
	p) # Admin user name
		ADMIN_PASSWORD=${OPTARG}
		;;		
    h)  # Helpful hints
		help
		exit 2
		;;
    \?) # Unrecognised option - show help
		echo -e \\n"Option -${BOLD}$OPTARG${NORM} not allowed."
		help
		exit 2
		;;
  esac
done

# Install essentials
apt-get -y update

#  Install Apache (a pre-requisite for Nagios)
apt-get -y install apache2

# Install MySQL (a pre-requisite for Nagios)
export DEBIAN_FRONTEND=noninteractive
apt-get -q -y install mysql-server mysql-client
mysqladmin -u root password $ADMIN_PASSWORD

# Install PHP (a pre-requisite for Nagios)
apt-get -y install php5 php5-mysql libapache2-mod-php5

# Install LAMP prerequisites
apt-get -y install build-essential libgd2-xpm-dev apache2-utils

# Restart apache2 service
service apache2 restart

# Create a new nagios user account and give it a password
useradd -m $ADMIN_USERNAME
echo '${ADMIN_USERNAME}:${ADMIN_USERNAME}' | chpasswd

# Create a new nagcmd group for allowing external commands to be submitted through the web interface. Add both the nagios user and the apache user to the group.
groupadd nagcmd
usermod -a -G nagcmd $ADMIN_USERNAME
usermod -a -G nagcmd www-data

# Download Nagios and plugins
wget http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-$CORE_VERSION.tar.gz
wget http://nagios-plugins.org/download/nagios-plugins-$PLUGINS_VERSION.tar.gz

# Install Nagios and plugins
tar xzf nagios-$CORE_VERSION.tar.gz
cd nagios-$CORE_VERSION
./configure --with-command-group=nagcmd

# Compile and install nagios modules
make all
make install
make install-init
make install-config
make install-commandmode

# Install Nagios Web interface
/usr/bin/install -c -m 644 sample-config/httpd.conf /etc/apache2/sites-enabled/nagios.conf

# Create a nagios admin account for logging into the Nagios web interface.
htpasswd -c /usr/local/nagios/etc/htpasswd.users $ADMIN_USERNAME #ASKS FOR PWD!

# Install Nagios plugins
tar xzf nagios-plugins-$PLUGINS_VERSION.tar.gz
cd nagios-plugins-$PLUGINS_VERSION
./configure --with-nagios-user=nagios --with-nagios-group=nagios
make
make install

# Enable Apache’s rewrite and cgi modules
a2enmod rewrite
a2enmod cgi
service apache2 restart

# Check nagios.conf file for any syntax errors
/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg

# Start nagios service and make it to start automatically on every boot
service nagios start
ln -s /etc/init.d/nagios /etc/rcS.d/S99nagios

log "Nagios Core was installed successfully"
