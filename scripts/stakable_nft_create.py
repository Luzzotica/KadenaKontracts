from kadena_sdk.kadena_sdk import KadenaSdk
from kadena_sdk.key_pair import KeyPair

TOKEN_ID = "stakable-nft-2"

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
(marmalade.ledger.create-account "{TOKEN_ID}" "k:{key_pair.get_pub_key()}" (read-keyset "nft-staker-admin"))

(let* 
  (
    (uri (kip.token-manifest.uri "swag" "hello"))
    (datum (kip.token-manifest.create-datum uri {{"data":"cool"}} ))
    (manifest (kip.token-manifest.create-manifest uri [datum] ))
  )
  
  (marmalade.ledger.create-token "{TOKEN_ID}" 0 manifest free.token-policy-transfer)
  (install-capability (marmalade.ledger.MINT "{TOKEN_ID}" "k:{key_pair.get_pub_key()}" 10.0))
  (marmalade.ledger.mint "{TOKEN_ID}" "k:{key_pair.get_pub_key()}" (read-keyset "nft-staker-admin") 10.0)
)
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
# result = sdk.send_and_listen(cmd)
# print(result.text)

# Get the hash of the token
  test = sdk.run_pact('''
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
    },)