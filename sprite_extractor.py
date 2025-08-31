#!/usr/bin/env python3
"""
PICO-8 Sprite Extractor

Extracts sprites of 8x8, 16x16, and 32x32 from PNG files and converts them to PICO-8 format.
PICO-8 uses a 16-color palette and 128x128 sprite sheet (16x16 grid of 8x8 sprites).
"""

import sys
import argparse
from PIL import Image
import numpy as np

# PICO-8 16-color palette (RGB values)
PICO8_PALETTE = [
    (0, 0, 0),        # 0: black
    (29, 43, 83),     # 1: dark blue
    (126, 37, 83),    # 2: dark purple
    (0, 135, 81),     # 3: dark green
    (171, 82, 54),    # 4: brown
    (95, 87, 79),     # 5: dark grey
    (194, 195, 199),  # 6: light grey
    (255, 241, 232),  # 7: white
    (255, 0, 77),     # 8: red
    (255, 163, 0),    # 9: orange
    (255, 236, 39),   # 10: yellow
    (0, 228, 54),     # 11: green
    (41, 173, 255),   # 12: blue
    (131, 118, 156),  # 13: indigo
    (255, 119, 168),  # 14: pink
    (255, 204, 170)   # 15: peach
]

def rgb_to_pico8_color(rgb):
    """Convert RGB color to closest PICO-8 palette color index."""
    min_distance = float('inf')
    closest_color = 0
    
    for i, palette_color in enumerate(PICO8_PALETTE):
        distance = sum((a - b) ** 2 for a, b in zip(rgb, palette_color))
        if distance < min_distance:
            min_distance = distance
            closest_color = i
    
    return closest_color

def extract_sprites_from_png(png_path, sprite_size=8):
    """Extract sprites from PNG file."""
    try:
        image = Image.open(png_path).convert('RGB')
        width, height = image.size
        
        sprites_x = width // sprite_size
        sprites_y = height // sprite_size
        
        sprites = []
        
        for y in range(sprites_y):
            for x in range(sprites_x):
                # Extract sprite region
                left = x * sprite_size
                top = y * sprite_size
                right = left + sprite_size
                bottom = top + sprite_size
                
                sprite_img = image.crop((left, top, right, bottom))
                sprite_data = []
                
                # Convert each pixel to PICO-8 color
                for py in range(sprite_size):
                    row = []
                    for px in range(sprite_size):
                        rgb = sprite_img.getpixel((px, py))
                        pico8_color = rgb_to_pico8_color(rgb)
                        row.append(pico8_color)
                    sprite_data.append(row)
                
                sprites.append({
                    'id': len(sprites),
                    'x': x,
                    'y': y,
                    'size': sprite_size,
                    'data': sprite_data
                })
        
        return sprites
    
    except Exception as e:
        print(f"Error loading PNG file: {e}")
        return []

def sprites_to_pico8_format(sprites, sprite_size=8):
    """Convert sprites to PICO-8 sprite sheet format."""
    # PICO-8 sprite sheet is 128x128 pixels (16x16 grid of 8x8 sprites)
    sheet_size = 128
    grid_size = sheet_size // 8  # 16x16 grid
    
    # Initialize sprite sheet with color 0 (black)
    sprite_sheet = [[0 for _ in range(sheet_size)] for _ in range(sheet_size)]
    
    sprite_index = 0
    
    for sprite in sprites:
        if sprite_index >= grid_size * grid_size:
            print(f"Warning: Too many sprites. PICO-8 supports max {grid_size * grid_size} 8x8 sprites.")
            break
        
        # Calculate position in PICO-8 sprite sheet
        sheet_x = (sprite_index % grid_size) * 8
        sheet_y = (sprite_index // grid_size) * 8
        
        # Handle different sprite sizes
        if sprite['size'] == 8:
            # Direct 8x8 mapping
            for y in range(8):
                for x in range(8):
                    sprite_sheet[sheet_y + y][sheet_x + x] = sprite['data'][y][x]
            sprite_index += 1
        
        elif sprite['size'] == 16:
            # 16x16 sprite takes 2x2 8x8 slots
            if sprite_index % grid_size > grid_size - 2 or sprite_index // grid_size > grid_size - 2:
                print(f"Warning: 16x16 sprite {sprite['id']} doesn't fit in remaining space.")
                continue
            
            # Split 16x16 into four 8x8 chunks
            for chunk_y in range(2):
                for chunk_x in range(2):
                    chunk_sheet_x = sheet_x + chunk_x * 8
                    chunk_sheet_y = sheet_y + chunk_y * 8
                    
                    for y in range(8):
                        for x in range(8):
                            src_y = chunk_y * 8 + y
                            src_x = chunk_x * 8 + x
                            sprite_sheet[chunk_sheet_y + y][chunk_sheet_x + x] = sprite['data'][src_y][src_x]
            
            sprite_index += 2  # Skip next slot horizontally
            if (sprite_index % grid_size) == 0:
                sprite_index += grid_size  # Skip next row
        
        elif sprite['size'] == 32:
            # 32x32 sprite takes 4x4 8x8 slots
            if sprite_index % grid_size > grid_size - 4 or sprite_index // grid_size > grid_size - 4:
                print(f"Warning: 32x32 sprite {sprite['id']} doesn't fit in remaining space.")
                continue
            
            # Split 32x32 into sixteen 8x8 chunks
            for chunk_y in range(4):
                for chunk_x in range(4):
                    chunk_sheet_x = sheet_x + chunk_x * 8
                    chunk_sheet_y = sheet_y + chunk_y * 8
                    
                    for y in range(8):
                        for x in range(8):
                            src_y = chunk_y * 8 + y
                            src_x = chunk_x * 8 + x
                            sprite_sheet[chunk_sheet_y + y][chunk_sheet_x + x] = sprite['data'][src_y][src_x]
            
            sprite_index += 4  # Skip next 3 slots horizontally
            for _ in range(3):  # Skip next 3 rows
                if (sprite_index % grid_size) == 0:
                    sprite_index += grid_size
    
    return sprite_sheet

def save_pico8_sprite_data(sprite_sheet, output_path):
    """Save sprite sheet as PICO-8 compatible data."""
    with open(output_path, 'w') as f:
        f.write("-- PICO-8 Sprite Data\n")
        f.write("-- Generated by sprite_extractor.py\n\n")
        
        f.write("__gfx__\n")
        
        # Convert sprite sheet to PICO-8 hex format
        for y in range(128):
            line = ""
            for x in range(0, 128, 2):
                # PICO-8 stores 2 pixels per hex byte (4 bits each)
                pixel1 = sprite_sheet[y][x]
                pixel2 = sprite_sheet[y][x + 1] if x + 1 < 128 else 0
                hex_byte = (pixel1 << 4) | pixel2
                line += f"{hex_byte:02x}"
            f.write(line + "\n")

def create_preview_image(sprite_sheet, output_path):
    """Create a preview PNG of the PICO-8 sprite sheet."""
    preview = Image.new('RGB', (128, 128))
    pixels = []
    
    for y in range(128):
        for x in range(128):
            color_index = sprite_sheet[y][x]
            rgb = PICO8_PALETTE[color_index]
            pixels.append(rgb)
    
    preview.putdata(pixels)
    preview = preview.resize((512, 512), Image.NEAREST)  # Scale up for visibility
    preview.save(output_path)

def main():
    parser = argparse.ArgumentParser(description='Extract sprites from PNG and convert to PICO-8 format')
    parser.add_argument('input_png', help='Input PNG file path')
    parser.add_argument('-s', '--size', type=int, choices=[8, 16, 32], default=8,
                       help='Sprite size (8x8, 16x16, or 32x32)')
    parser.add_argument('-o', '--output', default='sprites',
                       help='Output filename prefix (default: sprites)')
    parser.add_argument('--preview', action='store_true',
                       help='Generate preview PNG of sprite sheet')
    
    args = parser.parse_args()
    
    print(f"Extracting {args.size}x{args.size} sprites from {args.input_png}...")
    
    # Extract sprites
    sprites = extract_sprites_from_png(args.input_png, args.size)
    if not sprites:
        print("No sprites extracted. Check your input file.")
        return 1
    
    print(f"Extracted {len(sprites)} sprites")
    
    # Convert to PICO-8 format
    sprite_sheet = sprites_to_pico8_format(sprites, args.size)
    
    # Save PICO-8 data
    p8_output = f"{args.output}.p8"
    save_pico8_sprite_data(sprite_sheet, p8_output)
    print(f"PICO-8 sprite data saved to {p8_output}")
    
    # Generate preview if requested
    if args.preview:
        preview_output = f"{args.output}_preview.png"
        create_preview_image(sprite_sheet, preview_output)
        print(f"Preview image saved to {preview_output}")
    
    print("\nTo use in PICO-8:")
    print(f"1. Copy the __gfx__ section from {p8_output}")
    print("2. Paste it into your .p8 file")
    print("3. Use spr() function to draw sprites")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())