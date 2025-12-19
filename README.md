# Cloudflare R2 Backup Script

Automatic backup script for synchronizing local directories to Cloudflare R2 with automatic retention management and restore functionality.

## Features

- ✅ Automatic uploading of backups to Cloudflare R2
- ✅ Automatic retention management (old backups are deleted)
- ✅ Restore function with automatic detection of the latest backup
- ✅ Lock mechanism against parallel execution
- ✅ Detailed logging
- ✅ Configurable backup patterns for different backup types

## Prerequisites

- **Rclone** (version 1.60 or higher)
- **Bash** Shell
- **Cloudflare R2** Account and configured Rclone Remote

## Installation

### 1. Install Rclone

```bash
curl https://rclone.org/install.sh | sudo bash
```

### 2. Configure Rclone for Cloudflare R2

```bash
rclone config
```

Follow the instructions and choose:
- Storage: `s3`
- Provider: `Cloudflare`
- Enter your R2 Access Key ID and Secret Access Key
- Endpoint: `https://<account-id>.r2.cloudflarestorage.com`

Name the remote, e.g., `cloudflare-backup`. This is the default value for `RCLONE_DEST`.

### 3. Download Script

```bash
git clone <repository-url>
cd cloudflare_r2
chmod +x install.sh syncbackup_cloudflare.sh
```

### 4. Install Script (Optional but Recommended)

Run the installation script to set up the backup tool system-wide:

```bash
sudo ./install.sh
```

This will:
- Install the script to `/opt/cloudflare_r2_backup` (or custom location)
- Create a symlink `/usr/local/bin/cloudflare-r2` for easy access
- Create configuration file `backup.env`
- Set up log files

**Or manually copy to desired location:**

```bash
# Example: Install to /usr/local/share
sudo mkdir -p /usr/local/share/cloudflare_r2_backup
sudo cp syncbackup_cloudflare.sh /usr/local/share/cloudflare_r2_backup/
sudo cp backup.env.example /usr/local/share/cloudflare_r2_backup/backup.env
sudo chmod +x /usr/local/share/cloudflare_r2_backup/syncbackup_cloudflare.sh
```

## Configuration

The script automatically loads `backup.env` from the same directory where the script is located. You can also set environment variables manually before execution.

| Variable         | Description                                                                | Default Value                         |
| :--------------- | :------------------------------------------------------------------------- | :------------------------------------ |
| `SOURCE`         | Source directory for backups.                                              | `/backup_source`                      |
| `RETENTION_DAYS` | Retention time for backups in days.                                        | `5`                                   |
| `RCLONE_DEST`    | Rclone destination in `remote-name:bucket/path` format.                    | `cloudflare-backup:my-backups/`       |
| `BACKUP_PATTERN` | Regex pattern for automatic folder detection during restore.               | `^backup-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}/$` |
| `LOGFILE`        | Path to the log file.                                                      | `/var/log/backup_sync.log`            |
| `LOCKFILE`       | Path to the lock file (prevents parallel execution).                       | `/var/log/backup_sync.lock`           |
| `RCLONE`         | Path to the Rclone executable.                                             | `/usr/bin/rclone`                     |

### Using Environment File

The script will automatically load `backup.env` from its own directory if the file exists. 

Create a `backup.env` file (copy from `backup.env.example`) in the same directory as the script:

```bash
# If installed via install.sh:
nano /opt/cloudflare_r2_backup/backup.env

# Or in your custom location:
nano /path/to/your/script/backup.env
```

Edit `backup.env` with your settings:

```bash
export SOURCE="/backups/"
export RETENTION_DAYS=7
export RCLONE_DEST="remote:backups/your-backup-destination"
export BACKUP_PATTERN='^mailcow-[0-9]{4}-[0-9]{2}-[0-9]{2}/$'
export LOGFILE="/var/log/backup_sync.log"
```

⚠️ **Important:** The `backup.env` file is excluded from Git to protect sensitive data. Never commit credentials to the repository.

**Alternative: Manual environment variables:**

```bash
export SOURCE="/home/user/my_data_to_backup"
export RETENTION_DAYS=7
export RCLONE_DEST="my-r2-remote:my-bucket/daily-backups"
export BACKUP_PATTERN='^mydata-[0-9]{4}-[0-9]{2}-[0-9]{2}/$'
export LOGFILE="/var/log/backup_sync.log"
./syncbackup_cloudflare.sh
```

## Usage

### Interactive Mode (Recommended)

Simply run the script without arguments for an interactive menu:

```bash
# If installed system-wide:
cloudflare-r2

# Or with full path:
/opt/cloudflare_r2_backup/syncbackup_cloudflare.sh

# Or from your custom location:
/path/to/syncbackup_cloudflare.sh
```

The script will guide you through:
1. **Choosing between Backup or Restore**
2. **Selecting from available backups** (if restoring)
3. **Choosing destination directory** (optional)

### Command Line Mode

**Create a Backup**

```bash
# If installed system-wide:
cloudflare-r2 backup

# Or:
/opt/cloudflare_r2_backup/syncbackup_cloudflare.sh backup
```

**Perform a Restore (Import)**

**Automatically restore the latest backup:**
```bash
cloudflare-r2 restore
```

**Restore a specific backup folder:**
```bash
cloudflare-r2 restore backup-2025-12-17-01-00-45
```

**Restore to a different destination directory:**
```bash
cloudflare-r2 restore backup-2025-12-17-01-00-45 /tmp/restore
```

## Automation with Cron

Add a Cron job for regular backups. **Important:** When running via cron, you must explicitly pass the `backup` argument to avoid the interactive menu.

```bash
sudo crontab -e
```

Examples:

```bash
# Daily at 4:00 AM (if installed to /opt/cloudflare_r2_backup)
0 4 * * * /opt/cloudflare_r2_backup/syncbackup_cloudflare.sh backup >> /var/log/syncbackup_cloudflare.cron.log 2>&1

# Daily at 4:00 AM (using system-wide command - RECOMMENDED)
0 4 * * * /usr/local/bin/cloudflare-r2 backup >> /var/log/syncbackup_cloudflare.cron.log 2>&1

# Every 6 hours
0 */6 * * * /opt/cloudflare_r2_backup/syncbackup_cloudflare.sh backup

# Every Sunday at 3:00 AM
0 3 * * 0 /opt/cloudflare_r2_backup/syncbackup_cloudflare.sh backup
```

**Note:** 
- The script automatically loads `backup.env` from its own directory
- Always pass `backup` as the first argument in cron to skip the interactive menu
- The script logs go to `/var/log/backup_sync.log`
- Optional: Redirect cron output to a separate log file with `>> /var/log/syncbackup_cloudflare.cron.log 2>&1`

## Logging

The script writes all actions to the configured log file (default: `./backup_sync.log`).

**View Log:**
```bash
tail -f /var/log/backup_sync.log
```

**Check last backup activity:**
```bash
grep "Backup End" /var/log/backup_sync.log | tail -1
```

## Retention Management

The script automatically deletes backups older than `RETENTION_DAYS` days. The retention time can be adjusted via the `RETENTION_DAYS` environment variable.

## Troubleshooting

### Script is already running (Lock file exists)

```bash
# Manually remove the lock file (only if no backup is running!)
rm -f /var/log/backup_sync.lock
```

### Rclone not found

```bash
# Check Rclone path
which rclone

# Adjust path in the script or via the RCLONE environment variable if necessary
```

### No permissions for log file

```bash
# Ensure the user executing the script has write permissions for the LOGFILE path.
```

## Security Notes

⚠️ **Important:**
- Protect your Rclone configuration (`~/.config/rclone/rclone.conf`)
- Use separate R2 Access Keys with minimal permissions for production systems
- Regularly test restores in a test environment
- Use encrypted connections (Rclone uses HTTPS by default)

## License

MIT License - see LICENSE file (if present)

## Contributing

Pull requests are welcome! For larger changes, please open an issue first.
