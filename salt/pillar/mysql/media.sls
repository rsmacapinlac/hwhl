mysql:
  server:
    root_password: 'somepass'
    mysqld:
      bind-address: 0.0.0.0

  database:
    - newznab

  user:
    nagios:
      password: 'nagios123'
      host: '%'
    newznab:
      password: 'newznab'
      host: '%'
      databases:
        - database: newznab
          grants: ['all privileges']
