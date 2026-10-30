# Neura-Med AI — Biomedical Visualization & Reporting Toolkit

A reusable, object-oriented MATLAB toolkit for building professional biomedical
dashboards, signal/image viewers, clinical reports, and publication-quality
figures. Designed as the shared visualization layer for **every Neura-Med AI
product** 

> **Status:** v1.0.0 — Modules 1, 5, 6, 7 fully implemented and tested.
> Modules 2–4 have production-ready core classes with clearly marked
> extension points (see [Roadmap](#roadmap)).

---

## Why this exists

Every Neura-Med AI project (Neurix EEG stress classification, ECG analysis,
OcuScan retinal screening) was independently rebuilding the same dashboards,
plots, and report generators. This toolkit centralizes that work into one
versioned, testable, themeable component library so every product looks and
behaves consistently, and every improvement (a new export format, a bug fix
in R-peak detection, a new theme) benefits every product at once.

## Requirements

| Requirement | Version |
|---|---|
| MATLAB | R2021b or later (R2023b recommended) |
| Image Processing Toolbox | Required for Module 2 (imaging) |
| MATLAB Report Generator | Optional — enables rich DOCX/PDF in Module 4; falls back gracefully if absent |
| Statistics and Machine Learning Toolbox | Recommended for Module 5 (`perfcurve`, `confusionchart`) |

## Installation

```matlab
% From the toolkit root folder:
setupNeuraMedToolkit
```

This adds the toolkit (and its `+neuramed` namespace) to your MATLAB path
and prints a dependency check.

## 60-second Quick Start

```matlab
setupNeuraMedToolkit

fig = uifigure;
g = uigridlayout(fig, [1 1]);

ecgViewer = neuramed.signals.ECGViewer(g);
ecgViewer.initialize();
ecgViewer.loadData(t, ecgSignal, fs);   % t: seconds, ecgSignal: Nx1, fs: Hz
ecgViewer.detectRPeaks();

fprintf('Heart rate: %.1f bpm\n', ecgViewer.HeartRateBPM);
```

Or launch the full reference dashboard:

```matlab
app = NeuraMedDashboardApp;
```

See `examples/RunFullDemo.m` for an end-to-end walkthrough across signals,
publication figures, and export.

## Folder Structure

```
NeuraMedAI_Toolkit/
├── +neuramed/                     # Toolkit namespace (package) — import as neuramed.*
│   ├── +core/                     # Module 7 — shared GUI framework primitives
│   │   ├── NeuraMedComponent.m    #   Abstract base class for every component
│   │   ├── NeuraMedEventData.m    #   Generic event payload wrapper
│   │   └── ThemeManager.m         #   Single source of truth for colors/fonts (Dark/Light)
│   │
│   ├── +signals/                  # Module 1 — Signal Visualization
│   │   ├── SignalViewerBase.m     #   Shared zoom/pan/annotation/measurement engine
│   │   ├── ECGViewer.m            #   + R-peak detection, HR, RR-intervals
│   │   ├── EEGViewer.m            #   + band-power (delta..gamma), montage stacking
│   │   ├── EMGViewer.m            #   + RMS envelope, onset detection
│   │   ├── PPGViewer.m            #   + pulse detection, SpO2 estimator hook
│   │   └── MultiChannelViewer.m   #   Stacks/links any of the above viewers
│   │
│   ├── +imaging/                  # Module 2 — Image Visualization
│   │   ├── MedicalImageViewer.m   #   ROI, overlay (heatmap/segmentation), histogram
│   │   └── MultiPanelViewer.m     #   Tiled multi-panel / comparison layout
│   │
│   ├── +dashboard/                # Module 3 — Clinical Dashboard
│   │   └── ClinicalDashboard.m    #   Patient info, prediction, alarm, trend, summary
│   │
│   ├── +reporting/                # Module 4 — Report Generation
│   │   └── ReportGenerator.m      #   PDF/DOCX via MATLAB Report Generator
│   │
│   ├── +publication/              # Module 5 — Publication Graphics
│   │   └── PublicationFigures.m   #   Confusion matrix, ROC, training curves, etc.
│   │
│   └── +utils/                    # Module 6 — Export Utilities
│       └── ExportManager.m        #   PNG/JPG/SVG/EPS/MAT/CSV/XLSX/PDF, one call
│
├── apps/
│   └── NeuraMedDashboardApp.m     # Module 7 — reference App Designer-style app
│
├── examples/
│   └── RunFullDemo.m              # End-to-end usage across all modules
│
├── tests/
│   ├── test_SignalViewers.m       # Module 1 unit tests
│   └── test_CoreAndUtils.m        # Theme/Export/Publication unit tests
│
├── docs/
│   └── UserManual.md
│
├── setupNeuraMedToolkit.m         # One-line path/dependency setup
├── README.md
└── RELEASE_NOTES.md
```

## Architecture

```
                     ┌─────────────────────────────┐
                     │      neuramed.core.*         │
                     │  NeuraMedComponent (handle)  │◄──── every component subclasses this
                     │  ThemeManager (static)       │◄──── every component reads colors from here
                     └───────────────┬─────────────┘
                                     │
        ┌────────────────┬──────────┼───────────┬─────────────────┐
        ▼                ▼          ▼           ▼                 ▼
 +signals/*        +imaging/*   +dashboard/*  +reporting/*   +publication/*
 SignalViewerBase   MedicalImg   ClinicalDash  ReportGen      PublicationFigures
 ├─ECGViewer        Viewer       board          (PDF/DOCX)     (static utility)
 ├─EEGViewer        MultiPanel   composes:                          │
 ├─EMGViewer        Viewer       ├─PatientPanel                     ▼
 ├─PPGViewer                     ├─SignalDisplay ───────────► +utils/ExportManager
 └─MultiChannel                  │  (MultiChannelViewer)      (PNG/JPG/SVG/EPS/
    Viewer                       ├─ImageDisplay                MAT/CSV/XLSX/PDF)
                                 │  (MedicalImageViewer)
                                 ├─PredictionPanel + Gauge
                                 ├─AlarmIndicator
                                 └─TrendGraph + Summary
```

**Design principles**

- **Composition over inheritance for products, inheritance for viewer families.**
  `SignalViewerBase` centralizes zoom/pan/annotation logic once; `ECGViewer`,
  `EEGViewer`, etc. add only their domain-specific analysis. `ClinicalDashboard`
  *composes* a `MultiChannelViewer` and a `MedicalImageViewer` rather than
  inheriting from them — this is what lets any product mix-and-match panels.
- **Theming is centralized.** No component hard-codes a color. Everything
  reads from `neuramed.core.ThemeManager.palette(...)`, so a single palette
  edit restyles every viewer, dashboard, and figure in every product.
- **Every visual component follows the same lifecycle**: construct → 
  `initialize()` (calls `buildUI` then `applyTheme`) → `refresh()` on new data
  → `setTheme()` on theme change → `delete()` cleans up listeners/graphics.
- **Export is centralized.** Nothing calls `exportgraphics`/`saveas` directly
  outside of `neuramed.utils.ExportManager`, so format support and resolution
  defaults are consistent everywhere (e.g. journal figures always at 600 DPI).

## Roadmap

- [x] Module 1 — Signal Visualization (ECG/EEG/EMG/PPG/Multi-channel, zoom, annotations, measurement)
- [x] Module 5 — Publication Graphics (confusion matrix, ROC, training curves, accuracy, boxplots)
- [x] Module 6 — Export Utilities (all formats, batch export)
- [x] Module 7 — GUI Framework (base component, theming, reference app)
- [x] Module 2 — Image Visualization (core viewer, ROI, overlay, multi-panel) — *Image Comparison sync-zoom and DICOM-specific loaders planned for v1.1*
- [x] Module 3 — Clinical Dashboard (all panels wired) — *drag-to-reorder panels planned for v1.1*
- [x] Module 4 — Report Generation (PDF/DOCX core) — *auto-populated findings from `ClinicalDashboard.Prediction` planned for v1.1*

## License / Ownership

Internal proprietary toolkit — © Neura-Med AI. Not for external distribution
without written permission.
