# Minecraft ThinkPad Server - Setup (Sanitized)

This repository contains scripts and systemd service files to set up a ThinkPad or Linux machine as a dedicated Minecraft server that exposes itself through a reverse SSH tunnel.

## Files
- `setup_mcserver.sh` - Full setup script (sanitized). Fill the placeholders before running.
- `minecraft.service` - systemd unit to run the server inside a `screen` session.
- `mc-tunnel.service` - systemd unit template to run the persistent reverse SSH tunnel with `autossh`.
- `.gitignore` - recommended ignores.

## Usage
1. Clone the repo on the target machine.
2. Edit `setup_mcserver.sh` and replace placeholders: `<VPS_USER>`, `<VPS_IP>`, `<VPS_PATH>`, `<MC_PORT>`, `<REVERSE_SSH_PORT>`.
3. Run with `sudo bash setup_mcserver.sh`.
4. Copy the generated public SSH key (printed during the script) to your VPS `~/.ssh/authorized_keys`.
5. Edit `/etc/ssh/sshd_config` on the VPS and enable `GatewayPorts yes`.
6. Start/enable the services:
   ```
   sudo systemctl daemon-reload
   sudo systemctl enable minecraft
   sudo systemctl enable reverse-ssh
   sudo systemctl start minecraft reverse-ssh
   ```

## Security
- Do **not** commit real credentials to the repository.
- Use SSH key authentication; the script generates keys in `/home/mcserver/.ssh/`.
- Protect your VPS by disabling password authentication once keys are in place.

