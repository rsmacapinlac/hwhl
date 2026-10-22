#!/bin/sh
# zigbee-last-seen.sh: read-only count of Zigbee devices seen in the last 24h, from ZHA's zigbee.db.
# Run on the node hosting smarthome. From ansible/: ansible 10.1.0.144 -u root -m script -a ../sop/scripts/zigbee-last-seen.sh
# Picks the newest devices_vN table by number (a text sort puts devices_v9 after devices_v12)
# and lists every device not seen in 24h.
CT=${CT:-226}
pct exec "$CT" -- docker exec homeassistant python3 -c "
import re, sqlite3, time
c = sqlite3.connect('/config/zigbee.db')
names = [r[0] for r in c.execute(\"select name from sqlite_master where type='table'\")]
t = max((n for n in names if re.fullmatch(r'devices_v\d+', n)), key=lambda n: int(n[9:]))
now = time.time()
rows = c.execute(f'select ieee, last_seen from {t}').fetchall()
print('table', t, '| total', len(rows), '| <24h', sum(1 for _, l in rows if l and now - l < 86400))
for ieee, l in sorted(rows, key=lambda r: r[1] or 0):
    if not l or now - l >= 86400:
        print('not seen <24h:', ieee, time.strftime('%Y-%m-%d %H:%M', time.localtime(l)) if l else 'never')"
