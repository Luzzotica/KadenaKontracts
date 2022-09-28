import json

from kadena_sdk.kadena_sdk import KadenaSdk
from kadena_sdk.key_pair import KeyPair

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

# (install-capability (free.marmalade-nft-staker.UNSTAKE (read-keyset "nft-staker-admin"))) 
payload = {
  "exec": {
    "data": {
      "nft-staker-admin": { "keys": [key_pair.get_pub_key()], "pred": "keys-all"}
    },
    "code": f'(free.marmalade-nft-staker-3.unstake "k:{key_pair.get_pub_key()}" "pool-test" "stakable-nft")',
  }
}
signers = [
  {
    "pubKey": key_pair.get_pub_key(),
    "clist": [
      {
        "name": "free.marmalade-nft-staker-3.UNSTAKE",
        "args": ["pool-test", f"k:{key_pair.get_pub_key()}"]
      },
      {
        "name": "coin.GAS",
        "args": []
      }
    ],
  }
]

cmd = sdk.build_command(f'k:{key_pair.get_pub_key()}', payload, signers)
result = sdk.local(cmd)
print(result.text)

# result = sdk.send_and_listen(cmd)
# print(result.text)