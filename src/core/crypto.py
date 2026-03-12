"""Cryptographic utilities for password encryption and key derivation."""

import base64
import hashlib

from cryptography.fernet import Fernet


class CryptoManager:
    """Handles encryption/decryption operations."""
    
    SALT = b"audio_pwd_manager_salt_v1"
    
    @staticmethod
    def derive_key(password: str) -> bytes:
        """Derive encryption key from master password using SHA256."""
        key_material = password.encode() + CryptoManager.SALT
        for _ in range(100000):
            key_material = hashlib.sha256(key_material).digest()
        key_material = key_material[:32]
        return base64.urlsafe_b64encode(key_material)
    
    @staticmethod
    def encrypt(data: str, key: bytes) -> bytes:
        """Encrypt data using Fernet."""
        cipher = Fernet(key)
        return cipher.encrypt(data.encode())
    
    @staticmethod
    def decrypt(encrypted_data: bytes, key: bytes) -> str:
        """Decrypt data using Fernet."""
        cipher = Fernet(key)
        return cipher.decrypt(encrypted_data).decode()
