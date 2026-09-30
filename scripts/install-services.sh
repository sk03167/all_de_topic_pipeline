#!/usr/bin/env bash
# Install Debezium Kafka Connect and Karapace directly on the provisioned EC2 host.
# Run only after Terraform apply; it never creates AWS resources.
set -euo pipefail
readonly KAFKA_HOME=/opt/kafka
readonly CONNECT_HOME=/opt/kafka-connect
readonly DEBEZIUM_VERSION=2.7.3.Final
readonly KARAPACE_VENV=/opt/karapace-venv
readonly KARAPACE_VERSION=3.7.1
readonly KARAPACE_REQUIREMENTS_URL="https://raw.githubusercontent.com/Aiven-Open/karapace/${KARAPACE_VERSION}/requirements/requirements.txt"

# `envsubst` resolves the connector template immediately before registration;
# install it here as well so this script is safe on an already-bootstrapped host.
sudo dnf install -y gettext
sudo mkdir -p "$CONNECT_HOME/plugins" /etc/kafka-connect /etc/karapace
sudo curl --fail --location "https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/${DEBEZIUM_VERSION}/debezium-connector-postgres-${DEBEZIUM_VERSION}-plugin.tar.gz" --output /tmp/debezium.tar.gz
sudo tar -xzf /tmp/debezium.tar.gz -C "$CONNECT_HOME/plugins"
# Amazon Linux owns its system pip through RPM. Keep Karapace isolated so an
# application upgrade can never break operating-system package management.
sudo python3 -m venv "$KARAPACE_VENV"
sudo "$KARAPACE_VENV/bin/pip" install --upgrade pip
# The release's setup metadata omits several runtime dependencies. Its locked
# requirements file also pins Aiven's compatible Kafka client fork.
sudo "$KARAPACE_VENV/bin/pip" install --requirement "$KARAPACE_REQUIREMENTS_URL"
sudo "$KARAPACE_VENV/bin/pip" install --no-deps "git+https://github.com/Aiven-Open/karapace.git@${KARAPACE_VERSION}"
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
sudo tee /etc/systemd/system/karapace.service >/dev/null <<EOF
[Unit]
Description=Karapace Schema Registry
After=kafka.service
[Service]
User=kafka
# Amazon Linux's Python 3.9 does not load ``importlib.util`` when importing
# ``importlib`` alone; Karapace 3.7.1 expects it to exist. Preload it here.
ExecStart=${KARAPACE_VENV}/bin/python -c 'import importlib.util; from karapace.karapace_all import main; main()' /etc/karapace/config.json
Restart=always
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now kafka-connect karapace
echo 'Services installed. Register contracts and the connector next.'
