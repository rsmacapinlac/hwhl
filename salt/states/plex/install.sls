plex_download:
  cmd.run:
    - name: cd /tmp; wget https://downloads.plex.tv/plex-media-server/0.9.15.6.1714-7be11e1/plexmediaserver_0.9.15.6.1714-7be11e1_amd64.deb
    - name: cd /tmp; wget https://downloads.plex.tv/plex-media-server/0.9.16.6.1993-5089475/plexmediaserver_0.9.16.6.1993-5089475_amd64.deb
    - creates: /tmp/plexmediaserver_0.9.16.6.1993-5089475_amd64.deb


plex_install:
  cmd.run:
    - name: dpkg -i /tmp/plexmediaserver_0.9.16.6.1993-5089475_amd64.deb
