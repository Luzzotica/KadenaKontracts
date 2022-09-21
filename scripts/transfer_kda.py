import json

from kadena_sdk.kadena_sdk import KadenaSdk
from kadena_sdk.key_pair import KeyPair

import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-p') # Pub key
parser.add_argument('-t') # To
parser.add_argument('-a') # Amount
args = parser.parse_args()

pub_key = args.p
to_account = args.t
amount = args.a

TESTNET = {
  'base_url': 'https://api.testnet.chainweb.com',
  'network_id': 'testnet04',
  'chain_id': '1',
}
NETWORK = TESTNET

key_pair = KeyPair('keys.json')
sdk = KadenaSdk(key_pair, 
  NETWORK['base_url'], 
  NETWORK['network_id'], 
  NETWORK['chain_id'])

payload = {
  "exec": {
    "data": None,
    "code": f"(coin.transfer \"k:{pub_key}\" \"{to_account}\" {amount}.0)"
  }
}
signers = [
  {
    "pubKey": pub_key,
    "clist": [
      {
        "name": "coin.TRANSFER",
        "args": [f"k:{pub_key}", to_account, float(amount)]
      },
      {
        "name": "coin.GAS",
        "args": []
      }
    ],
  }
]

cmd = sdk.build_command(f'k:{pub_key}', payload, signers)
result = sdk.local(cmd)
print(result.text)
# print(json.dumps(cmd))