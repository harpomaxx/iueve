#!/usr/bin/env python3
"""
PNG to PICO-8 All Sprites Extractor
Extracts all 8x8 sprites from a PNG file arranged horizontally and converts to PICO-8 format
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

def extract_sprite_from_position(img, x_offset, y_offset, sprite_size=8):
    """Extract a single 8x8 sprite from the image at given position"""
    sprite_data = []
    
    for y in range(sprite_size):
        row = []
        for x in range(sprite_size):
            pixel_x = x_offset + x
            pixel_y = y_offset + y
            
            # Check bounds
            if pixel_x >= img.width or pixel_y >= img.height:
                row.append(0)  # black for out of bounds
            else:
                pixel = img.getpixel((pixel_x, pixel_y))
                pico8_color = find_closest_pico8_color(pixel)
                row.append(pico8_color)
        sprite_data.append(row)
    
    return sprite_data

def extract_16x16_sprite(img, x_offset, y_offset):
    """Extract a single 16x16 sprite and convert to PICO-8 colors"""
    sprite_data = []
    
    for y in range(16):
        row = []
        for x in range(16):
            pixel_x = x_offset + x
            pixel_y = y_offset + y
            
            if pixel_x >= img.width or pixel_y >= img.height:
                row.append(0)  # black for out of bounds
            else:
                pixel = img.getpixel((pixel_x, pixel_y))
                pico8_color = find_closest_pico8_color(pixel)
                row.append(pico8_color)
        sprite_data.append(row)
    
    return sprite_data

def split_16x16_to_8x8(sprite_data):
    """Split a 16x16 sprite into four 8x8 sprites"""
    sprites = {
        'top_left': [[0]*8 for _ in range(8)],
        'top_right': [[0]*8 for _ in range(8)],
        'bottom_left': [[0]*8 for _ in range(8)],
        'bottom_right': [[0]*8 for _ in range(8)]
    }
    
    for y in range(16):
        for x in range(16):
            color = sprite_data[y][x]
            
            if y < 8 and x < 8:
                sprites['top_left'][y][x] = color
            elif y < 8 and x >= 8:
                sprites['top_right'][y][x-8] = color
            elif y >= 8 and x < 8:
                sprites['bottom_left'][y-8][x] = color
            else:
                sprites['bottom_right'][y-8][x-8] = color
    
    return sprites

def extract_all_sprites(png_path, sprite_size=16):
    """Extract all 16x16 sprites from a PNG file"""
    if not os.path.exists(png_path):
        print(f"Error: File {png_path} not found")
        return None
    
    try:
        img = Image.open(png_path)
        img = img.convert("RGBA")  # ensure RGBA mode
        
        # Calculate number of 16x16 sprites horizontally
        sprites_horizontal = img.width // sprite_size
        sprites_vertical = img.height // sprite_size
        
        print(f"Image size: {img.width}x{img.height}")
        print(f"Extracting {sprites_horizontal}x{sprites_vertical} 16x16 sprites ({sprites_horizontal * sprites_vertical} total)")
        print(f"Each 16x16 sprite becomes four 8x8 sprites for PICO-8")
        
        all_sprites = []
        
        for row in range(sprites_vertical):
            for col in range(sprites_horizontal):
                x_offset = col * sprite_size
                y_offset = row * sprite_size
                
                # Extract 16x16 sprite
                sprite_16x16 = extract_16x16_sprite(img, x_offset, y_offset)
                
                # Split into four 8x8 sprites
                split_sprites = split_16x16_to_8x8(sprite_16x16)
                
                sprite_index = row * sprites_horizontal + col
                all_sprites.append({
                    'index': sprite_index,
                    'position': (col, row),
                    'top_left': split_sprites['top_left'],
                    'top_right': split_sprites['top_right'],
                    'bottom_left': split_sprites['bottom_left'],
                    'bottom_right': split_sprites['bottom_right']
                })
        
        return all_sprites
    
    except Exception as e:
        print(f"Error loading image: {e}")
        return None

def sprite_to_hex_string(sprite_data):
    """Convert 8x8 sprite data to PICO-8 hex format"""
    hex_lines = []
    for row in sprite_data:
        hex_chars = [hex(color)[2:] for color in row]
        hex_line = ''.join(hex_chars)
        hex_lines.append(hex_line)
    return hex_lines

def generate_gfx_output(sprites, output_file=None):
    """Generate complete __gfx__ section ready for copy-paste"""
    
    # Create a 128x128 sprite sheet (16x16 sprites, each 8x8)
    sprite_sheet = [['00000000' for _ in range(16)] for _ in range(128)]
    
    for sprite in sprites:
        index = sprite['index']
        
        # Calculate sprite positions: 0,1 then 16,17 then 2,3 then 18,19 etc.
        # For sprite N: top-left at N*2, top-right at N*2+1
        # bottom-left at N*2+16, bottom-right at N*2+17
        
        base_sprite = index * 2
        
        # Top-left sprite position
        tl_sprite_id = base_sprite
        tl_row = tl_sprite_id // 16
        tl_col = tl_sprite_id % 16
        
        # Top-right sprite position  
        tr_sprite_id = base_sprite + 1
        tr_row = tr_sprite_id // 16
        tr_col = tr_sprite_id % 16
        
        # Bottom-left sprite position
        bl_sprite_id = base_sprite + 16
        bl_row = bl_sprite_id // 16
        bl_col = bl_sprite_id % 16
        
        # Bottom-right sprite position
        br_sprite_id = base_sprite + 17
        br_row = br_sprite_id // 16
        br_col = br_sprite_id % 16
        
        # Place sprite parts
        tl_hex = sprite_to_hex_string(sprite['top_left'])
        tr_hex = sprite_to_hex_string(sprite['top_right'])
        bl_hex = sprite_to_hex_string(sprite['bottom_left'])
        br_hex = sprite_to_hex_string(sprite['bottom_right'])
        
        # Top-left
        for i, line in enumerate(tl_hex):
            if tl_row * 8 + i < 128:
                sprite_sheet[tl_row * 8 + i][tl_col] = line
        
        # Top-right  
        for i, line in enumerate(tr_hex):
            if tr_row * 8 + i < 128:
                sprite_sheet[tr_row * 8 + i][tr_col] = line
        
        # Bottom-left
        for i, line in enumerate(bl_hex):
            if bl_row * 8 + i < 128:
                sprite_sheet[bl_row * 8 + i][bl_col] = line
        
        # Bottom-right
        for i, line in enumerate(br_hex):
            if br_row * 8 + i < 128:
                sprite_sheet[br_row * 8 + i][br_col] = line
    
    # Generate output
    output_lines = ['__gfx__']
    for row in sprite_sheet:
        output_lines.append(''.join(row))
    
    output_content = '\n'.join(output_lines)
    
    if output_file:
        with open(output_file, 'w') as f:
            f.write(output_content)
        print(f"Sprite data written to {output_file}")
    
    return output_content

def main():
    if len(sys.argv) < 2:
        print("Usage: python png_extract_all_sprites.py <path_to_png> [output_file]")
        print("Extracts all 16x16 sprites from a PNG file and converts to PICO-8 format")
        print("If output_file is provided, saves the __gfx__ section to that file")
        sys.exit(1)
    
    png_path = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    
    # Extract all sprites
    sprites = extract_all_sprites(png_path)
    if sprites is None:
        sys.exit(1)
    
    # Generate __gfx__ output
    gfx_content = generate_gfx_output(sprites, output_file)
    
    if not output_file:
        print("\nReady-to-paste __gfx__ section:")
        print("=" * 80)
        print(gfx_content)
        print("=" * 80)
    
    print(f"\nTotal 16x16 sprites extracted: {len(sprites)}")
    print(f"Total 8x8 sprites generated: {len(sprites) * 4}")
    print("\nSimply copy the entire __gfx__ section above and paste it into your .p8 file!")

if __name__ == "__main__":
    main()