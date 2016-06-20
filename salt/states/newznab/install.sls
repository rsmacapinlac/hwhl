apache2:
  pkg.installed

php7.0:
  pkg.installed

php7.0-dev:
  pkg.installed

php7.0-gd:
  pkg.installed

#php-pear:
#  pkg.installed

php7.0-curl:
  pkg.installed

php7.0-mysql:
  pkg.installed

subversion:
  pkg.installed

unrar:
  pkg.installed

lame:
  pkg.installed

screen:
  pkg.installed

tmux:
  pkg.installed

/etc/php/7.0/cli/php.ini:
  file.managed:
    - source: salt://newznab/files/php-cli.ini

/etc/php/7.0/fpm/php.ini:
  file.managed:
    - source: salt://newznab/files/php-apache2.ini

svn://svn.newznab.com/nn/branches/nnplus:
  svn.latest:
    - force: True
    - trust: True
    - target: /var/www/nnplus
    - username: {{  salt['pillar.get']('newznab:svn:username') }}
    - password: {{  salt['pillar.get']('newznab:svn:password') }}
