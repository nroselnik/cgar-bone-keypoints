(* ::Package:: *)

(* ============================================================
   Part 3: keypoint figures with the background removed
   Fixes Figures 1 and 2: no keypoints on the black cloth.
   Steps per image:
     1. Bone mask (same settings as Parts 1 and 2)
     2. Background set to pure black (image x mask)
     3. SURF keypoints detected on the masked image
     4. Keypoints whose centre is not on the bone are dropped
     5. Strongest 25 remaining keypoints drawn
   Long bones lying horizontally are rotated upright so all
   panels share one orientation and height.
   Output: PAPER/results3
   ============================================================ *)

(* EDIT THIS LINE: full path to the PAPER folder (see README) *)
baseDir = "/path/to/PAPER";
If[! DirectoryQ[baseDir],
  Print["Folder not found. Check that Google Drive for desktop is running:\n", baseDir]; Abort[]];
SetDirectory[baseDir];
outDir = FileNameJoin[{baseDir, "results3"}];
If[! DirectoryQ[outDir], CreateDirectory[outDir]];
panelDir = FileNameJoin[{outDir, "panels"}];
If[! DirectoryQ[panelDir], CreateDirectory[panelDir]];

elements = {"Mandible_lateral", "Maxilla_ventral", "Humerus", "Tibia"};
speciesOrder = {"Hystrix_brachyura", "Trichys_fasciculata", "Muntiacus_muntjak", "Muntiacus_atherodes"};
shortName = <|"Hystrix_brachyura" -> "H. brachyura", "Trichys_fasciculata" -> "T. fasciculata",
   "Muntiacus_muntjak" -> "M. muntjak", "Muntiacus_atherodes" -> "M. atherodes"|>;

maxSize = 1000; bgThreshold = 0.25; cropMargin = 20;
nShow = 25;          (* keypoints drawn per panel *)
nCandidates = 80;    (* detected before filtering, so 25 remain after dropping off-bone points *)
panelHeight = 900;   (* all panels scaled to this height; each panel is also exported on its own *)

imageFiles[dir_] := Sort@FileNames[{"*.JPG", "*.jpg", "*.jpeg", "*.JPEG"}, dir];
loadImg[file_] := ImageResize[Import[file], {UpTo[maxSize], UpTo[maxSize]}];

boneMaskAndBox[img_] := Module[{bin, lab, counts, big, boxes},
  bin = FillingTransform@DeleteSmallComponents[
     Binarize[ColorConvert[img, "Grayscale"], bgThreshold], 200];
  lab = MorphologicalComponents[bin];
  counts = ComponentMeasurements[lab, "Count"];
  big = First[First[MaximalBy[counts, Last]]];
  boxes = Association@ComponentMeasurements[lab, "BoundingBox"];
  {Image[1 - Unitize[lab - big]], boxes[big]}
];

(* Returns {panel image, number of candidate keypoints dropped as off-bone} *)
maskedPanel[file_] := Module[{img, mask, box, clean, cleanC, maskC, kp, onBone, keep, dropped, out},
  img = loadImg[file];
  {mask, box} = boneMaskAndBox[img];
  clean = ImageMultiply[ColorConvert[img, "RGB"], ColorConvert[mask, "RGB"]];
  cleanC = ImageTrim[clean, box, cropMargin];
  maskC = ImageTrim[mask, box, cropMargin];
  kp = ImageKeypoints[cleanC, {"Position", "Scale", "Strength"},
     MaxFeatures -> nCandidates, Method -> "SURF"];
  onBone = (Round[PixelValue[maskC, #[[1]]]] == 1) & /@ kp;
  keep = Take[Reverse@SortBy[Pick[kp, onBone], Last], UpTo[nShow]];
  dropped = Count[onBone, False];
  out = HighlightImage[cleanC, {Red, AbsoluteThickness[2], Circle[#[[1]], 2.5 #[[2]]] & /@ keep,
      Yellow, PointSize[0.012], Point[keep[[All, 1]]]}];
  (* upright orientation for long bones photographed lying down *)
  If[MatchQ[ImageDimensions[out], {w_, h_} /; w > 1.3 h], out = ImageRotate[out, Pi/2]];
  {ImageResize[out, {Automatic, panelHeight}], dropped, Length[kp]}
];

log = {};
Do[
  Module[{panels = {}},
    Do[
      With[{files = imageFiles[FileNameJoin[{baseDir, el, sp}]]},
        If[files =!= {},
          With[{res = maskedPanel[First[files]]},
            Export[FileNameJoin[{panelDir, el <> "_" <> sp <> ".png"}], res[[1]]];
            AppendTo[panels, Labeled[res[[1]], Style[shortName[sp], 14, Italic], Bottom]];
            AppendTo[log, {el, sp, FileNameTake[First[files]], res[[3]], res[[2]]}]]]],
      {sp, speciesOrder}];
    fig = Row[panels, Spacer[20]];
    Export[FileNameJoin[{outDir, "keypoints_masked_" <> el <> ".png"}], fig, ImageResolution -> 300];
    Print[el]; Print[fig]],
  {el, elements}];

Export[FileNameJoin[{outDir, "keypoints_masked_log.csv"}],
  Prepend[log, {"Element", "Species", "File", "CandidatesDetected", "DroppedOffBone"}]];
Print[TableForm[log, TableHeadings -> {None, {"Element", "Species", "File", "Detected", "Dropped"}}]];
Print["Done. Results in: ", outDir];
