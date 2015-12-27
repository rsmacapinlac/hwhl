/etc/default/sabnzbdplus:
  file.managed:
    - source: salt://sabnzbd/files/sabnzbdplus

/home/media/.sabnzbd:
  file.directory:
    - makedirs: True
    - user: media
    - recurse:
      - user

/home/media/.sabnzbd/sabnzbd.ini:
  file.managed:
    - source: salt://sabnzbd/files/sabnzbd.ini
    - template: jinja
    - replace: False
    - makedirs: True
    - user: media

sabnzbdplus_service:
  service.running:
    - name: sabnzbdplus
    - enable: True
    - reload: True
