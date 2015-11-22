rabbitmq:
  plugin:
    rabbitmq_management:
      - enabled
  policy:
    rabbitmq_policy:
      - name: HA
      - pattern: '.*'
      - definition: '{"ha-mode": "all"}'
  vhost:
    virtual_host:
      - owner: rabbit_user
      - conf: .*
      - write: .*
      - read: .*
  user:
    sensu:
      - password: secret
      - force: True
      - tags: monitoring, user
      - perms:
        - '/sensu':
          - '.*'
          - '.*'
          - '.*'
      - runas: root
{#- vim:ft=sls
-#}
