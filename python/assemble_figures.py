"""Assemble the manuscript figures from the Mathematica outputs.

Run after the three Mathematica scripts.

Usage:
    python assemble_figures.py PAPER_DIR OUT_DIR

Produces:
    Fig1_mandible_keypoints.jpg, Fig2_humerus_keypoints.jpg,
    FigS1_maxilla_keypoints.jpg, FigS2_tibia_keypoints.jpg   (from results3/panels)
    Fig3_match_matrices_all.jpg                              (from results/pairwise_matches_*.csv)
    Fig4_shape_vs_network_MDS.jpg                            (from results2/*_MDS_*.png)
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


def mds_combined(paper, out):
    """Figure 4: outline shape (left) vs network features (right), one row per element."""
    from matplotlib.lines import Line2D
    bg = '#1a1a1a'
    methods = [('Shape', 'Outline shape'), ('Deep', 'Network features')]

    def crop(path):
        im = Image.open(path).convert('RGB')
        a = np.asarray(im.convert('L')).astype(int)
        rows = [y for y in range(a.shape[0]) if (a[y] > 120).sum() > 0.35 * a.shape[1]]
        return im.crop((0, max(rows[0] - 1, 0), 1262, a.shape[0]))  # drop panel title and legend

    fig, axes = plt.subplots(4, 2, figsize=(7.5, 9.6), facecolor=bg)
    for i, el in enumerate(ELEMENTS):
        for j, (m, mn) in enumerate(methods):
            ax = axes[i, j]
            ax.imshow(crop(os.path.join(paper, 'results2', f'{m}_MDS_{el}.png')))
            ax.axis('off')
            ax.text(-0.01, 1.0, f'({"abcdefgh"[2 * i + j]})', transform=ax.transAxes, color='white',
                    fontsize=11, fontweight='bold', va='bottom', ha='left')
            if i == 0:
                ax.set_title(mn, color='white', fontsize=13, fontweight='bold', pad=16)
            if j == 0:
                ax.text(-0.09, 0.5, TITLES[el], transform=ax.transAxes, color='white', fontsize=12,
                        fontweight='bold', rotation=90, va='center', ha='center')
    cols = ['#d95e00', '#f2a633', '#0073b3', '#59b3e6']
    handles = [Line2D([], [], marker='o', ls='', ms=8, color=c, label=n) for c, (_, n) in zip(cols, SPECIES)]
    leg = fig.legend(handles=handles, loc='lower center', ncol=4, frameon=False, bbox_to_anchor=(0.53, 0.0),
                     prop={'style': 'italic', 'size': 11})
    for t in leg.get_texts():
        t.set_color('white')
    plt.subplots_adjust(left=0.07, right=0.995, top=0.95, bottom=0.05, wspace=0.04, hspace=0.12)
    plt.savefig(out, dpi=300, facecolor=bg, pil_kwargs={'quality': 92})
    plt.close(fig)

def main(paper, outdir):
    os.makedirs(outdir, exist_ok=True)
    for el, name in [('Mandible_lateral', 'Fig1_mandible_keypoints.jpg'), ('Humerus', 'Fig2_humerus_keypoints.jpg'),
                     ('Maxilla_ventral', 'FigS1_maxilla_keypoints.jpg'), ('Tibia', 'FigS2_tibia_keypoints.jpg')]:
        keypoint_figure(paper, el, os.path.join(outdir, name))
    match_matrices(paper, os.path.join(outdir, 'Fig3_match_matrices_all.jpg'))
    mds_combined(paper, os.path.join(outdir, 'Fig4_shape_vs_network_MDS.jpg'))
    print('Figures written to', outdir)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
