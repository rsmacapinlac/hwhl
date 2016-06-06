# The top file. Host and group definitions go here. So many wonderous things.

base:
  '*':
    - packages
    - ntp
    - logrotate
    - motd
    - network.hosts
    - sensu.client

  #'^(\w+).(infra|db|media).*':
  #  - match: pcre
  #  - nagios.minion

  #'^(\w+).(infra|db|media).*':
  #  - match: pcre

  '*.media.*':
    - fileservers.media
    - users.media
    # TODO: setup key for the 'media' user

  # This is the self configuration of the saltmaster
  'makarov.infra.*':
    - saltstack.master
    - saltstack.minion
    - saltstack.cron_refresh

  # Warren is from FairyTail, he can communicate and get status updates from
  # everyone telepathically. (nagios)
  'warren.infra.*':
    - sensu
    - sensu.server
    - sensu.api
    - sensu.uchiwa
    - redis.server
    - rabbitmq
    - rabbitmq.config

  'laxus.media.*':
    - plex.install

  # Hinata is from Naruto, she's kinda always in the background.
  'hinata.media.*':
    - mysql.client
    - newznab.install
    - newznab.config
    - sabnzbd.install
    - sabnzbd.config
    - sickbeard.sabnzb
    - apache.vhosts.standard
    - apache.modules

  # Kiba is from Naruto, he's kinda loud and most people talk to him.
  'kiba.media.*':
    - sickbeard.install
    - sickbeard.config
    - transmission.install
    - transmission.config

  # Shino is from Naurto, he's part of Team 8 and is probably the required
  # foundation to the team
  'shino.db.*':
    - mysql
    - mysql.database
    - mysql.server
    - mysql.user
