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

  'laxus1.media.macapinlac.com':
    - plex.install

  'hinata1.media.macapinlac.com':
    - mysql.client
    - sabnzbd.install
    - sabnzbd.config
    - newznab.install

  '*.db.macapinlac.com':
    - mysql.server

  'chewie.infra.macapinlac.com':
    - redis
    - sensu.server
    - sensu.rabbitmq_conf
    - sensu.api
    - sensu.uchiwa
    - sensu.client
    - sensu.plugins
