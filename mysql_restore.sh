#!/bin/bash
#----------------------------------------
# -- !! NOTE !! --
# data restoretion need all privileges to mysql user::
# create user :: CREATE USER 'restore'@'%' IDENTIFIED BY 'root';
# grant all privileges :: GRANT ALL PRIVILEGES ON *.* TO  'restore'@'%';
#
# -- !! NOTE !! --
#----------------------------------------

#----------------------------------------
# OPTIONS
# PERAMETER 1 :: backup file name
# PERAMETER 2 :: database name
#----------------------------------------
USER='restore'  # MySQL User
PASSWORD='root' # MySQL Password
#----------------------------------------

# LOGGING
START_TIME=$(date +%s)
echo "Starting restore of Mysql at $(date)"

# Restore all databases
date=$(date -I)
echo "Restoring all databases"

if [ ! $1 ]; then
  echo "Please provide the backup file name"
  exit 1
fi
if [ ! -f $1 ]; then
  echo "Backup file not found"
  exit 1
fi

if [ ! $2 ]; then
  echo "Please provide the database name"
  exit 1
fi

BACKUP_FILE=$1
DB_NAME=$2

# create database if not exist
echo "Creating database $DB_NAME"
mysql -u $USER -p$PASSWORD -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
echo "Database created"

#
# # remove create and use database statement from backup file
#
sed -i '/CREATE DATABASE/d;/USE/d' $BACKUP_FILE 2>/dev/null
RETURNCODE=$?
if [ $RETURNCODE -ne 0 ]; then
  echo "Error removing create and use database statement from backup file"
  exit 1
fi

# restore database
echo "Restoring database $DB_NAME"
mysql -u $USER -p$PASSWORD $DB_NAME -e "source $BACKUP_FILE;" 2>/dev/null
RETURNCODE=$?
if [ $RETURNCODE -ne 0 ]; then
  echo "Error restoring database"
  exit 1
fi
echo "Database restored"

# FINISH
END_TIME=$(date +%s)
TIME_DIFF=$((END_TIME - START_TIME))
echo "Restore finished in $TIME_DIFF seconds"
