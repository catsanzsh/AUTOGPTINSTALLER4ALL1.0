#!/usr/bin/env bash

# Auto-GPT v0.4.9 installation script for macOS M1/M2

echo "== Step 1: Checking Homebrew installation =="
# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
  echo "Homebrew not found. Installing Homebrew..."
  # Install Homebrew (official script)
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ $? -ne 0 ]; then
    echo "Error: Homebrew installation failed. Aborting." >&2
    exit 1
  fi
  # Add Homebrew to PATH for the current script session (especially for Apple Silicon)
  echo "Homebrew installed successfully. Configuring environment..."
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "Homebrew is already installed."
  # Make sure Homebrew is up to date (optional):
  brew update
fi

echo "== Step 2: Installing Python3, Git, and Docker (via Homebrew) =="
# Install Python3
if ! command -v python3 &> /dev/null; then
  echo "Installing Python3..."
  brew install python || { echo "Error: Failed to install Python3." >&2; exit 1; }
else
  echo "Python3 is already installed."
fi
# Install Git
if ! command -v git &> /dev/null; then
  echo "Installing Git..."
  brew install git || { echo "Error: Failed to install Git." >&2; exit 1; }
else
  echo "Git is already installed."
fi
# Install Docker (Docker Desktop for Mac)
if ! command -v docker &> /dev/null; then
  echo "Installing Docker Desktop..."
  brew install --cask docker || { echo "Error: Failed to install Docker." >&2; exit 1; }
  echo "Docker installed. You may need to start Docker Desktop manually to finish setup."
else
  echo "Docker is already installed."
fi

echo "== Step 3: Cloning Auto-GPT v0.4.9 repository =="
# Clone the Auto-GPT repository at the specified version
REPO_URL="https://github.com/Significant-Gravitas/AutoGPT.git"
VERSION_TAG="autogpt-platform-beta-v0.4.9"
# Check if target directory already exists
if [ -d "AutoGPT" ]; then
  echo "Error: Directory 'AutoGPT' already exists. Please remove/rename it and rerun the script." >&2
  exit 1
fi
echo "Cloning Auto-GPT repository (version $VERSION_TAG)..."
git clone -b "$VERSION_TAG" "$REPO_URL" AutoGPT || { echo "Error: Failed to clone Auto-GPT repo." >&2; exit 1; }
cd AutoGPT || { echo "Error: Could not enter AutoGPT directory." >&2; exit 1; }

echo "== Step 4: Setting up Python virtual environment =="
# Create a Python virtual environment (venv)
python3 -m venv venv || { echo "Error: Failed to create Python virtual environment." >&2; exit 1; }
# Activate the virtual environment
# shellcheck source=/dev/null
source venv/bin/activate || { echo "Error: Failed to activate virtual environment." >&2; exit 1; }
echo "Virtual environment created and activated."

echo "== Step 5: Installing Python dependencies =="
# Upgrade pip to latest (for compatibility on M1/M2)
echo "Upgrading pip..."
pip install --upgrade pip
# Install the required Python packages from requirements.txt
if [ -f "requirements.txt" ]; then
  echo "Installing packages from requirements.txt (this may take a moment)..."
  pip install -r requirements.txt || { echo "Error: Failed to install Python dependencies." >&2; deactivate; exit 1; }
else
  echo "Error: requirements.txt not found. Aborting." >&2
  deactivate
  exit 1
fi

echo "== Step 6: Configuring environment variables =="
# Rename .env.template to .env
if [ -f ".env.template" ]; then
  mv .env.template .env
else
  echo "Error: .env.template file not found. Aborting." >&2
  deactivate
  exit 1
fi
echo "'.env.template' has been renamed to '.env'."

# Prompt user for API keys to update .env
# OpenAI API Key (required)
read -s -p "Enter your OpenAI API Key: " OPENAI_KEY
echo ""
if [ -z "$OPENAI_KEY" ]; then
  echo "Error: OpenAI API key is required to run Auto-GPT. Please obtain an API key and rerun the script." >&2
  deactivate
  exit 1
fi
# Update OpenAI key in .env
sed -i '' -e "s|^OPENAI_API_KEY=.*|OPENAI_API_KEY=$OPENAI_KEY|" .env

# Pinecone API Key (optional)
read -s -p "Enter your Pinecone API Key (press Enter to skip): " PINECONE_KEY
echo ""
if [ -n "$PINECONE_KEY" ]; then
  # Pinecone environment (region) is needed if key is provided
  read -p "Enter your Pinecone Environment (e.g., us-west4, or press Enter to skip): " PINECONE_ENV
  # Update Pinecone settings in .env
  sed -i '' -e "s|^PINECONE_API_KEY=.*|PINECONE_API_KEY=$PINECONE_KEY|" .env
  if [ -n "$PINECONE_ENV" ]; then
    sed -i '' -e "s|^PINECONE_ENV=.*|PINECONE_ENV=$PINECONE_ENV|" .env
  else
    echo "Warning: No Pinecone environment provided. You may need to edit .env later to set PINECONE_ENV for Pinecone to work."
  fi
fi

echo "API keys have been configured in the .env file."

echo "== Step 7: Launching Auto-GPT =="
echo "Activating virtual environment and starting Auto-GPT..."
# (The venv is already activated at this point)
python3 -m autogpt 2>/dev/null || python3 main.py

# Note: The above tries "python3 -m autogpt" (if autogpt is installed as module) 
# and falls back to "python3 main.py" to run Auto-GPT. Any errors are suppressed to avoid confusion.
# When Auto-GPT exits, deactivate the virtual environment and end script.
deactivate
