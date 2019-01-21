#!/bin/bash

## Config ##

# Import Swift Config
source ./swift.conf

# Restic release
release="0.9.1"

# Repository path
repo="/"

# Backup location (See Restic doc)
driver="swift"
driver_param="web"

# Folders to backup (separated by comma)
backup_folders=""

# Databases to backup (separated by comma)
databases=""

# Mysql credentials
mysql_username=""
mysql_password=""

# Restic repository password
export RESTIC_PASSWORD=""

## End Config ##

command -v restic > /dev/null 2>&1

if [ $? -gt 0 ]; then
        echo "Installing Restic $release"
        wget "https://github.com/restic/restic/releases/download/v$release/restic_${release}_linux_amd64.bz2"
        bzip2 -d restic_${release}_linux_amd64.bz2
        mv ./restic_${release}_linux_amd64 /usr/bin/restic
        chmod +x /usr/bin/restic
        echo "Restic installed"
fi

if [ $driver == "local" ] ; then
        r=$repo
else
        r="$driver:$driver_param:$repo"
fi

restic -r $r snapshots > /dev/null 2>&1

if [ $? -gt 0 ] ; then
        echo "Initializing repo"
        restic -r $r init
fi

folders=(${backup_folders//;/ })

for i in "${folders[@]}" ; do
        echo ""
        echo "$(tput setaf 5)Backuping $(tput sgr 0)$i"

        restic -r $r backup $i
        sleep 2s
done

restic -r $r forget --keep-daily 30

if [ -n "$databases" ]; then
        driver_param="sql"

        if [ $driver == "local" ] ; then
                r=$repo
        else
                r="$driver:$driver_param:$repo"
        fi

        d=(${databases//;/ })

        for i in "${d[@]}" ; do
                echo ""
                echo "$(tput setaf 5)Backuping $(tput sgr 0)$i database"

                if [ -n "$mysql_password" ]; then
                        mysqldump -u $mysql_username -p$mysql_password $i | gzip | restic -r $r backup --stdin --stdin-filename $i.sql.gz
                else
                        mysqldump -u $mysql_username $i | gzip | restic -r $r backup --stdin --stdin-filename $i.sql.gz
                fi

                sleep 2s
        done
        restic -r $r forget --keep-daily 30
fi
