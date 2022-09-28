from kadena_sdk.kadena_sdk import KadenaSdk
from kadena_sdk.key_pair import KeyPair

TOKEN_ID = "stakable-nft"

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

code = f"""
(marmalade.ledger.mint "{TOKEN_ID}" "k:{key_pair.get_pub_key()}" (read-keyset "nft-staker-admin") 10.0)
"""

payload = {
  "exec": {
    "data": {
      "nft-staker-admin": { "keys": [key_pair.get_pub_key()], "pred": "keys-all"},
      "mint-guard": { "keys": [key_pair.get_pub_key()], "pred": "keys-all"},
      "burn-guard": { "keys": [key_pair.get_pub_key()], "pred": "keys-all"},
      "sale-guard": { "keys": [key_pair.get_pub_key()], "pred": "keys-all"},
      "transfer-guard": { "keys": [key_pair.get_pub_key()], "pred": "keys-all"}
    },
    "code": code,
  }
}

signers = [
  {
    "pubKey": key_pair.get_pub_key(),
    "clist": [
      {
        "name": "marmalade.ledger.MINT",
        "args": [f"{TOKEN_ID}", f"k:{key_pair.get_pub_key()}", 10.0]
      },
      {
        "name": "coin.GAS",
        "args": []
      }
    ],
  }
]

cmd = sdk.build_command(f"k:{key_pair.get_pub_key()}", payload, signers)
# result = sdk.local(cmd)
result = sdk.send_and_listen(cmd)
print(result.text)