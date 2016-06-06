rabbitmq:
  policy:
    rabbitmq_policy:
      - name: HA
      - pattern: '.*'
      - definition: '{"ha-mode": "all"}'
  vhost:
    sensu:
      - owner: sensu
      - conf: .*
      - write: .*
      - read: .*
  user:
    sensu:
      - password: pass
      - force: True
      - tags: monitoring, user
      - perms:
        - '/':
          - '.*'
          - '.*'
          - '.*'
      - runas: root
