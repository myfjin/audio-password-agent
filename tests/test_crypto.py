"""Tests for cryptography utilities."""
import pytest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from core.crypto import CryptoManager


class TestCryptoManager:
    def test_key_derivation(self):
        key1 = CryptoManager.derive_key("password123")
        key2 = CryptoManager.derive_key("password123")
        assert key1 == key2
    
    def test_different_passwords_different_keys(self):
        key1 = CryptoManager.derive_key("password1")
        key2 = CryptoManager.derive_key("password2")
        assert key1 != key2
    
    def test_encrypt_decrypt(self):
        key = CryptoManager.derive_key("test_password")
        original = "secret_token_123"
        encrypted = CryptoManager.encrypt(original, key)
        decrypted = CryptoManager.decrypt(encrypted, key)
        assert decrypted == original
    
    def test_wrong_key_fails(self):
        key1 = CryptoManager.derive_key("password1")
        key2 = CryptoManager.derive_key("password2")
        encrypted = CryptoManager.encrypt("secret", key1)
        with pytest.raises(Exception):
            CryptoManager.decrypt(encrypted, key2)
