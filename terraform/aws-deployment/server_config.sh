#!/bin/bash

# user_data file is executed as root user
# use 'sudo su' and 'exit' to test the commands locally

apt-get update
apt-get install nginx -y
apt-get install postgresql-client -y
add-apt-repository ppa:longsleep/golang-backports -y
apt-get install golang-go -y

mkdir -p /usr/local/src/golang-demo
git clone https://github.com/tonygitcoder/cicd-course-go-demo.git /usr/local/src/golang-demo
cd /usr/local/src/golang-demo

# This is wrong, as will create the schema with each instance creation
# But is the only working option if the RDS is not public (better for security)
# IMHO, schema should be created from the backend code (in the video.go)
export PGPASSWORD=${DB_PASSWORD}
psql -h ${DB_ENDPOINT} -U ${DB_USER} -d ${DB_NAME} -f db_schema.sql

# Without it go build doesn't work
export HOME=/home
# The build always failed without the -buildvcs=false flag (it was outputed in terminal)
sudo go build -o golang-demo -buildvcs=false

# TODO: Beautify??
cat <<EOF > /etc/systemd/system/golang-demo.service
[Unit]
After=network.target

[Service]
ExecStart=/usr/local/src/golang-demo/golang-demo
WorkingDirectory=/usr/local/src/golang-demo
Restart=always
Environment=DB_ENDPOINT=${DB_ENDPOINT}
Environment=DB_PORT=${DB_PORT}
Environment=DB_USER=${DB_USER}
Environment=DB_PASS=${DB_PASSWORD}
Environment=DB_NAME=db

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start golang-demo
systemctl enable golang-demo

# check status:
# sudo systemctl status golang-demo

# TODO: Beautify?? Like put in another file or what
# Tried several methods but this ubly one seems optimal
cat <<EOF > /etc/nginx/sites-available/default
server {
    listen 80;

    location / {
        proxy_pass http://localhost:8080;
    }
}
EOF

systemctl restart nginx