#!/bin/bash
#----------------------------------------
# -- !! NOTE !! --
# - Currently this script only supports restoring a single database from archive file
# -- !! NOTE !! --
#----------------------------------------

#----------------------------------------
# OPTIONS
# PERAMETER 1 :: backup file name
# PERAMETER 2 :: ns from backup file
# PERAMETER 3 :: ns to restore
#----------------------------------------
MONGO_HOST_PORT="127.0.0.1:27017" # MongoDB host and port
MONGO_USER=""                     # MongoDB User
MONGO_PASS=""                     # MongoDB Password
MONGO_RESTORE_OPTIONS=""          # MongoDB restore options

MONGO_RESTORE=$(which mongorestore) # Path to mongorestore
#----------------------------------------

# LOGGING
START_TIME=$(date +%s)
echo "Starting Restore of MongoDB on $MONGO_HOST_PORT at $(date)"

# PREPARE THE MONGO RESTORE COMMAND
if [ -n "$MONGO_USER" ]; then
  MONGO_RESTORE_OPTIONS="$(echo $MONGO_RESTORE_OPTIONS) -u $MONGO_USER"
fi
if [ -n "$MONGO_PASS" ]; then
  MONGO_RESTORE_OPTIONS="$(echo $MONGO_RESTORE_OPTIONS) -p $MONGO_PASS"
fi

# CHECK PERAMETERS
if [ ! $1 ]; then
  echo "Please provide the backup file name"
  exit 1
fi
if [ ! -f $1 ]; then
  echo "Backup file not found"
  exit 1
fi

if [ ! $2 ]; then
  echo "Please provide the nameSpace from backup file"
  exit 1
fi
if [ ! $3 ]; then
  echo "Please provide the nameSpace to restore"
  exit 1
fi

BACKUP_FILE=$1
DB_NAME=$2
DB_NAME_TO=$3

# RESTORE DATABASE
echo "Restoring database $DB_NAME"
$MONGO_RESTORE -h $MONGO_HOST_PORT $MONGO_RESTORE_OPTIONS --archive=$BACKUP_FILE --nsFrom="$DB_NAME.*" --nsTo="$DB_NAME_TO.*" --drop 2>/dev/null
RETURNCODE=$?
if [ $RETURNCODE -ne 0 ]; then
  echo "Error restoring database"
  exit 1
fi

# FINISH
END_TIME=$(date +%s)
TIME_DIFF=$((END_TIME - START_TIME))
echo "Restore finished in $TIME_DIFF seconds"
