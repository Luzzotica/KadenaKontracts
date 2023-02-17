import os
import requests
import json
from kadena_sdk.kadena_sdk import KadenaSdk
from kadena_sdk.key_pair import KeyPair

import boto3
from botocore.exceptions import ClientError

SECRET_NAME = os.environ['SECRET_NAME']
BUCKET = os.environ['BUCKET']
REGION = os.environ['REGION']
KADENA_NODE_URL = os.environ['KADENA_NODE_URL']
CHAIN_ID = os.environ['CHAIN_ID']
NFT_CONTRACT = os.environ['NFT_CONTRACT']
POLICY_CONTRACT = os.environ['POLICY_CONTRACT']
COLLECTION = os.environ['COLLECTION']

def get_secret():
    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
      service_name='secretsmanager',
      region_name=REGION
    )

    try:
      get_secret_value_response = client.get_secret_value(
        SecretId=SECRET_NAME
      )
    except ClientError as e:
        # For a list of exceptions thrown, see
        # https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetSecretValue.html
        raise e

    # Decrypts secret using the associated KMS key.
    secret = get_secret_value_response['SecretString']

    # Your code goes here.
    return secret


def get_minted_nfts(kadena):
  payload = {
    "exec": {
      "data": {},
      "code": f'({NFT_CONTRACT}.get-unrevealed-tokens-for-collection "{COLLECTION}")'
    }
  }

  cmd = kadena.build_command(payload, [CHAIN_ID], gas_limit=150000)
  resp = kadena.local(cmd)
  respJson = resp[CHAIN_ID].json()
  return respJson['result']['data']


def reveal_nft(kadena, minted_token, url, datum, send_local=False):
    
  # Get the hash of the token
  minted_token['hash'] = kadena.run_pact('''
    (let*
      (
        (uri (kip.token-manifest.uri (read-msg "scheme") (read-msg "data")))
        (datum-complete (kip.token-manifest.create-datum uri (read-msg "datum")))
        (manifest (kip.token-manifest.create-manifest uri [datum-complete]))
      )
      (at "hash" manifest)
    )
    ''',
    env_data={
      'scheme': 'https',
      'data': url,
      'datum': datum,
    })['data']
  
  signers = [
    {
      "pubKey": kadena.key_pair.get_pub_key(),
      "clist": [
        {
          "name": "coin.GAS",
          "args": []
        },
        {
          "name": "free.nft-mint.OPS",
          "args": []
        },
        {
          "name": "free.nft-policy.OPS",
          "args": []
        },
        {
          'name': 'marmalade.ledger.MINT',
          'args': [f't:{minted_token["hash"]}', minted_token["account"], 1]
        }
      ]
    }  
  ]
  
  payload = {
    "exec": {
      "data": {
        "m-token": minted_token,
        "t-token": {
          "scheme": "https",
          "data": url,
          "datum": datum,
        },
      },
      "code": f'''
({NFT_CONTRACT}.reveal-token 
  (read-msg "m-token") 
  (read-msg "t-token")
  0
  {POLICY_CONTRACT}
)
'''
    }
  }

  cmd = kadena.build_command(payload, [CHAIN_ID], signers=signers, gas_limit=2500, gas_price=1e-8)
  if send_local:
    resp = kadena.local(cmd)[CHAIN_ID]
    return resp.json()
  else:
    return kadena.send(cmd)[CHAIN_ID].json()

def lambda_handler(event, context):
    pub_priv_key = json.loads(get_secret())

    kp = KeyPair(type='json', 
      priv_key=pub_priv_key['priv_key'],
      pub_key=pub_priv_key['pub_key'])
    kadena = KadenaSdk(key_pair=kp, base_url=KADENA_NODE_URL)

    minted_nfts = get_minted_nfts(kadena)

    for minted_nft in minted_nfts:
      # Get the token id from the minted nft
      id = minted_nft['token-id']['int']

      # From the s3 bucket, get the json file, and reveal the image
      s3 = boto3.client('s3')
      marm_token_file = s3.get_object(Bucket=BUCKET, Key=f'{id}.json')
      marm_token_datum = json.loads(marm_token_file['Body'].read().decode('utf-8'))
      s3.put_object_tagging(
        Bucket=BUCKET,
        Key=f'{id}.gif',
        Tagging={'TagSet': [{'Key': 'revealed', 'Value': 'yes'}]}
      )
      s3.put_object_tagging(
        Bucket=BUCKET,
        Key=f'{id}.json',
        Tagging={'TagSet': [{'Key': 'revealed', 'Value': 'yes'}]}
      )
      url = f'{BUCKET}.s3.{REGION}.amazonaws.com/{id}.gif'

      # Reveal the nft
      print('')
      print(reveal_nft(kadena, minted_nft, url, marm_token_datum, send_local=False))

    return {
        'statusCode': 200,
        'body': json.dumps('success')
    }
