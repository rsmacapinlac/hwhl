# The top file. Host and group definitions go here. So many wonderous things.

base:
  '*':
    - packages
    - ntp
    - logrotate
    - motd

  '*.media.macapinlac.com':
    - fileservers.media
    - users.media
    # TODO: setup key for the 'media' user

  'laxus1.media.macapinlac.com':
    - plex.install

  # Hinata is from Naruto, she's kinda always in the background.
  'hinata.media.macapinlac.com':
    - mysql.client
    - newznab.install
    - newznab.config
    - sabnzbd.install
    - sabnzbd.config
    - apache.vhosts.standard
    - apache.modules

  # Kiba is from Naruto, he's kinda loud and most people talk to him.
  'kiba.media.macapinlac.com':
    - sickbeard.install
    - sickbeard.config
    - transmission.install
    - transmission.config

  # Shino is from Naurto, he's part of Team 8 and is probably the required
  # foundation to the team
  'shino.db.macapinlac.com':
    - mysql.database
    - mysql.server
    - mysql.user
    - nagios.minion

  # Warren is from FairyTail, he can communicate and get status updates from
  # everyone telepathically.
  'warren.infra.macapinlac.com':
    - nagios.server
    - nagios.config
    - apache.vhosts.standard
    - apache.modules
