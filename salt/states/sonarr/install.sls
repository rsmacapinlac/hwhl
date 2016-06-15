mono-devel:
  pkg.installed

/etc/init.d/nzbdrone:
  file.managed:
    - source: salt://sonarr/files/nzbdrone

sonarr:
  pkgrepo.managed:
    - humanname: Sonarr
    - name: deb http://apt.sonarr.tv/ master main
    - file: /etc/apt/sources.list.d/sonarr.list
    - keyid: FDA5DFFC
    - keyserver: keyserver.ubuntu.com
    - require_in:
      - nzbdrone

  pkg.latest:
    - name: nzbdrone
    - refresh: True
