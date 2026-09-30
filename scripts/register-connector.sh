#!/usr/bin/env bash
# Resolve the database secret just-in-time. Never persist it in Git or Terraform variables.
set -euo pipefail
readonly CONNECT_URL="${1:?usage: register-connector.sh http://CONNECT_HOST:8083}"
source /opt/olist-lakehouse/runtime.env
DB_PASSWORD=$(aws ssm get-parameter --name "$DB_PASSWORD_PARAMETER" --with-decryption --query Parameter.Value --output text)
export DB_HOST DB_NAME DB_USER DB_PASSWORD
envsubst < kafka-connect/debezium-postgres.json >/tmp/debezium-postgres.resolved.json
curl --fail --silent --show-error -X POST "$CONNECT_URL/connectors" -H 'Content-Type: application/json' --data @/tmp/debezium-postgres.resolved.json
rm -f /tmp/debezium-postgres.resolved.json
