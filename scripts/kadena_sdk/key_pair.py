import json


class KeyPair():

  def __init__(self, key_file='', type='keyring', **kwargs):
    if type == 'keyring':
      with open(key_file, 'r') as f:
        import keyring
        text = f.read()
        jason = json.loads(text)
        priv_key_info = jason['priv_key']
        self.priv_key = keyring.get_password(priv_key_info['service'], priv_key_info['username'])
        self.pub_key = jason['pub_key']
    elif type == 'json':
      self.priv_key = kwargs['priv_key']
      self.pub_key = kwargs['pub_key']
    elif type == 'pub_only':
      self.priv_key = ''
      self.pub_key = kwargs['pub_key']
  

  def get_priv_key(self):
    return self.priv_key
  

  def get_pub_key(self):
    return self.pub_key