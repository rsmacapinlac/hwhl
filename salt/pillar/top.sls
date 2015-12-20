# Doot doot
base:

  #'*.local.macapinlac.*':
  #  - network.static-ip

  'shino.db.local.macapinlac.*':
    - mysql.media
    - nagios

  'hinata.media.local.macapinlac.*':
    - apache.newznab
    - newznab.credentials

  'warren.infra.local.macapinlac.*':
    - nagios
    - apache.nagios
