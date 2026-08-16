# Neura-Med AI Toolkit — User Manual

## 1. Setup

```matlab
setupNeuraMedToolkit
```

Verifies MATLAB version, Image Processing Toolbox, and MATLAB Report
Generator availability, then adds the toolkit to your path.

## 2. Module 1 — Signal Visualization

All viewers (`ECGViewer`, `EEGViewer`, `EMGViewer`, `PPGViewer`) share the
same base API from `SignalViewerBase`:

```matlab
v = neuramed.signals.ECGViewer(parentContainer, 'Theme', 'Dark');
v.initialize();
v.loadData(timeVec, signalMat, fs, channelNames);   % channelNames optional
v.zoomToWindow(2.0, 5.0);        % focus on a time range
v.addAnnotation(3.2, "PVC", "critical", "Suspected premature ventricular contraction");
m = v.measure(3.0, 3.8);         % returns dt, dAmplitude, rateBPM
v.setTheme("Light");             % live theme switch
```

Domain-specific extras:

| Viewer | Method | Returns |
|---|---|---|
| `ECGViewer` | `detectRPeaks('MinPeakDistance', 0.3)` | fills `RPeakTimes`, `HeartRateBPM` |
| `ECGViewer` | `rrIntervals()` | RR-interval vector (s) |
| `EEGViewer` | `computeBandPower(channelIdx)` | table of delta/theta/alpha/beta/gamma power |
| `EEGViewer` | `stackMontage(offsetFactor)` | vertically offsets channels for paper-style montage |
| `EMGViewer` | `computeEnvelope(windowSec)` | RMS envelope vector |
| `EMGViewer` | `detectOnsets(thresholdFactor)` | onset times (s) |
| `PPGViewer` | `detectPulses(minPeakDistanceSec)` | fills `PulseTimes`, `PulseRateBPM` |
| `PPGViewer` | `estimateSpO2(redSig, irSig)` | SpO2 % (⚠ calibrate constants before clinical use) |

To display several viewers stacked with synchronized zoom:

```matlab
mcv = neuramed.signals.MultiChannelViewer(parentContainer);
mcv.addViewer(ecgViewer, "ECG");
mcv.addViewer(eegViewer, "EEG");
mcv.initialize();   % auto-links x-axes
```

## 3. Module 2 — Image Visualization

```matlab
iv = neuramed.imaging.MedicalImageViewer(parentContainer);
iv.initialize();
iv.loadImage(retinalImage);
iv.setOverlay(gradCamMap, "heatmap");        % or segmentationMask, "segmentation"
roi = iv.selectROI("ellipse");
stats = iv.roiStats();                        % Mean/Std/PixelCount/AreaFraction
iv.showHistogram();
```

Multi-panel comparison (e.g. original / segmentation / heatmap):

```matlab
mpv = neuramed.imaging.MultiPanelViewer(parentContainer);
mpv.addPanel(viewer1, "Original");
mpv.addPanel(viewer2, "Segmentation");
mpv.addPanel(viewer3, "GradCAM");
mpv.initialize();
```

## 4. Module 3 — Clinical Dashboard

```matlab
dash = neuramed.dashboard.ClinicalDashboard(parentContainer);
dash.initialize();
dash.setPatient(struct('Name',"Jane Doe",'ID',"P-001",'Age',34,'Sex',"F",'Device',"Neurix Wristband"));
dash.setPrediction("Elevated Stress", 0.82, "Moderate");   % label, confidence[0-1], risk
dash.setAlarm("Warning", "HRV below baseline for 10 min");
dash.pushTrendPoint(t, value, "Stress Index");
dash.setSummary("Free-text clinical summary...");
```

Attach live signal/image panels before calling `initialize()`:

```matlab
dash.SignalDisplay = mcv;   % a MultiChannelViewer
dash.ImageDisplay  = iv;    % a MedicalImageViewer
dash.initialize();
```

## 5. Module 4 — Report Generation

```matlab
rg = neuramed.reporting.ReportGenerator("PatientReport_001", "pdf");
rg.addTitlePage("Neurix Stress Assessment Report", dash.PatientInfo);
rg.addSummary("Clinical Findings", dash.SummaryText);
rg.addFigure(figCM, "Confusion Matrix — Validation Set");
rg.addTable(summaryTable, "Session Summary");
rg.addRecommendations(["Repeat EEG in 2 weeks", "Refer to neurologist if HR > 100 at rest"]);
rg.close();
```

If MATLAB Report Generator is not installed, `ReportGenerator` prints a
warning and no-ops gracefully — use `ExportManager.exportFigure` directly
for a plain PDF/PNG of any single figure instead.

## 6. Module 5 — Publication Graphics

```matlab
fig1 = neuramed.publication.PublicationFigures.confusionMatrix(yTrue, yPred, ["Neg","Pos"]);
[fig2, auc] = neuramed.publication.PublicationFigures.rocCurve(labels, scores, 1);
fig3 = neuramed.publication.PublicationFigures.trainingCurves(epochs, trainLoss, valLoss, trainAcc, valAcc);
fig4 = neuramed.publication.PublicationFigures.accuracyComparison(["ResNet34","XGBoost","SVM"], [94.2 92.3 88.7]);
fig5 = neuramed.publication.PublicationFigures.statisticalBoxplot({group1, group2}, ["Control","Stress"], "HRV (ms)");
```

## 7. Module 6 — Export Utilities

```matlab
neuramed.utils.ExportManager.exportFigure(fig, "figure1", ["png","pdf","svg"], 600);
neuramed.utils.ExportManager.exportData(myTable, "results", ["csv","xlsx"]);
neuramed.utils.ExportManager.batchExport(fig, "final_confusion_matrix", "output/figures");
```

## 8. Module 7 — GUI Framework

- `neuramed.core.ThemeManager.palette("Dark" | "Light")` — get the active color palette.
- Every component supports `.setTheme("Dark"|"Light")` for live switching.
- `NeuraMedDashboardApp` (in `apps/`) is the reference App Designer-style
  application: sidebar navigation, dark/light toggle, and a fully wired
  `ClinicalDashboard`. Copy this file as the starting point for a new
  product-specific app.

## 9. Extending the Toolkit

To add a new viewer type (e.g. a future respiration/RESP viewer):

1. Create `+neuramed/+signals/RESPViewer.m` extending `SignalViewerBase`.
2. Override only what's specific to that signal (detection algorithm,
   default `Config.YLabel`/`Config.Title`).
3. It automatically inherits zoom, pan, annotations, theming, and
   measurement tools — no duplicate UI code required.

The same pattern applies to imaging (`MedicalImageViewer` subclasses) and
any new dashboard panel (compose it into `ClinicalDashboard.buildUI`).

## 10. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Undefined function or variable 'neuramed...'` | Toolkit not on path | Run `setupNeuraMedToolkit` |
| DOCX/PDF report is empty/basic | Report Generator not installed | Install "MATLAB Report Generator" add-on, or use `ExportManager` for plain figure export |
| ROI tools throw an error | Image Processing Toolbox missing | Install Image Processing Toolbox |
| Colors look wrong after `setTheme` | A custom component didn't call `applyTheme` correctly | Ensure your subclass's `applyTheme(obj, themeName)` reads from `ThemeManager.palette(themeName)` and doesn't hard-code colors |
