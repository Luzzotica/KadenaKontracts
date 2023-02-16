aws secretsmanager put-secret-value \
  --secret-id OpsKeyset \
  --profile $PROFILE \
  --secret-string '{"priv_key":"", "pub_key":""}'

aws secretsmanager get-secret-value --secret-id mysecret --region us-west-2

aws s3 cp s3://bucket1-key s3://bucket2-key