mysql:
  server:
    root_password: 'somepass'
    mysqld:
      bind-address: 172.28.128.20

  database:
    - newznab

  user:
    newznab:
      password: 'newznab'
      host: '%'
      databases:
        - database: newznab
          grants: ['all privileges']
