#!/bin/bash

yum -y install https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm

yum -y install mariadb-server git mvn java httpd php mariadb php-mysqlnd php-pear-MDB2-Driver-mysqli


git clone https://github.com/spring-projects/spring-petclinic.git
cd /opt
git clone https://github.com/taniarascia/pdo.git
cd -

systemctl enable mariadb
systemctl start mariadb

# Configure pdo php application
mysql -u root -e "create database pdo;"
mysql -u root -e "create user 'pdouser'@'%' identified by 'secret123';"
mysql -u root -e "create user 'pdouser'@'localhost' identified by 'secret123';"
mysql -u root -e "grant all on pdo.* to 'pdouser'@'%';"
mysql -u root -e "grant all on pdo.* to 'pdouser'@'localhost';"

cd /opt/pdo
cat >config.php <<_END_
<?php

/**
 * Configuration for database connection
 *
 */

\$host       = "localhost";
\$username   = "pdouser";
\$password   = "secret123";
\$dbname     = "pdo";
\$dsn        = "mysql:host=\$host;dbname=\$dbname";
\$options    = array(
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
              );
_END_

cat >data/init.sql <<_END_

use pdo;

CREATE TABLE users (
	id INT(11) UNSIGNED AUTO_INCREMENT PRIMARY KEY, 
	firstname VARCHAR(30) NOT NULL,
	lastname VARCHAR(30) NOT NULL,
	email VARCHAR(50) NOT NULL,
	age INT(3),
	location VARCHAR(50),
	date TIMESTAMP
);
_END_

php install.php

# Configure PDO for web
cat >/etc/httpd/conf.d/pdo.conf <<_END_
Alias /pdo /opt/pdo/public
DocumentRoot /opt/pdo/public
DirectoryIndex index.html index.htm index.php
<Directory "/opt/pdo/public">
    Options MultiViews SymLinksIfOwnerMatch IncludesNoExec
    Require method GET POST OPTIONS
</Directory>
_END_

systemctl enable httpd
systemctl start httpd
