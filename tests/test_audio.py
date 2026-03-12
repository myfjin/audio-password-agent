"""Tests for audio steganography utilities."""
import pytest
import tempfile
import wave
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from core.audio import AudioSteganography


@pytest.fixture
def temp_wav_file():
    with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as f:
        filename = f.name
    with wave.open(filename, 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(44100)
        wav.writeframes(b'\x00\x00' * 44100)
    yield filename
    if os.path.exists(filename):
        os.unlink(filename)


class TestAudioSteganography:
    def test_embed_and_extract(self, temp_wav_file):
        original_data = b"Secret message 123"
        AudioSteganography.embed_data(temp_wav_file, original_data)
        extracted = AudioSteganography.extract_data(temp_wav_file, len(original_data))
        assert extracted == original_data
    
    def test_validate_audio_file(self, temp_wav_file):
        is_valid, msg = AudioSteganography.validate_audio_file(temp_wav_file)
        assert is_valid is True
    
    def test_validate_nonexistent_file(self):
        is_valid, msg = AudioSteganography.validate_audio_file("/nonexistent/file.wav")
        assert is_valid is False
