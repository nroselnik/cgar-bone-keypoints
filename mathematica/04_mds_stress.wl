(* ::Package:: *)

(* ============================================================
   Part 4: MDS ordinations with goodness-of-fit (stress)
   Same image set and descriptors as 02_shape_and_features.wl.

   Each ordination is computed by classical (Torgerson) MDS directly
   from the distance matrix used in the nearest-other-species test:
     Outline shape     -> Euclidean distance between Fourier descriptors
     Network features  -> cosine distance between feature vectors
   For each element and method it reports:
     Kruskal stress-1 of the 2-D solution
       Sqrt[ Sum (d_ij - dhat_ij)^2 / Sum d_ij^2 ]
       where d = original distance, dhat = distance on the MDS plot.
       Kruskal (1964): 0.20 poor, 0.10 fair, 0.05 good, 0.025 excellent.
     Variance explained by MDS axes 1 and 2
       (first two positive eigenvalues / sum of positive eigenvalues).
   Results go to PAPER/results4:
     MDS_coordinates_<method>_<element>.csv
     Distance_<method>_<element>.csv
     MDS_fit_summary.csv
   ============================================================ *)

(* ---------- 1. Paths and settings ---------- *)

(* EDIT THIS LINE: full path to the PAPER folder (or data/photos, see README) *)
baseDir = "/path/to/PAPER";

If[! DirectoryQ[baseDir],
  Print["Folder not found. Check that Google Drive for desktop is running:\n", baseDir];
  Abort[]
];
SetDirectory[baseDir];

outDir = FileNameJoin[{baseDir, "results4"}];
If[! DirectoryQ[outDir], CreateDirectory[outDir]];

elements = {"Mandible_lateral", "Maxilla_ventral", "Humerus", "Tibia"};
speciesOrder = {"Hystrix_brachyura", "Trichys_fasciculata", "Muntiacus_muntjak", "Muntiacus_atherodes"};

maxSize = 1000;
bgThreshold = 0.25;
cropMargin = 20;
nBins = 180;
nHarmonics = 30;

(* ---------- 2. Helpers (identical to Part 2) ---------- *)

imageFiles[dir_] := Sort@FileNames[{"*.JPG", "*.jpg", "*.jpeg", "*.JPEG"}, dir];
loadImg[file_] := ImageResize[Import[file], {UpTo[maxSize], UpTo[maxSize]}];

boneMaskAndBox[img_] := Module[{bin, lab, counts, big, boxes},
  bin = FillingTransform@DeleteSmallComponents[
     Binarize[ColorConvert[img, "Grayscale"], bgThreshold], 200];
  lab = MorphologicalComponents[bin];
  counts = ComponentMeasurements[lab, "Count"];
  If[counts === {}, Return[{bin, {{1, 1}, ImageDimensions[img]}}]];
  big = First[First[MaximalBy[counts, Last]]];
  boxes = Association@ComponentMeasurements[lab, "BoundingBox"];
  {Image[1 - Unitize[lab - big]], boxes[big]}
];

squareCrop[img_, box_] := Module[{c = ImageTrim[img, box, cropMargin], s},
  s = Max[ImageDimensions[c]];
  ImageCrop[c, {s, s}, Padding -> Black]];

shapeDescriptor[mask_] := Module[{m, pts, c, d, ang, bins, prof},
  m = ImageResize[mask, {UpTo[400], UpTo[400]}];
  pts = N@PixelValuePositions[Binarize[m, 0.5], 1];
  If[Length[pts] < 50, Return[ConstantArray[0., nHarmonics]]];
  c = Mean[pts];
  d = Norm /@ (# - c & /@ pts);
  ang = ArcTan @@@ (# - c & /@ pts);
  bins = Clip[Floor[(ang + Pi)/(2 Pi) nBins] + 1, {1, nBins}];
  prof = Table[0., nBins];
  MapThread[(prof[[#1]] = Max[prof[[#1]], #2]) &, {bins, d}];
  prof = prof / Mean[prof];
  Abs[Fourier[prof]][[2 ;; nHarmonics + 1]]
];

(* Classical (Torgerson) MDS from a distance matrix.
   Returns {2-D coordinates, all eigenvalues in decreasing order}. *)
classicalMDS[d_, k_: 2] := Module[{n = Length[d], J, B, es, vs, ord},
  J = IdentityMatrix[n] - ConstantArray[1./n, {n, n}];
  B = -0.5 J . (N[d]^2) . J;
  B = (B + Transpose[B])/2;
  {es, vs} = Eigensystem[B];
  ord = Ordering[es, All, Greater];
  es = es[[ord]]; vs = Normalize /@ vs[[ord]];
  {Transpose[vs[[;; k]]] . DiagonalMatrix[Sqrt[Clip[es[[;; k]], {0., Infinity}]]], es}
];

stress1[d_, x_] := Module[{dh = DistanceMatrix[x]},
  Sqrt[Total[Flatten[(N[d] - dh)^2]]/Total[Flatten[N[d]^2]]]];

varExplained2[es_] := Module[{pos = Select[es, # > 0 &]},
  Total[Take[pos, Min[2, Length[pos]]]]/Total[pos]];

(* ---------- 3. Load, mask, describe ---------- *)

records = Flatten@Table[
   Module[{files = imageFiles[FileNameJoin[{baseDir, el, sp}]]},
     Table[
       Module[{img = loadImg[f], mb},
         mb = boneMaskAndBox[img];
         <|"element" -> el, "species" -> sp, "file" -> FileNameTake[f],
           "square" -> squareCrop[img, mb[[2]]],
           "shape" -> shapeDescriptor[mb[[1]]]|>],
       {f, files}]],
   {el, elements}, {sp, speciesOrder}];
Print["Images processed: ", Length[records]];

Print["Extracting network features..."];
allFeatures = FeatureExtract[records[[All, "square"]]];
records = MapThread[Append[#1, "deep" -> #2] &, {records, allFeatures}];

(* ---------- 4. MDS and fit per element and method ---------- *)

fit = {};
Do[
  Module[{recs = Select[records, #element == el &], d, mds, xy, s, ve, negShare},
    Do[
      d = If[method == "Shape",
        DistanceMatrix[recs[[All, "shape"]], DistanceFunction -> EuclideanDistance],
        DistanceMatrix[recs[[All, "deep"]], DistanceFunction -> CosineDistance]];
      mds = classicalMDS[d, 2];
      xy = mds[[1]];
      s = stress1[d, xy];
      ve = varExplained2[mds[[2]]];
      negShare = Total[Abs@Select[mds[[2]], # < 0 &]]/Total[Abs[mds[[2]]]];
      AppendTo[fit, {el, method, Length[recs], N[s], N[ve], N[negShare]}];

      Export[FileNameJoin[{outDir, "MDS_coordinates_" <> method <> "_" <> el <> ".csv"}],
        Prepend[Transpose[{recs[[All, "file"]], recs[[All, "species"]], xy[[All, 1]], xy[[All, 2]]}],
          {"File", "Species", "MDS1", "MDS2"}]];
      Export[FileNameJoin[{outDir, "Distance_" <> method <> "_" <> el <> ".csv"}],
        Prepend[MapThread[Prepend, {d, recs[[All, "file"]]}], Prepend[recs[[All, "file"]], ""]]];
      Print[el, " | ", method, " | stress-1 = ", NumberForm[s, {3, 3}],
        " | variance on axes 1-2 = ", NumberForm[100 ve, {3, 1}], "%"],
      {method, {"Shape", "Deep"}}]],
  {el, elements}];

Export[FileNameJoin[{outDir, "MDS_fit_summary.csv"}],
  Prepend[fit, {"Element", "Method", "Images", "KruskalStress1", "VarianceAxes12", "NegativeEigenvalueShare"}]];
Print[TableForm[fit, TableHeadings -> {None,
   {"Element", "Method", "n", "Stress-1", "Var 1-2", "Neg. eig."}}]];
Print["Done. Results in: ", outDir];
