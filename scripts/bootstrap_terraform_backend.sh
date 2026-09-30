#!/usr/bin/env bash
# Root-only, one-time state backend bootstrap. This deliberately creates only a
# dedicated state bucket and updates the existing deployer policy to access it.
set -euo pipefail
readonly ACCOUNT_ID="${1:?usage: bootstrap_terraform_backend.sh ACCOUNT_ID KMS_KEY_ARN}"
readonly KMS_KEY_ARN="${2:?usage: bootstrap_terraform_backend.sh ACCOUNT_ID KMS_KEY_ARN}"
readonly REGION="ap-south-1"
readonly STATE_BUCKET="olist-lakehouse-tfstate-${ACCOUNT_ID}-${REGION}"
readonly POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/olist-lakehouse-terraform-deployer-policy"
readonly LAB_BUCKET="olist-lakehouse-lab-${ACCOUNT_ID}-${REGION}"

if ! aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
  aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION" --create-bucket-configuration LocationConstraint="$REGION"
fi
aws s3api put-public-access-block --bucket "$STATE_BUCKET" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$STATE_BUCKET" --server-side-encryption-configuration "{\"Rules\":[{\"ApplyServerSideEncryptionByDefault\":{\"SSEAlgorithm\":\"aws:kms\",\"KMSMasterKeyID\":\"$KMS_KEY_ARN\"},\"BucketKeyEnabled\":true}]}"

POLICY_DOCUMENT=$(mktemp)
trap 'rm -f "$POLICY_DOCUMENT"' EXIT
sed -e "s|\${ACCOUNT_ID}|${ACCOUNT_ID}|g" -e "s|\${KMS_KEY_ARN}|${KMS_KEY_ARN}|g" -e "s|\${LAB_BUCKET_NAME}|${LAB_BUCKET}|g" -e "s|\${STATE_BUCKET_NAME}|${STATE_BUCKET}|g" infra/iam/terraform-deployer-policy.template.json > "$POLICY_DOCUMENT"
# IAM allows only five managed-policy versions.  The current default remains in
# place until the new document is successfully created, so removing superseded
# non-default revisions here does not change the role's effective permissions.
for version_id in $(aws iam list-policy-versions --policy-arn "$POLICY_ARN" --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text); do
  aws iam delete-policy-version --policy-arn "$POLICY_ARN" --version-id "$version_id"
done
aws iam create-policy-version --policy-arn "$POLICY_ARN" --policy-document "file://$POLICY_DOCUMENT" --set-as-default >/dev/null
printf 'STATE_BUCKET=%s\n' "$STATE_BUCKET"
