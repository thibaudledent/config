#!/bin/bash
# Usage: ./compress-docx.sh input.docx output.docx [quality]

show_help() {
    cat <<EOF
Usage: $0 input.docx output.docx [quality]

Compresses images inside a .docx file to reduce its size.

Arguments:
  input.docx    Source .docx file
  output.docx   Destination .docx file
  quality       JPEG quality 1-100 (default: 65)

Options:
  -h, --help    Show this help message

Example:
  $0 big.docx small.docx 50
EOF
}

if [[ "$1" == "-h" || "$1" == "--help" || $# -lt 2 ]]; then
    show_help
    [[ $# -lt 2 && "$1" != "-h" && "$1" != "--help" ]] && exit 1
    exit 0
fi

FILE=$1
TARGET=$2
QUALITY=${3:-65}
TEMP_DIR="docx_tmp"

# 1. Unpack the docx (it's just a zip)
unzip -q "$FILE" -d "$TEMP_DIR"

# 2. Convert all images to JPGs using mogrify
MEDIA_DIR="$TEMP_DIR/word/media"
EMF_CONVERTED=0
if [ -d "$MEDIA_DIR" ]; then
    cd "$MEDIA_DIR"
    shopt -s nullglob nocaseglob

    # Convert EMF to PNG via LibreOffice (so it gets picked up by the loop below)
    emfs=( *.emf )
    if [ ${#emfs[@]} -gt 0 ]; then
        if command -v libreoffice >/dev/null 2>&1; then
            libreoffice --headless --convert-to png *.emf >/dev/null 2>&1
            rm -f *.emf
            EMF_CONVERTED=1
        else
            echo "WARNING: EMF files detected but 'libreoffice' is not installed. Skipping EMF compression." >&2
        fi
    fi

    # Raster formats -> JPG
    for ext in png gif bmp tiff tif webp jpeg; do
        files=( *.$ext )
        if [ ${#files[@]} -gt 0 ]; then
            mogrify -format jpg -background white -flatten -quality "$QUALITY" *.$ext
            rm -f *.$ext
        fi
    done
    # Recompress existing .jpg files too
    files=( *.jpg )
    if [ ${#files[@]} -gt 0 ]; then
        mogrify -background white -flatten -quality "$QUALITY" *.jpg
    fi
    shopt -u nullglob nocaseglob
    cd - >/dev/null
fi

# 3. Update the internal XML relationships
EXTS="png gif bmp tiff tif webp jpeg"
[ "$EMF_CONVERTED" -eq 1 ] && EXTS="$EXTS emf"
for ext in $EXTS; do
    find "$TEMP_DIR/word/_rels" -name "*.rels" -exec sed -i "" "s/\.$ext/\.jpg/gI" {} +
    find "$TEMP_DIR/word" -name "*.xml" -exec sed -i "" "s/\.$ext/\.jpg/gI" {} +
done

# 4. Repack the folder back into a .docx
cd "$TEMP_DIR"
zip -qr "../$TARGET" *
cd ..

# 5. Cleanup
rm -rf "$TEMP_DIR"

echo "Done! Compressed file saved as: $TARGET (quality: $QUALITY)"