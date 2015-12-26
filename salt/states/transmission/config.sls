configure_transmission:
  service.dead:
    - name: transmission-daemon
    - enable: True

  #file.managed:
  #  - name: /etc/transmission-daemon/setting.json
  #  - source: salt://transmission/files/settings.transmission.json


restart_transmission:
  service.running:
    - name: transmission-daemon
    - order: last
