#!/bin/bash
set -e

REPO_URL=https://github.com/zenmanenergy/studyguides.git
PROJECT_DIR=/opt/studyguides

echo "=== Study Guides Server Setup ==="

# Install system dependencies
apt-get update -q
apt-get install -y apache2 python3 python3-pip python3-venv git ufw

# Stop service if running
systemctl stop studyguides-chat 2>/dev/null || true

# Preserve .env across installs
if [ -f $PROJECT_DIR/.env ]; then
    echo "Preserving existing .env"
    cp $PROJECT_DIR/.env /tmp/studyguides_env_backup
fi

# Clone or update repo
if [ -d $PROJECT_DIR/.git ]; then
    echo "Updating existing repo..."
    git -C $PROJECT_DIR pull
else
    echo "Cloning repo..."
    git clone $REPO_URL $PROJECT_DIR
fi

# Restore or create .env
if [ -f /tmp/studyguides_env_backup ]; then
    cp /tmp/studyguides_env_backup $PROJECT_DIR/.env
elif [ ! -f $PROJECT_DIR/.env ]; then
    cp $PROJECT_DIR/.env.example $PROJECT_DIR/.env
    echo ""
    echo "ACTION REQUIRED: Set your API key before starting the service:"
    echo "  nano /opt/studyguides/.env"
    echo ""
fi

# Create Python venv and install dependencies
python3 -m venv $PROJECT_DIR/venv
$PROJECT_DIR/venv/bin/pip install -q --upgrade pip
$PROJECT_DIR/venv/bin/pip install -q -r $PROJECT_DIR/requirements.txt

# Set permissions
chown -R www-data:www-data $PROJECT_DIR
chmod 750 $PROJECT_DIR
find $PROJECT_DIR/subjects -type d -exec chmod 755 {} \;
find $PROJECT_DIR/subjects -type f -exec chmod 644 {} \;
chmod 640 $PROJECT_DIR/.env
mkdir -p $PROJECT_DIR/conversations
chown www-data:www-data $PROJECT_DIR/conversations
chmod 750 $PROJECT_DIR/conversations

# Apache config: serve subjects/ at /studyguides/
cat > /etc/apache2/conf-available/studyguides.conf << 'APACHECONF'
Alias /studyguides /opt/studyguides/subjects
<Directory /opt/studyguides/subjects>
    Options -Indexes +FollowSymLinks
    AllowOverride None
    Require all granted
    DirectoryIndex index.html
</Directory>
APACHECONF

a2enconf studyguides
systemctl enable apache2
systemctl reload apache2

# Systemd service
cp $PROJECT_DIR/studyguides-chat.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable studyguides-chat
systemctl start studyguides-chat

# Firewall
ufw allow 22/tcp comment "SSH"
ufw allow 80/tcp comment "HTTP"
ufw allow 5000/tcp comment "Chat server"
ufw --force enable

echo ""
echo "=== Setup Complete ==="
SERVER_IP=$(hostname -I | awk '{print $1}')
echo "Study Guides: http://$SERVER_IP/studyguides/"
echo "Chat server health: http://$SERVER_IP:5000/health"
echo ""
echo "Service status:"
systemctl status studyguides-chat --no-pager -l
