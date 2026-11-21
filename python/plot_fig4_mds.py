"""Figure 4: classical MDS of outline shape (left) and network features (right).

Reads PAPER/results4/MDS_coordinates_<Method>_<Element>.csv and MDS_fit_summary.csv
written by mathematica/04_mds_stress.wl.

Usage: python plot_fig4_mds.py <PAPER> <output.jpg>
"""
import csv, os, sys
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.lines import Line2D

ELEMENTS = [('Mandible_lateral', 'Mandible'), ('Maxilla_ventral', 'Maxilla'), ('Humerus', 'Humerus'), ('Tibia', 'Tibia')]
METHODS = [('Shape', 'Outline shape'), ('Deep', 'Network features')]
SPECIES = [('Hystrix_brachyura', 'H. brachyura', '#d95e00'), ('Trichys_fasciculata', 'T. fasciculata', '#f2a633'),
           ('Muntiacus_muntjak', 'M. muntjak', '#0073b3'), ('Muntiacus_atherodes', 'M. atherodes', '#59b3e6')]
BG, FG = '#1a1a1a', '#e6e6e6'


def main(paper, out):
    res = os.path.join(paper, 'results4')
    fit = {(r['Element'], r['Method']): r for r in csv.DictReader(open(os.path.join(res, 'MDS_fit_summary.csv')))}
    fig, axes = plt.subplots(4, 2, figsize=(7.5, 9.8), facecolor=BG)
    for i, (el, eln) in enumerate(ELEMENTS):
        for j, (m, mn) in enumerate(METHODS):
            ax = axes[i, j]
            rows = list(csv.DictReader(open(os.path.join(res, f'MDS_coordinates_{m}_{el}.csv'))))
            ax.set_facecolor(BG)
            ax.axhline(0, color='#555555', lw=0.6, zorder=0); ax.axvline(0, color='#555555', lw=0.6, zorder=0)
            for sp, _, col in SPECIES:
                pts = [(float(r['MDS1']), float(r['MDS2'])) for r in rows if r['Species'] == sp]
                if pts:
                    ax.scatter(*zip(*pts), s=22, color=col, edgecolor='none', zorder=2)
            f = fit[(el, m)]
            ax.text(1.0, 1.02, f"stress {float(f['KruskalStress1']):.2f}; axes 1+2: {100*float(f['VarianceAxes12']):.0f}%",
                    transform=ax.transAxes, ha='right', va='bottom', color=FG, fontsize=7.5)
            ax.margins(0.08)
            for s in ax.spines.values(): s.set_color('#888888')
            ax.tick_params(colors=FG, labelsize=7, length=2.5)
            ax.set_xlabel('MDS 1', color=FG, fontsize=8, labelpad=1)
            ax.set_ylabel('MDS 2', color=FG, fontsize=8, labelpad=1)
            ax.text(-0.02, 1.02, f'({"abcdefgh"[2*i+j]})', transform=ax.transAxes, color='white',
                    fontsize=10, fontweight='bold', va='bottom', ha='right')
            if i == 0:
                ax.set_title(mn, color='white', fontsize=12, fontweight='bold', pad=14)
            if j == 0:
                ax.text(-0.24, 0.5, eln, transform=ax.transAxes, color='white', fontsize=11,
                        fontweight='bold', rotation=90, va='center', ha='center')
    handles = [Line2D([], [], marker='o', ls='', ms=7, color=c, label=n) for _, n, c in SPECIES]
    leg = fig.legend(handles=handles, loc='lower center', ncol=4, frameon=False, bbox_to_anchor=(0.54, 0.0),
                     prop={'style': 'italic', 'size': 10})
    for t in leg.get_texts(): t.set_color('white')
    plt.subplots_adjust(left=0.12, right=0.985, top=0.95, bottom=0.07, wspace=0.25, hspace=0.38)
    plt.savefig(out, dpi=300, facecolor=BG, pil_kwargs={'quality': 92})


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
