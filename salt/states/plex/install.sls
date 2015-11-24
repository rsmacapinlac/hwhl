plex_download:
  cmd.run:
    - name: cd /tmp; wget https://downloads.plex.tv/plex-media-server/0.9.12.19.1537-f38ac80/plexmediaserver_0.9.12.19.1537-f38ac80_amd64.deb
    - creates: /tmp/plexmediaserver_0.9.12.19.1537-f38ac80_amd64.deb

plex_install:
  cmd.run:
    - name: dpkg -i /tmp/plexmediaserver_0.9.12.19.1537-f38ac80_amd64.deb

