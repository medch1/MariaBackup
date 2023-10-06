# Backup Automation Script

## Description
This GitHub repository contains a versatile and robust Bash script for automating database backups, designed to simplify the backup process for MySQL databases using MariaBackup. It also includes a Discord notification feature to keep you informed about the backup status.

## Features
- Supports backup of multiple databases on a MySQL server.
- Performs full and incremental backups based on existing data.
- Rsync-based transfer to securely copy backup files to a remote server.
- Discord notifications for backup success and failure.
- Easily customizable with variables for database credentials, backup locations, and more.

## Usage
1. Clone or download this repository to your local machine.
2. Customize the script's configuration variables to match your setup (e.g., database credentials, backup directories, and Discord webhook URL).
3. Run the script to initiate database backups.

### Example Usage
```bash
./backup_script.sh
```

### Prerequisites:

- MariaDB installed on the local machine.
- MariaBackup tool installed and accessible in the system path.
- Rsync for secure file transfer.

### configuration

Before running the script, make sure to configure the following variables in the script to match your environment:

- `DB_USER`: The username for database access.
- `DB_PASSWORD`: The password for the database user.
- `DB_HOST`: The hostname or IP address of the MySQL server.
- `WEBHOOK_URL`: Discord webhook URL for notifications.
- `DEST_SERVER`, `DEST_USER`, `DEST_DIR`: Destination server and directory for backup file transfer.
