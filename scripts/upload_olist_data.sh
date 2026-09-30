#!/usr/bin/env bash
# Upload user-downloaded Olist CSVs. Requires explicit source directory and bucket.
set -euo pipefail
readonly SOURCE_DIR="${1:?usage: upload_olist_data.sh /path/to/olist-csvs BUCKET_NAME}"
readonly BUCKET_NAME="${2:?usage: upload_olist_data.sh /path/to/olist-csvs BUCKET_NAME}"
find "$SOURCE_DIR" -maxdepth 1 -type f -name '*.csv' -print0 | while IFS= read -r -d '' file; do
  aws s3 cp "$file" "s3://$BUCKET_NAME/landing/olist/$(basename "$file")"
done
