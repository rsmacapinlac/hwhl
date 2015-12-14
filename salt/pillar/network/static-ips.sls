static_ips:
{% if grains['virtual'] == 'VirtualBox' %}
  salt.infra.macapinlac.com: 172.28.128.10
  warren.infra.macapinlac.com: 172.28.128.25
{% elif grains['virtual'] == 'kvm' %}
  salt.infra.macapinlac.com: 192.168.1.20
  warren.infra.macapinlac.com: 192.168.1.25
{% endif %}
