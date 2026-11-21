"""Make numbered thumbnail sheets of every photograph in a folder.

Used to find the run of frames for each element and view by eye.

Usage:
    python make_contact_sheets.py "<species folder>/Black bg" PREFIX OUTDIR
Example:
    python make_contact_sheets.py "Malayan porcupine/Black bg" Hys sheets/
"""
import os
import sys
from PIL import Image, ImageDraw

W, H, COLS, ROWS = 150, 100, 10, 8   # thumbnail size and grid per sheet


def main(src, prefix, outdir):
    os.makedirs(outdir, exist_ok=True)
    files = sorted(f for f in os.listdir(src) if f.lower().endswith(('.jpg', '.jpeg')))
    per = COLS * ROWS
    for s in range(0, len(files), per):
        sheet = Image.new('RGB', (W * COLS, (H + 14) * ROWS), 'white')
        d = ImageDraw.Draw(sheet)
        for k, f in enumerate(files[s:s + per]):
            im = Image.open(os.path.join(src, f))
            im.draft('RGB', (W * 2, H * 2))
            im = im.convert('RGB')
            im.thumbnail((W, H))
            x, y = (k % COLS) * W, (k // COLS) * (H + 14)
            sheet.paste(im, (x, y))
            d.text((x + 2, y + H), os.path.splitext(f)[0].replace('IMG_', ''), fill='black')
        sheet.save(os.path.join(outdir, f'{prefix}_{s // per:02d}.jpg'), quality=80)
    print(prefix, len(files), 'images')


if __name__ == '__main__':
    main(*sys.argv[1:4])
