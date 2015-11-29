# Doot doot
base:
  '*':
    - foo: bar

  'mavis.db.macapinlac.com':
    - mysql.media

  'hinata1.media.macapinlac.com':
    - apache.newznab
    - newznab.credentials

  'c3p0.infra.macapinlac.com':
    - saltmaster
