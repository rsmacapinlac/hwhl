sensu:
  server:
    install_gems:
      - mail
      - timeout
      - name: aws-sdk
        version: 2.2.6
  client:
    embedded_ruby: true
    nagios_plugins: true
    redact:
      - password
  rabbitmq:
    host: warren
    vhost: /sensu
    user: sensu
    password: pass
  api:
    password: secret

  uchiwa:
    host: warren
    port: 3000
    loglevel: warn
    users:
      - username: bobby
        password: testy
