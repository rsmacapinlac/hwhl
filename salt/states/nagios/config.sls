/etc/apache2/sites-available/nagios.conf:
  file.managed:
    - source: salt://nagios/files/nagios.apache.conf
    - user: www-data
    - group: www-data

/etc/nagios3/htpasswd.users:
  file.managed:
    - source: salt://nagios/files/htpasswd.users

/etc/nagios3/conf.d/shino.cfg:
  file.managed:
    - source: salt://nagios/files/shino.db.macapinlac.com.cfg

apache_enabed:
  cmd.run:
    - name: a2ensite nagios
