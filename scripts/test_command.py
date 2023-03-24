from kadena_sdk import KadenaSdk, blake_hash
import requests
import json
import time

cmd = {"signedCmd":{"hash":"f6kzsOKBgw5BiLfy5dTG4ylSAVKNk0odN-3FCheRU1w","sigs":[{"sig":"13f471e45590eedaabcef99b4923813de65eff6cc316a4c9b561b8ae77521e0075bfe16ce3e626770cd3daf40d7eaf0a85bdd0ebd37788ec1201291b3c4e0a0f"}],"cmd":"{\"networkId\":\"mainnet01\",\"payload\":{\"exec\":{\"data\":{},\"code\":\"\\\"hello\\\"\"}},\"signers\":[{\"pubKey\":\"d2adf52af5b0c969763a2d536692ba2727cc042615c0de8d07c08d1e90a5d901\"}],\"meta\":{\"creationTime\":1679508599,\"ttl\":600,\"gasLimit\":2000,\"chainId\":\"1\",\"gasPrice\":1e-8,\"sender\":\"k:d2adf52af5b0c969763a2d536692ba2727cc042615c0de8d07c08d1e90a5d901\"},\"nonce\":\"\\\"\\\\\\\"XIDS-2023-03-22T18:10:49.155Z\\\\\\\"\\\"\"}"}}


# creationTime\":1678400246

sdk = KadenaSdk(base_url='https://api.chainweb.com')

t_epoch = time.time()
t_epoch = round(t_epoch) - 15
print(t_epoch)

# res = sdk.local({
#   '1': cmd
# })

url = sdk.build_url(sdk.LOCAL, '1')
url = f'{url}?preflight=true'
print(url)
res = requests.post(url, json=cmd['signedCmd'])

print(blake_hash(cmd['signedCmd']))
print(res.text)