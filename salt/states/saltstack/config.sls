git-core:
  pkg.installed

/etc/salt/master:
  file.managed:
    - source: salt://saltstack/files/master
