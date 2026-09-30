#!/usr/bin/env bash
# Register contracts and enforce backward-compatible evolution through Karapace.
set -euo pipefail
readonly REGISTRY_URL="${1:?usage: register-contracts.sh http://REGISTRY:8081}"
for contract in data/contracts/*.avsc; do
  subject="$(basename "$contract" _v1.avsc)-value"
  payload=$(jq -n --rawfile schema "$contract" '{schema: $schema}')
  curl --fail --silent --show-error -X POST "$REGISTRY_URL/subjects/$subject/versions" -H 'Content-Type: application/vnd.schemaregistry.v1+json' --data "$payload"
  curl --fail --silent --show-error -X PUT "$REGISTRY_URL/config/$subject" -H 'Content-Type: application/vnd.schemaregistry.v1+json' --data '{"compatibility":"BACKWARD"}'
done
