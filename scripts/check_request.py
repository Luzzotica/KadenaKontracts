import requests
import argparse

PACT_SERVER = "https://api.testnet.chainweb.com/chainweb/0.0/testnet04/chain/1/pact/api/v1/listen"
# PACT_SERVER = "https://api.chainweb.com/chainweb/0.0/mainnet01/chain/2/pact/api/v1/listen"

parser = argparse.ArgumentParser()
parser.add_argument('-k')
args = parser.parse_args()

print(args.k)
data = {
  'listen': args.k
}

result = requests.post(PACT_SERVER, json=data)
print(result.content)
