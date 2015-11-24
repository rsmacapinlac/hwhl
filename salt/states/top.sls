# The top file. Host and group definitions go here. So many wonderous things.

base:
  '*':
    - packages
    - ntp
    - logrotate
    - motd

  '*.media.macapinlac.com':
    - fileserver.media

  'laxus1.media.macapinlac.com':
    - plex.install

  'chewie.infra.macapinlac.com':
    - redis
    - sensu.server
    - sensu.rabbitmq_conf
    - sensu.api
    - sensu.uchiwa
    - sensu.client
    - sensu.plugins
