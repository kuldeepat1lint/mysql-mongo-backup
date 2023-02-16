#!/bin/bash
#----------------------------------------
# -- !! NOTE !! --
# create a mysql user with the following privileges:
# SELECT, LOCK TABLES, REPLICATION CLIENT
# example:
# CREATE USER 'backup'@'%' IDENTIFIED BY 'root';
# GRANT SELECT, LOCK TABLES, REPLICATION CLIENT ON *.* TO  'backup'@'%';
# FLUSH PRIVILEGES;
# -- !! NOTE !! --
#----------------------------------------

#----------------------------------------
# OPTIONS
#----------------------------------------
USER='backup'            # MySQL User
PASSWORD='root'          # MySQL Password
DAYS_TO_KEEP=0           # 0 to keep forever
GZIP=0                   # 1 = Compress
BACKUP_PATH='./'         # Backup path
BACKUP_WHOLE_DB=0        # 1 = Backup all databases
BACKUP_DB='jan_project ' # Databases to backup (separated by space) (only if BACKUP_WHOLE_DB=0)

## AWS S3 UPLOAD OPTIONS ##
S3_UPLOAD=0                               # 1 = Upload to S3
export AWS_ACCESS_KEY_ID=''               # AWS Access Key ID
export AWS_SECRET_ACCESS_KEY=''           # AWS Secret Access Key
S3_PATH='s3://sass-taxi/mysql-backup'     # S3 path
S3_OPTIONS='--storage-class STANDARD_IA'  # S3 options
AWS_CLI_OPTIONS='--region ap-northeast-1' # AWS CLI options
#----------------------------------------

# LOGGING
START_TIME=$(date +%s)
echo "Starting backup of Mysql at $(date)"

# Create the backup folder
if [ ! -d $BACKUP_PATH ]; then
  mkdir -p $BACKUP_PATH
fi

# Backup all databases
if [ "$BACKUP_WHOLE_DB" -eq 1 ]; then
  date=$(date -I)
  if [ "$GZIP" -eq 0 ]; then
    echo "Backing up all databases without compression"
    mysqldump -u $USER -p$PASSWORD --all-databases --default-character-set=utf8 --column-statistics=0 --no-tablespaces --skip-set-charset >$BACKUP_PATH/$date-all-databases.sql

    if [ "$S3_UPLOAD" -eq 1 ]; then
      echo "Uploading to S3"
      aws s3 mv $BACKUP_PATH/$date-all-databases.sql $S3_PATH/$date-all-databases.sql $S3_OPTIONS $AWS_CLI_OPTIONS
    fi
  else
    echo "Backing up all databases with compression"
    mysqldump -u $USER -p$PASSWORD --all-databases --default-character-set=utf8 --column-statistics=0 --no-tablespaces --skip-set-charset | gzip -c >$BACKUP_PATH/$date-all-databases.gz

    if [ "$S3_UPLOAD" -eq 1 ]; then
      echo "Uploading to S3"
      aws s3 mv $BACKUP_PATH/$date-all-databases.gz $S3_PATH/$date-all-databases.gz $S3_OPTIONS $AWS_CLI_OPTIONS
    fi
  fi
  # Get list of database names
  databases=$(mysql -u $USER -p$PASSWORD -e "SHOW DATABASES;" | tr -d "|" | grep -v Database)

  for db in $databases; do

    if [ $db == 'information_schema' ] || [ $db == 'performance_schema' ] || [ $db == 'mysql' ] || [ $db == 'sys' ]; then
      echo "Skipping database: $db"
      continue
    fi

    date=$(date -I)
    if [ "$GZIP" -eq 0 ]; then
      echo "Backing up database: $db without compression"
      mysqldump -u $USER -p$PASSWORD --databases $db --default-character-set=utf8 --column-statistics=0 --no-tablespaces --skip-set-charset >$BACKUP_PATH/$date-$db.sql

      if [ "$S3_UPLOAD" -eq 1 ]; then
        echo "Uploading to S3"
        aws s3 mv $BACKUP_PATH/$date-$db.sql $S3_PATH/$date-$db.sql $S3_OPTIONS $AWS_CLI_OPTIONS
      fi
    else
      echo "Backing up database: $db with compression"
      mysqldump -u $USER -p$PASSWORD --databases $db --default-character-set=utf8 --column-statistics=0 --no-tablespaces --skip-set-charset | gzip -c >$BACKUP_PATH/$date-$db.gz

      if [ "$S3_UPLOAD" -eq 1 ]; then
        echo "Uploading to S3"
        aws s3 mv $BACKUP_PATH/$date-$db.gz $S3_PATH/$date-$db.gz $S3_OPTIONS $AWS_CLI_OPTIONS
      fi
    fi
  done
fi

# Backup specific databases
if [ "$BACKUP_WHOLE_DB" -eq 0 ]; then
  for db in $BACKUP_DB; do
    date=$(date -I)
    if [ "$GZIP" -eq 0 ]; then
      echo "Backing up database: $db without compression"
      mysqldump -u $USER -p$PASSWORD --databases $db --default-character-set=utf8 --column-statistics=0 --no-tablespaces --skip-set-charset >$BACKUP_PATH/$date-$db.sql

      if [ "$S3_UPLOAD" -eq 1 ]; then
        echo "Uploading to S3"
        aws s3 mv $BACKUP_PATH/$date-$db.sql $S3_PATH/$date-$db.sql $S3_OPTIONS $AWS_CLI_OPTIONS
      fi
    else
      echo "Backing up database: $db with compression"
      mysqldump -u $USER -p$PASSWORD --databases $db --default-character-set=utf8 --column-statistics=0 --no-tablespaces --skip-set-charset | gzip -c >$BACKUP_PATH/$date-$db.gz

      if [ "$S3_UPLOAD" -eq 1 ]; then
        echo "Uploading to S3"
        aws s3 mv $BACKUP_PATH/$date-$db.gz $S3_PATH/$date-$db.gz $S3_OPTIONS $AWS_CLI_OPTIONS
      fi
    fi
  done
fi

# Delete old backups
if [ "$DAYS_TO_KEEP" -gt 0 ]; then
  echo "Deleting backups older than $DAYS_TO_KEEP days"
  find $BACKUP_PATH/* -mtime +$DAYS_TO_KEEP -exec rm {} \;
fi

# FINISH
END_TIME=$(date +%s)
TIME_DIFF=$((END_TIME - START_TIME))
echo "Backup finished in $TIME_DIFF seconds"
