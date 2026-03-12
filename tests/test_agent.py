"""Tests for AudioPasswordAgent."""
import pytest
import tempfile
import wave
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from core.agent import AudioPasswordAgent


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


@pytest.fixture
def agent():
    return AudioPasswordAgent(master_password="test_password_123")


class TestAudioPasswordAgent:
    def test_agent_initialization(self, agent):
        assert agent.master_password == "test_password_123"
        assert len(agent.stored_services) == 0
    
    def test_store_credential(self, agent, temp_wav_file):
        result = agent.store_credential(
            audio_file=temp_wav_file,
            service="github",
            username="testuser",
            password="testpass123"
        )
        assert result["status"] == "success"
        assert result["service"] == "github"
        assert "github" in agent.stored_services
    
    def test_retrieve_credential(self, agent, temp_wav_file):
        agent.store_credential(
            audio_file=temp_wav_file,
            service="github",
            username="testuser",
            password="testpass123"
        )
        result = agent.retrieve_credential(
            audio_file=temp_wav_file,
            service="github"
        )
        assert result["status"] == "success"
        assert result["service"] == "github"
        assert result["username"] == "testuser"
        assert result["password"] == "testpass123"
