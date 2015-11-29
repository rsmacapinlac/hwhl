copy_config:
  cmd.run:
    - name: cp /home/media/.sickbeard/autoProcessTV/autoProcessTV.cfg.sample /home/media/.sickbeard/autoProcessTV/autoProcessTV.cfg
    - creates: /home/media/.sickbeard/autoProcessTV/autoProcessTV.cfg

config_autostart:
  cmd.run:
    - name: cp /home/media/.sickbeard/init.ubuntu /etc/init.d/sickbeard
    - creates: /etc/init.d/sickbeard
    - mode: 755

/etc/default/sickbeard:
  file.managed:
    - source: salt://sickbeard/files/sickbeard.conf

sickbeard:
  service.enabled
