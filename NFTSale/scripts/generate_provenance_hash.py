import os
import json
from kadena_sdk import *
import argparse

# Use arguments to get the path to the directory
# and the directory to put the hashes in
argparser = argparse.ArgumentParser()
argparser.add_argument('-p', help='Path to the directory')
argparser.add_argument('-b', help='The aws bucket url')
argparser.add_argument('-o', help='Directory to put the hashes in')
args = argparser.parse_args()

hashes = []

breaker = 0

filelist = os.listdir(args.p)
# Filter our the non json files
filelist = list(filter(lambda x: x.endswith('.json'), filelist))
# Sort the files based on their number
filelist.sort(key=lambda x: int(x.split('.')[0]))


kda = KadenaSdk()

def create_token_datum(file_data):
  return {
    'file_hash': blake_hash(file_data),
  }

# Loop through each json file in a directory
for filename in filelist:
  path = os.path.join(args.p, filename)
  
  # Open the file
  with open(path, 'r') as f:
    # Load the json file
    file_data = f.read()
    token_datum = create_token_datum(file_data)
    bucket_path = os.path.join(args.b, token_datum['image'])
    uri = {
      "data": bucket_path,
      "scheme": "https",
    }
    datum = {
      "hash": blake_hash({ "data": [blake_hash(token_datum)], "uri": uri}),
      "uri": uri,
      "datum": token_datum
    }
    manifest = {
      "hash": blake_hash({ "data": [datum['hash']], "uri": uri}),
      "uri": uri,
      "data": [
        datum
      ]
    }
    # Print the hash
    

#     pact_data = kda.run_pact('''
# (let*
#   (
#     (uri (kip.token-manifest.uri (read-msg "scheme") (read-msg "data")))
#     (datum-complete (kip.token-manifest.create-datum uri (read-msg "datum")))
#     (manifest (kip.token-manifest.create-manifest uri [datum-complete]))
#     (token-id (concat ["t:" (at "hash" manifest)]))
#   )
#   manifest
# )
# ''', env_data={
#   'scheme': 'https',
#   'data': 'https://s3/' + token_datum['image'],
#   'datum': token_datum
# })['data']

#     # print(manifest['data'])
#     # print(pact_data['data'])
    
#     print(DeepDiff(manifest, pact_data))

#     assert(manifest['hash'] == pact_data['hash'])

    print(manifest['uri'])
    hashes.append(manifest['hash'])
    
  # breaker += 1
  # if breaker > 10:
  #   break

with open(os.path.join(args.o), 'w') as f:
  json.dump({ 
    'hashes': hashes, 
    'provenance': blake_hash({'hashes': hashes})
  }, f, indent=2)