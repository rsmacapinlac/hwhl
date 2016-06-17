configure_transmission:
  service.dead:
    - name: transmission-daemon
    - enable: True

  file.managed:
    - name: /etc/transmission-daemon/settings.json
    - source: salt://transmission/files/settings.transmission.json

/home/media/Downloads:
  file.directory:
    - mode: 777
    - makedirs: True
    - recurse:
      - mode

restart_transmission:
  service.running:
    - name: transmission-daemon
    - order: last
