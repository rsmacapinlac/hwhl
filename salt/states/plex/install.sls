plex_download:
  cmd.run:
    - name: cd /tmp; wget https://downloads.plex.tv/plex-media-server/1.2.6.2975-9394c87/plexmediaserver_1.2.6.2975-9394c87_amd64.deb
    - creates: /tmp/plexmediaserver_1.2.6.2975-9394c87_amd64.deb


plex_install:
  cmd.run:
    - name: dpkg -i /tmp/plexmediaserver_1.2.6.2975-9394c87_amd64.deb
