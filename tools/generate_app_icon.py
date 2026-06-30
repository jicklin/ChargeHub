from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'ChargeHub' / 'Assets.xcassets' / 'AppIcon.appiconset'
OUT.mkdir(parents=True, exist_ok=True)
SIZE = 1024


def rounded_mask(size, radius):
    mask = Image.new('L', (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def lerp(a, b, t):
    return int(a + (b - a) * t)


def gradient_bg(size, colors):
    img = Image.new('RGBA', (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            if t < 0.5:
                local = t / 0.5
                c1, c2 = colors[0], colors[1]
            else:
                local = (t - 0.5) / 0.5
                c1, c2 = colors[1], colors[2]
            px[x, y] = tuple(lerp(c1[i], c2[i], local) for i in range(4))
    return img


def radial_glow(size, center, radius, color):
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    gx, gy = center
    px = glow.load()
    for y in range(size):
        for x in range(size):
            dx = x - gx
            dy = y - gy
            d = (dx * dx + dy * dy) ** 0.5
            t = max(0.0, 1.0 - d / radius)
            alpha = int(color[3] * (t ** 1.8))
            px[x, y] = (color[0], color[1], color[2], alpha)
    return glow.filter(ImageFilter.GaussianBlur(radius / 18))


def draw_icon(theme='light'):
    if theme == 'light':
        bg = gradient_bg(SIZE, [
            (84, 242, 226, 255),
            (76, 102, 255, 255),
            (173, 74, 255, 255),
        ])
        bg.alpha_composite(radial_glow(SIZE, (250, 180), 380, (255, 255, 255, 95)))
        bg.alpha_composite(radial_glow(SIZE, (780, 860), 420, (255, 90, 210, 90)))
        ring_color = (255, 255, 255, 88)
        battery_fill = (255, 255, 255, 245)
        battery_shadow = (36, 28, 92, 70)
        core_fill = (72, 93, 245, 255)
        bolt_color = (255, 255, 255, 250)
        dot_fill = (255, 255, 255, 220)
        smile_color = (255, 255, 255, 105)
    elif theme == 'dark':
        bg = gradient_bg(SIZE, [
            (14, 24, 54, 255),
            (30, 52, 124, 255),
            (83, 34, 128, 255),
        ])
        bg.alpha_composite(radial_glow(SIZE, (220, 160), 340, (115, 211, 255, 70)))
        bg.alpha_composite(radial_glow(SIZE, (800, 840), 360, (204, 87, 255, 58)))
        ring_color = (255, 255, 255, 70)
        battery_fill = (246, 249, 255, 245)
        battery_shadow = (0, 0, 0, 85)
        core_fill = (69, 98, 252, 255)
        bolt_color = (255, 255, 255, 250)
        dot_fill = (255, 255, 255, 200)
        smile_color = (255, 255, 255, 120)
    else:
        bg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
        ring_color = (255, 255, 255, 95)
        battery_fill = (255, 255, 255, 255)
        battery_shadow = (0, 0, 0, 0)
        core_fill = None
        bolt_color = (255, 255, 255, 255)
        dot_fill = (255, 255, 255, 255)
        smile_color = (255, 255, 255, 255)

    canvas = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    if theme != 'tinted':
        canvas.paste(bg, (0, 0), rounded_mask(SIZE, 230))
    else:
        canvas = bg.copy()

    shadow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle((286, 244, 738, 812), radius=180, fill=battery_shadow)
    shadow = shadow.filter(ImageFilter.GaussianBlur(36))
    canvas.alpha_composite(shadow)

    draw = ImageDraw.Draw(canvas)
    draw.ellipse((190, 190, 834, 834), outline=ring_color, width=22)
    draw.arc((248, 248, 776, 776), start=204, end=340, fill=ring_color, width=12)

    for cx, cy, r in [(242, 512, 22), (782, 512, 22), (512, 222, 18), (512, 802, 18)]:
        draw.ellipse((cx-r, cy-r, cx+r, cy+r), fill=dot_fill)

    draw.rounded_rectangle((306, 288, 718, 770), radius=132, fill=battery_fill)
    draw.rounded_rectangle((455, 228, 569, 300), radius=28, fill=battery_fill)

    if core_fill is not None:
        draw.rounded_rectangle((356, 348, 668, 720), radius=100, fill=core_fill)
    else:
        draw.rounded_rectangle((356, 348, 668, 720), radius=100, fill=(255, 255, 255, 0), outline=(255, 255, 255, 255), width=22)

    bolt = [(535, 388), (445, 544), (520, 544), (468, 680), (585, 500), (508, 500)]
    draw.polygon(bolt, fill=bolt_color)
    draw.arc((388, 558, 634, 706), start=18, end=162, fill=smile_color, width=14)

    if theme != 'tinted':
        hi = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
        hdraw = ImageDraw.Draw(hi)
        hdraw.rounded_rectangle((110, 90, 914, 520), radius=210, fill=(255, 255, 255, 42))
        hi = hi.filter(ImageFilter.GaussianBlur(72))
        canvas.alpha_composite(hi)

    return canvas


def save_resized(base, filename, size):
    base.resize((size, size), Image.Resampling.LANCZOS).save(OUT / filename)


light = draw_icon('light')
dark = draw_icon('dark')
tinted = draw_icon('tinted')

light.save(OUT / 'AppIcon-1024.png')
dark.save(OUT / 'AppIcon-1024-dark.png')
tinted.save(OUT / 'AppIcon-1024-tinted.png')

mac_specs = [
    ('AppIcon-mac-16.png', 16),
    ('AppIcon-mac-16@2x.png', 32),
    ('AppIcon-mac-32.png', 32),
    ('AppIcon-mac-32@2x.png', 64),
    ('AppIcon-mac-128.png', 128),
    ('AppIcon-mac-128@2x.png', 256),
    ('AppIcon-mac-256.png', 256),
    ('AppIcon-mac-256@2x.png', 512),
    ('AppIcon-mac-512.png', 512),
    ('AppIcon-mac-512@2x.png', 1024),
]
for name, size in mac_specs:
    save_resized(light, name, size)

print('generated', len(list(OUT.glob('*.png'))), 'png files')
