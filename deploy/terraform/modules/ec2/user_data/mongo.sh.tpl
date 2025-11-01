#!/bin/bash
set -e
apt-get update -y
apt-get install -y awscli jq

cat >/usr/local/bin/s3_backup_mongo.sh <<'SCRIPT'
#!/bin/bash
# === MongoDB Backup Script ===
TIMESTAMP=$(date +"%F-%H%M%S")
BACKUP_FILE="/tmp/mongo-backup-$${TIMESTAMP}.gz"

/usr/bin/mongodump \
  --archive=$${BACKUP_FILE} \
  --gzip \
  --username mongouser \
  --password 'password' \
  --authenticationDatabase admin || true

aws s3 cp $${BACKUP_FILE} s3://${MONGO_BUCKET}/ || true
SCRIPT

chmod +x /usr/local/bin/s3_backup_mongo.sh

# Schedule daily backup (02:00)
(crontab -l 2>/dev/null; echo "0 2 * * * MONGO_BUCKET='${MONGO_BUCKET}' /usr/local/bin/s3_backup_mongo.sh") | crontab -

