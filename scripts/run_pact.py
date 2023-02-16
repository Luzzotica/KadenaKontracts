
from kadena_sdk.kadena_sdk import KadenaSdk
from kadena_sdk.key_pair import KeyPair

# Code to run
PACT_CODE = '"hello"'

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
sdk = KadenaSdk(key_pair=key_pair)

payload = {
  "exec": {
    "data": {},
    "code": PACT_CODE,
  }
}

print()
print('wswag')
cmd = sdk.build_command(payload, chain_ids=['0'])
result = sdk.local(cmd)
print(result)
print(result['0'].text)

print()
print(cmd)
result_send = sdk.send(cmd)
print()
print(result_send['0'].text)
# result = sdk.send_and_listen(cmd)
# print(result.text)

print()