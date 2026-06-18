#!/bin/bash

# generate_app_icons.sh
# Generates ALL required iOS App Icon sizes from a single 1024x1024 source image.
# Usage: ./Scripts/generate_app_icons.sh /path/to/your-1024-icon.png

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <1024x1024-png-file>"
    exit 1
fi

SOURCE="$1"
DEST="GrokCast/Resources/Assets.xcassets/AppIcon.appiconset"

echo "🎨 Generating complete iOS App Icons..."

# Safety check: ensure the source image is exactly 1024x1024 pixels
WIDTH=$(sips -g pixelWidth "$SOURCE" | tail -n 1 | awk '{print $2}')
HEIGHT=$(sips -g pixelHeight "$SOURCE" | tail -n 1 | awk '{print $2}')

if [ "$WIDTH" != "1024" ] || [ "$HEIGHT" != "1024" ]; then
    echo "Error: Source image must be exactly 1024×1024 pixels."
    echo "Detected size: ${WIDTH}×${HEIGHT}"
    exit 1
fi

mkdir -p "$DEST"

# Generate all required sizes
sips -z 40 40     "$SOURCE" --out "$DEST/AppIcon-20@2x.png"
sips -z 60 60     "$SOURCE" --out "$DEST/AppIcon-20@3x.png"
sips -z 58 58     "$SOURCE" --out "$DEST/AppIcon-29@2x.png"
sips -z 87 87     "$SOURCE" --out "$DEST/AppIcon-29@3x.png"
sips -z 80 80     "$SOURCE" --out "$DEST/AppIcon-40@2x.png"
sips -z 120 120   "$SOURCE" --out "$DEST/AppIcon-40@3x.png"
sips -z 120 120   "$SOURCE" --out "$DEST/AppIcon-60@2x.png"
sips -z 180 180   "$SOURCE" --out "$DEST/AppIcon-60@3x.png"
sips -z 152 152   "$SOURCE" --out "$DEST/AppIcon-76@2x.png"
sips -z 167 167   "$SOURCE" --out "$DEST/AppIcon-83.5@2x.png"
sips -z 1024 1024 "$SOURCE" --out "$DEST/AppIcon-1024.png"

# Write the correct Contents.json so Xcode knows about all the icons
cat > "$DEST/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "AppIcon-20@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "AppIcon-20@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "20x20"
    },
    {
      "filename" : "AppIcon-29@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "AppIcon-29@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "29x29"
    },
    {
      "filename" : "AppIcon-40@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "AppIcon-40@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "40x40"
    },
    {
      "filename" : "AppIcon-60@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "filename" : "AppIcon-60@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "filename" : "AppIcon-20@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "AppIcon-29@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "AppIcon-40@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "AppIcon-76@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "76x76"
    },
    {
      "filename" : "AppIcon-83.5@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "83.5x83.5"
    },
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "✅ All app icon sizes + Contents.json generated successfully!"
echo "Please clean build folder and restart Xcode."