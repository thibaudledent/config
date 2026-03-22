#!/bin/bash
# Usage: ./compress-docx.sh input.docx output.docx

FILE=$1
TARGET=$2
TEMP_DIR="docx_tmp"

# 1. Unpack the docx (it's just a zip)
unzip -q "$FILE" -d "$TEMP_DIR"

# 2. Convert all PNGs to JPGs using mogrify
# -format jpg: creates new jpg files
# -background white -flatten: ensures transparency becomes white
# -quality 65
cd "$TEMP_DIR/word/media"
if ls *.png >/dev/null 2>&1; then
    mogrify -format jpg -background white -flatten -quality 65 *.png
    rm *.png
fi
cd ../../..

# 3. Update the internal XML relationships
# This swaps every mention of .png to .jpg so Word finds the new files
find "$TEMP_DIR/word/_rels" -name "*.rels" -exec sed -i 's/\.png/\.jpg/g' {} +
find "$TEMP_DIR/word" -name "*.xml" -exec sed -i 's/\.png/\.jpg/g' {} +

# 4. Repack the folder back into a .docx
cd "$TEMP_DIR"
zip -qr "../$TARGET" *
cd ..

# 5. Cleanup
rm -rf "$TEMP_DIR"

echo "Done! Compressed file saved as: $TARGET"
