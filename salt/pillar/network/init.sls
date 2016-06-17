network:
  saltmaster: makarov
  domain: macapinlac.com
  hosts:
    makarov:
      role: infra
      ipaddr: 172.28.128.10
    warren:
      role: infra
      ipaddr: 172.28.128.15
    mirajane:
      role: infra
      ipaddr: 172.28.128.20
    shino:
      role: db
      ipaddr: 172.28.128.30
    hinata:
      role: media
      ipaddr: 172.28.128.50
    kiba:
      role: media
      ipaddr: 172.28.128.55
