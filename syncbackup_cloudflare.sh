#!/bin/bash
#
# Automatic backup from local directories to Cloudflare R2
# Requires Rclone (v1.60+)
#

# Get the directory where this script is located (resolve symlinks)
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# Try to load backup.env from script directory if it exists and variables are not set
if [ -f "$SCRIPT_DIR/backup.env" ] && [ -z "$SOURCE" ]; then
    source "$SCRIPT_DIR/backup.env"
fi

# --- CONFIGURATION (via Environment Variables or Defaults) ---

# Source directory for backups.
# Default: /backup_source
SOURCE="${SOURCE:-/backup_source}"

# Retention time in days.
# Default: 5 days
RETENTION_DAYS="${RETENTION_DAYS:-5}"

# Rclone destination (format: remote-name:bucket/path).
# Default: cloudflare-backup:my-backups/
RCLONE_DEST="${RCLONE_DEST:-cloudflare-backup:my-backups/}"

# Regex pattern for automatic folder detection during restore.
# Default: generic backup pattern
BACKUP_PATTERN="${BACKUP_PATTERN:-^backup-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}/$}"

# Path to the log file.
# Default: /var/log/backup_sync.log
LOGFILE="${LOGFILE:-/var/log/backup_sync.log}"

# Path to the lock file (prevents parallel execution).
# Default: /var/log/backup_sync.lock
LOCKFILE="${LOCKFILE:-/var/log/backup_sync.lock}"

# Path to the rclone executable.
# Default: /usr/bin/rclone (adjust if rclone is installed elsewhere)
RCLONE="${RCLONE:-/usr/bin/rclone}"

# --- INTERACTIVE MODE ---
# If no arguments provided, show interactive menu
if [ $# -eq 0 ]; then
    echo "========================================="
    echo "  Cloudflare R2 Backup & Restore Tool"
    echo "========================================="
    echo ""
    echo "What would you like to do?"
    echo ""
    echo "  1) Backup - Upload current data to Cloudflare R2"
    echo "  2) Restore - Download backup from Cloudflare R2"
    echo "  3) Exit"
    echo ""
    read -p "Please select [1-3]: " choice
    
    case $choice in
        1)
            ACTION="backup"
            ;;
        2)
            ACTION="restore"
            # Check if rclone is available
            if [ ! -x "$RCLONE" ]; then
                echo "ERROR: rclone not found at $RCLONE"
                exit 1
            fi
            
            echo ""
            echo "Fetching available backups from R2..."
            echo ""
            
            # List all backup folders
            mapfile -t BACKUP_FOLDERS < <("$RCLONE" lsf "$RCLONE_DEST" --dirs-only | grep -E "$BACKUP_PATTERN" | sed 's:/$::' | sort -r)
            
            if [ ${#BACKUP_FOLDERS[@]} -eq 0 ]; then
                echo "ERROR: No backup folders found on R2"
                exit 1
            fi
            
            echo "Available backups:"
            echo ""
            for i in "${!BACKUP_FOLDERS[@]}"; do
                printf "  %2d) %s\n" $((i+1)) "${BACKUP_FOLDERS[$i]}"
            done
            echo "   0) Cancel"
            echo ""
            
            read -p "Select backup to restore [0-${#BACKUP_FOLDERS[@]}]: " backup_choice
            
            if [ "$backup_choice" -eq 0 ] 2>/dev/null; then
                echo "Restore cancelled."
                exit 0
            fi
            
            if [ "$backup_choice" -ge 1 ] && [ "$backup_choice" -le ${#BACKUP_FOLDERS[@]} ] 2>/dev/null; then
                RESTORE_NAME="${BACKUP_FOLDERS[$((backup_choice-1))]}"
                echo ""
                echo "Selected: $RESTORE_NAME"
                echo ""
                read -p "Restore to directory [$SOURCE]: " custom_dest
                RESTORE_DEST="${custom_dest:-$SOURCE}"
                echo ""
                echo "Starting restore..."
            else
                echo "ERROR: Invalid selection"
                exit 1
            fi
            ;;
        3)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "ERROR: Invalid choice"
            exit 1
            ;;
    esac
else
    # --- MODE / PARAMETERS (non-interactive) ---
    ACTION=${1:-backup}               # backup (default) or restore/import
    RESTORE_NAME=${2:-}               # Name/folder/file on R2 (required for restore/import)
    RESTORE_DEST=${3:-$SOURCE}        # Local destination directory (default: $SOURCE)
fi

# Check for lock file (prevents parallel execution)
if [ -f "$LOCKFILE" ]; then
    echo "$(date): Script is already running (lock file exists)" >> "$LOGFILE"
    exit 1
fi

# Create lock file
echo $$ > "$LOCKFILE"
trap "rm -f '$LOCKFILE'; exit" EXIT INT TERM

# Check if rclone is available
if [ ! -x "$RCLONE" ]; then
    echo "$(date): ERROR - rclone not found at $RCLONE" >> "$LOGFILE"
    exit 1
fi

# --- RESTORE / IMPORT ---
if [ "$ACTION" = "restore" ] || [ "$ACTION" = "import" ]; then
    # If no specific name was given, automatically detect the newest folder
    if [ -z "$RESTORE_NAME" ]; then
        echo "Searching for the newest backup folder..." >> "$LOGFILE"
        # List all folders, sort descending and take the first one (newest)
        RESTORE_NAME=$("$RCLONE" lsf "$RCLONE_DEST" --dirs-only | grep -E "$BACKUP_PATTERN" | sort -r | head -n 1 | sed 's:/$::')
        
        if [ -z "$RESTORE_NAME" ]; then
            echo "$(date): ERROR - No backup folder found" >> "$LOGFILE"
            exit 1
        fi
        echo "Newest backup folder found: $RESTORE_NAME" >> "$LOGFILE"
    fi

    mkdir -p "$RESTORE_DEST"
    echo "--- Restore Start: $(date) ---" >> "$LOGFILE"
    echo "Starting restore from $RESTORE_NAME to $RESTORE_DEST ..." >> "$LOGFILE"
    
    # Show progress on terminal, log to file
    echo ""
    echo "Restoring $RESTORE_NAME to $RESTORE_DEST ..."
    echo "This may take several minutes depending on backup size..."
    echo ""

    "$RCLONE" copy "${RCLONE_DEST}/${RESTORE_NAME}" "$RESTORE_DEST" \
        --progress \
        --stats 5s \
        --transfers=4 \
        --checkers=8 \
        2>&1 | tee -a "$LOGFILE"
    
    RCLONE_EXIT=${PIPESTATUS[0]}

    if [ $RCLONE_EXIT -eq 0 ]; then
        echo ""
        echo "✓ Restore: SUCCESS" | tee -a "$LOGFILE"
        echo "--- Restore End: $(date) ---" >> "$LOGFILE"
        rm -f "$LOCKFILE"
        exit 0
    else
        echo ""
        echo "✗ Restore: ERROR (See log)" | tee -a "$LOGFILE"
        rm -f "$LOCKFILE"
        exit 1
    fi
fi

echo "--- Backup Start: $(date) ---" >> "$LOGFILE"

# 1. UPLOAD (COPY)
echo "Starting upload to Cloudflare..." >> "$LOGFILE"
echo ""
echo "========================================="
echo "  Uploading to Cloudflare R2..."
echo "========================================="
echo ""

"$RCLONE" copy "$SOURCE" "$RCLONE_DEST" \
    --progress \
    --stats 10s \
    --transfers=4 \
    --checkers=8 \
    2>&1 | tee -a "$LOGFILE"

RCLONE_EXIT=${PIPESTATUS[0]}

RCLONE_EXIT=${PIPESTATUS[0]}

echo ""
if [ $RCLONE_EXIT -eq 0 ]; then
    echo "✓ Upload: SUCCESS" | tee -a "$LOGFILE"
else
    echo "✗ Upload: ERROR (See log)" | tee -a "$LOGFILE"
    exit 1
fi
echo ""

# 2. CLEANUP (Delete backups older than RETENTION_DAYS days)
echo "========================================="
echo "  Cleanup old backups..."
echo "========================================="
echo ""
echo "Checking old backups on Cloudflare (Keeping last $RETENTION_DAYS days)..." | tee -a "$LOGFILE"

# Calculate cutoff date (X days ago)
CUTOFF_DATE=$(date -d "$RETENTION_DAYS days ago" +%s)

# List all backup files with timestamp
"$RCLONE" lsf "$RCLONE_DEST" --files-only --format "tp" 2>> "$LOGFILE" | while read -r TIMESTAMP FILE; do
    # Convert rclone timestamp to Unix timestamp
    FILE_DATE=$(date -d "$TIMESTAMP" +%s 2>/dev/null)
    
    if [ $? -eq 0 ] && [ "$FILE_DATE" -lt "$CUTOFF_DATE" ]; then
        echo "  Deleting: $FILE (Date: $TIMESTAMP)" | tee -a "$LOGFILE"
        "$RCLONE" deletefile "$RCLONE_DEST/$FILE" >> "$LOGFILE" 2>&1
        if [ $? -eq 0 ]; then
            echo "  ✓ Successfully deleted" | tee -a "$LOGFILE"
        else
            echo "  ✗ ERROR during deletion" | tee -a "$LOGFILE"
        fi
    fi
done

echo ""
echo "✓ Cleanup completed." | tee -a "$LOGFILE"
echo "--- Backup End: $(date) ---" >> "$LOGFILE"
echo ""
echo "========================================="
echo "  Backup completed successfully!"
echo "========================================="
echo ""

# Clean exit
rm -f "$LOCKFILE"
exit 0