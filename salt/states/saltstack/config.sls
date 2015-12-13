git-core:
  pkg.installed

/etc/salt/master:
  file.managed:
    - source: salt://saltstack/files/master

/etc/salt/autosign.conf:
  file.managed:
    - source: salt://saltstack/files/autosign.conf

/etc/salt/autoreject.conf:
  file.managed:
    - source: salt://saltstack/files/autoreject.conf

salt-master:
  service.running:
    - enable: True
    - reload: True
