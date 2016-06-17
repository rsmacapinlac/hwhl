# hwhl
Happy wife, happy life

This is the start of my home server setup. At least once I figure things out.

To start, you need to create a file with the necessary credentials.

cp salt/pillar/newznab/credentials.sls.example salt/pillar/newznab/credentials.sls
Then edit the credentials.sls file with your #newznab credentials that you've
received by donating.

You also need a newsgroup subscription (with a server url, port, username and
password).

# setup your salt master

1. Make sure that your saltmaster has a static IP (this is needed when you're setting up the minions)
2. Run this: `sh -c "$(wget https://raw.githubusercontent.com/rsmacapinlac/hwhl/master/bootstrap/master.sh -O -)"`

What it will do, it will set the hostname to `makarov.infra.macapinlac.com`.
Then it will install the repository, copy the necessary SaltStack configuration
and then restart the minion / master.

## Setup your minions

1. Make sure that you know your saltmaster's static IP
2. Run this `sh -c "$(wget https://raw.githubusercontent.com/rsmacapinlac/hwhl/master/bootstrap/minion.sh -O -)" hey <shino.db.macapinlac.com> <192.168.1.400>`

Where shino.db.macapinlac.com is the hostname to set the minion to and 192.168.1.400 is the IP address of the saltmaster.
