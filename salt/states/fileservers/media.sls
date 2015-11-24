cifs-utils:
  pkg.installed

/media/daikichi
  file.directory:
    - mode: 777
    - makedirs: True

  mount.mounted:
    - device: //daikichi/WDTVLiveHub
    - persist: True
    - mkmnt: True
