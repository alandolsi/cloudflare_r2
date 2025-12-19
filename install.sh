#!/bin/bash
#
# Installation script for Cloudflare R2 Backup Tool
#

set -e

echo "==========================================="
echo "  Cloudflare R2 Backup - Installation"
echo "==========================================="
echo ""
echo "⚠️  This script will:"
echo "  - Copy files to installation directory"
echo "  - Create symlink in /usr/local/bin"
echo "  - Set up log files in /var/log"
echo ""
read -p "Continue with installation? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  Please run as root (sudo ./install.sh)"
    exit 1
fi

# Default installation directory
DEFAULT_INSTALL_DIR="/opt/cloudflare_r2_backup"

# Ask for installation directory
echo ""
read -p "Installation directory [$DEFAULT_INSTALL_DIR]: " INSTALL_DIR
INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"

# Verify directory doesn't exist or ask for confirmation
if [ -d "$INSTALL_DIR" ]; then
    echo ""
    echo "⚠️  Directory $INSTALL_DIR already exists!"
    read -p "Overwrite existing files? [y/N]: " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
fi

# Create installation directory
echo ""
echo "Creating installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Copy files with verification
echo "Copying files..."
if [ ! -f "syncbackup_cloudflare.sh" ]; then
    echo "❌ ERROR: syncbackup_cloudflare.sh not found in current directory"
    exit 1
fi

# Check for backup.env.example or backup.env
if [ -f "backup.env.example" ]; then
    ENV_SOURCE="backup.env.example"
elif [ -f "backup.env" ]; then
    ENV_SOURCE="backup.env"
    echo "ℹ️  Using backup.env as template (backup.env.example not found)"
else
    echo "❌ ERROR: Neither backup.env.example nor backup.env found in current directory"
    exit 1
fi

cp syncbackup_cloudflare.sh "$INSTALL_DIR/"
cp "$ENV_SOURCE" "$INSTALL_DIR/backup.env.example"

# Make script executable
chmod +x "$INSTALL_DIR/syncbackup_cloudflare.sh"

# Create symlink in /usr/local/bin
echo "Creating symlink in /usr/local/bin..."
if [ -L "/usr/local/bin/cloudflare-r2" ]; then
    echo "  Removing existing symlink..."
    rm -f /usr/local/bin/cloudflare-r2
fi
ln -sf "$INSTALL_DIR/syncbackup_cloudflare.sh" /usr/local/bin/cloudflare-r2

# Create backup.env if it doesn't exist
if [ ! -f "$INSTALL_DIR/backup.env" ]; then
    echo "Creating backup.env configuration file..."
    cp "$INSTALL_DIR/backup.env.example" "$INSTALL_DIR/backup.env"
    echo ""
    echo "⚠️  IMPORTANT: Edit $INSTALL_DIR/backup.env with your settings!"
else
    echo "✓ Keeping existing backup.env configuration"
fi

# Create log files
echo "Setting up log files..."
touch /var/log/backup_sync.log
chmod 644 /var/log/backup_sync.log

echo ""
echo "==========================================="
echo "  ✓ Installation Complete!"
echo "==========================================="
echo ""
echo "📋 Installation Summary:"
echo "  - Script location: $INSTALL_DIR/syncbackup_cloudflare.sh"
echo "  - Config file: $INSTALL_DIR/backup.env"
echo "  - Command: cloudflare-r2"
echo "  - Log file: /var/log/backup_sync.log"
echo ""
echo "Next steps:"
echo ""
echo "1. Configure your backup settings:"
echo "   nano $INSTALL_DIR/backup.env"
echo ""
echo "2. Test the backup interactively:"
echo "   cloudflare-r2"
echo ""
echo "3. Or run backup directly:"
echo "   cloudflare-r2 backup"
echo ""
echo "4. Setup cronjob for automatic backups:"
echo "   crontab -e"
echo ""
echo "   Add this line for daily backups at 4:00 AM:"
echo "   0 4 * * * $INSTALL_DIR/syncbackup_cloudflare.sh backup >> /var/log/syncbackup_cloudflare.cron.log 2>&1"
echo ""
echo "==========================================="
