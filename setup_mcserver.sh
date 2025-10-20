#!/bin/bash
# ==============================================
# 🧱 Minecraft Server Setup + Reverse SSH Tunnel
# ==============================================
set -e

# === [ CONFIG - FILL LOCALLY BEFORE RUNNING ] ===
VPS_USER="<VPS_USER>"             # your VPS username (e.g. root)
VPS_IP="<VPS_IP>"                 # your VPS public IP
VPS_PATH="<VPS_PATH>"             # e.g. /root/mcserver
MC_USER="mcserver"
LOCAL_PATH="/home/mcserver/minecraft"
MC_PORT="<MC_PORT>"               # e.g. 25565
REV_SSH_PORT="<REVERSE_SSH_PORT>" # e.g. 2222 (on VPS side)
SSH_KEY_PATH="/home/mcserver/.ssh/id_ed25519"

echo "🚀 Starting Minecraft + Reverse SSH setup..."
sleep 1

# === [ Install dependencies ] ===
apt update -y
apt install -y openjdk-21-jre-headless rsync sshpass autossh screen htop ufw curl nano

# === [ Create Minecraft user if missing ] ===
if ! id "$MC_USER" &>/dev/null; then
    echo "👤 Creating user $MC_USER..."
    adduser --disabled-password --gecos "" $MC_USER
fi

# === [ System limits tuning ] ===
cat <<EOF >/etc/security/limits.d/mcserver.conf
$MC_USER   hard   nofile   65535
$MC_USER   soft   nofile   65535
EOF

# === [ UFW firewall rules ] ===
ufw allow 22/tcp
# NOTE: MC port placeholder — fill locally before running
ufw allow ${MC_PORT}/tcp
ufw --force enable

# === [ Sync server files from VPS (Optional) ] ===
echo "🌍 Syncing Minecraft server files from VPS..."
read -sp "Enter VPS password for ${VPS_USER}@${VPS_IP}: " VPS_PASS
echo
mkdir -p $LOCAL_PATH
chown -R $MC_USER:$MC_USER $(dirname $LOCAL_PATH)

sudo -u $MC_USER sshpass -p "$VPS_PASS" rsync -avzP -e "ssh -o StrictHostKeyChecking=no"${VPS_USER}@${VPS_IP}:${VPS_PATH}/ $LOCAL_PATH/

chown -R $MC_USER:$MC_USER $LOCAL_PATH

# === [ Create systemd for Minecraft ] ===
# NOTE: start.sh is the script for starting the Minecraft server you should create it on your own to be able to use this.
cat <<EOF >/etc/systemd/system/minecraft.service
[Unit]
Description=Minecraft Server
After=network.target

[Service]
User=$MC_USER
WorkingDirectory=$LOCAL_PATH
ExecStart=/usr/bin/screen -DmS minecraft bash -c "cd $LOCAL_PATH && bash start.sh"
ExecStop=/usr/bin/screen -S minecraft -X stuff "say SERVER SHUTTING DOWN IN 5 SECONDS...$(printf '\r')"
ExecStop=/bin/sleep 5
ExecStop=/usr/bin/screen -S minecraft -X stuff "stop$(printf '\r')"
ExecStop=/bin/sleep 10
Restart=on-failure
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF

# === [ Reverse SSH Setup (Persistent via autossh) ] ===
echo "🔁 Setting up Reverse SSH (autossh)..."
sudo -u $MC_USER mkdir -p /home/$MC_USER/.ssh
sudo -u $MC_USER ssh-keygen -t ed25519 -N "" -f $SSH_KEY_PATH

echo
echo "➡️ Copy the following public key to your VPS authorized_keys:"
echo "------------------------------------------------------------"
cat ${SSH_KEY_PATH}.pub
echo "------------------------------------------------------------"
echo "   On VPS: add above line to ~/.ssh/authorized_keys"
echo "   Then ensure SSH on VPS allows GatewayPorts yes"
echo "------------------------------------------------------------"
echo

# create systemd unit for autossh
cat <<EOF >/etc/systemd/system/reverse-ssh.service
[Unit]
Description=Persistent Reverse SSH Tunnel
After=network-online.target
Wants=network-online.target

[Service]
User=$MC_USER
Environment="AUTOSSH_GATETIME=0"
ExecStart=/usr/bin/autossh -N -o "ServerAliveInterval=30" -o "ServerAliveCountMax=3" \
  -R ${REV_SSH_PORT}:localhost:22 ${VPS_USER}@${VPS_IP} -i $SSH_KEY_PATH
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable minecraft.service reverse-ssh.service
systemctl start minecraft.service reverse-ssh.service

echo
echo "✅ Setup complete! Reverse SSH active."
echo "--------------------------------------"
echo "To connect from VPS -> Laptop:"
echo "   ssh -p ${REV_SSH_PORT} localhost"
echo
echo "🧠 Management:"
echo "   sudo systemctl status minecraft"
echo "   sudo systemctl status reverse-ssh"
echo
echo "🎮 Minecraft running at port $MC_PORT"
echo "Reverse SSH listening on VPS:${REV_SSH_PORT}"
echo
