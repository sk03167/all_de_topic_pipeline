-- Run once by a Unity Catalog metastore administrator after selecting a bucket and IAM role.
-- Names are examples. Never grant broad account-admin access to pipeline identities.
CREATE CATALOG IF NOT EXISTS ${catalog};
CREATE SCHEMA IF NOT EXISTS ${catalog}.bronze;
CREATE SCHEMA IF NOT EXISTS ${catalog}.silver;
CREATE SCHEMA IF NOT EXISTS ${catalog}.gold;
CREATE SCHEMA IF NOT EXISTS ${catalog}.audit;

-- Demonstration policy: analysts see only a masked e-mail address.
-- Replace `analyst_group` with your IdP-backed group.
CREATE OR REPLACE FUNCTION ${catalog}.silver.mask_email(email STRING)
RETURN CASE WHEN is_account_group_member('analyst_group') THEN regexp_replace(email, '(^.).*(@.*$)', '$1***$2') ELSE 'REDACTED' END;

-- Apply to a table only after it exists:
-- ALTER TABLE ${catalog}.silver.customers ALTER COLUMN customer_email SET MASK ${catalog}.silver.mask_email;
