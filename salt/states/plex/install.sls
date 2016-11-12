plex_download:
  cmd.run:
    - name: cd /tmp; wget https://downloads.plex.tv/plex-media-server/1.2.7.2987-1bef33a/plexmediaserver_1.2.7.2987-1bef33a_amd64.deb
    - creates: /tmp/plexmediaserver_1.2.7.2987-1bef33a_amd64.deb


plex_install:
  cmd.run:
    - name: dpkg -i /tmp/plexmediaserver_1.2.7.2987-1bef33a_amd64.deb
