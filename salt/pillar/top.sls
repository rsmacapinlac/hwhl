# Doot doot
base:
  '^(\w+).(infra|db|media).macapinlac.com':
    - match: pcre
    - network.static-ips

  'shino.db.macapinlac.com':
    - mysql.media
    - nagios

  'hinata.media.macapinlac.com':
    - apache.newznab
    - newznab.credentials

  'warren.infra.macapinlac.com':
    - nagios
    - apache.nagios
