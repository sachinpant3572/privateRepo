"""PIL drawing helpers."""
import math
from PIL import Image, ImageDraw, ImageFont
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FONTB = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def font(sz, bold=False): return ImageFont.truetype(FONTB if bold else FONT, sz)

class Canvas:
    """World coords in metres (x east, y north) mapped to a W x H image."""
    def __init__(self, x0, y0, x1, y1, W=1200, margin=40, top=70, bg=(250, 248, 243)):
        self.x0, self.y0, self.x1, self.y1 = x0, y0, x1, y1
        sx = (W - 2 * margin) / (x1 - x0)
        self.s = sx
        H = int((y1 - y0) * sx) + margin + top
        self.W, self.H, self.m, self.top = W, H, margin, top
        self.im = Image.new('RGB', (W, H), bg)
        self.d = ImageDraw.Draw(self.im)
    def px(self, x, y):
        return (self.m + (x - self.x0) * self.s, self.top + (self.y1 - y) * self.s)
    def line(self, xy, fill, width=1):
        if len(xy) >= 2: self.d.line([self.px(*p) for p in xy], fill=fill, width=width, joint='curve')
    def poly(self, xy, outline, fill=None, width=1):
        if len(xy) >= 3: self.d.polygon([self.px(*p) for p in xy], outline=outline, fill=fill, width=width)
    def text(self, x, y, s, sz=12, fill=(30, 30, 30), bold=False, anchor='mm', halo=True):
        X, Y = self.px(x, y); f = font(sz, bold)
        if halo:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    self.d.text((X + dx, Y + dy), s, font=f, fill=(255, 255, 255), anchor=anchor)
        self.d.text((X, Y), s, font=f, fill=fill, anchor=anchor)
    def title(self, t, sub=''):
        self._title = (t, sub)
    def _draw_title(self, t, sub=''):
        self.d.rectangle([0, 0, self.W, self.top - 4], fill=(250, 248, 243))
        self.d.text((self.m, 12), t, font=font(20, True), fill=(20, 20, 20))
        if sub: self.d.text((self.m, 40), sub, font=font(12), fill=(70, 70, 70))
    def scalebar(self, metres=None):
        if metres is None:
            span = self.x1 - self.x0
            for m in (100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000):
                if m > span / 6: metres = m; break
        X0 = self.m + 10; Y0 = self.H - 18
        self.d.rectangle([X0 - 4, Y0 - 16, X0 + metres * self.s + 60, Y0 + 8], fill=(255, 255, 255))
        self.d.line([(X0, Y0), (X0 + metres * self.s, Y0)], fill=(0, 0, 0), width=3)
        lab = f'{metres/1000:g} km' if metres >= 1000 else f'{metres} m'
        self.d.text((X0 + metres * self.s + 6, Y0), lab, font=font(12), fill=(0, 0, 0), anchor='lm')
        # north arrow
        Xn = self.W - self.m - 10; Yn = self.top + 30
        self.d.polygon([(Xn, Yn - 18), (Xn - 7, Yn + 4), (Xn + 7, Yn + 4)], fill=(0, 0, 0))
        self.d.text((Xn, Yn + 14), 'N', font=font(12, True), fill=(0, 0, 0), anchor='mm')
    def legend(self, items, x=None, y=None):
        f = font(12); x = x if x is not None else self.W - self.m - 260; y = y if y is not None else self.H - 22 - 18 * len(items)
        self.d.rectangle([x - 6, y - 6, x + 262, y + 18 * len(items)], fill=(255, 255, 255), outline=(180, 180, 180))
        for i, (col, w, lab) in enumerate(items):
            yy = y + 18 * i + 6
            self.d.line([(x, yy), (x + 26, yy)], fill=col, width=w)
            self.d.text((x + 34, yy), lab, font=f, fill=(20, 20, 20), anchor='lm')
    def save(self, path):
        if getattr(self, '_title', None): self._draw_title(*self._title)
        self.im.convert('P', palette=Image.ADAPTIVE, colors=96).save(path, optimize=True)
