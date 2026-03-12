"""Audio steganography utilities for hiding data in WAV files."""

import wave
from pathlib import Path
from typing import Tuple


class AudioSteganography:
    """Handles hiding and extracting data in audio files using LSB encoding."""
    
    @staticmethod
    def embed_data(audio_file: str, data: bytes, output_file: str = None) -> str:
        """
        Embed binary data in audio file using LSB steganography.
        
        Args:
            audio_file: Path to WAV file
            data: Binary data to hide
            output_file: Output path (defaults to overwriting input)
            
        Returns:
            Path to output file
        """
        if output_file is None:
            output_file = audio_file
        
        try:
            with wave.open(audio_file, 'rb') as audio:
                frames = bytearray(list(audio.readframes(audio.getnframes())))
                params = audio.getparams()
        except Exception as e:
            raise IOError(f"Failed to read audio file: {str(e)}")
        
        binary_data = ''.join(format(byte, '08b') for byte in data)
        
        if len(binary_data) > len(frames):
            raise ValueError(
                f"Audio file too small: need {len(binary_data)} bits, have {len(frames)} bits"
            )
        
        for i, bit in enumerate(binary_data):
            frames[i] = (frames[i] & 0xFE) | int(bit)
        
        try:
            with wave.open(output_file, 'wb') as output:
                output.setparams(params)
                output.writeframes(bytes(frames))
        except Exception as e:
            raise IOError(f"Failed to write audio file: {str(e)}")
        
        return output_file
    
    @staticmethod
    def extract_data(audio_file: str, max_bytes: int = None) -> bytes:
        """Extract hidden data from audio file."""
        try:
            with wave.open(audio_file, 'rb') as audio:
                frames = bytearray(list(audio.readframes(audio.getnframes())))
        except Exception as e:
            raise IOError(f"Failed to read audio file: {str(e)}")
        
        binary_data = ''.join(str(frame & 1) for frame in frames)
        
        extracted = bytearray()
        num_bytes = max_bytes if max_bytes else len(binary_data) // 8
        
        for i in range(0, min(num_bytes * 8, len(binary_data)) - 7, 8):
            byte = int(binary_data[i:i+8], 2)
            extracted.append(byte)
        
        return bytes(extracted).rstrip(b'\x00')
    
    @staticmethod
    def validate_audio_file(audio_file: str) -> Tuple[bool, str]:
        """Validate that file is a readable WAV file."""
        path = Path(audio_file)
        
        if not path.exists():
            return False, f"File not found: {audio_file}"
        
        if path.suffix.lower() != '.wav':
            return False, f"File must be WAV format, got {path.suffix}"
        
        try:
            with wave.open(audio_file, 'rb') as audio:
                nframes = audio.getnframes()
                if nframes < 100:
                    return False, "Audio file too small (< 100 samples)"
        except Exception as e:
            return False, f"Invalid WAV file: {str(e)}"
        
        return True, "Valid WAV file"
