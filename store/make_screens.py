#!/usr/bin/env python3
"""
App Store screenshots for MLX.app: the raw UI-test shots (CI artifact "screenshots", demo data) set on a
warm brand background with a headline. Usage: python3 ios/store/make_screens.py <shots dir> <out dir>
Outputs iphone-69/NN.png (1320x2868), iphone-63/NN.png (1206x2622) and ipad-13/NN.png (2752x2064, landscape).
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = "/usr/share/fonts/opentype/inter/"
INK = (17, 18, 22)
SUB = (92, 88, 84)
ORANGE = (255, 122, 26)

SHOTS = [
    ("02-macs", "Every Mac, at a glance.", "See which Macs are working and what they mined today."),
    ("03-mac", "Pause or resume.\nFrom anywhere.", "Live speed, jobs, temperature and power for each Mac."),
    ("04-limits", "Decide when\nyour Mac works.", "Idle time, night hours, memory and heat, sent in a minute."),
    ("05-nodes", "Your nodes,\nall in one place.", "What each node earned and when it unlocks."),
    ("01-signin", "Signs in with\nyour passkey.", "Your wallet key stays on your device."),
]


def font(name, size):
    return ImageFont.truetype(FONT + name, size)


def background(w, h):
    bg = Image.new("RGB", (w, h), (246, 241, 235))
    glow = Image.new("RGB", (w, h), (246, 241, 235))
    d = ImageDraw.Draw(glow)
    r = int(w * 0.75)
    d.ellipse((w - r // 1.2, h - r // 1.1, w + r // 1.6, h + r // 1.8), fill=(255, 196, 140))
    d.ellipse((-r // 2, -r // 2.4, r // 1.6, r // 2.6), fill=(255, 232, 210))
    glow = glow.filter(ImageFilter.GaussianBlur(w // 5))
    return Image.blend(bg, glow, 0.85)


def rounded(im, radius):
    m = Image.new("L", im.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, im.width, im.height), radius, fill=255)
    out = Image.new("RGBA", im.size)
    out.paste(im, (0, 0), m)
    return out


def device(shot, width, radius, bezel):
    s = shot.convert("RGB")
    h = int(s.height * width / s.width)
    s = s.resize((width, h), Image.LANCZOS)
    frame = Image.new("RGBA", (width + bezel * 2, h + bezel * 2))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, frame.width, frame.height), radius + bezel, fill=(20, 20, 24))
    frame.alpha_composite(rounded(s, radius), (bezel, bezel))
    shadow = Image.new("RGBA", (frame.width + 200, frame.height + 200), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((100, 130, 100 + frame.width, 130 + frame.height), radius + bezel, fill=(60, 30, 0, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(45))
    shadow.alpha_composite(frame, (100, 100))
    return shadow


def text_block(d, x, y, head, sub, hsize, ssize, maxw, center=True):
    hf, sf = font("InterDisplay-Bold.otf", hsize), font("Inter-Medium.otf", ssize)
    for line in head.split("\n"):
        tw = d.textlength(line, font=hf)
        d.text((x - tw / 2 if center else x, y), line, font=hf, fill=INK)
        y += int(hsize * 1.08)
    y += int(ssize * 0.6)
    words, line, lines = sub.split(), "", []
    for w in words:
        t = (line + " " + w).strip()
        if d.textlength(t, font=sf) > maxw and line:
            lines.append(line)
            line = w
        else:
            line = t
    lines.append(line)
    for l in lines:
        tw = d.textlength(l, font=sf)
        d.text((x - tw / 2 if center else x, y), l, font=sf, fill=SUB)
        y += int(ssize * 1.3)
    return y


def phone(src, out):
    W, H = 1320, 2868
    for i, (name, head, sub) in enumerate(SHOTS, 1):
        im = background(W, H).convert("RGBA")
        d = ImageDraw.Draw(im)
        y = text_block(d, W // 2, 190, head, sub, 112, 50, W - 220)
        dev = device(Image.open(f"{src}/iPhone 17 Pro Max/{name}.png"), 1010, 120, 26)
        im.alpha_composite(dev, ((W - dev.width) // 2, max(y + 40, 640) - 100))
        im = im.convert("RGB")
        im.save(f"{out}/iphone-69/{i:02d}.png", optimize=True)
        # App Store Connect's default iPhone slot (6.3-inch, 1206x2622): same design, scaled
        im.resize((1206, 2622), Image.LANCZOS).save(f"{out}/iphone-63/{i:02d}.png", optimize=True)


def pad(src, out):
    W, H = 2752, 2064
    for i, (name, head, sub) in enumerate(SHOTS, 1):
        im = background(W, H).convert("RGBA")
        d = ImageDraw.Draw(im)
        y = text_block(d, W // 2, 130, head.replace("\n", " "), sub, 104, 46, W - 600)
        shot = Image.open(f"{src}/iPad Pro 13-inch (M5)/{name}.png")
        if shot.width < shot.height:  # captured in landscape, saved upright: turn it back
            shot = shot.rotate(90, expand=True)
        dev = device(shot, 2040, 60, 30)
        im.alpha_composite(dev, ((W - dev.width) // 2, y + 10))
        im.convert("RGB").save(f"{out}/ipad-13/{i:02d}.png", optimize=True)


if __name__ == "__main__":
    src, out = sys.argv[1], sys.argv[2]
    os.makedirs(f"{out}/iphone-69", exist_ok=True)
    os.makedirs(f"{out}/iphone-63", exist_ok=True)
    os.makedirs(f"{out}/ipad-13", exist_ok=True)
    phone(src, out)
    pad(src, out)
    print("done")
