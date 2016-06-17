{% set domain_name = pillar['network']['domain'] %}
{% set hosts = pillar['network']['hosts'] %}

/etc/hosts:
    file.managed:
        - contents: |
            127.0.0.1 localhost
            ::1 localhost

            {% raw %}
            {% endraw %}

            {%- for hostname, netcfg in hosts.items() -%}
            {{ netcfg['ipaddr'] }}  {{ hostname }}.{{ netcfg['role'] }}.{{ domain_name }} {{ hostname }}

            {% endfor %}


python /srv/hwhl/salt/states/network/files/build_network.py:
  cron.present:
    - user: root
    - minute: '*/1'
