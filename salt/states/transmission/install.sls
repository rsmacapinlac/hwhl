transmission-ppa:
  pkgrepo.managed:
    - ppa: transmissionbt/ppa

transmission_install:
  pkg.installed:
    - pkgs:
      - transmission-cli
      - transmission-common
      - transmission-daemon
