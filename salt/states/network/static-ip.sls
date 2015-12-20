
{% set assigned_ip = salt['pillar.get']('static_ips:dev:ips', '') %}
{% set interface = salt['pillar.get']('static_ips:dev:interface', 'eth0') %}

{{ interface }}:
  network.managed:
    - enabled: True
    - type: eth
    - ipaddr: {{ pillar['static_ips'][grains['id']] }}
    - netmask: 255.255.255.0
    - gateway: 172.28.128.1
    - dns:
      - 8.8.8.8
      - 8.8.4.4

