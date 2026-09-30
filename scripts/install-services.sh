#!/usr/bin/env bash
# Install Debezium Kafka Connect and Karapace directly on the provisioned EC2 host.
# Run only after Terraform apply; it never creates AWS resources.
set -euo pipefail
readonly KAFKA_HOME=/opt/kafka
readonly CONNECT_HOME=/opt/kafka-connect
readonly DEBEZIUM_VERSION=2.7.3.Final

sudo mkdir -p "$CONNECT_HOME/plugins" /etc/kafka-connect /etc/karapace
sudo curl --fail --location "https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/${DEBEZIUM_VERSION}/debezium-connector-postgres-${DEBEZIUM_VERSION}-plugin.tar.gz" --output /tmp/debezium.tar.gz
sudo tar -xzf /tmp/debezium.tar.gz -C "$CONNECT_HOME/plugins"
sudo python3 -m pip install --upgrade pip
sudo python3 -m pip install 'karapace==3.15.0'
sudo cp kafka-connect/karapace-config.json /etc/karapace/config.json
sudo cp "$KAFKA_HOME/config/connect-distributed.properties" /etc/kafka-connect/connect-distributed.properties
sudo tee -a /etc/kafka-connect/connect-distributed.properties >/dev/null <<EOF
bootstrap.servers=localhost:9092
group.id=olist-connect
config.storage.topic=_connect-configs
offset.storage.topic=_connect-offsets
status.storage.topic=_connect-status
config.storage.replication.factor=1
offset.storage.replication.factor=1
status.storage.replication.factor=1
plugin.path=${CONNECT_HOME}/plugins
EOF
sudo tee /etc/systemd/system/kafka-connect.service >/dev/null <<EOF
[Unit]
Description=Kafka Connect with Debezium
After=kafka.service
[Service]
User=kafka
ExecStart=${KAFKA_HOME}/bin/connect-distributed.sh /etc/kafka-connect/connect-distributed.properties
Restart=always
[Install]
WantedBy=multi-user.target
EOF
sudo tee /etc/systemd/system/karapace.service >/dev/null <<'EOF'
[Unit]
Description=Karapace Schema Registry
After=kafka.service
[Service]
User=kafka
ExecStart=/usr/local/bin/karapace_all /etc/karapace/config.json
Restart=always
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now kafka-connect karapace
echo 'Services installed. Register contracts and the connector next.'
