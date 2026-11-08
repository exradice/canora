"""Renders docs/canora.gif: same layout logic as canora.be, AWTRIX panel font, LED look.

Usage: python3 render-demo.py awtrix.bdf canora.gif
The font is assets/fonts/awtrix.bdf from https://github.com/Blueforcer/awtrix-ng (OFL-1.1).
"""
import sys
from PIL import Image, ImageDraw

FONT, OUT = sys.argv[1], sys.argv[2]
W, H = 52, 16
SUNG, PENDING, TITLE_C = (0xFF, 0xB0, 0x00), (0xA0, 0xA0, 0xA0), (0x48, 0x48, 0x48)
TITLE = "Wellerman"

# Traditional sea shanty (19th century), public domain. Timestamps written for this demo.
LRC = [
    (0, ""),
    (5500, "There once was a ship that put to sea"),
    (8900, "The name of the ship was the Billy o' Tea"),
    (12300, "The winds blew up, her bow dipped down"),
    (15700, "O blow, my bully boys, blow"),
    (19100, ""),
]
LENGTH_MS, FPS = 21500, 15


def load_bdf(path):
    glyphs, cur, bits = {}, None, None
    for line in open(path, encoding="latin-1"):
        p = line.split()
        if not p:
            continue
        if p[0] == "ENCODING":
            cur = {"enc": int(p[1])}
        elif p[0] == "DWIDTH" and cur is not None:
            cur["dw"] = int(p[1])
        elif p[0] == "BBX" and cur is not None:
            cur["bbx"] = list(map(int, p[1:5]))
        elif p[0] == "BITMAP" and cur is not None:
            bits = []
        elif p[0] == "ENDCHAR" and cur is not None:
            cur["bits"] = bits
            glyphs[chr(cur["enc"])] = cur
            cur, bits = None, None
        elif bits is not None:
            bits.append(int(p[0], 16))
    return glyphs


G = load_bdf(FONT)


def text_width(s):
    return sum(G.get(c, G["?"])["dw"] for c in s)


def draw_text(px, x, y, s, color):
    for c in s:
        g = G.get(c, G["?"])
        w, h, xo, yo = g["bbx"]
        nbytes = (w + 7) // 8
        for row, v in enumerate(g["bits"]):
            for col in range(w):
                if v & (1 << (nbytes * 8 - 1 - col)):
                    X, Y = x + xo + col, y - yo - h + row
                    if 0 <= X < W and 0 <= Y < H:
                        px[Y][X] = color
        x += g["dw"]
    return x


# ---- same structure as canora.be ----
times = [t for t, _ in LRC]
lines = [s for _, s in LRC]
rows = [(-1, 0, 0, None)]          # (line, a, b, text)
l_row0, l_n, l_dur = [], [], []
for i, s in enumerate(lines):
    n = len(s)
    l_row0.append(len(rows))
    l_n.append(n)
    until = times[i + 1] - times[i] if i + 1 < len(times) else 5000
    l_dur.append(max(1, min(max(n * 125, 1000), until)))
    if n == 0:
        rows.append((i, 0, 0, None))
    a = 0
    while a < n:
        while a < n and s[a] == " ":
            a += 1
        if a >= n:
            break
        b, j = -1, a
        while j < n:
            e = j
            while e < n and s[e] != " ":
                e += 1
            if text_width(s[a:e]) > W:
                break
            b = j = e
            while j < n and s[j] == " ":
                j += 1
        if b < 0:
            b = a + 1
            while b < n and text_width(s[a:b + 1]) <= W:
                b += 1
        rows.append((i, a, b, s[a:b]))
        a = b


def line_at(t):
    i = -1
    while i + 1 < len(times) and times[i + 1] <= t:
        i += 1
    return i


def row_at(i, k):
    if i < 0:
        return 0
    r = l_row0[i]
    while r + 1 < len(rows) and rows[r + 1][0] == i and k >= rows[r][2]:
        r += 1
    return r


state = {"top": -1, "anim": None}


def frame(t):
    px = [[None] * W for _ in range(H)]
    i = line_at(t)
    k = 0
    if i >= 0:
        p = max(0, min(1000, (t - times[i]) * 1000 // l_dur[i]))
        k = l_n[i] * p // 1000
    cur = row_at(i, k)
    if cur != state["top"]:
        state["anim"] = t if state["top"] >= 0 and cur == state["top"] + 1 else None
        state["top"] = cur
    shift = 0
    if state["anim"] is not None:
        el = t - state["anim"]
        if el < 250:
            shift = 8 - el * 8 // 250
        else:
            state["anim"] = None
    for r in range(max(cur - 1, 0), min(cur + 3, len(rows))):
        y = 6 + (r - cur) * 8 + shift
        if not (-2 < y < 22):
            continue
        li, a, b, txt = rows[r]
        if txt is None:
            if r != cur:
                continue
            target = times[li + 1] if li + 1 < len(times) else -1
            left = target - t
            if target >= 0 and 0 < left <= 3000:
                dots = (left + 999) // 1000
                x = (W - (dots * 4 - 2)) // 2
                for _ in range(dots):
                    for dy in range(2):
                        for dx in range(2):
                            if 0 <= y - 4 + dy < H:
                                px[y - 4 + dy][x + dx] = SUNG
                    x += 4
            else:
                draw_text(px, (W - text_width(TITLE)) // 2, y, TITLE, TITLE_C)
            continue
        n = len(txt)
        kk = n if li < i else (max(0, min(n, k - a)) if li == i else 0)
        x = (W - text_width(txt)) // 2
        x = draw_text(px, x, y, txt[:kk], SUNG)
        draw_text(px, x, y, txt[kk:], PENDING)
    return px


# ---- LED look ----
S, PAD = 12, 14
OFF, BG = (22, 22, 22), (8, 8, 8)


def led_image(px):
    img = Image.new("RGB", (W * S + 2 * PAD, H * S + 2 * PAD), BG)
    d = ImageDraw.Draw(img)
    for y in range(H):
        for x in range(W):
            c = px[y][x] or OFF
            x0, y0 = PAD + x * S + 1, PAD + y * S + 1
            d.rounded_rectangle((x0, y0, x0 + S - 3, y0 + S - 3), radius=3, fill=c)
    return img


step = 1000 // FPS
frames = [led_image(frame(t)) for t in range(0, LENGTH_MS, step)]
# Palette from frames with all colours (title, sung, pending), side by side
probe = [frames[5], frames[len(frames) // 2], frames[-5]]
strip = Image.new("RGB", (probe[0].width * len(probe), probe[0].height))
for n, f in enumerate(probe):
    strip.paste(f, (n * f.width, 0))
pal = strip.quantize(colors=32, method=Image.Quantize.MEDIANCUT)
q = [f.quantize(palette=pal, dither=Image.Dither.NONE) for f in frames]
q[0].save(OUT, save_all=True, append_images=q[1:], duration=step, loop=0, optimize=True, disposal=1)
print(len(frames), "frames,", len(rows), "rows")
