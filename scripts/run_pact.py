
from kadena_sdk.kadena_sdk import KadenaSdk
from kadena_sdk.key_pair import KeyPair

# Code to run
PACT_CODE = '(describe-keyset "free.nft-staker-admin")'

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

payload = {
  "exec": {
    "data": {
      "nft-staker-admin": { "keys": [key_pair.get_pub_key()], "pred": "keys-all"}
    },
    "code": PACT_CODE,
  }
}
signers = [
  {
    "pubKey": key_pair.get_pub_key(),
    "clist": [
      # {
      #   "name": f"{CONTRACT_NAME}.GOV",
      #   "args": []
      # },
      # {
      #   "name": "coin.GAS",
      #   "args": []
      # }
    ],
  }
]

print()
print('wswag')
cmd = sdk.build_command(f'k:{key_pair.get_pub_key()}', payload, signers)
result = sdk.local(cmd)
print(result.text)

# result = sdk.send_and_listen(cmd)
# print(result.text)

print()