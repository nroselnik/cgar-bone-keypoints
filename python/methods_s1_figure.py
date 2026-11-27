"""Worked example of the outline shape descriptor (Figure S3 in Methods S1).

A Python re-implementation of shapeDescriptor[] in 02_shape_and_features.wl,
for illustration only (the paper's numbers come from the Mathematica scripts).

Usage: python methods_s1_figure.py <photos_dir> <output.png>
"""
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt

N_BINS, N_HARM, THRESH = 180, 30, 0.25


def bone_mask(path):
    im = Image.open(path).convert('L')
    im.thumbnail((1000, 1000))
    g = np.asarray(im) / 255.0
    b = g > THRESH
    lab, n = ndimage.label(b)
    sizes = ndimage.sum(b, lab, range(1, n + 1))
    keep = np.isin(lab, 1 + np.where(sizes >= 200)[0])
    keep = ndimage.binary_fill_holes(keep)
    lab, n = ndimage.label(keep)
    sizes = ndimage.sum(keep, lab, range(1, n + 1))
    m = lab == (1 + np.argmax(sizes))
    mi = Image.fromarray((m * 255).astype(np.uint8)); mi.thumbnail((400, 400))
    return np.asarray(mi) > 127


def descriptor(mask):
    rows, cols = np.nonzero(mask)
    x, y = cols.astype(float), (mask.shape[0] - 1 - rows).astype(float)  # y up
    cx, cy = x.mean(), y.mean()
    d = np.hypot(x - cx, y - cy)
    ang = np.arctan2(y - cy, x - cx)
    bins = np.clip(np.floor((ang + np.pi) / (2 * np.pi) * N_BINS).astype(int), 0, N_BINS - 1)
    prof = np.zeros(N_BINS)
    np.maximum.at(prof, bins, d)
    prof = prof / prof.mean()
    F = np.fft.fft(prof) / np.sqrt(N_BINS)          # same scaling as Mathematica Fourier[]
    return (cx, cy), prof, np.abs(F[1:N_HARM + 1])


def main(photos, out):
    examples = [('Hystrix_brachyura', 'IMG_9378.JPG', 'H. brachyura'),
                ('Muntiacus_muntjak', 'IMG_7853.JPG', 'M. muntjak')]
    fig, ax = plt.subplots(2, 3, figsize=(10, 5.6), gridspec_kw={'width_ratios': [1.25, 1, 1]})
    for i, (sp, f, name) in enumerate(examples):
        m = bone_mask(os.path.join(photos, 'Mandible_lateral', sp, f))
        (cx, cy), prof, mag = descriptor(m)
        # transformed copy: mirrored and rotated by 37 degrees
        mt = np.asarray(Image.fromarray(m[:, ::-1].astype(np.uint8) * 255).rotate(37, expand=True)) > 127
        _, prof_t, mag_t = descriptor(mt)
        # (a) silhouette with centroid and every 10th bin ray
        a = ax[i, 0]
        a.imshow(m, cmap='Greys', origin='upper')
        cyi = m.shape[0] - 1 - cy
        mean_r = prof.mean()  # =1 after normalising; rays drawn with raw radius
        rows, cols = np.nonzero(m)
        xx, yy = cols, m.shape[0] - 1 - rows
        dd = np.hypot(xx - cx, yy - cy); aa = np.arctan2(yy - cy, xx - cx)
        bb = np.clip(np.floor((aa + np.pi) / (2 * np.pi) * N_BINS).astype(int), 0, N_BINS - 1)
        for k in range(0, N_BINS, 10):
            sel = bb == k
            if sel.any():
                j = np.argmax(np.where(sel, dd, -1))
                a.plot([cx, xx[j]], [cyi, m.shape[0] - 1 - yy[j]], color='0.45', lw=0.8)
                a.plot(xx[j], m.shape[0] - 1 - yy[j], 'o', ms=3, mfc='white', mec='black', mew=0.8)
        a.plot(cx, cyi, '+', color='black', ms=10, mew=1.5)
        a.set_xticks([]); a.set_yticks([])
        a.set_title(f'({"ad"[i]}) Silhouette, centroid and rays', fontsize=9, loc='left')
        a.text(0.03, 0.95, name, transform=a.transAxes, fontsize=10, style='italic', va='top')
        # (b) profile
        b = ax[i, 1]
        deg = np.linspace(-180, 180, N_BINS, endpoint=False) + 1
        b.plot(deg, prof, color='black', lw=1.2, label='original')
        b.plot(deg, prof_t, color='0.55', lw=1.0, ls='--', label='mirrored + rotated 37°')
        b.axhline(1, color='0.8', lw=0.6, zorder=0)
        b.set_xlim(-180, 180); b.set_xticks([-180, -90, 0, 90, 180])
        b.set_xlabel('Angle from centroid (degrees)', fontsize=8); b.set_ylabel('Radius / mean radius', fontsize=8)
        b.set_title(f'({"be"[i]}) Radius profile (180 bins)', fontsize=9, loc='left')
        b.tick_params(labelsize=7)
        if i == 0: b.legend(fontsize=7, frameon=False, loc='upper left')
        # (c) spectrum
        c = ax[i, 2]
        h = np.arange(1, N_HARM + 1)
        c.bar(h - 0.2, mag, width=0.4, color='black', label='original')
        c.bar(h + 0.2, mag_t, width=0.4, color='0.6', label='mirrored + rotated 37°')
        c.set_xlabel('Harmonic m', fontsize=8); c.set_ylabel('|F(m)|', fontsize=8)
        c.set_title(f'({"cf"[i]}) Shape descriptor (m = 1 to 30)', fontsize=9, loc='left')
        c.tick_params(labelsize=7)
        if i == 0: c.legend(fontsize=7, frameon=False)
        print(name, 'distance original vs transformed:', round(float(np.linalg.norm(mag - mag_t)), 3))
    descs = []
    for sp, f, _ in examples:
        descs.append(descriptor(bone_mask(os.path.join(photos, 'Mandible_lateral', sp, f)))[2])
    print('distance H. brachyura vs M. muntjak:', round(float(np.linalg.norm(descs[0] - descs[1])), 3))
    plt.tight_layout()
    plt.savefig(out, dpi=300)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
