cifs-utils:
  pkg.installed

/media/daikichi:
  file.directory:
    - mode: 777
    - makedirs: True

# //daikichi/WDTVLiveHub /media/daikichi cifs  guest,uid=1000,iocharset=utf8  0 0

  mount.mounted:
    - device: //daikichi/WDTVLiveHub
    - fstype: cifs
    - opts: guest,uid=1000
    - persist: True
    - mkmnt: True
