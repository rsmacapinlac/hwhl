/etc/update-motd.d/00-header:
  file.managed:
    - source: salt://motd/00-header
    - user: root
    - group: root
    - mode: 755

/etc/update-motd.d/10-help-text:
  file.managed:
    - source: salt://motd/10-help-text
    - user: root
    - group: root
    - mode: 755

/etc/motd:
  file.managed:
    - source: salt://motd/motd
    - user: root
    - group: root
    - mode: 644

/etc/update-motd.d/51-cloudguest:
  file.absent:
    - name: /etc/update-motd.d/51-cloudguest
