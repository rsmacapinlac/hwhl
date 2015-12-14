eth0:
  network.managed:
    - enabled: True
    - type: eth
    - ipaddr: {{ pillar['static_ips'][grains['id']] }}
    - netmask: 255.255.255.0
    - gateway: 192.168.1.1
    - dns:
      - 8.8.8.8
      - 8.8.4.4
