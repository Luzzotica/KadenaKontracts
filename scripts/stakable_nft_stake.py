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

payload = {
  "exec": {
    "data": {
      "nft-staker-admin": { "keys": [key_pair.get_pub_key()], "pred": "keys-all"}
    },
    "code": f'(free.marmalade-nft-staker.stake "k:{key_pair.get_pub_key()}" (read-keyset "nft-staker-admin") "pool-test" "stakable-nft" 10.0)',
  }
}
signers = [
  {
    "pubKey": key_pair.get_pub_key(),
    "clist": [
      {
        "name": "marmalade.ledger.TRANSFER",
        "args": ["stakable-nft", f"k:{key_pair.get_pub_key()}", "m:free.marmalade-nft-staker:pool-test", 10.0]
      },
      {
        "name": "coin.GAS",
        "args": []
      }
    ],
  }
]

cmd = sdk.build_command(f'k:{key_pair.get_pub_key()}', payload, signers)
# result = sdk.local(cmd)
# print(result.text)

result = sdk.send_and_listen(cmd)
print(result.text)