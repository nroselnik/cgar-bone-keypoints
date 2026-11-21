# cgar-bone-keypoints

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.24423156.svg)](https://doi.org/10.5281/zenodo.24423156)

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

The 107 analysed photographs are in `data/photos/`, as the original JPEG files from the camera (Canon EOS 600D, 18–55 mm lens, black background). The camera settings for each photograph are stored in its EXIF metadata. Photographs are released under CC BY 4.0 (see `data/photos/LICENSE`).

To run the analysis on these photographs, point `baseDir` in the scripts to `data/photos` (full path). The results folders are then written inside `data/photos`.

The scripts expect this folder layout (the same as `data/photos/`, and as built by `select_images.py`):

```
data/photos/   (or your own PAPER folder)
  Mandible_lateral/  Hystrix_brachyura/  Trichys_fasciculata/  Muntiacus_muntjak/  Muntiacus_atherodes/
  Maxilla_ventral/   (same four species)
  Humerus/           Hystrix_brachyura/  Trichys_fasciculata/  Muntiacus_muntjak/
  Tibia/             Hystrix_brachyura/  Trichys_fasciculata/  Muntiacus_muntjak/
```

*M. atherodes* has no humerus or tibia folder because the reference skeleton lacks these bones. The scripts skip missing species automatically.

## How to reproduce

1. **Build the image set** (skip this step if you use `data/photos/`):
   ```
   python python/make_contact_sheets.py "<RAW>/Malayan porcupine /Black bg " Hys sheets/
   python python/select_images.py <RAW> <PAPER>
   ```
   `<RAW>` is the folder holding the original species folders. Some original folder names end in a space; keep them as they are.

2. **Set the path.** In each of the three `.wl` files, edit the line marked `EDIT THIS LINE` so that `baseDir` points to `data/photos` (or your own PAPER folder). Use the full path, in quotes.

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

## Citing

Please cite the archived release: Othmarani, N. H. S., V. Bujeng, B. A. Bunyau and N. F. N. Rosely. 2026. cgar-bone-keypoints, v1.0. Zenodo. https://doi.org/10.5281/zenodo.24423156

## Licence

Code is released under the MIT Licence (see `LICENSE`). Photographs in `data/photos/` are released under the Creative Commons Attribution 4.0 International Licence (CC BY 4.0; see `data/photos/LICENSE`). Please credit the authors and the Centre for Global Archaeological Research, Universiti Sains Malaysia.

## Contact

Nik Fadzly N Rosely, School of Biological Sciences, Universiti Sains Malaysia (nfadzly@usm.my)
