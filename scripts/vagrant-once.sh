#!/usr/bin/env bash

echo "==> Running vagrant-once.sh <=="
echo ""

### Add swap file

# https://gist.github.com/shovon/9dd8d2d1a556b8bf9c82
# size of swapfile in megabytes
swapsize=8000
# does the swap file already exist?
grep -q "swapfile" /etc/fstab

# if not then create it
if [ $? -ne 0 ]; then
  echo '--> Adding swap: 8G'
  fallocate -l ${swapsize}M /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap defaults 0 0' >> /etc/fstab
fi


### update packages
echo "--> Updating packages (it can take a while)..."
apt-get update
apt-get -y dist-upgrade
apt-get -y autoremove

# install packages that are needed
echo "--> Installing LAMP stack plus some utilities..."
apt-get -y install acl apache2 php5 php-apc php5-mysql php5-curl php5-gd php5-intl git mysql-client links curl unzip

# configure apache2
echo "--> Configuring apache2..."
a2enmod ssl
a2enmod rewrite
a2enmod headers
a2dismod autoindex

# run apache2 as vagrant to avoid permission problems
sed -i 's/www-data/vagrant/' /etc/apache2/envvars

# install composer
if [ ! -f /usr/local/bin/composer ]; then
    echo "--> Installing composer (global)..."
    cd /usr/local/src
    curl -sS https://getcomposer.org/installer | php
    mv composer.phar /usr/local/bin/composer
fi

# install mysql-server if not already installed, and setup root-user
dpkg -l | grep -q mysql-server-5.5
if [ $? == 1 ]; then
    echo "--> Installing mysql-server..."
    # install mysql-server and set root password to 'abc123'
    echo "mysql-server-5.5 mysql-server/root_password password abc123" | debconf-set-selections
    echo "mysql-server-5.5 mysql-server/root_password_again password abc123" | debconf-set-selections
    apt-get -y install mysql-server-5.5
    # allow to connect from host
    echo "grant all privileges on *.* to root@'%' identified by 'abc123';" | mysql -u root -pabc123
    # bind to all addresses
    rm -f /etc/mysql/conf.d/bind_all.cnf
    echo "# this file is autogenerated, do not edit." >> /etc/mysql/conf.d/bind_all.cnf
    echo "[mysqld]" >> /etc/mysql/conf.d/bind_all.cnf
    echo "bind-address = 0.0.0.0" >> /etc/mysql/conf.d/bind_all.cnf
    service mysql restart
fi

# install phpmyadmin if not already installed
dpkg -l | grep -q phpmyadmin
if [ $? == 1 ]; then
    echo "--> Installing phpmyadmin..."
    echo "phpmyadmin phpmyadmin/dbconfig-install boolean true" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/app-password-confirm password abc123" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/admin-pass password abc123" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/mysql/app-pass password abc123" | debconf-set-selections
    echo "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2" | debconf-set-selections
    apt-get -y install phpmyadmin php5-mcrypt
    php5enmod mcrypt
fi

# reload apache2
echo "--> Restart apache2"
service apache2 restart
