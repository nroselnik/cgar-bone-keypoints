(* ::Package:: *)

(* ============================================================
   Keypoint analysis of diagnostic skeletal elements
   CGAR reference bones (Hanani FYP 2026 image set)
   Elements: Mandible_lateral, Maxilla_ventral, Humerus, Tibia
   Species: Hystrix brachyura, Trichys fasciculata,
            Muntiacus muntjak, Muntiacus atherodes
   Method: SURF keypoints (ImageKeypoints) and keypoint matching
           (ImageCorrespondingPoints), after Fadzly et al. 2021
   Open in Mathematica and run all (Evaluation > Evaluate Notebook),
   or run Get["<path>/keypoint_analysis.wl"].
   ============================================================ *)

(* ---------- 1. Paths and settings ---------- *)

(* EDIT THIS LINE: full path to the PAPER folder (see README) *)
baseDir = "/path/to/PAPER";

If[! DirectoryQ[baseDir],
  Print["Folder not found. Check that Google Drive for desktop is running:\n", baseDir];
  Abort[]
];
SetDirectory[baseDir];

outDir = FileNameJoin[{baseDir, "results"}];
If[! DirectoryQ[outDir], CreateDirectory[outDir]];

elements = {"Mandible_lateral", "Maxilla_ventral", "Humerus", "Tibia"};
speciesOrder = {"Hystrix_brachyura", "Trichys_fasciculata", "Muntiacus_muntjak", "Muntiacus_atherodes"};
shortName = <|
  "Hystrix_brachyura" -> "H. brachyura",
  "Trichys_fasciculata" -> "T. fasciculata",
  "Muntiacus_muntjak" -> "M. muntjak",
  "Muntiacus_atherodes" -> "M. atherodes"|>;

maxSize = 1000;        (* resize longest side to this many pixels *)
nKeypointsBg = 40;     (* keypoints used for the background check *)
nKeypointsFig = 25;    (* strongest keypoints drawn on figures *)
bgThreshold = 0.25;    (* grey level separating bone from black cloth; raise if cloth is picked up *)
cropMargin = 20;       (* pixels kept around the bone when cropping *)

(* ---------- 2. Helper functions ---------- *)

imageFiles[dir_] := Sort@FileNames[{"*.JPG", "*.jpg", "*.jpeg", "*.JPEG"}, dir];

loadImg[file_] := ImageResize[Import[file], {UpTo[maxSize], UpTo[maxSize]}];

(* Largest bright component = the bone. Returns {mask, boundingBox}. *)
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

cropBone[img_] := Module[{mb = boneMaskAndBox[img]},
  ImageTrim[img, mb[[2]], cropMargin]];

(* Fraction of the strongest keypoints that fall on the background, not the bone *)
backgroundFraction[img_] := Module[{mb, kp, onBone},
  mb = boneMaskAndBox[img];
  kp = ImageKeypoints[img, "Position", MaxFeatures -> nKeypointsBg, Method -> "SURF"];
  If[kp === {}, Return[Missing["NoKeypoints"]]];
  onBone = Round[PixelValue[mb[[1]], #]] & /@ kp;
  N[Count[onBone, 0] / Length[kp]]
];

keypointFigure[img_, label_] := Module[{kp},
  kp = ImageKeypoints[img, {"Position", "Scale"}, MaxFeatures -> nKeypointsFig, Method -> "SURF"];
  Labeled[
    HighlightImage[img, {Red, AbsoluteThickness[2], Circle[#[[1]], 2.5 #[[2]]] & /@ kp,
       Yellow, PointSize[0.012], Point[kp[[All, 1]]]}],
    Style[label, 12, Italic], Top]
];

matchCount[a_, b_] := Quiet@Check[
   Length@First@ImageCorrespondingPoints[a, b, Method -> "SURF",
      TransformationClass -> "Similarity"], 0];

(* ---------- 3. Load images ---------- *)

loadSpecies[el_, sp_] := Module[{files = imageFiles[FileNameJoin[{baseDir, el, sp}]]},
   If[files === {}, Nothing,
     sp -> <|"files" -> (FileNameTake /@ files), "images" -> (loadImg /@ files)|>]];

(* species with no folder (e.g. M. atherodes humerus and tibia) are skipped *)
data = Association@Table[el -> Association@Table[loadSpecies[el, sp], {sp, speciesOrder}],
   {el, elements}];

Print["Images loaded:"];
Do[Print["  ", el, ": ",
   KeyValueMap[shortName[#1] <> " " <> ToString[Length[#2["files"]]] &, data[el]]],
  {el, elements}];

(* ---------- 4. Background check (uncropped images) ---------- *)
(* High values mean the detector is looking at the cloth, the failure seen in
   Fadzly et al. 2021 (Fig. 1a) and in Hanani's YOLO models. *)

bgTable = Flatten[Table[
    MapThread[{el, sp, #1, backgroundFraction[#2]} &,
      {data[el][sp]["files"], data[el][sp]["images"]}],
    {el, Keys[data]}, {sp, Keys[data[el]]}], 2];

Export[FileNameJoin[{outDir, "background_keypoint_fraction.csv"}],
  Prepend[bgTable, {"Element", "Species", "File", "FractionKeypointsOnBackground"}]];

Print["Mean fraction of keypoints on background, by element:"];
Print[Dataset@GroupBy[bgTable, First -> Last, Mean@*DeleteMissing]];

(* ---------- 5. Crop to the bone ---------- *)

crops = Map[<|#, "crops" -> (cropBone /@ #["images"])|> &, data, {2}];

(* ---------- 6. Keypoint figures: first image of each species per element ---------- *)

Do[
  fig = Row[KeyValueMap[keypointFigure[First[#2["crops"]], shortName[#1]] &, crops[el]],
    Spacer[10]];
  Export[FileNameJoin[{outDir, "keypoints_" <> el <> ".png"}], fig, ImageResolution -> 200];
  Print[el]; Print[fig],
  {el, elements}];

(* ---------- 7. Pairwise keypoint matching ---------- *)

matchResults = Association[];

Do[
  Module[{labels, imgs, files, n, pairs, m, counter = 0, spList, spMat, spNames},
    labels = Flatten[KeyValueMap[ConstantArray[#1, Length[#2["crops"]]] &, crops[el]]];
    imgs = Flatten[Values[crops[el]][[All, "crops"]]];
    files = Flatten[Values[crops[el]][[All, "files"]]];
    n = Length[imgs];
    pairs = Subsets[Range[n], {2}];
    m = ConstantArray[0, {n, n}];
    Print["Matching ", el, ": ", Length[pairs], " pairs"];
    Monitor[
      Do[counter++;
        With[{c = matchCount[imgs[[p[[1]]]], imgs[[p[[2]]]]]},
          m[[p[[1]], p[[2]]]] = c; m[[p[[2]], p[[1]]]] = c],
        {p, pairs}],
      ProgressIndicator[counter, {0, Length[pairs]}]];

    (* image-level matrix *)
    Export[FileNameJoin[{outDir, "pairwise_matches_" <> el <> ".csv"}],
      Prepend[MapThread[Prepend, {m, files}], Prepend[files, ""]]];
    Export[FileNameJoin[{outDir, "pairwise_matches_" <> el <> ".png"}],
      MatrixPlot[m, ColorFunction -> "SunsetColors", PlotLegends -> Automatic,
        FrameTicks -> None, PlotLabel -> el <> ": matched keypoints, image by image\n(blocks on the diagonal = photos of the same specimen)"],
      ImageResolution -> 200];

    (* species-level mean matches; diagonal = same specimen, different photos *)
    spList = Keys[crops[el]];
    spNames = shortName /@ spList;
    spMat = Table[
      Module[{ii = Flatten@Position[labels, s1], jj = Flatten@Position[labels, s2], vals},
        vals = Flatten@Table[If[i == j, Nothing, m[[i, j]]], {i, ii}, {j, jj}];
        If[vals === {}, Missing[], N@Mean[vals]]],
      {s1, spList}, {s2, spList}];

    Export[FileNameJoin[{outDir, "species_mean_matches_" <> el <> ".csv"}],
      Prepend[MapThread[Prepend, {spMat, spNames}], Prepend[spNames, ""]]];
    Export[FileNameJoin[{outDir, "species_mean_matches_" <> el <> ".png"}],
      MatrixPlot[spMat /. Missing[] -> 0, ColorFunction -> "SunsetColors",
        PlotLegends -> Automatic,
        FrameTicks -> {{Transpose[{Range[Length[spNames]], spNames}], None},
                       {None, Transpose[{Range[Length[spNames]], Rotate[#, Pi/2] & /@ spNames}]}},
        PlotLabel -> el <> ": mean matched keypoints between species"],
      ImageResolution -> 200];

    (* dendrogram on cross-species similarity only *)
    If[Length[spList] >= 3,
      Module[{dist, dendro},
        dist[a_, b_] := Module[{i = First@FirstPosition[spList, a], j = First@FirstPosition[spList, b]},
          1/(1 + spMat[[i, j]])];
        dendro = Quiet@Check[
          Dendrogram[spList, Top, DistanceFunction -> dist,
            ClusterDissimilarityFunction -> "Average", PlotLabel -> el], $Failed];
        If[dendro =!= $Failed,
          Export[FileNameJoin[{outDir, "dendrogram_" <> el <> ".png"}], dendro, ImageResolution -> 200];
          Print[dendro]]
      ]];

    matchResults[el] = <|"labels" -> labels, "files" -> files, "imageMatrix" -> m,
       "speciesMatrix" -> spMat, "species" -> spNames|>;
    Print[TableForm[spMat, TableHeadings -> {spNames, spNames}]];
  ],
  {el, elements}];

(* ---------- 8. Save workspace ---------- *)

DumpSave[FileNameJoin[{outDir, "keypoint_workspace.mx"}], {matchResults, bgTable}];
Print["Done. Results in: ", outDir];
