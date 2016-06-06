/etc/salt/minion:
  file.managed:
    - source: salt://saltstack/files/minion
    - template: jinja
