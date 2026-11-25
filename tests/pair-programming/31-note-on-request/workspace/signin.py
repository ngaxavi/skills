import configparser
import hashlib
import hmac
import os
import secrets

config = configparser.ConfigParser()
config.read("config.ini")


def hash_password(password):
    salt = os.urandom(16)
    key = hashlib.scrypt(password.encode(), salt=salt, n=2**14, r=8, p=1)
    return salt + key


def verify(password, stored):
    salt, key = stored[:16], stored[16:]
    candidate = hashlib.scrypt(password.encode(), salt=salt, n=2**14, r=8, p=1)
    return hmac.compare_digest(candidate, key)


def new_session(sessions, user):
    token = secrets.token_urlsafe(32)
    name = hmac.new(config["session"]["key"].encode(), token.encode(), "sha256").hexdigest()
    sessions[name] = user
    return token
