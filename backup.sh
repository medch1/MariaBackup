#!/bin/bash

DB_USER="root"
DB_PASSWORD="password"
DB_HOST="localhost"
WEBHOOK_URL="https://discord.com/api/webhooks/"
my_hostname=$(hostname)

DEST_SERVER="1.2.3.4"
DEST_USER="root"
DEST_DIR="/var/backups/"

# Function to perform incremental backup

perform_incremental_backup() {
    echo "Partial backup exists. Launching incremental backup."

    LAST_INCREMENTAL=$(ls -d $BACKDIR/incremental_* | tail -n 1)

    # Set the value of --incremental-basedir based on the last incremental backup
    if [ -n "$LAST_INCREMENTAL" ]; then
        INCREMENTAL_BASEDIR=$(ls -d $LAST_INCREMENTAL/incremental_* | tail -n 1)
    else
        INCREMENTAL_BASEDIR="$BASEBACKDIR"
    fi

    # Create the backup directories
    mkdir -p $INCREMENTALDIR

    # Perform the incremental backup
    mysqldump --no-data -u $DB_USER -p$DB_PASSWORD $DB_NAME > $BACKDIR/incremental_${TIMESTAMP}/schema.sql

    echo "INCREMENTAL BASE DIR IS $INCREMENTAL_BASEDIR "

    mariabackup --user=$DB_USER --password=$DB_PASSWORD --host=$DB_HOST --backup --rsync --target-dir=$INCREMENTALDIR --incremental-basedir=$INCREMENTAL_BASEDIR --databases=$DB_NAME

}



# Function to copy backup file to destination server using rsync
copy_backup_file() {
    local source_file=$1
    #rsync -a  "$source_file" "${DEST_USER}@${DEST_SERVER}:${DEST_DIR}"
    rsync -a --rsync-path="mkdir -p ${DEST_DIR} && rsync" "$source_file" "${DEST_USER}@${DEST_SERVER}:${DEST_DIR}"

}



# Function to send Discord notification
notification_discord() {
    local status=$1
    local message=$2

if [ $status -eq 0 ]; then
        color=53763 # Green color for success
        status_message="Success"
    else
        color=13700352 # Red color for failure
        status_message="Failure"
    fi

PAYLOAD='{
  "content": "",
  "tts": false,
  "embeds": [
    {
      "id": 965345895,
      "description": "'"$status_message\n$message"'",
      "fields": [],
      "color": '"$color"',
      "title": "Backup Status",
      "author": {
        "icon_url": "https://img.icons8.com/?size=64&id=44793&format=png",
        "name": "MariaBackup"
      }
    }
  ],
  "components": [],
  "actions": {}
}'

curl -X POST -H "Content-Type: application/json" -d "$PAYLOAD" "$WEBHOOK_URL"

}




# Get the list of databases
databases=$(mysql -u $DB_USER -p$DB_PASSWORD -h $DB_HOST -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|mysql|sys)")

# Loop through each database and perform partial backup
for DB_NAME in $databases; do
    echo "Performing partial backup for database: $DB_NAME"
    echo "------------------------------------------"

    # Create a timestamp for the backup directories
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    BACKDIR="/data/mysql_backup/${DB_NAME}"
   # BACKDIR="/data/new/${DB_NAME}"
    BASEBACKDIR="$BACKDIR/base/base"
    INCREMENTALDIR="$BACKDIR/incremental_${TIMESTAMP}/incremental_${TIMESTAMP}"




    # Check if there is a partial backup
    if [ -d $BASEBACKDIR ] || [ "$(ls -A  $BACKDIR/incremental_*)" ]; then

        echo "Partial backup exists. Launching incremental backup."
	perform_incremental_backup

	backup_status=$?
	echo "Incremental backup for database $DB_NAME completed with status: $backup_status."
    	notification_discord $backup_status "Incremental backup for database $DB_NAME in $my_hostname."

   	if [ $backup_status -eq 0 ]; then
        	cd $BACKDIR
        	tar -czvf incremental-compressed-${TIMESTAMP}.tar.gz $BACKDIR/incremental_${TIMESTAMP}
	        DEST_DIR="/var/backups/mohamed/${DB_NAME}"
        	copy_backup_file incremental-compressed-${TIMESTAMP}.tar.gz
        	copy_status=$?
        	if [ $copy_status -eq 0 ]; then
            		rm -rf incremental-compressed-${TIMESTAMP}.tar.gz
        	else
            		notification_discord $backup_status "Error While send compressed Backup Incremental $DB_NAME in $my_hostname ."
        	fi
		rm -rf $INCREMENTAL_BASEDIR
	else
        	notification_discord $backup_status "Error While Backup Incremental $DB_NAME in $my_hostname."
   	fi




        echo "Incremental backup for database $DB_NAME completed."
    else
        echo "No partial backup found. Skipping incremental backup."
        mkdir -p $BASEBACKDIR
         # Perform the full backup
           mysqldump --no-data -u $DB_USER -p$DB_PASSWORD $DB_NAME > $BACKDIR/base/schema.sql
           mariabackup --user=$DB_USER --password=$DB_PASSWORD --host=$DB_HOST --backup --rsync --target-dir=$BASEBACKDIR --databases=$DB_NAME

	backup_status=$?

	if [ $backup_status -eq 0 ]; then
	perform_incremental_backup
        backup_status=$?
        echo "Incremental backup for database $DB_NAME completed with status: $backup_status."
        notification_discord $backup_status "Incremental backup for database $DB_NAME in $my_hostname."

        if [ $backup_status -eq 0 ]; then
                cd $BACKDIR
                tar -czvf incremental-compressed-${TIMESTAMP}.tar.gz $BACKDIR/incremental_${TIMESTAMP}
                DEST_DIR="/var/backups/mohamed/${DB_NAME}"
                copy_backup_file incremental-compressed-${TIMESTAMP}.tar.gz
                copy_status=$?
                if [ $copy_status -eq 0 ]; then
                        rm -rf incremental-compressed-${TIMESTAMP}.tar.gz
                else
                    	notification_discord $backup_status "Error While send compressed Backup Incremental $DB_NAME in $my_hostname ."
                fi
        else
            	notification_discord $backup_status "Error While Backup Incremental $DB_NAME in $my_hostname."
        fi

	 cd $BACKDIR
         tar -czvf  base-compressed-${TIMESTAMP}.tar.gz $BACKDIR/base
	 copy_backup_file base-compressed-${TIMESTAMP}.tar.gz
         copy_status=$?
         if [ $copy_status -eq 0 ]; then
	 	rm -rf base-compressed-${TIMESTAMP}.tar.gz

	 	rm -rf $INCREMENTAL_BASEDIR
else
		 notification_discord $backup_status "Error While send compressed Backup Base $DB_NAME in $my_hostname."
         fi

       else
        notification_discord $backup_status "Error While Backup full backup for $DB_NAME."

       fi



        echo "Partial backup for database $DB_NAME completed with status: $backup_status."
        notification_discord $backup_status "Full backup for database $DB_NAME in $my_hostname ."



    fi

    echo "Partial backup for database $DB_NAME completed."
    echo "------------------------------------------"
done
