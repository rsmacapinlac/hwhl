# The top file. Host and group definitions go here. So many wonderous things.

base:
  '*':
    - packages
    - ntp
    - logrotate
    - motd

  '^(\w+).(infra|db|media).macapinlac.*':
    - match: pcre
    - nagios.minion

  '^(\w+).(infra|db|media).macapinlac.com':
    - match: pcre
    - network.static-ip

  '*.media.macapinlac.*':
    - fileservers.media
    - users.media
    # TODO: setup key for the 'media' user

  # This is the self configuration of the saltmaster
  'salt.infra.macapinlac.*':
    - saltstack.config

  'laxus1.media.macapinlac.*':
    - plex.install

  # Hinata is from Naruto, she's kinda always in the background.
  'hinata.media.macapinlac.*':
    - mysql.client
    - newznab.install
    - newznab.config
    - sabnzbd.install
    - sabnzbd.config
    - apache.vhosts.standard
    - apache.modules

  # Kiba is from Naruto, he's kinda loud and most people talk to him.
  'kiba.media.macapinlac.*':
    - sickbeard.install
    - sickbeard.config
    - transmission.install
    - transmission.config

  # Shino is from Naurto, he's part of Team 8 and is probably the required
  # foundation to the team
  'shino.db.macapinlac.*':
    - mysql.database
    - mysql.server
    - mysql.user

  # Warren is from FairyTail, he can communicate and get status updates from
  # everyone telepathically.
  'warren.infra.macapinlac.*':
    - nagios.server
    - nagios.config
    - apache.vhosts.standard
    - apache.modules
