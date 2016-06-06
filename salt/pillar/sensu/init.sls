sensu:
  server:
    install_gems:
      - mail
      - timeout
  client:
    embedded_ruby: true
    nagios_plugins: true

  rabbitmq:
    host: warren
    vhost: /sensu
    user: sensu
    password: pass

  api:
    user: sensu
    password: pass

  uchiwa:
    host: warren
    port: 3000
    loglevel: warn
    users:
      - username: admin
        password: password
  sites:
    - name: 'House'
      host: warren
