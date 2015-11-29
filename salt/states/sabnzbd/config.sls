/etc/default/sabnzbdplus:
  file.managed:
    - source: salt://sabnzbd/sabnzbdplus

/home/media/.sabnzbd:
  file.directory:
    - makedirs: True
    - user: media
    - recurse:
      - user

/home/media/.sabnzbd/sabnzbd.ini:
  file.managed:
    - source: salt://sabnzbd/sabnzbd.ini
    - replace: False
    - makedirs: True
    - user: media

sabnzbdplus_service:
  service.running:
    - name: sabnzbdplus
    - enable: True
    - reload: True
