# Doot doot
base:
  '*':
    - foo: bar

  '*.nucleoid.com':
    - rsyslog

  '*.(uat|staging|prod).nucleoid.com':
    - ruby-stage

  'salt.(dev|uat|staging|prod).nucleoid.com':
    - jenkins

  'c3p0.infra.nucleoid.com':
    - saltmaster

  'chewie.infra.nucleoid.com':
    - sensu
    - rabbitmq
    - redis

