#!/bin/bash

# 1 - simple deploy script
# chown does not work, may need to run as root

set -e

MYSQL_PASSWORD=$1

PROJECT_DIR="/var/www/ryantest.xyz/html/site"

mkdir -p $PROJECT_DIR

cd $PROJECT_DIR

git config --global --add safe.directory $PROJECT_DIR

# the project has not been cloned yet (first deploy)
if [ ! -d $PROJECT_DIR"/.git" ]; then
  GIT_SSH_COMMAND="ssh -i ~/.ssh/id_rsa -o IdentitiesOnly=yes" git clone git@github.com:ryegaspar/cicd-test.git .
else
  GIT_SSH_COMMAND="ssh -i ~/.ssh/id_rsa -o IdentitiesOnly=yes" git pull
fi

# install dependencies
npm install
npm run build
composer install --no-interaction --no-dev --prefer-dist --optimize-autoloader

# initialize .env if does not exist (first deploy)
if [ ! -f $PROJECT_DIR"/.env" ]; then
  cp .env.example .env
#  sed -i "/DB_PASSWORD/c\DB_PASSWORD=$MYSQL_PASSWORD" $PROJECT_DIR"/.env"
  sed -i '/QUEUE_CONNECTION/c\QUEUE_CONNECTION=database' $PROJECT_DIR"/.env"
  php artisan key:generate
fi

#chown -R www-data:www-data $PROJECT_DIR"/storage"
#chown -R www-data:www-data $PROJECT_DIR"/bootstrap/cache"

php artisan storage:link
php artisan optimize:clear

php artisan down

php artisan migrate --force
php artisan config:cache
php artisan route:cache
php artisan view:cache

php artisan up

# sudo cp $PROJECT_DIR"/deployment/config/nginx.conf" /etc/nginx/sites-available/ryantest.xyz

# sudo nginx -t
# sudo systemctl reload nginx
