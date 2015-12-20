mysql:
  server:
    root_password: 'somepass'

  database:
    - newznab

  user:
    newznab:
      password: 'newznab'
      host: '%'
      databases:
        - database: newznab
          grants: ['all privileges']
