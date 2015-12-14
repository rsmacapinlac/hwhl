# Doot doot
base:
  '^(\w+).(infra|db|media).macapinlac.com':
    - match: pcre
    - network.static-ips

  'shino.db.macapinlac.*':
    - mysql.media
    - nagios

  'hinata.media.macapinlac.*':
    - apache.newznab
    - newznab.credentials

  'warren.infra.macapinlac.*':
    - nagios
    - apache.nagios
