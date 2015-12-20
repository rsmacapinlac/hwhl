# The top file. Host and group definitions go here. So many wonderous things.

base:
  '*':
    - packages
    - ntp
    - logrotate
    - motd

  '*.local.macapinlac.*':
    - nagios.minion
  #  - network.static-ip

  '^(\w+).(infra|db|media).local.macapinlac.*':
    - match: pcre
    - nagios.minion

  '^(\w+).(infra|db|media).local.macapinlac.com':
    - match: pcre

  '*.media.local.macapinlac.*':
    - fileservers.media
    - users.media
    # TODO: setup key for the 'media' user

  # This is the self configuration of the saltmaster
  'makarov.infra.local.macapinlac.*':
    - saltstack.config

  # this is to setup a cron refresh from the repository
  'makarov.infra.local.macapinlac.com':
    - saltstack.cron_refresh

  'naruto.media.local.macapinlac.*':
    - plex.install

  # Hinata is from Naruto, she's kinda always in the background.
  'hinata.media.local.macapinlac.*':
    - mysql.client
    - newznab.install
    - newznab.config
    - sabnzbd.install
    - sabnzbd.config
    - apache.vhosts.standard
    - apache.modules

  # Kiba is from Naruto, he's kinda loud and most people talk to him.
  'kiba.media.local.macapinlac.*':
    - sickbeard.install
    - sickbeard.config
    - transmission.install
    - transmission.config

  # Shino is from Naurto, he's part of Team 8 and is probably the required
  # foundation to the team
  'shino.db.local.macapinlac.*':
    - mysql
    - mysql.database
    - mysql.server
    - mysql.user

  'mirajane.infra.local.macapinlac.*':
    - dnsmasq

  # Warren is from FairyTail, he can communicate and get status updates from
  # everyone telepathically.
  'warren.infra.local.macapinlac.*':
    - nagios.server
    - nagios.config
    - apache.vhosts.standard
    - apache.modules
