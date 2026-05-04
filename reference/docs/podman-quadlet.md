# Podman Quadlet — Cheat Sheet for pi-cortex
> Source: https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
> Fetched: 2026-05-04

## File placement

| Location | Use case |
|----------|---------|
| `/etc/containers/systemd/` | System (rootful) — use this for pi-cortex |
| `~/.config/containers/systemd/` | User (rootless) |
| `/run/containers/systemd/` | Temporary testing only |

After placing or modifying files: `sudo systemctl daemon-reload`

Then start: `sudo systemctl start <name>.service`

## Minimal .container file example

```ini
# /etc/containers/systemd/neo4j.container
[Unit]
Description=Neo4j Graph Database
After=network-online.target

[Container]
Image=neo4j:5.20-community
Environment=NEO4J_AUTH=neo4j/CHANGE_ME
Environment=NEO4J_PLUGINS=["apoc","graph-data-science"]
Volume=neo4j-data.volume:/data
Network=pi-cortex-net.network
# NO PublishPort — use nginx proxy instead (netavark DNAT bug on Ubuntu 24.04)

[Service]
Restart=on-failure
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target default.target
```

## [Container] section — key options

### Image=
```ini
# Recommended: use full digest for reproducibility
Image=docker.io/neo4j:5.20-community
# Or tag (less reproducible):
Image=neo4j:5.20-community
```

### Environment= and EnvironmentFile=
```ini
# Inline (one per line, can repeat):
Environment=NEO4J_AUTH=neo4j/secret
Environment=NEO4J_PLUGINS=["apoc"]

# From file (one KEY=VALUE per line):
EnvironmentFile=/home/bzn/.pi/.env
```

### Volume=
```ini
# Named volume (references neo4j-data.volume file → auto-dependency):
Volume=neo4j-data.volume:/data

# Host directory:
Volume=/opt/knowledge-vault:/vault:ro

# Multiple volumes (repeat the key):
Volume=neo4j-data.volume:/data
Volume=/var/backups/neo4j:/backup
```

### Network=
```ini
# Reference a .network file → auto-dependency + "systemd-" prefix added to name:
Network=pi-cortex-net.network

# Use host network:
Network=host

# Multiple networks:
Network=pi-cortex-net.network
Network=host
```

### PublishPort= — AVOID on Ubuntu 24.04
```ini
# DO NOT USE — triggers netavark DNAT bug on Ubuntu 24.04
# PublishPort=7474:7474

# CORRECT APPROACH: bind container port inside, nginx proxies outside
# Use PodmanArgs to bind to 127.0.0.1 only:
PodmanArgs=--network=pi-cortex-net.network:ip=10.89.2.1
```

### User=
```ini
User=1000        # numeric UID
# Or:
User=neo4j
```

### AddDevice=
```ini
# GPU for CUDA containers:
AddDevice=nvidia.com/gpu=all   # CDI device (requires nvidia-ctk cdi generate)
# Optional device (no error if missing on host):
AddDevice=-/dev/dri/card0
```

### Secret=
```ini
# Inject a Podman secret as environment variable:
Secret=webui_secret_key,type=env,target=WEBUI_SECRET_KEY
```

### PodmanArgs=
```ini
# Pass options not covered by Quadlet syntax:
PodmanArgs=--shm-size=256m
PodmanArgs=--cap-add=SYS_PTRACE
```

## .volume file example

```ini
# /etc/containers/systemd/neo4j-data.volume
[Volume]
Driver=local
```

## .network file example

```ini
# /etc/containers/systemd/pi-cortex-net.network
[Network]
Subnet=10.89.2.0/24
Gateway=10.89.2.1
```

## Fixed IP for container on a network

```ini
# In the .container file — use Network= with ip= option:
Network=pi-cortex-net.network:ip=10.89.2.10
```

Note: `PodmanArgs=--ip` fails with multi-network containers. Use the `Network=name:ip=x.x.x.x` syntax.

## Useful debug commands

```bash
# Check generated systemd unit:
/usr/lib/systemd/system-generators/podman-system-generator --dry-run

# View container logs:
sudo podman logs neo4j --tail 50

# Enter container:
sudo podman exec -it neo4j bash

# Check container IPs:
sudo podman inspect neo4j | python3 -c "
import sys,json
d=json.load(sys.stdin)[0]
for net,info in d['NetworkSettings']['Networks'].items():
    print(net, info.get('IPAddress',''))
"

# Restart after config change:
sudo systemctl daemon-reload && sudo systemctl restart neo4j.service
```

## Neo4j specific environment variables

```ini
# Auth (format: user/password):
Environment=NEO4J_AUTH=neo4j/your_password_here

# Plugins (JSON array as string):
Environment=NEO4J_PLUGINS=["apoc","graph-data-science"]

# Memory:
Environment=NEO4J_server_memory_heap_initial__size=512m
Environment=NEO4J_server_memory_heap_max__size=2g
Environment=NEO4J_server_memory_pagecache__size=1g

# Bind to localhost only (REQUIRED — never 0.0.0.0):
Environment=NEO4J_server_default__listen__address=127.0.0.1
Environment=NEO4J_server_bolt_listen__address=127.0.0.1:7687
Environment=NEO4J_server_http_listen__address=127.0.0.1:7474
```
