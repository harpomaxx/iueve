#!/usr/bin/env python3
"""
PNG to PICO-8 Sprite Converter
Converts a 16x16 PNG image to PICO-8 __gfx__ format as four 8x8 sprites
"""

from PIL import Image
import sys
import os

# PICO-8 16-color palette (RGB values)
PICO8_PALETTE = [
    (0, 0, 0),       # 0: black
    (29, 43, 83),    # 1: dark_blue
    (126, 37, 83),   # 2: dark_purple
    (0, 135, 81),    # 3: dark_green
    (171, 82, 54),   # 4: brown
    (95, 87, 79),    # 5: dark_grey
    (194, 195, 199), # 6: light_grey
    (255, 241, 232), # 7: white
    (255, 0, 77),    # 8: red
    (255, 163, 0),   # 9: orange
    (255, 236, 39),  # 10: yellow
    (0, 228, 54),    # 11: green
    (41, 173, 255),  # 12: blue
    (131, 118, 156), # 13: indigo
    (255, 119, 168), # 14: pink
    (255, 204, 170)  # 15: peach
]

def find_closest_pico8_color(rgb):
    """Find the closest PICO-8 color to the given RGB value"""
    if len(rgb) == 4:  # RGBA
        if rgb[3] == 0:  # transparent
            return 0  # use black for transparent pixels
        rgb = rgb[:3]
    
    min_distance = float('inf')
    closest_color = 0
    
    for i, pico_color in enumerate(PICO8_PALETTE):
        distance = sum((a - b) ** 2 for a, b in zip(rgb, pico_color))
        if distance < min_distance:
            min_distance = distance
            closest_color = i
    
    return closest_color

def convert_png_to_pico8(png_path):
    """Convert a 16x16 PNG to PICO-8 sprite data"""
    if not os.path.exists(png_path):
        print(f"Error: File {png_path} not found")
        return None
    
    try:
        img = Image.open(png_path)
        img = img.convert("RGBA")  # ensure RGBA mode
        
        if img.size != (16, 16):
            print(f"Warning: Image is {img.size}, resizing to 16x16")
            img = img.resize((16, 16), Image.NEAREST)
        
        # Convert to PICO-8 colors
        pico8_data = []
        for y in range(16):
            row = []
            for x in range(16):
                pixel = img.getpixel((x, y))
                pico8_color = find_closest_pico8_color(pixel)
                row.append(pico8_color)
            pico8_data.append(row)
        
        return pico8_data
    
    except Exception as e:
        print(f"Error loading image: {e}")
        return None

def split_into_8x8_sprites(data):
    """Split 16x16 data into four 8x8 sprites"""
    sprites = {
        'top_left': [[0]*8 for _ in range(8)],
        'top_right': [[0]*8 for _ in range(8)],
        'bottom_left': [[0]*8 for _ in range(8)],
        'bottom_right': [[0]*8 for _ in range(8)]
    }
    
    for y in range(16):
        for x in range(16):
            color = data[y][x]
            
            if y < 8 and x < 8:
                # Top-left sprite
                sprites['top_left'][y][x] = color
            elif y < 8 and x >= 8:
                # Top-right sprite
                sprites['top_right'][y][x-8] = color
            elif y >= 8 and x < 8:
                # Bottom-left sprite
                sprites['bottom_left'][y-8][x] = color
            else:
                # Bottom-right sprite
                sprites['bottom_right'][y-8][x-8] = color
    
    return sprites

def sprite_to_hex_string(sprite_data):
    """Convert 8x8 sprite data to PICO-8 hex format"""
    hex_lines = []
    for row in sprite_data:
        hex_chars = [hex(color)[2:] for color in row]
        hex_line = ''.join(hex_chars)
        hex_lines.append(hex_line)
    return hex_lines

def main():
    if len(sys.argv) != 2:
        print("Usage: python png_to_pico8.py <path_to_16x16_png>")
        sys.exit(1)
    
    png_path = sys.argv[1]
    
    # Convert PNG to PICO-8 data
    pico8_data = convert_png_to_pico8(png_path)
    if pico8_data is None:
        sys.exit(1)
    
    # Split into 8x8 sprites
    sprites = split_into_8x8_sprites(pico8_data)
    
    # Convert to hex format
    print("PICO-8 Sprite Data (copy these lines into your __gfx__ section):")
    print("=" * 60)
    
    print("\nTop-left sprite (sprite_tl):")
    tl_hex = sprite_to_hex_string(sprites['top_left'])
    for line in tl_hex:
        print(line)
    
    print("\nTop-right sprite (sprite_tr):")
    tr_hex = sprite_to_hex_string(sprites['top_right'])
    for line in tr_hex:
        print(line)
    
    print("\nBottom-left sprite (sprite_bl):")
    bl_hex = sprite_to_hex_string(sprites['bottom_left'])
    for line in bl_hex:
        print(line)
    
    print("\nBottom-right sprite (sprite_br):")
    br_hex = sprite_to_hex_string(sprites['bottom_right'])
    for line in br_hex:
        print(line)
    
    print()
    print("=" * 60)
    print("Copy these hex strings into your PICO-8 __gfx__ section,")
    print("replacing the appropriate sprite slots (1, 2, 17, 18 for player)")

if __name__ == "__main__":
    main()
