# Overview

These contracts, website, and AWS Stack were used to build the [KadenaArtwork](https://mint.kadenaartwork.com/) NFT Mint.

This code provides tools and implementations for the following:

1. A minting contract to create a collection on the marmalade ledger on chain 8
2. A custom policy that can be easily extended to anything you might need (Like adding royalties)
3. A website that already communicates with those contracts, just change the contract name and chain in the .env files
4. An AWS stack that will deploy a lambda function and a bucket for you. The lambda function will autoreveal the NFTs as they are minted. The bucket will store your NFTs, wich index starting at 1.
5. Scripts to help you deploy the stack, copy NFTs into the bucket using the CLI, and generate a provenance hash for your NFT sale.

The NFTs in this mint are revealed as they are purchased.
If you wish a truly random, unsnipeable reveal, you must reveal all of the tokens after they have been minted, and randomize their order throughout the mint, as done in [this](https://github.com/kadena-io/marmalade/blob/main/pact/simple-one-off-collection-policy.pact) contract by Kadena. It shouldn't be difficult to extend this contract to accommodate that kind of interaction.
If you don't auto-reveal, then the lambda function in the AWS Stack can be commented out. You don't need it.

If you also wish to not use chain 8 marmalade ledger, it's pretty easy to fork it and use it on a different chain, you will just have to deploy that smart contract as well. 

## To Deploy

### The smart contracts

Each contract can be deployed using easily with the `nft-init-data-test.json` or `nft-init-data.json` used as your environment data.

I'm assuming that you have changed the namge of the module in each smart contract (i.e `nft-perms` -> `your-perms`), but that the name of the file is the same.

If you are using [KadenaKode](https://kadenakode.luzzotica.xyz/), the steps to deploy your smart contact are:

1. Modify the json file you wish to use with all your collection's information
  1. Generate your provenence hash (If you care) using the python script in `scripts` folder and add it to the data.
```bash
python3 generate_provenance_hash.py -p PATH_TO_NFT_DIR -b AWS_BUCKET_URL -o PATH_TO_OUTPUT_DIR
```
  2. Update the collection name, tier start and end dates, the cost during each tier, etc. 
  3. Add the whitelist accounts to each of the objects in the `tier-data` list.
  4. Update the guards for gov, ops, and the bank (You want your money)
2. Copy the json data into the Env Data in KadenaKode
3. Copy the `nft-perms.pact` contract into the code area, and send it
4. Copy the `nft-policy.pact` contract into the code area, and send it, you will have to wait for perms to complete.
5. Copy the `nft-mint.pact` contract into the code area, and send it, you will have to wait for policy to complete.

You're done! Your contracts are in the wild and 100% initialized with your collection and ready to rumble.

### The AWS Stack

To deploy your AWS Stack, you need to use the AWS CLI and CDK. I'm assuming you have the AWS CLI setup and ready to rumble.

In the `auto-reveal` folder, run this command to enter into a python environment with all the necessary dependencies:
```bash
python3 -m venv .venv
```

Then run the following commands to build and deploy your stack:
```bash
cdk synth
STACK=nft CHAIN_ID=8 NFT_CONTRACT=free.nft-mint POLICY_CONTRACT=free.nft-policy COLLECTION=nft-prod cdk deploy
```

Once you've finished the stack deployment, you will need to generate a secret key for Kadena that the auto-reveal lambda function can use to mint NFTs for your purchasers.

I do this with `pact -g` in my command line. This only works if you've installed pact via Homebrew using `brew install pact`.

Once you've generated those keys you need to run this command:
```bash
aws secretsmanager put-secret-value \
  --secret-id OpsKeyset \
  --profile $PROFILE \
  --secret-string '{"priv_key":"YOUR_PRIV_KEY", "pub_key":"YOUR_PUB_KEY"}'
```
You will then need to fund that key.
I would save the key somewhere safe and secure as well for future reference. Like if you want to deploy on Testnet and Mainnet, or if you have to fund it with more KDA.

Your bucket is also ready to hold your NFTs, you can copy your data into it from your local machine using this command:
```bash
aws s3 cp path/to/your/local/folder/ s3://YOUR_STACK_BUCKET -recursive
```

And it's ready to go!

### The Website

Once you've modified the website to your pleasure, all you need to do is update the .env files to point at your smart contract and bucket and it will just work.

I normally use netlify to deploy my website, as it allows me to build multiple branches for dev/test/prod networks really easily.

### All done!
You've finished everything! Your contracts are deployed, your stack is ready, and your 