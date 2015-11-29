apache2:
  pkg.installed

php5:
  pkg.installed

php5-dev:
  pkg.installed

php5-gd:
  pkg.installed

php-pear:
  pkg.installed

php5-curl:
  pkg.installed

php5-mysql:
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

/etc/php5/cli/php.ini:
  file.managed:
    - source: salt://newznab/files/php-cli.ini

/etc/php5/apache2/php.ini:
  file.managed:
    - source: salt://newznab/files/php-apache2.ini

svn://svn.newznab.com/nn/branches/nnplus:
  svn.latest:
    - force: True
    - trust: True
    - target: /var/www/nnplus
    - username: 
    - password: 
