#Some definitions

rsyslog-gnutls:
  pkg:
    - installed

# Do certs
/etc/ssl/rsyslog:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

/etc/ssl/rsyslog/ca.pem:
  file.managed:
    - source: salt://rsyslog/files/ca.pem
    - template: jinja

/etc/ssl/rsyslog/machine-cert.pem:
  file.managed:
    - source: salt://rsyslog/files/machine-cert.pem
    - template: jinja

/etc/ssl/rsyslog/machine-key.pem:
  file.managed:
    - source: salt://rsyslog/files/machine-key.pem
    - template: jinja

{% if salt['grains.get']('id') == salt['pillar.get']('rsyslog:server:name') -%}
/ebs1/logs:
  file.directory:
    - user: root
    - group: root
    - mode: 755
    - makedirs: True
    - recurse:
          - user
          - group
          - mode

/etc/rsyslog.d/50-default.conf:
  file.managed:
    - source: salt://rsyslog/files/50-default.conf
    - template: jinja

{% endif %}

#do config
/etc/rsyslog.conf:
  file.managed:
    - source: salt://rsyslog/files/rsyslog.conf
    - template: jinja

