for i in {1..20}; do
  aws s3api put-object-tagging --bucket $BUCKET --key $i.gif --profile $PROFILE --tagging '{ "TagSet": [{ "Key": "revealed", "Value": "yes" }]}'
  aws s3api put-object-tagging --bucket $BUCKET --key $i.json --profile $PROFILE --tagging '{ "TagSet": [{ "Key": "revealed", "Value": "yes" }]}'
done

