cifs-utils:
  pkg.installed

/media/saber:
  file.directory:
    - mode: 777
    - makedirs: True
    - recurse:
      - mode

  mount.mounted:
    - device: //saber/Volume_1
    - fstype: cifs
    - opts: guest,uid=1000
    - persist: True
    - mkmnt: True

/media/daikichi:
  file.directory:
    - mode: 777
    - makedirs: True
    - recurse:
      - mode

  mount.mounted:
    - device: //daikichi/WDTVLiveHub
    - fstype: cifs
    - opts: guest,uid=1000
    - persist: True
    - mkmnt: True
