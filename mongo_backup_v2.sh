#!/bin/bash
#----------------------------------------
# OPTIONS
#----------------------------------------
MONGO_HOST_PORT="127.0.0.1:27017" # MongoDB host and port
ARCHIVE=1                         # 1 = Archive
MONGO_USER=""                     # MongoDB User
MONGO_PASS=""                     # MongoDB Password
MONGO_DUMP_OPTIONS=""             # MongoDB dump options
DO_BACKUP=""                      # Which database to backup (leave blank to backup all databases)
GZIP=0                            # 1 = Compress
BACKUP_PATH='./'                  # Backup path
DAYS_TO_KEEP=1                    # 0 to keep forever

MONGO_DUMP=$(which mongodump) # Path to mongodump

## AWS S3 UPLOAD OPTIONS ##
S3_UPLOAD=1                               # 1 = Upload to S3
DAY_TO_KEEP_S3OBJECTS=5                   # 0 to keep forever
export AWS_ACCESS_KEY_ID=''               # AWS Access Key ID
export AWS_SECRET_ACCESS_KEY=''           # AWS Secret Access Key
S3_PATH='s3://sass-taxi/mongo-backup'     # S3 path
S3_BUCKET='s3://sass-taxi'                # S3 BUCKET
S3_OPTIONS='--storage-class STANDARD_IA'  # S3 options
AWS_CLI_OPTIONS='--region ap-northeast-1' # AWS CLI options
#----------------------------------------

# LOGGING
START_TIME=$(date +%s)
echo "Starting backup of MongoDB on $MONGO_HOST_PORT at $(date)"

# Create the backup folder
if [ ! -d $BACKUP_PATH ]; then
  mkdir -p $BACKUP_PATH
fi

date=$(date -I)
COMPRESSED_NAME="$date-$DO_BACKUP"

# PREPARE THE MONGO DUMP COMMAND
if [[ -n "$MONGO_USER" ]]; then
  MONGO_DUMP_OPTIONS="$(echo $MONGO_DUMP_OPTIONS) -u $MONGO_USER"
fi

if [ -n "$MONGO_PASS" ]; then
  MONGO_DUMP_OPTIONS="$(echo $MONGO_DUMP_OPTIONS) -p $MONGO_PASS"
fi

if [ -z "$DO_BACKUP" ]; then
  DO_BACKUP="full"
  COMPRESSED_NAME="$date-all-databases"

else
  MONGO_DUMP_OPTIONS="$(echo $MONGO_DUMP_OPTIONS) -d $DO_BACKUP"
fi

if [ $GZIP == 1 ]; then
  COMPRESSED_NAME="$COMPRESSED_NAME.gz"
  MONGO_DUMP_OPTIONS="$(echo $MONGO_DUMP_OPTIONS) --gzip"
fi

ARCHIVE_FILE="$BACKUP_PATH/$COMPRESSED_NAME"
if [ $ARCHIVE == 1 ]; then
  MONGO_DUMP_OPTIONS="$(echo $MONGO_DUMP_OPTIONS) --archive=$ARCHIVE_FILE"
else
  MONGO_DUMP_OPTIONS="$(echo $MONGO_DUMP_OPTIONS) --out=$BACKUP_PATH/$COMPRESSED_NAME"
fi

# PERFORM THE BACKUP
cd $BACKUP_PATH 2>/dev/null
echo "starting mongodump (this will take a while).... "

$MONGO_DUMP -h $MONGO_HOST_PORT $MONGO_DUMP_OPTIONS 2>/dev/null
RETURN=$?
if [ $RETURN -ne 0 ]; then
  echo "mongodump failed with error code $RETURN"
  exit 1
fi

# UPLOAD TO S3
if [ "$S3_UPLOAD" -eq 1 ]; then
  echo "Uploading to S3"

  if [ $ARCHIVE -eq 1 ]; then
    aws s3 mv $ARCHIVE_FILE $S3_PATH/$COMPRESSED_NAME $S3_OPTIONS $AWS_CLI_OPTIONS 2>/dev/null
    RETURN=$?

    if [ $RETURN -ne 0 ]; then
      echo "Upload to S3 failed with error code $RETURN"
      exit 1
    fi
  else
    # zip the backup folder
    zip -r $BACKUP_PATH/$COMPRESSED_NAME $COMPRESSED_NAME 2>/dev/null
    RETURN=$?
    if [ $RETURN -ne 0 ]; then
      echo "zip failed with error code $RETURN"
      exit 1
    fi
    # upload the zip file
    aws s3 mv $BACKUP_PATH/$COMPRESSED_NAME.zip $S3_PATH/$COMPRESSED_NAME.zip $S3_OPTIONS $AWS_CLI_OPTIONS 2>/dev/null
    RETURN=$?

    if [ $RETURN -ne 0 ]; then
      echo "Upload to S3 failed with error code $RETURN"
      exit 1
    fi
  fi
fi

# Delete old backups
if [ "$DAYS_TO_KEEP" -gt 0 ]; then
  echo "Deleting backups older than $DAYS_TO_KEEP days"
  find $BACKUP_PATH/* -mtime +$DAYS_TO_KEEP -exec rm {} \;
fi

# Delete old backups from S3
if [ "$DAY_TO_KEEP_S3OBJECTS" -gt 0 ]; then
  echo "Deleting backups older than $DAY_TO_KEEP_S3OBJECTS days from S3"
  KEYS = aws s3api list-objects --bucket sass-taxi --prefix mongo-backup --query 'Contents[?LastModified<=`'"$(date -d "$DAY_TO_KEEP_S3OBJECTS days ago" -u +%Y-%m-%dT%H:%M:%SZ)"'`].Key' --output text | awk -v bucket=$S3_BUCKET '{for(i=1;i<=NF;i++) printf("%s/%s ", bucket,$i)}'
  if [ -n "$KEYS" ]; then
    echo $KEYS | xargs -n 1 aws s3 rm
  else
    echo "No objects to delete"
  fi
fi

# FINISH
END_TIME=$(date +%s)
TIME_DIFF=$((END_TIME - START_TIME))
echo "Backup finished in $TIME_DIFF seconds"
