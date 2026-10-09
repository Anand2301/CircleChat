import os
from PIL import Image, ImageDraw

def generate_circlechat_logo(size=1024):
    # Render at 4x resolution for supersampled anti-aliasing
    scale = 4
    render_size = size * scale
    img = Image.new("RGBA", (render_size, render_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Charcoal rounded square background
    # Background color #101820
    bg_color = (16, 24, 32, 255)
    corner_radius = int(render_size * 0.22)
    padding = int(render_size * 0.04)
    draw.rounded_rectangle(
        [padding, padding, render_size - padding, render_size - padding],
        radius=corner_radius,
        fill=bg_color
    )

    # 2. Back bubble: Pale Blue #A5D8F3
    # Upper-right chat bubble
    pale_blue = (165, 216, 243, 255)
    b1_x0 = int(render_size * 0.38)
    b1_y0 = int(render_size * 0.22)
    b1_x1 = int(render_size * 0.78)
    b1_y1 = int(render_size * 0.58)
    b1_radius = int((b1_y1 - b1_y0) * 0.36)

    draw.rounded_rectangle(
        [b1_x0, b1_y0, b1_x1, b1_y1],
        radius=b1_radius,
        fill=pale_blue
    )
    # Tail for bubble 1 (pointing right/down)
    tail1 = [
        (int(render_size * 0.68), int(render_size * 0.55)),
        (int(render_size * 0.82), int(render_size * 0.64)),
        (int(render_size * 0.60), int(render_size * 0.58))
    ]
    draw.polygon(tail1, fill=pale_blue)

    # 3. Front bubble: Mint #B7F7D4
    # Lower-left chat bubble overlapping the back bubble
    mint = (183, 247, 212, 255)
    b2_x0 = int(render_size * 0.22)
    b2_y0 = int(render_size * 0.42)
    b2_x1 = int(render_size * 0.66)
    b2_y1 = int(render_size * 0.78)
    b2_radius = int((b2_y1 - b2_y0) * 0.36)

    # Shadow between bubbles for depth
    shadow_color = (16, 24, 32, 90)
    draw.rounded_rectangle(
        [b2_x0 - int(render_size * 0.01), b2_y0 + int(render_size * 0.01),
         b2_x1 + int(render_size * 0.01), b2_y1 + int(render_size * 0.01)],
        radius=b2_radius,
        fill=shadow_color
    )

    draw.rounded_rectangle(
        [b2_x0, b2_y0, b2_x1, b2_y1],
        radius=b2_radius,
        fill=mint
    )
    # Tail for bubble 2 (pointing left/down)
    tail2 = [
        (int(render_size * 0.30), int(render_size * 0.75)),
        (int(render_size * 0.18), int(render_size * 0.84)),
        (int(render_size * 0.40), int(render_size * 0.78))
    ]
    draw.polygon(tail2, fill=mint)

    # 4. Three dots inside the mint bubble: Charcoal #101820
    dot_color = (16, 24, 32, 230)
    dot_y = (b2_y0 + b2_y1) // 2
    dot_radius = int(render_size * 0.024)
    dot_spacing = int(render_size * 0.065)
    center_x = (b2_x0 + b2_x1) // 2

    for offset in (-1, 0, 1):
        dx = center_x + offset * dot_spacing
        draw.ellipse(
            [dx - dot_radius, dot_y - dot_radius, dx + dot_radius, dot_y + dot_radius],
            fill=dot_color
        )

    # Resize down with high quality Lanczos resampling
    final_img = img.resize((size, size), Image.Resampling.LANCZOS)
    return final_img

def main():
    base_dir = r"C:\Users\Anand\.gemini\antigravity\scratch\CircleChat\mobile\circle_chat"
    assets_icon_dir = os.path.join(base_dir, "assets", "icon")
    os.makedirs(assets_icon_dir, exist_ok=True)

    # Generate 1024 and 512 for assets
    img_1024 = generate_circlechat_logo(1024)
    img_1024.save(os.path.join(assets_icon_dir, "logo_1024.png"), "PNG")

    img_512 = generate_circlechat_logo(512)
    img_512.save(os.path.join(assets_icon_dir, "logo.png"), "PNG")
    print("Saved logo.png and logo_1024.png to assets/icon/")

    # Generate Android launcher icons
    res_dir = os.path.join(base_dir, "android", "app", "src", "main", "res")
    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }

    for folder, px in densities.items():
        target_dir = os.path.join(res_dir, folder)
        os.makedirs(target_dir, exist_ok=True)
        icon = generate_circlechat_logo(px)
        icon_path = os.path.join(target_dir, "ic_launcher.png")
        icon.save(icon_path, "PNG")
        print(f"Saved {icon_path} ({px}x{px})")

if __name__ == "__main__":
    main()
