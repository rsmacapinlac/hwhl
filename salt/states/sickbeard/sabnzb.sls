/home/media/.sickbeard/autoConfigTV:
  file.directory:
    - makedirs: True
    - user: media
    - group: media

/home/media/.sickbeard/autoConfigTV/autoProcessTV.cfg:
  file.managed:
    - source: salt://sickbeard/files/autoProcessTV/autoProcessTV.cfg
    - user: media
    - group: media

/home/media/.sickbeard/autoConfigTV/autoProcessTV.py:
  file.managed:
    - source: salt://sickbeard/files/autoProcessTV/autoProcessTV.py
    - user: media
    - group: media

/home/media/.sickbeard/autoConfigTV/sabToSickBeard.py:
  file.managed:
    - source: salt://sickbeard/files/autoProcessTV/sabToSickBeard.py
    - user: media
    - group: media
