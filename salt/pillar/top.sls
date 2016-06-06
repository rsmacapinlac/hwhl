# Doot doot
base:

  #'*.local.macapinlac.*':
  #  - network.static-ip

  '*':
    - network

  'shino.db.local.macapinlac.*':
    - mysql.media
    # - nagios

  'hinata.media.local.macapinlac.*':
    - mysql.media
    - apache.newznab
    - newznab.credentials

  #'warren.infra.*':
  #  - nagios.server
  #  - apache.nagios
