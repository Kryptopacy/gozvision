"""
Build Official Favicon & App Icons for GozVision

Uses the official navbar logo asset (`apps/website/assets/gozvision_lens.png`)
with its crisp white squircle card (radius matching .brand-logo-img border-radius: 8px on 34px = 23.5%).
Deploys across apps/website, apps/clinic/web, and apps/patient/web.
"""

import os
from PIL import Image, ImageDraw

def generate_assets():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    source_logo_path = os.path.join(base_dir, 'apps', 'website', 'assets', 'gozvision_lens.png')
    
    if not os.path.exists(source_logo_path):
        raise FileNotFoundError(f"Source logo not found at {source_logo_path}")
        
    print(f"==> Loading official navbar logo from: {source_logo_path}")
    src = Image.open(source_logo_path).convert('RGBA')
    w, h = src.size
    
    # 1. Create high-res master squircle (1024x1024)
    # The navbar logo is gozvision_lens.png (which has white background)
    # clipped with border-radius: 8px on 34px height = 23.5% corner radius
    master_size = 1024
    master_white = Image.new('RGBA', (master_size, master_size), (255, 255, 255, 255))
    resized_src = src.resize((master_size, master_size), Image.Resampling.LANCZOS)
    master_white.paste(resized_src, (0, 0))
    
    # Rounded corner mask for squircle
    radius = int(master_size * 0.235)
    mask = Image.new('L', (master_size, master_size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, master_size, master_size), radius=radius, fill=255)
    
    squircle_master = Image.new('RGBA', (master_size, master_size), (0, 0, 0, 0))
    squircle_master.paste(master_white, (0, 0), mask=mask)
    
    # 2. Maskable PWA Master (Solid white background, 80% safe-zone centered)
    # As per W3C maskable icon specification
    maskable_master = Image.new('RGBA', (master_size, master_size), (255, 255, 255, 255))
    safe_size = int(master_size * 0.80)
    safe_offset = (master_size - safe_size) // 2
    resized_safe = src.resize((safe_size, safe_size), Image.Resampling.LANCZOS)
    maskable_master.paste(resized_safe, (safe_offset, safe_offset))
    
    # 3. Target directories
    targets = [
        os.path.join(base_dir, 'apps', 'website'),
        os.path.join(base_dir, 'apps', 'clinic', 'web'),
        os.path.join(base_dir, 'apps', 'patient', 'web'),
    ]
    
    # Also check if apps/clinic/build/web exists
    clinic_build = os.path.join(base_dir, 'apps', 'clinic', 'build', 'web')
    if os.path.exists(clinic_build):
        targets.append(clinic_build)
        
    for target in targets:
        os.makedirs(target, exist_ok=True)
        icons_dir = os.path.join(target, 'icons')
        os.makedirs(icons_dir, exist_ok=True)
        
        # 3.1 Favicons (Standard Squircle Badge)
        f16 = squircle_master.resize((16, 16), Image.Resampling.LANCZOS)
        f32 = squircle_master.resize((32, 32), Image.Resampling.LANCZOS)
        f48 = squircle_master.resize((48, 48), Image.Resampling.LANCZOS)
        f64 = squircle_master.resize((64, 64), Image.Resampling.LANCZOS)
        f180 = squircle_master.resize((180, 180), Image.Resampling.LANCZOS)
        f192 = squircle_master.resize((192, 192), Image.Resampling.LANCZOS)
        f512 = squircle_master.resize((512, 512), Image.Resampling.LANCZOS)
        
        # Multi-size favicon.ico
        ico_path = os.path.join(target, 'favicon.ico')
        f64.save(ico_path, format='ICO', sizes=[(16, 16), (32, 32), (48, 48), (64, 64)])
        
        # Standard PNG favicons
        f32.save(os.path.join(target, 'favicon.png'), format='PNG')
        f32.save(os.path.join(target, 'favicon-32x32.png'), format='PNG')
        f16.save(os.path.join(target, 'favicon-16x16.png'), format='PNG')
        
        # Apple Touch Icon
        f180.save(os.path.join(target, 'apple-touch-icon.png'), format='PNG')
        
        # PWA Standard Icons
        f192.save(os.path.join(icons_dir, 'Icon-192.png'), format='PNG')
        f512.save(os.path.join(icons_dir, 'Icon-512.png'), format='PNG')
        
        # PWA Maskable Icons (Safe Zone spec)
        m192 = maskable_master.resize((192, 192), Image.Resampling.LANCZOS)
        m512 = maskable_master.resize((512, 512), Image.Resampling.LANCZOS)
        m192.save(os.path.join(icons_dir, 'Icon-maskable-192.png'), format='PNG')
        m512.save(os.path.join(icons_dir, 'Icon-maskable-512.png'), format='PNG')
        
        # Extra mirror for website assets/
        if target.endswith('website'):
            website_assets = os.path.join(target, 'assets')
            os.makedirs(website_assets, exist_ok=True)
            f32.save(os.path.join(website_assets, 'favicon.png'), format='PNG')
            
        print(f"  ✓ Successfully deployed official squircle favicons & app icons to {target}")

    print("\n==> All official GozVision favicons and app icons regenerated and deployed successfully!")

if __name__ == '__main__':
    generate_assets()
