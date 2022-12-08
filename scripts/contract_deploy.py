
from kadena_sdk.kadena_sdk import KadenaSdk
from kadena_sdk.key_pair import KeyPair

import argparse
parser = argparse.ArgumentParser()
parser.add_argument('-p') # Contract path
parser.add_argument('-n') # Contract name
parser.add_argument('-i') # Init, providing a value means it's true
args = parser.parse_args()

# Setup Endpoint and Keys
CONTRACT_PATH = args.p
CONTRACT_NAME = args.n
init = args.i != None

MAINNET = {
  'base_url': 'https://api.chainweb.com',
  'network_id': 'mainnet01',
  'chain_id': '1',
}
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

print(f'Deploying {CONTRACT_NAME} located at {CONTRACT_PATH}. Initialize: {init}')

contract_content = ''
with open(CONTRACT_PATH, 'r') as f:
  contract_content = f.read()

payload = {
  "exec": {
    "data": {
      "gov": { "keys": ["aeecd476ad8a4842ec84f3fbdad39b73fe7329fb4feaa3ea4367314a29a7e42b"], "pred": "="},
      "ops": { "keys": ["aeecd476ad8a4842ec84f3fbdad39b73fe7329fb4feaa3ea4367314a29a7e42b"], "pred": "="},
      "tier-data": [
        {
          "rarity": "Pink",
          "min-hash-rate": 1,
          "cost-per-th-usd": 680.0
        },
        {
          "rarity": "Blue",
          "min-hash-rate": 5,
          "cost-per-th-usd": 650.0
        },
        {
          "rarity": "Gold",
          "min-hash-rate": 10,
          "cost-per-th-usd": 599.0
        },
        {
          "rarity": "Spectrum",
          "min-hash-rate": 20,
          "cost-per-th-usd": 550.0
        },
        {
          "rarity": "Spectrum",
          "min-hash-rate": 40,
          "cost-per-th-usd": 530.0
        }
      ],
      "bank-account": "k:aeecd476ad8a4842ec84f3fbdad39b73fe7329fb4feaa3ea4367314a29a7e42b",
      "init": init
    },
    "code": contract_content,
  }
}
signers = [
  {
    "pubKey": key_pair.get_pub_key(),
    # Unrestricted signing key!
  }
]

print()
cmd = sdk.build_command(f'k:{key_pair.get_pub_key()}', payload, signers)
result = sdk.local(cmd)
# result = sdk.send_and_listen(cmd)
print(result.text)

print()