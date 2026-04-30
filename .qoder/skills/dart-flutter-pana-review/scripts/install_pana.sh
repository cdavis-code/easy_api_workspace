#!/bin/bash

# Install pana if not already installed
# This script ensures pana is available for package analysis

set -e

echo "Checking if pana is installed..."

# Check if pana is in PATH
if command -v pana &> /dev/null; then
    echo "✓ pana is already installed"
    pana --version
    exit 0
fi

echo "pana is not installed. Installing..."

# Install pana globally using dart pub
dart pub global activate pana

# Verify installation
if command -v pana &> /dev/null; then
    echo "✓ pana successfully installed"
    pana --version
else
    echo "✗ Failed to install pana"
    echo "Please ensure dart is in your PATH and try: dart pub global activate pana"
    exit 1
fi