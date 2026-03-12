"""Main AudioPasswordAgent for managing credentials with audio steganography."""

import json
from datetime import datetime
from typing import Dict, Optional

from core.crypto import CryptoManager
from core.audio import AudioSteganography


class AudioPasswordAgent:
    """
    Agent for storing and retrieving encrypted credentials hidden in audio files.
    """
    
    def __init__(self, master_password: str):
        """Initialize the agent with a master password."""
        self.master_password = master_password
        self.key = CryptoManager.derive_key(master_password)
        self.stored_services: Dict[str, Dict] = {}
    
    def store_credential(
        self,
        audio_file: str,
        service: str,
        username: str,
        password: str,
        metadata: Optional[Dict] = None,
        output_file: Optional[str] = None
    ) -> Dict:
        """Store encrypted credential in audio file."""
        try:
            is_valid, msg = AudioSteganography.validate_audio_file(audio_file)
            if not is_valid:
                return {
                    "status": "error",
                    "message": f"Audio validation failed: {msg}",
                    "service": service
                }
            
            encrypted_pwd = CryptoManager.encrypt(password, self.key)
            
            payload = {
                "service": service,
                "username": username,
                "encrypted_password": json.dumps({
                    "encrypted": encrypted_pwd.decode('utf-8'),
                    "algorithm": "Fernet"
                }),
                "timestamp": datetime.utcnow().isoformat(),
                "version": "1.0",
                "custom_metadata": metadata or {}
            }
            
            payload_json = json.dumps(payload).encode()
            out_file = output_file or audio_file
            AudioSteganography.embed_data(audio_file, payload_json, out_file)
            
            self.stored_services[service] = {
                "username": username,
                "audio_file": out_file,
                "timestamp": payload["timestamp"]
            }
            
            return {
                "status": "success",
                "message": f"✓ Credentials for '{service}' stored in {out_file}",
                "service": service,
                "username": username,
                "audio_file": out_file,
                "timestamp": payload["timestamp"]
            }
        
        except Exception as e:
            return {
                "status": "error",
                "message": f"Failed to store credentials: {str(e)}",
                "service": service
            }
    
    def retrieve_credential(self, audio_file: str, service: str) -> Dict:
        """Retrieve and decrypt credential from audio file."""
        try:
            is_valid, msg = AudioSteganography.validate_audio_file(audio_file)
            if not is_valid:
                return {
                    "status": "error",
                    "message": f"Audio validation failed: {msg}"
                }
            
            extracted = AudioSteganography.extract_data(audio_file)
            payload = json.loads(extracted.decode())
            
            if payload["service"] != service:
                return {
                    "status": "error",
                    "message": f"Audio file contains '{payload['service']}', not '{service}'"
                }
            
            encrypted_obj = json.loads(payload["encrypted_password"])
            encrypted_pwd = encrypted_obj["encrypted"].encode('utf-8')
            decrypted = CryptoManager.decrypt(encrypted_pwd, self.key)
            
            return {
                "status": "success",
                "service": service,
                "username": payload["username"],
                "password": decrypted,
                "stored_at": payload["timestamp"],
                "metadata": payload.get("custom_metadata", {})
            }
        
        except Exception as e:
            return {
                "status": "error",
                "message": f"Failed to retrieve credentials: {str(e)}"
            }
    
    def list_stored_services(self) -> Dict:
        """List all services stored."""
        return {
            "status": "success",
            "services": self.stored_services,
            "count": len(self.stored_services)
        }
