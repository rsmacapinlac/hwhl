include:
  - sensu

uchiwa:
  pkg.installed:
    - require:
      - pkgrepo: sensu
  file.managed:
    - name: /etc/sensu/uchiwa.json
    - source: salt://sensu/files/uchiwa.json
    - template: jinja
    - mode: 644
    - user: uchiwa
    - group: sensu
    - require:
      - pkg: uchiwa
  service.running:
    - enable: True
    - require:
      - file: /etc/sensu/uchiwa.json
    - watch:
      - file: /etc/sensu/uchiwa.json

