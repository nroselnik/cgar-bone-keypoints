# cgar-bone-keypoints

Code for the paper:

**What the machine sees: keypoints, outlines and pretrained features on porcupine and muntjac bones**
Nurulain Hanani Syahirah Othmarani, Velat Bujeng, Bugin Anak Bunyau, Nik Fadzly N Rosely
(manuscript in preparation)

The study measures how strongly photographs of one specimen resemble each other, and uses keypoint, outline-shape and pretrained-network analyses on photographs of four elements (mandible, maxilla, humerus, tibia) from four Malaysian mammals held at the Centre for Global Archaeological Research (CGAR), Universiti Sains Malaysia: *Hystrix brachyura*, *Trichys fasciculata*, *Muntiacus muntjak* and *Muntiacus atherodes*.

## Contents

```
mathematica/
  01_keypoint_analysis.wl          background check, keypoint maps, pairwise SURF matching
  02_shape_and_features.wl         outline shape, network features, nearest-other-species test, MDS
  03_keypoint_figures_masked.wl    keypoint figures with the background masked (Figures 1, 2, S1, S2)
python/
  make_contact_sheets.py           numbered thumbnail sheets used to find each element's photo run
  select_images.py                 copies the analysed frames into the PAPER folder structure
  assemble_figures.py              builds the manuscript figures from the Mathematica outputs
data/
  selection_log.txt                exact frames used for every element and species
```

## Requirements

- Wolfram Mathematica 15 (scripts use ImageKeypoints, ImageCorrespondingPoints, FeatureExtract, DimensionReduce)
- Python 3.9 or later with Pillow, NumPy and Matplotlib (`pip install pillow numpy matplotlib`)
- Internet access the first time `02_shape_and_features.wl` runs, to download Mathematica's default image feature extractor

## Data

The photographs are not included in this repository. They are available from the authors on request [or: archived at Zenodo, DOI to be added].

The scripts expect this folder layout (built by `select_images.py`):

```
PAPER/
  Mandible_lateral/  Hystrix_brachyura/  Trichys_fasciculata/  Muntiacus_muntjak/  Muntiacus_atherodes/
  Maxilla_ventral/   (same four species)
  Humerus/           Hystrix_brachyura/  Trichys_fasciculata/  Muntiacus_muntjak/
  Tibia/             Hystrix_brachyura/  Trichys_fasciculata/  Muntiacus_muntjak/
```

*M. atherodes* has no humerus or tibia folder because the reference skeleton lacks these bones. The scripts skip missing species automatically.

## How to reproduce

1. **Build the image set** (optional if you already have the PAPER folder):
   ```
   python python/make_contact_sheets.py "<RAW>/Malayan porcupine /Black bg " Hys sheets/
   python python/select_images.py <RAW> <PAPER>
   ```
   `<RAW>` is the folder holding the original species folders. Some original folder names end in a space; keep them as they are.

2. **Set the path.** In each of the three `.wl` files, edit the line marked `EDIT THIS LINE` so that `baseDir` points to your PAPER folder. Use the full path, in quotes.

3. **Run the Mathematica scripts in order** (open each file and choose Evaluation > Evaluate Notebook, or use `Get["path/to/file.wl"]`):
   - `01_keypoint_analysis.wl` writes to `PAPER/results`
   - `02_shape_and_features.wl` writes to `PAPER/results2`
   - `03_keypoint_figures_masked.wl` writes to `PAPER/results3`

   Script 01 is the slowest (several minutes for about 500 image pairs per element). If needed, lower `maxSize` near the top of the file.

4. **Assemble the figures:**
   ```
   python python/assemble_figures.py <PAPER> figures/
   ```

## Key settings (identical in all scripts)

| Setting | Value |
|---|---|
| Image size | longest side resized to 1000 px |
| Bone mask | greyscale, Binarize at 0.25, remove components < 200 px, fill holes, keep largest component |
| Crop margin | 20 px |
| Keypoints | SURF; 40 strongest for the background check; 25 strongest on bone for figures (from 80 candidates) |
| Matching | ImageCorrespondingPoints, SURF, TransformationClass "Similarity" |
| Outline shape | max centroid distance in 180 angular bins, mean-normalised, Fourier magnitudes 1 to 30 |
| Network features | FeatureExtract default extractor on square black-padded crops, cosine distance |
| Test | nearest image of a different species; success if congener (*Muntiacus*) or confamilial (Hystricidae); one-sided binomial |

## Notes

- Mathematica's default feature extractor can change between versions. Results for the network-feature analysis were produced with Mathematica 15.
- Images of one specimen are not independent, so p-values describe these specimens, not species in general.

## Licence

Code is released under the MIT Licence (see `LICENSE`).

## Contact

Nik Fadzly N Rosely, School of Biological Sciences, Universiti Sains Malaysia (nfadzly@usm.my)
