# The top file. Host and group definitions go here. So many wonderous things.

base:
  '*':
    - packages
    - ntp
    - logrotate
    - motd

  '*.media.macapinlac.com':
    - fileservers.media
    - users.media

    # TODO: setup key for the 'media' user

  'laxus1.media.macapinlac.com':
    - plex.install

  'hinata1.media.macapinlac.com':
    - mysql.client
    - sabnzbd.install
    - sabnzbd.config
    - newznab.install
    - newznab.config
    - apache.vhosts.standard
    - apache.modules

    # TODO: auto start the newznab_screen_local.sh
    # TODO: Set password information (for newsgroup) in excluded pillar info
    # TODO: Set username and password configuration for newznab svn server into excluded pillar info

  'mavis.db.macapinlac.com':
    - mysql.database
    - mysql.server
    - mysql.user

  'chewie.infra.macapinlac.com':
    - redis
    - sensu.server
    - sensu.rabbitmq_conf
    - sensu.api
    - sensu.uchiwa
    - sensu.client
    - sensu.plugins
