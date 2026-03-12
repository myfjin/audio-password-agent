from setuptools import setup, find_packages

setup(
    name="audio-password-agent",
    version="0.1.0",
    description="Audio steganography password manager with LM Studio integration",
    author="myfjin",
    python_requires=">=3.10",
    packages=find_packages(),
    install_requires=[
        "fastapi==0.104.1",
        "uvicorn[standard]==0.24.0",
        "pydantic==2.5.0",
        "cryptography==41.0.7",
        "pydantic-settings==2.1.0",
        "python-dotenv==1.0.0",
    ],
)
