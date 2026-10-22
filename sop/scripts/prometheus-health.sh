#!/bin/sh
# prometheus-health.sh: down targets and firing alerts on one monitor host.
# Run from ansible/: ansible prometheus -b -m script -a ../sop/scripts/prometheus-health.sh
curl -s "localhost:9090/api/v1/targets?state=active" | python3 -c '
import json, sys
t = json.load(sys.stdin)["data"]["activeTargets"]
down = [x for x in t if x["health"] != "up"]
print("targets: %d up / %d" % (len(t) - len(down), len(t)))
for x in down:
    print("! DOWN %s (%s)" % (x["scrapeUrl"], x.get("lastError", "")))'
curl -s "localhost:9090/api/v1/alerts" | python3 -c '
import json, sys
a = [x for x in json.load(sys.stdin)["data"]["alerts"] if x["state"] == "firing"]
print("firing alerts: %d" % len(a))
for x in a:
    print("! ALERT %s %s" % (x["labels"].get("alertname"), x["labels"].get("instance", "")))'
