# Cloudflare R2 Backup Script for Mailcow

Automatic backup solution for **Mailcow** (and other applications) to Cloudflare R2 with automated retention management and easy restore functionality.

Perfect for backing up Mailcow to Cloudflare R2 with automatic cleanup and one-click restore! 🚀

## Features

- ✅ **Mailcow-optimized** - Designed for Mailcow backup structure
- ✅ **Automatic uploads** to Cloudflare R2
- ✅ **Smart retention** - Auto-delete old backups after X days
- ✅ **Easy restore** - Interactive selection from available backups
- ✅ **Self-update** - Update script directly from GitHub
- ✅ **Cron-ready** - Set it and forget it

## Quick Start for Mailcow Users

### Prerequisites

- Working Mailcow installation
- Cloudflare R2 account
- Rclone installed

### Installation

**1. Install Rclone:**

```bash
curl https://rclone.org/install.sh | sudo bash
```

**2. Configure Rclone for Cloudflare R2:**

```bash
rclone config
```

Choose:
- Storage: `s3`
- Provider: `Cloudflare`
- Access Key ID and Secret Access Key (from R2 dashboard)
- Endpoint: `https://<your-account-id>.r2.cloudflarestorage.com`
- Remote name: `cloudflare-backup`

**3. Install this script:**

```bash
cd ~
git clone https://github.com/alandolsi/cloudflare_r2.git
cd cloudflare_r2
chmod +x install.sh
sudo ./install.sh
```

**4. Configure for Mailcow:**

```bash
sudo nano /opt/cloudflare_r2_backup/backup.env
```

Example configuration:

```bash
export SOURCE="/backups/"
export RETENTION_DAYS=7
export RCLONE_DEST="cloudflare-backup:backups/mail.example.com"
export BACKUP_PATTERN='^mailcow-[0-9]{4}-[0-9]{2}-[0-9]{2}/$'
export LOGFILE="/var/log/backup_sync.log"
```

**5. Set up Mailcow backup cron:**

```bash
sudo crontab -e
```

Add:

```bash
# Mailcow creates backup at 1:00 AM (keeps 1 day locally)
0 1 * * * cd /opt/mailcow-dockerized/; MAILCOW_BACKUP_LOCATION=/backups/ /opt/mailcow-dockerized/helper-scripts/backup_and_restore.sh backup all --delete-days 1

# Upload to Cloudflare R2 at 4:00 AM (keeps 7 days in cloud)
0 4 * * * cloudflare-r2 backup
```

**Done!** Your Mailcow backups are now automatically synced to Cloudflare R2! 🎉

## Usage

### Interactive Mode

```bash
cloudflare-r2
```

Menu options:
1. **Backup** - Upload current backups to R2
2. **Restore** - Browse and restore from available backups
3. **Update** - Update script from GitHub
4. **Exit**

### Command Line

**Create backup:**
```bash
cloudflare-r2 backup
```

**Restore (interactive selection):**
```bash
cloudflare-r2 restore
```

**Restore specific backup:**
```bash
cloudflare-r2 restore mailcow-2025-12-23-01-00-31
```

**Restore to custom location:**
```bash
cloudflare-r2 restore mailcow-2025-12-23-01-00-31 /tmp/restore-test
```

**Update script:**
```bash
cloudflare-r2 update
```

## Restore Mailcow from Backup

**Step 1: Stop Mailcow**
```bash
cd /opt/mailcow-dockerized
docker-compose down
```

**Step 2: Restore backup interactively**
```bash
cloudflare-r2 restore
```

Select the backup you want to restore (e.g., `1` for latest).

**Step 3: Restore Mailcow from downloaded backup**
```bash
cd /opt/mailcow-dockerized
./helper-scripts/backup_and_restore.sh restore /backups/mailcow-YYYY-MM-DD-HH-MM-SS
```

**Step 4: Start Mailcow**
```bash
docker-compose up -d
```

Done! Your Mailcow is restored! ✅

## Configuration Variables

| Variable | Description | Default | Mailcow Recommended |
|----------|-------------|---------|---------------------|
| `SOURCE` | Source directory for backups | `/backup_source` | `/backups/` |
| `RETENTION_DAYS` | Days to keep backups on R2 | `5` | `7` or more |
| `RCLONE_DEST` | R2 destination `remote:bucket/path` | `cloudflare-backup:my-backups/` | `cloudflare-backup:backups/mail.yourdomain.com` |
| `BACKUP_PATTERN` | Regex for backup folder detection | Generic pattern | `^mailcow-[0-9]{4}-[0-9]{2}-[0-9]{2}/$` |
| `LOGFILE` | Log file path | `/var/log/backup_sync.log` | `/var/log/backup_sync.log` |
| `LOCKFILE` | Lock file to prevent parallel runs | `/var/log/backup_sync.lock` | `/var/log/backup_sync.lock` |
| `RCLONE` | Rclone executable path | `/usr/bin/rclone` | `/usr/bin/rclone` |

## Monitoring

**View logs:**
```bash
tail -f /var/log/backup_sync.log
```

**Check last backup:**
```bash
grep "Backup End" /var/log/backup_sync.log | tail -1
```

**List backups on R2:**
```bash
rclone lsf cloudflare-backup:backups/mail.example.com --dirs-only
```

## Cost Optimization

Cloudflare R2 offers:
- **10 GB free storage** per month
- **No egress fees** (unlike AWS S3!)
- Perfect for Mailcow backups (typically 5-20 GB)

**Recommendation:** Set `RETENTION_DAYS=7` to balance between cost and safety.

## Troubleshooting

**"No backup folders found on R2"**
- Check `RCLONE_DEST` in `backup.env`
- Verify rclone config: `rclone lsd cloudflare-backup:`

**"All files already synced"**
- This is normal! Means backups are up-to-date
- New files will be uploaded when Mailcow creates new backups

**Script update fails**
- Ensure you're using symlink installation (see Installation step 3)
- Manual update: `cd ~/cloudflare_r2 && git pull`

## About

Created by **Landolsi Webdesign** for reliable Mailcow backups to Cloudflare R2.

🌐 **Website:** [landolsi.de](https://www.landolsi.de)  
📧 **Contact:** abdellatif@landolsi.de  
💻 **GitHub:** [alandolsi/cloudflare_r2](https://github.com/alandolsi/cloudflare_r2)

## Contributing

Pull requests welcome! For major changes, please open an issue first.

## License

MIT License - Free to use and modify!

---

⭐ **If this helps you, please star the repository!** ⭐
