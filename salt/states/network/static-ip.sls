eth1:
  network.managed:
    - enabled: True
    - type: eth
    - ipaddr: {{ pillar['static_ips'][grains['nodename']] }}
    - netmask: 255.255.255.0
    - dns:
      - 8.8.8.8
      - 8.8.4.4
