#### Creating Your Keyring

This library relies on python [keyring](https://pypi.org/project/keyring/) to pull in your private keys.

To setup your private key in the keyring:
`keyring set kadena deploy`
Then paste in your private key.

You will also need to create your own `keys.json` file. An example has been created for you, simply copy it and fill in your public key. `keys.json` is in the gitignore. It will not be pushed to the repo or any repo.