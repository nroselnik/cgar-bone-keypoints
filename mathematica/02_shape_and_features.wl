(* ::Package:: *)

(* ============================================================
   Part 2: shape and deep-feature comparison between species
   Same image set as keypoint_analysis.wl (PAPER folder).
   Adds:
     A. Fixed keypoint figures (labels under each image)
     B. Silhouette shape: centroid-distance profile, Fourier magnitudes
        (invariant to rotation, scale, start point and mirroring)
     C. Pretrained-network features (FeatureExtract), cosine distance
     D. Nearest-other-species test: for each image, which OTHER species
        is most similar? Congener/confamilial pairs:
        Muntiacus muntjak + M. atherodes; Hystrix + Trichys (Hystricidae)
   Results go to PAPER/results2.
   ============================================================ *)

(* ---------- 1. Paths and settings ---------- *)

(* EDIT THIS LINE: full path to the PAPER folder (see README) *)
baseDir = "/path/to/PAPER";

If[! DirectoryQ[baseDir],
  Print["Folder not found. Check that Google Drive for desktop is running:\n", baseDir];
  Abort[]
];
SetDirectory[baseDir];

outDir = FileNameJoin[{baseDir, "results2"}];
If[! DirectoryQ[outDir], CreateDirectory[outDir]];

elements = {"Mandible_lateral", "Maxilla_ventral", "Humerus", "Tibia"};
speciesOrder = {"Hystrix_brachyura", "Trichys_fasciculata", "Muntiacus_muntjak", "Muntiacus_atherodes"};
shortName = <|
  "Hystrix_brachyura" -> "H. brachyura",
  "Trichys_fasciculata" -> "T. fasciculata",
  "Muntiacus_muntjak" -> "M. muntjak",
  "Muntiacus_atherodes" -> "M. atherodes"|>;
group = <|
  "Hystrix_brachyura" -> "Hystricidae", "Trichys_fasciculata" -> "Hystricidae",
  "Muntiacus_muntjak" -> "Muntiacus", "Muntiacus_atherodes" -> "Muntiacus"|>;
speciesColour = <|
  "Hystrix_brachyura" -> RGBColor[0.85, 0.37, 0.0], "Trichys_fasciculata" -> RGBColor[0.95, 0.65, 0.2],
  "Muntiacus_muntjak" -> RGBColor[0.0, 0.45, 0.7], "Muntiacus_atherodes" -> RGBColor[0.35, 0.7, 0.9]|>;

maxSize = 1000;
bgThreshold = 0.25;    (* same as Part 1 *)
cropMargin = 20;
nKeypointsFig = 25;
nBins = 180;           (* angular bins for the silhouette profile *)
nHarmonics = 30;       (* Fourier magnitudes kept as the shape descriptor *)

(* ---------- 2. Helpers (same masking as Part 1) ---------- *)

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

(* square, black-padded crop so the network does not stretch long bones *)
squareCrop[img_, box_] := Module[{c = ImageTrim[img, box, cropMargin], s},
  s = Max[ImageDimensions[c]];
  ImageCrop[c, {s, s}, Padding -> Black]];

(* Silhouette descriptor: max radius from centroid in each angular bin,
   normalised by its mean, then Fourier magnitudes. *)
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

keypointFigure[img_, label_] := Module[{kp},
  kp = ImageKeypoints[img, {"Position", "Scale"}, MaxFeatures -> nKeypointsFig, Method -> "SURF"];
  Labeled[
    Show[HighlightImage[img, {Red, AbsoluteThickness[2], Circle[#[[1]], 2.5 #[[2]]] & /@ kp,
        Yellow, PointSize[0.012], Point[kp[[All, 1]]]}], ImageSize -> {Automatic, 320}],
    Style[label, 13, Italic], Bottom]
];

(* For each image, the most similar image of a DIFFERENT species *)
nearestOtherSpecies[dist_, labels_] := Table[
   Module[{others = Select[Range[Length[labels]], labels[[#]] =!= labels[[i]] &]},
     labels[[First@MinimalBy[others, dist[[i, #]] &]]]],
   {i, Length[labels]}];

speciesMeanDist[dist_, labels_, spList_] := Table[
   Module[{ii = Flatten@Position[labels, a], jj = Flatten@Position[labels, b], v},
     v = Flatten@Table[If[i == j, Nothing, dist[[i, j]]], {i, ii}, {j, jj}];
     If[v === {}, Missing[], N@Mean[v]]],
   {a, spList}, {b, spList}];

exportMatrix[file_, mat_, names_] := Export[file,
   Prepend[MapThread[Prepend, {mat /. Missing[] -> "NA", names}], Prepend[names, ""]]];

(* ---------- 3. Load, mask and crop ---------- *)

records = Flatten@Table[
   Module[{files = imageFiles[FileNameJoin[{baseDir, el, sp}]]},
     Table[
       Module[{img = loadImg[f], mb},
         mb = boneMaskAndBox[img];
         <|"element" -> el, "species" -> sp, "file" -> FileNameTake[f],
           "crop" -> ImageTrim[img, mb[[2]], cropMargin],
           "square" -> squareCrop[img, mb[[2]]],
           "shape" -> shapeDescriptor[mb[[1]]]|>],
       {f, files}]],
   {el, elements}, {sp, speciesOrder}];

Print["Images processed: ", Length[records]];

(* ---------- 4. A. Fixed keypoint figures ---------- *)

Do[
  Module[{recs = Select[records, #element == el &], firsts},
    firsts = First /@ GatherBy[recs, #species &];
    fig = Row[keypointFigure[#crop, shortName[#species]] & /@ firsts, Spacer[15]];
    Export[FileNameJoin[{outDir, "keypoints_" <> el <> ".png"}], fig, ImageResolution -> 200];
    Print[el]; Print[fig]],
  {el, elements}];

(* ---------- 5. Deep features (one call, all images) ---------- *)
(* The first run downloads the default image feature extractor. *)

Print["Extracting network features..."];
allFeatures = FeatureExtract[records[[All, "square"]]];
records = MapThread[Append[#1, "deep" -> #2] &, {records, allFeatures}];

(* ---------- 6. B, C, D per element ---------- *)

summary = {};

Do[
  Module[{recs = Select[records, #element == el &], labels, spList, names,
      shapeD, deepD, method, dist, nn, congener, nCong, n, chance, pval, coords, plot},
    labels = recs[[All, "species"]];
    spList = DeleteDuplicates[labels];
    names = shortName /@ spList;
    shapeD = DistanceMatrix[recs[[All, "shape"]], DistanceFunction -> EuclideanDistance];
    deepD = DistanceMatrix[recs[[All, "deep"]], DistanceFunction -> CosineDistance];

    Do[
      dist = If[method == "Shape", shapeD, deepD];

      exportMatrix[FileNameJoin[{outDir, method <> "_species_mean_distance_" <> el <> ".csv"}],
        speciesMeanDist[dist, labels, spList], names];

      (* nearest other species *)
      nn = nearestOtherSpecies[dist, labels];
      Export[FileNameJoin[{outDir, method <> "_nearest_other_species_" <> el <> ".csv"}],
        Prepend[Transpose[{recs[[All, "file"]], shortName /@ labels, shortName /@ nn}],
          {"File", "Species", "NearestOtherSpecies"}]];

      (* congener / confamilial test, only where the partner species is present *)
      congener = Select[Transpose[{labels, nn}],
        Count[spList, s_ /; group[s] == group[#[[1]]]] >= 2 &];
      n = Length[congener];
      nCong = Count[congener, {a_, b_} /; group[a] == group[b]];
      chance = If[n == 0, Missing[],
        Mean[Table[1./(Length[spList] - 1), n]]];
      pval = If[n == 0, Missing[],
        N[1 - CDF[BinomialDistribution[n, chance], nCong - 1]]];
      AppendTo[summary, {el, method, Length[spList], n, nCong,
        If[n == 0, "NA", N[nCong/n]], chance /. Missing[] -> "NA", pval /. Missing[] -> "NA"}];

      Print[el, " | ", method, " | nearest other species is the congener/confamilial in ",
        nCong, " of ", n, " images (chance = ", chance, ", one-sided binomial p = ", pval, ")"];
      Print[TableForm[Tally[Transpose[{shortName /@ labels, shortName /@ nn}]]]];

      (* MDS plot *)
      coords = Quiet@Check[DimensionReduce[If[method == "Shape", recs[[All, "shape"]], recs[[All, "deep"]]], 2,
          Method -> "MultidimensionalScaling"], $Failed];
      If[coords =!= $Failed,
        plot = ListPlot[
          Table[Pick[coords, labels, s], {s, spList}],
          PlotStyle -> (Directive[speciesColour[#], PointSize[0.025]] & /@ spList),
          PlotLegends -> (Style[#, Italic] & /@ names), Frame -> True,
          FrameLabel -> {"MDS 1", "MDS 2"}, PlotLabel -> el <> " (" <> method <> ")",
          ImageSize -> 450];
        Export[FileNameJoin[{outDir, method <> "_MDS_" <> el <> ".png"}], plot, ImageResolution -> 200];
        Print[plot]],
      {method, {"Shape", "Deep"}}]],
  {el, elements}];

Export[FileNameJoin[{outDir, "nearest_other_species_summary.csv"}],
  Prepend[summary, {"Element", "Method", "SpeciesPresent", "ImagesTested",
    "NearestIsCongenerOrConfamilial", "Proportion", "ChanceExpectation", "OneSidedBinomialP"}]];

Print[TableForm[summary, TableHeadings -> {None,
   {"Element", "Method", "Spp", "n", "Congener", "Prop", "Chance", "p"}}]];

DumpSave[FileNameJoin[{outDir, "shape_features_workspace.mx"}], {summary}];
Print["Done. Results in: ", outDir];
