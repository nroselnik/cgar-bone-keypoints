"""Copy the analysed frames into the PAPER folder structure.

Frame runs were identified by eye on the contact sheets. Within each run,
up to 8 frames are taken at equal intervals. Writes PAPER/selection_log.txt.

Usage:
    python select_images.py RAW_DIR PAPER_DIR
RAW_DIR holds the species folders exactly as photographed, e.g.
    RAW_DIR/Malayan porcupine /Black bg /IMG_9374.JPG
(note the trailing spaces in some original folder names).
"""
import os
import shutil
import sys

SRC = {
    'Hystrix_brachyura': 'Malayan porcupine /Black bg ',
    'Trichys_fasciculata': 'Long tailed porcupine /Black bg ',
    'Muntiacus_muntjak': 'Muntiacus muntjak/Black bg',
    'Muntiacus_atherodes': 'Muntiacus atherodes /Black bg',
}

# element: species: (first frame, last frame) of the run used
RUNS = {
    'Mandible_lateral': {'Hystrix_brachyura': (9374, 9389), 'Trichys_fasciculata': (389, 404),
                         'Muntiacus_muntjak': (7853, 7871), 'Muntiacus_atherodes': (8550, 8564)},
    'Maxilla_ventral': {'Hystrix_brachyura': (9420, 9440), 'Trichys_fasciculata': (462, 478),
                        'Muntiacus_muntjak': (7913, 7924), 'Muntiacus_atherodes': (8619, 8624)},
    'Humerus': {'Hystrix_brachyura': (9755, 9777), 'Trichys_fasciculata': (495, 511),
                'Muntiacus_muntjak': (7786, 7796)},
    'Tibia': {'Hystrix_brachyura': (9734, 9747), 'Trichys_fasciculata': (644, 648),
              'Muntiacus_muntjak': (8082, 8096)},
}
N_MAX = 8


def main(raw, paper):
    log = []
    for el, d in RUNS.items():
        for sp, (a, b) in d.items():
            files = [f'IMG_{i:04d}.JPG' for i in range(a, b + 1)
                     if os.path.exists(os.path.join(raw, SRC[sp], f'IMG_{i:04d}.JPG'))]
            n = min(N_MAX, len(files))
            step = len(files) / n
            pick = [files[int(k * step)] for k in range(n)]
            out = os.path.join(paper, el, sp)
            os.makedirs(out, exist_ok=True)
            for f in pick:
                shutil.copy2(os.path.join(raw, SRC[sp], f), os.path.join(out, f))
            log.append(f'{el},{sp},{a}-{b},{len(files)} in run,{n} copied: '
                       + ' '.join(p[4:8] for p in pick))
    with open(os.path.join(paper, 'selection_log.txt'), 'w') as fh:
        fh.write('\n'.join(log) + '\n')
    print('\n'.join(log))


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
