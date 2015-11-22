fail2ban:
  pkg: 
    - installed
  service:
    - running


/etc/fail2ban/jail.conf:
  file.managed:
    - source: salt://fail2ban/jail.conf
    - user: root
    - group: root
    - mode: 644
{% for user, ip in pillar.get('ips', {}).items() %}
  file.blockreplace:
    - marker_start: "# START managed fail2ban -DO-NOT-EDIT-"
    - marker_end: "# END managed fail2ban --"
    - content: "ignoreip = 127.0.0.1/8 {{ip}}/32"
{% endfor %}
