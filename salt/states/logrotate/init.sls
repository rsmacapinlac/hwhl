/etc/logrotate.conf:
  file.managed:
    - source: salt://logrotate/logrotate.conf
    - user: root
    - group: root
    - mode: 644

