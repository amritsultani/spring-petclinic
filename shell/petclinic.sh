#!/bin/bash

if [[ -e /etc/init.d/petclinic ]]
then
	service petclinic stop
fi

echo "Installing necessary software"
yum -y install https://download1.rpmfusion.org/free/el/rpmfusion-free-release-7.noarch.rpm https://download1.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-7.noarch.rpm

yum -y install mariadb-server git mvn java-1.8.0-openjdk mariadb java-1.8.0-openjdk-devel

# Install maven for compiling
wget http://mirror.vorboss.net/apache/maven/maven-3/3.5.2/binaries/apache-maven-3.5.2-bin.tar.gz -O /tmp/maven.tgz
cd /opt
tar xvf /tmp/maven.tgz
mv apache-maven* maven
PATH=$PATH:/opt/maven/bin

echo "Downloading or updating the petclinic code"
cd /opt
#if ! git clone https://github.com/spring-projects/spring-petclinic.git
#then
	#cd spring-petclinic
	#git pull
#fi
# Using local copy as we know it works
cp -r /vagrant/files/spring-petclinic /opt/spring-petclinic

# Build the jar ( This is Jenkins not your AMI )
# Set the DB to mysql
cp /vagrant/files/application* /opt/spring-petclinic/src/main/resources/
cd /opt/spring-petclinic
/opt/maven/bin/mvn package -DskipTests
mkdir /opt/petclinic

cp /opt/spring-petclinic/target/spring-petclinic-*.jar /opt/petclinic/
# Remove the compiled PC so that this is like deploying

echo "Starting the Database server"
systemctl enable mariadb
systemctl start mariadb

# Configure petclinic application
mysql -u root -e "create database petclinic;"
mysql -u root -e "create user 'root'@'%' identified by 'petclinic';"
mysql -u root -e "grant all on petclinic.* to 'root'@'%';"
mysql -u root -e "grant all on petclinic.* to 'root'@'localhost';"

# Set up the DB using the PC scripts
mysql -u root </opt/spring-petclinic/src/main/resources/db/mysql/schema.sql
mysql -u root petclinic </opt/spring-petclinic/src/main/resources/db/mysql/data.sql

# Set root password for MySQL
mysql -u root -e "set password for 'root'@'localhost' = password('petclinic');"
#mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'petclinic';"

rm -rf /opt/spring-petclinic /root/.m2

# Create start/stop script
cat >/etc/init.d/petclinic <<_END_
#!/bin/bash

#description: Petclinic control script
#chkconfig: 2345 99 99

case \$1 in
  'start')
    # The next 2 lines is only required if you want to compile and run
    #cd /opt/spring-petclinic
    #./mvnw spring-boot:run >/var/log/petclinic.stdout 2>/var/log/petclinic.stderr &
    # The next 2 lines are for running PC from a pre-compiled jar
    cd /opt/petclinic
    java -jar /opt/petclinic/spring-petclinic-2.0.0.jar >/var/log/petclinic.stdout 2>/var/log/petclinic.stderr &
    ;;
  'stop')
    kill \$(ps -ef | grep petclinic | grep -v grep | awk '{print \$2}')
    ;;
  'status')
    PID=\$(ps -ef | grep java | grep petclinic | grep -v grep | awk '{print \$2}')
    if [[ -n \$PID ]]
    then
      echo "Petclinic is running with PID \$PID"
    fi
    ;;
  *)
    echo "I do not understand that option"
    ;;
esac
_END_

>/var/log/petclinic.stdout
>/var/log/petclinic.stderr

chmod +x /etc/init.d/petclinic
chkconfig --add petclinic
sleep 2
echo "Starting PetClinic"
service petclinic start

until grep "Started PetClinicApplication in .* seconds" /var/log/petclinic.std* >/dev/null 2>&1
do
	sleep 20
done
echo "System ready"
