include:
  - sensu

/etc/sensu/conf.d/rabbitmq.json:
  file.managed:
    - source: salt://sensu/files/rabbitmq.json
    - template: jinja
    - user: root
    - group: root
    - mode: 644

{%- if salt['pillar.get']('sensu:ssl:enable', true) %}
/etc/sensu/ssl:
  file.directory:
    - user: sensu
    - group: sensu
    - require:
      - pkg: sensu

/etc/sensu/ssl/key.pem:
  file.managed:
    - contents_pillar: sensu:ssl:key_pem
    - require:
      - file: /etc/sensu/ssl

/etc/sensu/ssl/cert.pem:
  file.managed:
    - contents_pillar: sensu:ssl:cert_pem
    - require:
      - file: /etc/sensu/ssl
{%- endif %}
