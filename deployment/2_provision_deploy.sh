#!/bin/bash

# ch 2 - provision server from local machine
# this is script should be run from local machine

set -e

MYSQL_PASSWORD=$1
SSH_KEY=$2

PROJECT_DIR="/var/www/ryantest.xyz/html/site"

mkdir -p $PROJECT_DIR
chown -R ryan:www-data $PROJECT_DIR
cd $PROJECT_DIR

if [ ! -d $PROJECT_DIR"/.git" ]; then
  GIT_SSH_COMMAND="ssh -i ~/.ssh/id_rsa -o IdentitiesOnly=yes" git clone git@github.com:ryegaspar/cicd-test.git .
    cp $PROJECT_DIR"/.env.example" $PROJECT_DIR"/.env"
    sed -i "/DB_PASSWORD/c\DB_PASSWORD=$MYSQL_PASSWORD" $PROJECT_DIR"/.env"
    sed -i '/QUEUE_CONNECTION/c\QUEUE_CONNECTION=database' $PROJECT_DIR"/.env"
fi

# node & npm
rm -f /usr/bin/node
rm -f /usr/bin/npm
rm -f /usr/bin/npx

cd /usr/lib
wget https://nodejs.org/dist/v14.21.3/node-v14.21.3-linux-x64.tar.xz
tar xf node-v14.21.3-linux-x64.tar.xz
rm node-v14.21.3-linux-x64.tar.xz
mv ./node-v14.21.3-linux-x64/bin/node /usr/bin/node
ln -s /usr/lib/node-v14.21.3-linux-x64/lib/node_modules/npm/bin/npm-cli.js /usr/bin/npm
ln -s /usr/lib/node-v14.21.3-linux-x64/lib/node_modules/npm/bin/npx-cli.js /usr/bin/npx

# php 8.2
add-apt-repository ppa:ondrej/php -y
apt update -y
apt install php8.2 php8.2-cli php8.2-common php8.2-dom php8.2-gd php8.2-zip  php8.2-curl php8.2-mysql php8.2-sqlite3 php8.2-mbstring php8.2-fpm -y
# php8.2-bz2 php8.2-xml php8.2-intl
apt install net-tools -y
apt install supervisor -y

# composer
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'e21205b207c3ff031906575712edab6f13eb0b361f2085f1f1237b7126d785e826a450292b6cfd1d64d92e6563bbde02') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
php composer-setup.php
php -r "unlink('composer-setup.php');"
mv composer.phar /usr/bin/composer

# mysql
mysql -uroot -p$MYSQL_PASSWORD < $PROJECT_DIR"/deployment/config/mysql/create_database.sql" || echo "Database already exists"
mysql -uroot -p$MYSQL_PASSWORD < $PROJECT_DIR"/deployment/config/mysql/set_native_password.sql"

# cron tab
echo "* * * * * cd $PROJECT_DIR && php artisan schedule:run >> /dev/null 2>&1" >> cron_tmp
crontab cron_tmp
rm cron_tmp

cp $PROJECT_DIR"/deployment/config/supervisor/logrotate" /etc/logrotate.d/supervisor

# create new user and use it to ssh into server
useradd -G www-data,root -u 1000 -d /home/ryan ryan
mkdir -p /home/ryan/.ssh
touch /home/ryan/.ssh/authorized_keys
chown -R ryan:ryan /home/ryan
chown -R ryan:ryan /var/www/html
chmod 700 /home/ryan/.ssh
chmod 644 /home/ryan/.ssh/authorized_keys

echo "$SSH_KEY" >> /home/ryan/.ssh/authorized_keys

# make sure when you run a command such as sudo with the new user, Linux wont require a password
echo "ryan ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/ryan

php -v
node -v
npm -v

cp $PROJECT_DIR"/deployment/config/supervisor/supervisord.conf"  /etc/supervisor/conf.d/supervisord.conf

supervisorctl update

# restart workers (notice the : at the end. It refers to the process group)
supervisorctl restart workers:

# php-fprm conf
cp $PROJECT_DIR"/deployment/config/php-fpm/www.conf" /etc/php/8.2/fpm/pool.d/www.conf
systemctl restart php8.2-fpm.service