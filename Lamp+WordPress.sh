#!/bin/bash

 # Bash script to install  Apache + Mysql + PHP in Ubuntu Server 
 # Author: Rakesh (stratagile.com)

# Check if running as root
 if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
 fi

echo -n " Give sitename to create? (y/n): "; read dom

#Reading the site name and create the root path s
if [ "$dom" = "y" ]; then
	echo -n " Type an Domain name: " ; read domTemp

	path=/var/www/$domTemp/www

	a=$(mkdir -v -p  "$path")
 
	cd $path
	install_dir=$(pwd)

else

exit 1

fi


#Creating Random WP Database Credenitals

db_name=wp$(echo $domTemp | sed 's/....$//')

db_user="$db_name`date +%s`" 

db_password=`date |md5sum |cut -c '1-12'` #if you need more complex password use pwgen instead of dat
sleep 1

db_root_password=`date |md5sum |cut -c '1-12'`
sleep 1

#### Install Packages for https and mysql
add-apt-repository universe

apt -y update
apt  install apache2 apache2-utils libexpat1 ssl-cert mysql-server lynx -y

#Starting apache server boot time

systemctl enable apache2
systemctl start apache2


#### Start mysql and set root user and password for update

systemctl enable mysql
systemctl start mysql

if [ -f /root/.my.cnf ]; then
echo "Config Already added"
	sleep 1
else 
	touch /root/.my.cnf
	chmod 640 /root/.my.cnf
	echo "[client]">>/root/.my.cnf
	echo "user=root">>/root/.my.cnf
	echo "password="$db_root_pass>>/root/.my.cnf
fi


# If /root/.my.cnf exists then it won't ask for root password
if [ -f /root/.my.cnf ]; then

    mysql -e "CREATE DATABASE ${db_name} /*\!40100 DEFAULT CHARACTER SET utf8 */;"
    mysql -e "CREATE USER ${db_user}@localhost IDENTIFIED BY '${db_password}';"
    mysql -e "GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
fi

mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$db_root_pass';"
mysql -e "FLUSH PRIVILEGES;"


####Install PHP
#Install required PHP modules for WordPress
sudo apt-get install -y php7.4-mysql php7.4-curl php7.4-gd php7.4-intl php7.4-mbstring php7.4-soap php7.4-xml php7.4-xmlrpc php7.4-zip

sed -i '0,/AllowOverride\ None/! {0,/AllowOverride\ None/ s/AllowOverride\ None/AllowOverride\ All/}' /etc/apache2/apache2.conf #Allow htaccess usage

systemctl restart apache2

####Download and extract latest WordPress Package
if test -f /tmp/latest.tar.gz
then
	echo "WP is already downloaded."
else
	echo "Downloading WordPress"
	cd /tmp/ && wget "http://wordpress.org/latest.tar.gz";
fi

	/bin/tar -C $install_dir -zxf /tmp/latest.tar.gz --strip-components=1
	chown www-data:www-data $install_dir -R

#### Create WP-config and set DB credentials
	/bin/mv $install_dir/wp-config-sample.php $install_dir/wp-config.php

	/bin/sed -i "s/database_name_here/$db_name/g" $install_dir/wp-config.php

	/bin/sed -i "s/username_here/$db_user/g" $install_dir/wp-config.php

	/bin/sed -i "s/password_here/$db_password/g" $install_dir/wp-config.php

cat << EOF >> $install_dir/wp-config.php
define('FS_METHOD', 'direct');
EOF

cat << EOF >> $install_dir/.htaccess
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index.php$ – [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
EOF

chown www-data: $install_dir -R

##### Set WP Salts
grep -A50 'table_prefix' $install_dir/wp-config.php > /tmp/wp-tmp-config
/bin/sed -i '/**#@/,/$p/d' $install_dir/wp-config.php
/usr/bin/lynx --dump -width 200 https://api.wordpress.org/secret-key/1.1/salt/ >> $install_dir/wp-config.php
/bin/cat /tmp/wp-tmp-config >> $install_dir/wp-config.php && rm /tmp/wp-tmp-config -f


######Display generated passwords to log file.
echo "Database Name: " $db_name
echo "Database User: " $db_user
echo "Database Password: " $db_password
echo "Mysql root password: " $db_root_password
