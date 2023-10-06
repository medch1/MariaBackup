#!/bin/bash



    DB_NAME="test"
    DB_USER="root"
    DB_PASS="pass"


 #INCREMENTALDIR="$BACKDIR/incremental_${TIMESTAMP}"
    STOP_TIMESTAMP="20230613154547"

    #TIMESTAMP=$(date +%Y%m%d%H%M%S)
    BACKDIR="/data/mysql_backup/${DB_NAME}"
     #BACKDIR="/mdb/mariadb-backup/${DB_NAME}"
    BASEBACKDIR="$BACKDIR/base/base"
    INCREMENTALDIR="$BACKDIR/incremental_${TIMESTAMP}/incremental_${TIMESTAMP}"


  #step1 Prepare backup
  # Prepare the full backup
  mariabackup --prepare   --export --target-dir=$BASEBACKDIR

  # Prepare the incremental backup
  # Loop through the incremental backups and restore them

for file in "$BACKDIR"/incremental_*; do

        echo "$file"
        NEWTIMESTAMP=$(basename "$file"| grep -oP '\d{14}')
#       echo "$NEWTIMESTAMP"


  if [[ $NEWTIMESTAMP > $STOP_TIMESTAMP ]]; then
echo "stop"
   break  # Exit the loop if the current timestamp exceeds the stop timestamp

fi
 #echo "$file"
  echo "prepare  from $file/incremental_$NEWTIMESTAMP"
  echo " mariabackup --prepare --target-dir=$BASEBACKDIR  --incremental-dir=$file/incremental_$NEWTIMESTAMP/ "
  mariabackup --prepare  --export  --target-dir=$BASEBACKDIR  --incremental-dir=$file/incremental_$NEWTIMESTAMP/

done






echo "  # Step 2: Source the input.sql file"
  echo "CREATE DATABASE ${DB_NAME} -p${DB_PASS}"
  mysql -u $DB_USER -p$DB_PASS -e "CREATE DATABASE ${DB_NAME} ; "

  mysql -u $DB_USER -p$DB_PASS -e  "USE $DB_NAME ; source $BACKDIR/incremental_${STOP_TIMESTAMP}/schema.sql;"

#  cat  $BACKDIR/incremental_${STOP_TIMESTAMP}/schema.sql
  echo " Step 3: Loop through all tables in the database "

  for table in $(mysql -u$DB_USER -p$DB_PASS -e "USE $DB_NAME ; SHOW TABLES;" | awk '{if(NR>1)print}')

 do
echo " Step 4: Discard the tablespace for the current table "

  echo " $table"

  mysql -u $DB_USER -p$DB_PASS -e "USE $DB_NAME; SET FOREIGN_KEY_CHECKS=0; ALTER TABLE $DB_NAME.$table DISCARD TABLESPACE;"

echo  " # Step 5: Copy the .ibd files to the destination server"
  done

  cp -f $BASEBACKDIR/$DB_NAME/*.ibd /var/lib/mysql/$DB_NAME/


echo "  # Step 6: Copy the .cfg files to the destination server "
  cp -f $BASEBACKDIR/$DB_NAME/*.cfg /var/lib/mysql/$DB_NAME/


echo " # Step 7: chown /var/lib/ and  Import the tablespace for the current table "

  chown -R  mysql:mysql /var/lib/mysql


 for table in $(mysql -u $DB_USER -p$DB_PASS -e "USE $DB_NAME ; SHOW TABLES;" | awk '{if(NR>1)print}')

  do
    echo " ALTER TABLE $DB_NAME.$table "
    mysql -u $DB_USER -p$DB_PASS -e "USE $DB_NAME ; ALTER TABLE $DB_NAME.$table IMPORT TABLESPACE;"

done


echo "# Remove subdirectories under BACKDIR"

find "$BACKDIR" -mindepth 1 -type d -exec rm -rf {} +

