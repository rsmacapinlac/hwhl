# Doot doot
base:

  #'*.local.macapinlac.*':
  #  - network.static-ip

  '*':
    - network

  'shino.db.macapinlac.*':
    - mysql.media
    # - nagios

  'hinata.media.macapinlac.*':
    - mysql.media
    - apache.newznab
    - newznab.credentials

  #'warren.infra.*':
  #  - nagios.server
  #  - apache.nagios
