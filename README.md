[DockerHub](https://hub.docker.com/r/jackavery/ansible-tf2network-relay)

# ansible-tf2network-relay

Relay bot for use with [ansible-tf2network](https://github.com/jack-avery/ansible-tf2network).

This only facilitates Discord to TF2 message relaying and the `/rcon` command,
and is usually paired with a plugin for relaying from the server.

## Setup

The bot expects two environment variables:
1. `DISCORD_TOKEN` - Your Discord bot token from your [developer portal](https://discord.com/developers/applications)
2. `RCON_USERS` - Colon-delimited list of Discord user IDs to grant `rcon` access to

The bot also expects a `manifest.yml` defining the servers.
This is usually generated using your Ansible variables and [this Python script](https://github.com/jack-avery/ansible-tf2network/blob/main/manifest.py),
but here is a sample:
```yml
hosts:
- hostname: "My Team Fortress 2 Server"
  internal_name: my_unique_internal_id # id for use with the /rcon command
  ip: tf2.mytf2server.com:27015
  rcon_pass: p4$$w0rd
  relay_channel: 1238569871910895626 # messages to this channel will be relayed in-game
  stv_enabled: false
- # ... other servers...
```

A sample `docker-compose.yml`:
```yml
version: '3'

services:
  my-relay:
    image: "jackavery/ansible-tf2network-relay:latest"
    env:
      DISCORD_TOKEN: "mydiscordtoken"
      RCON_USERS: "97441955893477376:1178147836081217627"
    volumes:
      - /path/to/your/manifest.yml:/manifest.yml
```
