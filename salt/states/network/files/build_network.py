#!/usr/bin/env python

import salt.client
import salt.runner
import yaml

network_datafile = '/srv/hwhl/salt/pillar/network/init.sls'
network_data = yaml.load(open(network_datafile))

opts = salt.config.master_config('/etc/salt/master')
opts['quiet'] = True

r = salt.runner.RunnerClient(opts)
c = salt.client.LocalClient()
_active_minions = r.cmd("manage.up")

for minion in _active_minions:
  _g = c.cmd(minion, 'grains.items')

  network_data['network']['hosts'][_g[minion]['host']]['ipaddr'] = _g[minion]['ipv4'][1]
  #print network_data['network']['hosts']
  #print minion + ': ' + _g[minion]['ipv4'][1]

_network_data = open(network_datafile, 'w')
_network_data.write(yaml.dump(network_data, default_flow_style=False, allow_unicode=True))
