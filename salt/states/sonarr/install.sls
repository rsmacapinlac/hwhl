mono-devel:
  pkg.installed

autostart_sonar:
  file.managed:
    - name: /etc/init/nzbdrone.conf
    - source: salt://sonarr/files/nzbdrone

  cmd.run:
    - name: 'start nzbdrone'


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
