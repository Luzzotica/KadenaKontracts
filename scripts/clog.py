from kadena_sdk.kadena_sdk import KadenaSdk
from kadena_sdk.key_pair import KeyPair
import time

# Code to run
PACT_CODE = '"Clog"'

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
    },
    "code": PACT_CODE,
  }
}
signers = [
  {
    "pubKey": key_pair.get_pub_key()
  }
]

def job():
  cmd = sdk.build_command(f'k:{key_pair.get_pub_key()}', 
    payload, signers, gas_limit=150000, gas_price=1e-4)
  result = sdk.send(cmd)
  print(result.text)

while True:
  job()
  time.sleep(20)