refresh_salt_from_repo:
  cron.present:
    - name: cd /srv; git co http://github.com/rsmacapinlac/hwhl hwhl
    - user: root
    - minute: '*/5'
