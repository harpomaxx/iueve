#!/bin/bash

# Exit on any error
set -e

echo "Starting Dollhouse Leak Fixer export process..."

# Copy the game to PICO-8 carts directory
echo "Copying game to PICO-8 carts directory..."
mkdir -p /home/harpo/.lexaloffle/pico-8/carts/
cp dollhouse_leak_fixer.p8 /home/harpo/.lexaloffle/pico-8/carts/

# Copy existing label if it exists
echo "Looking for existing label..."
LABEL_FILE=$(find /home/harpo/.lexaloffle/pico-8/ -maxdepth 1 -name "*_label.png" | head -1)
if [ -n "$LABEL_FILE" ] && [ "$LABEL_FILE" != "/home/harpo/.lexaloffle/pico-8/dollhouse_leak_fixer_label.png" ]; then
    echo "Copying existing label: $LABEL_FILE"
    cp "$LABEL_FILE" /home/harpo/.lexaloffle/pico-8/carts/dollhouse_leak_fixer_label.png
    cp "$LABEL_FILE" /home/harpo/.lexaloffle/pico-8/dollhouse_leak_fixer_label.png
else
    echo "Label already exists or no label file found"
fi

# Create js subdirectory if it doesn't exist
mkdir -p js

# Run PICO-8 with headless export
echo "Running PICO-8 export..."
cd ~/Downloads/pico-8
# First create a .p8.png with the label, then export to HTML
./pico8 /home/harpo/.lexaloffle/pico-8/carts/dollhouse_leak_fixer.p8 -export dollhouse_temp.p8.png
if [ -f "dollhouse_temp.p8.png" ]; then
    echo "Created .p8.png, now exporting to HTML..."
    ./pico8 dollhouse_temp.p8.png -export iueve.html
    rm dollhouse_temp.p8.png
else
    echo "Failed to create .p8.png file"
fi

# Check what files were created and move them
echo "Checking for exported files..."
cd ~/Downloads/pico-8
if [ -f "iueve.html" ]; then
    echo "Moving HTML file..."
    mv iueve.html /home/harpo/Dropbox/ongoing-work/git-repos/iueve/js/
else
    echo "HTML file not found in ~/Downloads/pico-8/"
    ls -la *.html 2>/dev/null || echo "No HTML files found"
fi

if [ -f "iueve.js" ]; then
    echo "Moving JS file..."
    mv iueve.js /home/harpo/Dropbox/ongoing-work/git-repos/iueve/js/
else
    echo "JS file not found in ~/Downloads/pico-8/"
    ls -la *.js 2>/dev/null || echo "No JS files found"
fi

echo "Export complete! Files are now in js/ directory:"
echo "  - js/iueve.html (main file)"
echo "  - js/iueve.js (game code)"
