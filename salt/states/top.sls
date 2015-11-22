# The top file. Host and group definitions go here. So many wonderous things.

base:
  '*':
    - packages

  '*.macapinlac.com':
    - ntp
    - logrotate
    - motd

  'chewie.infra.macapinlac.com':
    - redis
    - sensu.server
    - sensu.rabbitmq_conf
    - sensu.api
    - sensu.uchiwa
    - sensu.client
    - sensu.plugins
