for i in {1..20}; do
  aws s3 cp s3://nftnft/$i.json s3://nft-test-nftbucket877a7526-1stizoua2czcc/$i.json --profile nft
  aws s3 cp s3://nftnft/$i.gif s3://nft-test-nftbucket877a7526-1stizoua2czcc/$i.gif --profile nft
done