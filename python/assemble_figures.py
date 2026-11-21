"""Assemble the manuscript figures from the Mathematica outputs.

Run after the three Mathematica scripts.

Usage:
    python assemble_figures.py PAPER_DIR OUT_DIR

Produces:
    Fig1_mandible_keypoints.jpg, Fig2_humerus_keypoints.jpg,
    FigS1_maxilla_keypoints.jpg, FigS2_tibia_keypoints.jpg   (from results3/panels)
    Fig3_match_matrices_all.jpg                              (from results/pairwise_matches_*.csv)
    Fig4_shape_MDS_all.jpg, FigS3_deep_MDS_all.jpg           (from results2/*_MDS_*.png)
"""
import csv
import os
import sys

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from PIL import Image, ImageDraw, ImageFont

SPECIES = [('Hystrix_brachyura', 'H. brachyura'), ('Trichys_fasciculata', 'T. fasciculata'),
           ('Muntiacus_muntjak', 'M. muntjak'), ('Muntiacus_atherodes', 'M. atherodes')]
ELEMENTS = ['Mandible_lateral', 'Maxilla_ventral', 'Humerus', 'Tibia']
TITLES = {'Mandible_lateral': 'Mandible', 'Maxilla_ventral': 'Maxilla', 'Humerus': 'Humerus', 'Tibia': 'Tibia'}


def font(size, italic=False):
    names = ['DejaVuSerif-Italic.ttf' if italic else 'DejaVuSans-Bold.ttf']
    for d in ['/usr/share/fonts/truetype/dejavu/', '/Library/Fonts/', '/System/Library/Fonts/Supplemental/']:
        for n in names:
            if os.path.exists(d + n):
                return ImageFont.truetype(d + n, size)
    return ImageFont.load_default()


def keypoint_figure(paper, el, out):
    pdir = os.path.join(paper, 'results3', 'panels')
    ims = [(Image.open(os.path.join(pdir, f'{el}_{s}.png')).convert('RGB'), n)
           for s, n in SPECIES if os.path.exists(os.path.join(pdir, f'{el}_{s}.png'))]
    gap, lab, h = 50, 90, max(im.size[1] for im, _ in ims)
    colw = [max(im.size[0], 300) for im, _ in ims]
    c = Image.new('RGB', (sum(colw) + gap * (len(ims) - 1), h + lab), 'white')
    d, f, x = ImageDraw.Draw(c), font(44, italic=True), 0
    for (im, n), cw in zip(ims, colw):
        c.paste(im, (x + (cw - im.size[0]) // 2, 0))
        d.text((x + (cw - d.textlength(n, font=f)) / 2, h + 15), n, fill='black', font=f)
        x += cw + gap
    c.save(out, quality=92)


def match_matrices(paper, out):
    fig, axs = plt.subplots(2, 2, figsize=(12, 11), gridspec_kw={'wspace': 0.45, 'hspace': 0.35})
    for ax, el, letter in zip(axs.flat, ELEMENTS, 'abcd'):
        rows = list(csv.reader(open(os.path.join(paper, 'results', f'pairwise_matches_{el}.csv'))))
        files = rows[0][1:]
        m = np.array([[float(v) for v in r[1:]] for r in rows[1:]])
        # species block sizes from the image folders, in analysis order
        counts = [len([f for f in os.listdir(os.path.join(paper, el, s)) if f.lower().endswith('.jpg')])
                  for s, _ in SPECIES if os.path.isdir(os.path.join(paper, el, s))]
        assert sum(counts) == len(files), (el, counts, len(files))
        names = [n for s, n in SPECIES if os.path.isdir(os.path.join(paper, el, s))]
        im = ax.imshow(m, cmap='magma', vmin=0, vmax=100)
        edges = np.cumsum([0] + counts) - 0.5
        for e in edges[1:-1]:
            ax.axhline(e, color='white', lw=1.2)
            ax.axvline(e, color='white', lw=1.2)
        mids = [(edges[i] + edges[i + 1]) / 2 for i in range(len(counts))]
        ax.set_xticks(mids)
        ax.set_xticklabels(names, style='italic', rotation=30, ha='right', fontsize=10)
        ax.set_yticks(mids)
        ax.set_yticklabels(names, style='italic', fontsize=10)
        ax.tick_params(length=0)
        ax.set_title(f'({letter}) {TITLES[el]}', fontsize=13, loc='left')
    cb = fig.colorbar(im, ax=axs, shrink=0.55, pad=0.03)
    cb.set_label('Matched SURF keypoints between two photographs', fontsize=11)
    plt.savefig(out, dpi=200, bbox_inches='tight', pil_kwargs={'quality': 92})


def mds_grid(paper, method, out):
    ims = [Image.open(os.path.join(paper, 'results2', f'{method}_MDS_{el}.png')).convert('RGB') for el in ELEMENTS]
    w, h, left = max(i.size[0] for i in ims), max(i.size[1] for i in ims), 90
    c = Image.new('RGB', (2 * (w + left) + 20, 2 * h + 40), (26, 26, 26))
    d, f = ImageDraw.Draw(c), font(48)
    for k, (im, letter) in enumerate(zip(ims, 'abcd')):
        x, y = (k % 2) * (w + left + 20), (k // 2) * (h + 40)
        c.paste(im, (x + left, y))
        d.text((x + 10, y + 5), f'({letter})', fill='white', font=f)
    c.save(out, quality=92)


def main(paper, outdir):
    os.makedirs(outdir, exist_ok=True)
    for el, name in [('Mandible_lateral', 'Fig1_mandible_keypoints.jpg'), ('Humerus', 'Fig2_humerus_keypoints.jpg'),
                     ('Maxilla_ventral', 'FigS1_maxilla_keypoints.jpg'), ('Tibia', 'FigS2_tibia_keypoints.jpg')]:
        keypoint_figure(paper, el, os.path.join(outdir, name))
    match_matrices(paper, os.path.join(outdir, 'Fig3_match_matrices_all.jpg'))
    mds_grid(paper, 'Shape', os.path.join(outdir, 'Fig4_shape_MDS_all.jpg'))
    mds_grid(paper, 'Deep', os.path.join(outdir, 'FigS3_deep_MDS_all.jpg'))
    print('Figures written to', outdir)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
