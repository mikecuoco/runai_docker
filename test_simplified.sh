#!/bin/bash
# Simple test script for the conda environments and build system
set -e

echo "=== Testing simplified bash scripts ==="

# Test 1: Check script syntax
echo "Testing script syntax..."
bash -n scripts/generate-lockfiles.sh
bash -n scripts/provision-gvl.sh  
bash -n scripts/user_env_install.sh
bash -n scripts/user_post_setup.sh
bash -n scripts/setup-dotfiles.sh
bash -n build.sh
echo "✅ All scripts have valid syntax"

# Test 2: Test build script help and list
echo ""
echo "Testing build script functionality..."
./build.sh --help > /dev/null
./build.sh --list > /dev/null
echo "✅ Build script help and list work"

# Test 3: Check environment files exist
echo ""
echo "Testing environment files..."
if [ -f "environments/gvl.yml" ]; then
    echo "✅ Main environment (gvl.yml) exists"
else
    echo "❌ Main environment (gvl.yml) missing"
    exit 1
fi

if [ -f "environments/test.yml" ]; then
    echo "✅ Test environment (test.yml) exists"
else
    echo "❌ Test environment (test.yml) missing"
    exit 1
fi

# Test 4: Check docker_images.txt is readable
echo ""
echo "Testing docker configuration..."
if [ -f "docker_images.txt" ]; then
    echo "✅ Docker images configuration exists"
    echo "Available images:"
    grep -v '^#' docker_images.txt | grep -v '^$' | while read line; do
        image_name=$(echo "$line" | cut -f1)
        echo "  - $image_name"
    done
else
    echo "❌ Docker images configuration missing"
    exit 1
fi

echo ""
echo "🎉 All tests passed! Scripts are simplified and working."