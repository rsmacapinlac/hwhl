# svn://svn.newznab.com/nn/branches/nnplus
#  php5-dev php-pear php5-gd php5-mysql php5-curl

apache2:
  pkg.installed

php5:
  pkg.installed

php-dev:
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

svn://svn.newznab.com/nn/branches/nnplus:
  svn.latest:
    - target: /var/www/nnplus
# go donate to get the username and password
#    - username:
#    - password:
