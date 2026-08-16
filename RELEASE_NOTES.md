# Release Notes — Neura-Med AI Biomedical Visualization & Reporting Toolkit

## v1.1.1 — Patch (2026-08-16)

### Fixed (found via first real execution in MATLAB R2025a)
- `ReportGenerator` and `setupNeuraMedToolkit`: detection of MATLAB Report
  Generator relied solely on `~isempty(which('mlreportgen.dom.Document'))`,
  which only confirms the class file is findable on the path — it does
  **not** confirm a valid license is actually checked out. On systems
  where the class stub is findable but Report Generator isn't licensed,
  this left `HasReportGen = true` and caused every subsequent `addXxx()`
  call to throw `"Unable to check out a Report Generator license"` instead
  of gracefully falling back, defeating the whole point of the flag.
  Fixed by checking `license('test', 'MATLAB_Report_Generator')` first,
  and additionally wrapping the actual `Document()` construction in
  try/catch as a second line of defense against any other real-world
  install issue — either failure now cleanly sets `HasReportGen = false`
  with one clear warning instead of a crash.
- `examples/ValidateImageAndReportModules.m`: now checks `HasReportGen`
  up front and marks Module 4 content checks as explicit SKIPPED (with
  reason) rather than silently recording a misleading PASS for `addXxx()`
  calls that no-op when Report Generator isn't licensed.
- `tests/test_ImageAndReporting.m`: applied the same corrected license
  check so the full-pipeline PDF test cleanly skips instead of failing
  with a license-checkout error on unlicensed systems.

### Validation status — CONFIRMED by actual execution (MATLAB R2025a, 2026-08-16)
- **Module 2 (Image Visualization): 13/13 checks PASSED**, confirmed by
  actual execution — image loading (RGB + grayscale), heatmap/segmentation
  overlays, overlay size-mismatch validation, programmatic ROI selection,
  ROI statistics, histogram, multi-panel viewing including the dynamic
  add-after-initialize() fix, and image comparison.
- **Module 4 (Report Generation): degrades correctly, confirmed by
  execution.** No crash; clean `[NOTICE]`; construction check passed
  (`HasReportGen = 0`, correctly detected); all six content-generation
  checks correctly reported SKIPPED; the two PDF-output checks correctly
  FAILED with an honest reason (no license = no PDF produced) — this is
  the intended, documented behavior on an unlicensed system, not a bug.
- **Unit tests (`test_ImageAndReporting`): 12 passed, 0 failed, 1
  correctly filtered** by `assumeFail` (the full-PDF-pipeline test hits
  the same license gap and skips cleanly instead of failing).
- **Dashboard Signal Display integration: confirmed by execution.** The
  ECG trace with R-peak annotations now renders directly inside the
  Clinical Dashboard's own Signal Display panel.

## v1.1.0 — Module 2 & 4 Validation Pass + Dashboard Signal Integration (2026-08-07)

### Added
- `examples/ValidateImageAndReportModules.m` — runnable validation script
  exercising every Module 2 (Image Visualization) and Module 4 (Report
  Generation) function against synthetic data, printing PASS/FAIL per check.
- `tests/test_ImageAndReporting.m` — headless `matlab.unittest` coverage
  for the same two modules, following the existing test suite pattern.
- `MedicalImageViewer.selectROI` now accepts an optional programmatic
  `position` argument (rectangle/ellipse/polygon), so ROI selection can be
  exercised in automated scripts/tests without blocking on interactive
  mouse input. Interactive behavior (no position given) is unchanged.

### Fixed (genuine bugs found during code review)
- `MedicalImageViewer.refresh`: setting the axes colormap for a heatmap
  overlay (e.g. `'jet'`) also recolored the base image whenever it was a
  grayscale (2D) array, since `imshow` of a 2D array is colormap-indexed —
  this went unnoticed while only RGB images had been exercised so far.
  Fixed by forcing the base image to true-color RGB at `loadImage()` time,
  making it immune to axes colormap changes regardless of input format.
- `MedicalImageViewer.setOverlay`: added explicit dimension-mismatch
  validation (`NeuraMed:OverlaySizeMismatch`) and a missing-image check
  (`NeuraMed:NoImage`) — previously a mismatched mask size or a missing
  base image would fail with a confusing low-level error deep inside
  `imagesc`/`bwboundaries` instead of a clear message at the call site.
- `MultiPanelViewer.addPanel`: calling this after `initialize()` updated
  the panel count/grid size but never actually parented or built the new
  panel — it silently never appeared. Refactored `buildUI`/`addPanel` to
  share a `reflowPanels` method so panels added dynamically are correctly
  attached, built, and laid out, matching panels added before `initialize()`.
- `ReportGenerator.addFigure`: `img.Height = []` was a type mismatch (the
  DOM `Image.Height` property requires a char/string, not numeric empty)
  that would have thrown a property validation error the first time
  `addFigure()` ran, breaking the whole report pipeline. Per MathWorks
  documentation, setting only `Width` auto-scales `Height` to preserve
  aspect ratio, so the line was removed rather than reassigned.
- `ReportGenerator` constructor: cast `fileNameNoExt`/`format` to `char`
  before passing to `mlreportgen.dom.Document(...)` as defensive insurance
  against string-type edge cases in that API.

### Changed
- `NeuraMedDashboardApp`: the Clinical Dashboard's Signal Display panel
  now hosts a live `ECGViewer` directly (same class already validated
  standalone in `RunFullDemo.m`), populated with the same synthetic ECG
  data and R-peak detection call. Previously this panel was an empty
  placeholder and the ECG only appeared in a separate standalone window.
- `examples/RunFullDemo.m`: added a clarifying comment noting that its
  standalone ECG viewer window is a Module 1 API demo distinct from the
  dashboard's own integrated Signal Display panel.

### Validation status
Every check above was prepared and code-reviewed but **requires
confirmation by running `ValidateImageAndReportModules.m` and
`runtests('test_ImageAndReporting')` in MATLAB R2025a** — these changes
were authored and statically reviewed without MATLAB execution access.
See the validation report delivered alongside this release for the exact
scope of what has and has not been confirmed by actual execution.

## v1.0.4 — Patch (2026-08-06)

### Fixed
- `NeuraMedDashboardApp`: card panels (Patient Information, Signal Display,
  Image Display, etc.) rendered with dark/near-black backgrounds and
  low-contrast or invisible text, even though `ThemeManager`'s Light
  palette explicitly sets them to white with dark text. Root cause:
  starting in R2025a, `uifigure` automatically inherits the MATLAB
  **desktop's** dark/light theme unless the figure's own `Theme` property
  is explicitly pinned — so on a machine with the MATLAB desktop in dark
  mode, the app silently rendered dark regardless of what our own
  `ThemeManager` palette specified, and our Light-theme text colors
  (designed for a white background) ended up nearly invisible against it.
  Fixed by explicitly setting `uifigure(..., 'Theme', 'light')` (or
  `'dark'`, matching `CurrentTheme`) at app creation, and keeping
  `app.UIFigure.Theme` in sync whenever the Dark Mode switch is toggled.
  This is the approach MathWorks documents for apps that need consistent
  appearance regardless of the end user's desktop theme setting.

## v1.0.3 — Patch (2026-08-06)

### Fixed
- `ClinicalDashboard`: Patient Information panel stayed blank even after
  the row-height fix in v1.0.2. Root cause was structural, not sizing:
  `renderPatientInfo` deleted and recreated the entire nested grid layout
  on every call (once during initial build with empty data, again when
  `setPatient()` supplied real data) — that delete-and-rebuild-a-nested-
  layout-inside-a-layout pattern doesn't reliably repaint. Alarm Status
  and Disease Prediction never had this problem because they build their
  labels/gauge once and only update `.Text`/`.Value` afterward. Patient
  Information now follows the same build-once, update-in-place pattern:
  a new `buildPatientCard` constructs the 4 label rows a single time
  during `buildUI`, and `renderPatientInfo` only updates their `.Text`.

## v1.0.2 — Patch (2026-08-06)

### Fixed
- `ClinicalDashboard`: the top row (Patient Information / Alarm Status /
  Disease Prediction cards) was fixed at 90px tall — nowhere near enough
  to fit a 4-row patient info grid or a circular confidence gauge. Patient
  Information rendered blank and the gauge collapsed into an unreadable
  sliver. Fixed by:
  - increasing the top row height from 90px to 230px,
  - giving the prediction card an explicit label/gauge row split (28px
    label, remaining space to the gauge) instead of an even 50/50 split,
  - giving the patient info grid explicit row heights (26px) and column
    widths instead of relying on default equal-fraction sizing,
  - explicitly setting label `FontColor` from the active theme palette as
    a defensive measure against any figure-level theme overriding default
    text colors.

## v1.0.1 — Patch (2026-08-06)

### Fixed
- `PublicationFigures.confusionMatrix`: passing custom `classNames` alongside
  raw numeric label vectors triggered `Unable to set the 'ClassLabels'
  property... because it is read-only` on R2025a (and some other releases).
  Fixed by building the confusion matrix explicitly via `confusionmat` and
  calling `confusionchart(matrix, labels)` — the documented-safe path for
  custom class names. Also now raises a clear `NeuraMed:ClassLabelMismatch`
  error if `classNames` doesn't have one entry per detected class, instead
  of failing inside MATLAB's chart constructor.

## v1.0.0 — Initial Release (2026-07-10)

### Added
- **Module 1 — Signal Visualization**: `SignalViewerBase` engine with
  interactive zoom/pan, annotations, and cursor measurement; concrete
  `ECGViewer` (R-peak/HR/RR), `EEGViewer` (band power, montage stacking),
  `EMGViewer` (RMS envelope, onset detection), `PPGViewer` (pulse detection,
  SpO2 estimator hook), and `MultiChannelViewer` (linked multi-viewer stack).
- **Module 2 — Image Visualization**: `MedicalImageViewer` with ROI
  selection (rectangle/ellipse/freehand/polygon), ROI statistics, heatmap
  and segmentation-boundary overlays, intensity histogram; `MultiPanelViewer`
  for tiled/comparison layouts.
- **Module 3 — Clinical Dashboard**: `ClinicalDashboard` composing patient
  info, signal display, image display, disease-prediction panel with
  confidence gauge, alarm indicator, trend graph, and clinical summary.
- **Module 4 — Report Generation**: `ReportGenerator` producing PDF/DOCX
  via MATLAB Report Generator (title page, summary, figures, tables,
  recommendations), with graceful fallback if Report Generator is absent.
- **Module 5 — Publication Graphics**: `PublicationFigures` static library —
  confusion matrix, ROC curve (+AUC), training/validation curves, model
  accuracy comparison bar chart, statistical boxplot, high-res export helper.
- **Module 6 — Export Utilities**: `ExportManager` — unified export to
  PNG/JPG/TIFF, vector PDF, SVG, EPS, MAT, CSV, XLSX, plus `batchExport`
  for one-call publication packaging.
- **Module 7 — GUI Framework**: `NeuraMedComponent` abstract base class
  (build/refresh/theme/destroy lifecycle), `ThemeManager` (Dark/Light
  palettes, colorblind-safe channel colors, shared typography), and
  `NeuraMedDashboardApp` reference application (sidebar navigation, live
  theme toggle, wired `ClinicalDashboard`).
- Unit tests: `test_SignalViewers.m`, `test_CoreAndUtils.m`.
- `examples/RunFullDemo.m` end-to-end walkthrough.
- `setupNeuraMedToolkit.m` one-line installer with dependency check.

### Known Limitations
- `PPGViewer.estimateSpO2` uses placeholder calibration constants (A=110,
  B=25) — **must** be recalibrated against a reference pulse oximeter
  before any clinical use.
- `ReportGenerator` DOCX/PDF features require the MATLAB Report Generator
  add-on; without it, only basic figure/data export via `ExportManager`
  is available.
- `MedicalImageViewer` currently supports single 2D images (fundus, X-ray
  slice, etc.); volumetric/DICOM series support is planned for v1.1.
- `ClinicalDashboard` panel positions are fixed in a 3×3 grid; drag-to-
  reorder layout customization is planned for v1.1.

### Compatibility
- MATLAB R2021b+ (developed/validated against R2023b conventions:
  `arguments` blocks, `uigridlayout`, string arrays).
- Image Processing Toolbox required for Module 2.
- Statistics and Machine Learning Toolbox recommended for Module 5
  (`confusionchart`, `perfcurve`).

---

## Planned — v1.1.0
- DICOM series loading + volumetric slice viewer (Module 2)
- Synchronized side-by-side image comparison with linked pan/zoom (Module 2)
- Auto-populated report findings sourced from `ClinicalDashboard.Prediction`
  and `TrendData` (Module 4)
- Draggable/reorderable dashboard panel layout (Module 3)
- Respiration (RESP) signal viewer (Module 1)
