include:
  - sensu

/etc/sensu/conf.d/api.json:
  file.managed:
    - source: salt://sensu/files/api.json
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: sensu

sensu-api:
  service.running:
    - enable: True
    - require:
      - file: /etc/sensu/conf.d/api.json
    - watch:
      - file: /etc/sensu/conf.d/api.json
