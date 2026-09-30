#!/usr/bin/env bash
# Root-only, one-time bootstrap. This creates exactly one KMS key and one role;
# it never creates the lakehouse VPC, EC2, RDS, S3 bucket, or Databricks assets.
set -euo pipefail
readonly ACCOUNT_ID="${1:?usage: bootstrap_kms_and_role.sh ACCOUNT_ID}"
readonly REGION="ap-south-1"
readonly ROLE_NAME="olist-lakehouse-terraform-deployer"
readonly POLICY_NAME="olist-lakehouse-terraform-deployer-policy"
readonly BUCKET_NAME="olist-lakehouse-lab-${ACCOUNT_ID}-${REGION}"

KEY_ARN=$(aws kms create-key --region "$REGION" --description 'Olist lab encryption key' --tags TagKey=Project,TagValue=olist-lakehouse-lab --query 'KeyMetadata.Arn' --output text)
aws kms enable-key-rotation --region "$REGION" --key-id "$KEY_ARN"
aws kms create-alias --region "$REGION" --alias-name alias/olist-lakehouse-lab --target-key-id "$KEY_ARN"

POLICY_DOCUMENT=$(mktemp)
trap 'rm -f "$POLICY_DOCUMENT"' EXIT
sed -e "s|\${ACCOUNT_ID}|${ACCOUNT_ID}|g" -e "s|\${KMS_KEY_ARN}|${KEY_ARN}|g" -e "s|\${LAB_BUCKET_NAME}|${BUCKET_NAME}|g" infra/iam/terraform-deployer-policy.template.json > "$POLICY_DOCUMENT"
POLICY_ARN=$(aws iam create-policy --policy-name "$POLICY_NAME" --policy-document "file://$POLICY_DOCUMENT" --query 'Policy.Arn' --output text)
aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document file://infra/iam/terraform-deployer-trust-policy.json --max-session-duration 3600 --tags Key=Project,Value=olist-lakehouse-lab
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"

printf 'KMS_KEY_ARN=%s\nROLE_ARN=arn:aws:iam::%s:role/%s\n' "$KEY_ARN" "$ACCOUNT_ID" "$ROLE_NAME"
