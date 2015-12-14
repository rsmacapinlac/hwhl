# Doot doot
base:
  '^(\w+).(infra|db|media).local.macapinlac.com':
    - match: pcre
    - network.static-ips

  'shino.db.local.macapinlac.*':
    - mysql.media
    - nagios

  'hinata.media.local.macapinlac.*':
    - apache.newznab
    - newznab.credentials

  'warren.infra.local.macapinlac.*':
    - nagios
    - apache.nagios
