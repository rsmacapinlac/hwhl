# Happy wife, Happy life (hwhl)

This is my ansible setup for my homelab.

## Pre-reqs

What do you need?
- Your own domain that is configured with Cloudflare.
- A Proxmox server
- A working knowledge of your router's DHCP configuration
- Your public key (scripts assume that it can be found in $HOME/.ssh/id_rsa.pub)

1. Clone the repository

```bash
git clone git@github.com:rsmacapinlac/hwhl.git
```

2. Create a 'files' folder

```bash
cd hwhl
mkdir files
```

3. Start your inventory file

```
touch inventory/proxmox.yml
```

Contents of the file:

```bash
proxmox_control_node_by_ip:
  hosts:
    # this is the IP of your proxmox server
    10.1.0.141:
```

## Build the base of the homelab

### DNS (PiHole) (x3)

You can build more (x4) but 3 will do.

1. Create an LXC in Proxmox

```
storage: 32GB
ip addr: 10.1.0.2 # this assumes that you're on a 10.1.x.x network (where your Router is 10.1.0.1)
Unpriviledged container: No
Features: Nesting=1
# Cloudflare's public DNS
DNS: 1.1.1.1; 1.0.0.1
```

2. Modify the inventory file

Add this content to the end.

```
dns:
  hosts:
    dns0.int.macapinlac.network:
      ansible_host: 10.1.0.2

```

3. Create an environment file for PiHole

```
mkdir files/config/pihole
touch files/config/pihole/environment

# contents:

FTLCONF_webserver_api_password: 'my super secret password' #obviously change this
FTLCONF_dns_listeningMode: 'all'
FTLCONF_dns_upstreams: '1.1.1.1;1.0.0.1'
```
