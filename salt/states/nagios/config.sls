/etc/apache2/sites-available/nagios.conf:
  file.managed:
    - source: salt://nagios/files/nagios.apache.conf
    - user: www-data
    - group: www-data

/etc/nagios3/htpasswd.users:
  file.managed:
    - source: salt://nagios/files/htpasswd.users

/etc/nagios3/conf.d/dnsmasq.cfg:
  file.managed:
    - source: salt://nagios/files/mirajane.infra.local.macapinlac.com.cfg

/etc/nagios3/conf.d/saltmaster.cfg:
  file.managed:
    - source: salt://nagios/files/makarov.infra.local.macapinlac.com.cfg

/etc/nagios3/conf.d/mysql.cfg:
  file.managed:
    - source: salt://nagios/files/shino.db.macapinlac.com.cfg

/etc/nagios3/conf.d/hostgroups_nagios2.cfg:
  file.managed:
    - source: salt://nagios/files/hostgroups_nagios2.cfg

/etc/nagios3/conf.d/services_nagios2.cfg:
  file.managed:
    - source: salt://nagios/files/services_nagios2.cfg

apache_enabed:
  cmd.run:
    - name: a2ensite nagios
