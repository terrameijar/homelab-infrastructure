# Reverse SSH Tunnel

Some services require a reverse SSH tunnel to expose themselves to the Internet when running in a private Kubernetes cluster.

To run the SSH tunnel, set the following environment variables on the server:

1. `SSH_TUNNEL_USER` -- The user account that the systemd service will be run as
1. `SSH_LOCAL_HOST` -- hostname or IP address of local server or ingress resource
1. `SSH_LOCAL_PORT` -- local port to forward the reverse SSH tunnel to
1. `SSH_KEY_PATH` -- Path to the SSH key required to authenticate to the remote host
1. `SSH_REMOTE_HOST` -- Hostname/IP of the remote host
1. `SSH_REMOTE_USER` -- Username on the remote host

## Create the service file

```ini
[Unit]
Description= Service to maintain an SSH reverse tunnel
Wants=network-online.target
After=network-online.target
StartLimitIntervalSec=0

[Service]
User=${SSH_TUNNEL_USER}
Type=simple
ExecStart=/usr/bin/ssh -qNn \
	-o ServerAliveInterval=30 \
	-o ServerAliveCountMax=3 \
	-o ExitOnForwardFailure=yes \
	-o StrictHostKeyChecking=yes \
	-i ${SSH_KEY_PATH} \
	-R {SSH_LOCAL_PORT}:${SSH_LOCAL_HOST}:80 \
	${SSH_REMOTE_USER}@${SSH_REMOTE_HOST} 2>&1 | logger -t ssh-tunnel
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

## Validate the unit file

```shell
sudo systemd-analyze verify reverse-ssh-tunnel.service
```

Next, copy the `reverse-ssh-tunnel.service` file to the systemd directory

```shell
sudo cp reverse-ssh-tunnel.service /etc/systemd/system
```

Reload systemd and enable the tunnel service

```shell
sudo systemctl daemon-reload
sudo systemctl enable reverse-ssh-tunnel.service
```
