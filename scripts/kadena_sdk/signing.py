import ed25519
import base64
import hashlib

def hash_and_sign(cmd_json, pub_key, priv_key):
  # Turn the json into a byte string
  cmd_data = bytes(cmd_json, encoding="utf8")

  # Create the signature
  sk = ed25519.keys.SigningKey(bytes(priv_key, encoding="utf8"))
  signing_key = priv_key + pub_key
  sk.vk_s = bytes.fromhex(pub_key)
  sk.sk_s = bytes.fromhex(signing_key)

  # Create the hash code
  hash_bytes = blake2b(cmd_data)
  hash_code = base64.urlsafe_b64encode(hash_bytes).decode().rstrip('=')

  return hash_code, sk.sign(hash_bytes).hex()


def blake2b(bytes):
  hash2b = hashlib.blake2b(bytes, digest_size=32)
  return hash2b.digest()