apache2:
  pkg.installed

php5-repo:
  pkgrepo.managed:
    - ppa: wolfnet/logstash

# libapache2-mod-php:
#  pkg.installed

php5.6:
  pkg.installed

#php5.6-fpm:
#  pkg.installed

php5.6-dev:
  pkg.installed

php5.6-gd:
  pkg.installed

php-pear:
  pkg.installed

php5.6-curl:
  pkg.installed

php5.6-mysql:
  pkg.installed

subversion:
  pkg.installed

unrar:
  pkg.installed

lame:
  pkg.installed

screen:
  pkg.installed

/etc/php/5.6/cli/php.ini:
  file.managed:
    - source: salt://newznab/files/php-cli.ini

/etc/php/5.6/fpm/php.ini:
  file.managed:
    - source: salt://newznab/files/php-apache2.ini

svn://svn.newznab.com/nn/branches/nnplus:
  svn.latest:
    - force: True
    - trust: True
    - target: /var/www/nnplus
    - username: {{  salt['pillar.get']('newznab:svn:username') }}
    - password: {{  salt['pillar.get']('newznab:svn:password') }}
