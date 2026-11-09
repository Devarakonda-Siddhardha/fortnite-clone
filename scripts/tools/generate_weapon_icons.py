import os
from PIL import Image, ImageDraw, ImageFilter

os.makedirs("assets/icons", exist_ok=True)

def create_base_icon(color_glow):
    img = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Background rounded container with radial gradient / border
    draw.rounded_rectangle([4, 4, 124, 124], radius=16, fill=(20, 24, 34, 220), outline=color_glow, width=3)
    return img, draw

# 1. Pickaxe Icon
def make_pickaxe():
    img, draw = create_base_icon((60, 160, 255, 255))
    # Wooden Handle (diagonal)
    draw.line([30, 98, 92, 36], fill=(139, 90, 43, 255), width=7)
    # Steel Head
    draw.polygon([(78, 22), (106, 30), (102, 54), (90, 46)], fill=(180, 195, 210, 255))
    draw.polygon([(82, 18), (86, 42), (64, 48), (68, 28)], fill=(140, 155, 175, 255))
    # Pick point
    draw.line([106, 30, 116, 20], fill=(220, 235, 255, 255), width=4)
    img.save("assets/icons/pickaxe.png")

# 2. Assault Rifle Icon
def make_ar():
    img, draw = create_base_icon((80, 180, 255, 255))
    # Rifle Body
    draw.rectangle([28, 56, 88, 68], fill=(60, 68, 78, 255))
    # Barrel
    draw.rectangle([88, 60, 108, 64], fill=(45, 50, 60, 255))
    # Stock
    draw.polygon([(28, 58), (14, 66), (14, 78), (28, 70)], fill=(40, 46, 54, 255))
    # Magazine (curved down)
    draw.polygon([(56, 68), (50, 92), (62, 94), (66, 68)], fill=(30, 35, 42, 255))
    # Scope / Sight rail
    draw.rectangle([46, 50, 72, 56], fill=(50, 56, 66, 255))
    # Grip
    draw.polygon([(36, 68), (30, 84), (40, 86), (44, 68)], fill=(35, 40, 48, 255))
    img.save("assets/icons/assault_rifle.png")

# 3. Shotgun Icon
def make_shotgun():
    img, draw = create_base_icon((90, 220, 120, 255))
    # Heavy Receiver & Barrel
    draw.rectangle([34, 58, 104, 66], fill=(55, 60, 68, 255))
    # Magazine Tube
    draw.rectangle([44, 66, 96, 72], fill=(40, 45, 52, 255))
    # Pump slide
    draw.rectangle([66, 64, 82, 74], fill=(130, 85, 45, 255))
    # Stock
    draw.polygon([(34, 58), (16, 68), (16, 78), (34, 72)], fill=(120, 75, 40, 255))
    # Grip
    draw.polygon([(38, 70), (32, 84), (42, 86), (46, 70)], fill=(45, 50, 58, 255))
    img.save("assets/icons/shotgun.png")

# 4. Sniper Rifle Icon
def make_sniper():
    img, draw = create_base_icon((180, 90, 255, 255))
    # Long thin barrel
    draw.rectangle([76, 61, 114, 65], fill=(70, 75, 85, 255))
    # Receiver
    draw.rectangle([36, 58, 76, 68], fill=(50, 55, 65, 255))
    # Large Scope
    draw.rectangle([42, 46, 70, 54], fill=(35, 40, 48, 255))
    draw.polygon([(38, 44), (42, 46), (42, 54), (38, 56)], fill=(255, 200, 50, 255))
    draw.polygon([(70, 46), (74, 44), (74, 56), (70, 54)], fill=(255, 200, 50, 255))
    # Stock
    draw.polygon([(36, 60), (14, 68), (14, 80), (36, 72)], fill=(40, 44, 52, 255))
    # Bipod / Magazine
    draw.polygon([(52, 68), (48, 80), (56, 80), (58, 68)], fill=(30, 34, 40, 255))
    img.save("assets/icons/sniper_rifle.png")

# 5. Shield Potion Icon
def make_shield_potion():
    img, draw = create_base_icon((60, 180, 255, 255))
    # Glass Jar Body
    draw.rounded_rectangle([42, 46, 86, 96], radius=14, fill=(40, 140, 240, 220), outline=(180, 230, 255, 255), width=3)
    # Glowing liquid center
    draw.rounded_rectangle([48, 54, 80, 90], radius=10, fill=(80, 190, 255, 255))
    # Bottle Neck
    draw.rectangle([54, 34, 74, 46], fill=(180, 230, 255, 180), outline=(200, 240, 255, 255), width=2)
    # Cork Stopper
    draw.rounded_rectangle([52, 26, 76, 36], radius=3, fill=(160, 110, 60, 255))
    # Magic Shimmer Star
    draw.polygon([(64, 60), (67, 68), (76, 70), (69, 75), (71, 84), (64, 79), (57, 84), (59, 75), (52, 70), (61, 68)], fill=(255, 255, 255, 240))
    img.save("assets/icons/shield_potion.png")

# 6. Medkit Icon
def make_medkit():
    img, draw = create_base_icon((255, 80, 80, 255))
    # Red Case Body
    draw.rounded_rectangle([32, 44, 96, 96], radius=10, fill=(225, 45, 45, 255), outline=(255, 130, 130, 255), width=3)
    # White Medical Cross
    draw.rectangle([58, 52, 70, 88], fill=(255, 255, 255, 255))
    draw.rectangle([46, 64, 82, 76], fill=(255, 255, 255, 255))
    # Handle on top
    draw.arc([48, 28, 80, 52], 180, 360, fill=(180, 180, 180, 255), width=5)
    img.save("assets/icons/medkit.png")

make_pickaxe()
make_ar()
make_shotgun()
make_sniper()
make_shield_potion()
make_medkit()
print("All 6 weapon icons generated successfully!")
