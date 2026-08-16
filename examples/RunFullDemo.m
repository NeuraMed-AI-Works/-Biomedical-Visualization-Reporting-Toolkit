%% Neura-Med AI Toolkit — End-to-End Example
% Demonstrates Module 1 (ECG viewer), Module 5 (publication figures),
% Module 6 (export), and Module 7 (launching the full dashboard app).
%
% Run section-by-section (Ctrl+Enter) in MATLAB R2023b or later.

%% 0. Add toolkit to path
addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..')));

%% 1. Signal Visualization — ECGViewer used standalone (own window)
% This shows the ECGViewer/SignalViewerBase API in isolation. Section 4
% below launches NeuraMedDashboardApp, which uses this same ECGViewer
% class attached directly to the Clinical Dashboard's Signal Display
% panel — no separate window there, this section is just the standalone
% Module 1 API demo.
fig = uifigure('Name', 'ECG Viewer Example', 'Position', [100 100 900 400]);
g = uigridlayout(fig, [1 1]);

fs = 250;
t = (0:1/fs:10)';
ecg = 0.6*sin(2*pi*1.2*t) .* (mod(t,0.83) < 0.15) + 0.05*randn(size(t));

viewer = neuramed.signals.ECGViewer(g, 'Theme', 'Light');
viewer.initialize();
viewer.loadData(t, ecg, fs, {'Lead II'});
viewer.detectRPeaks('MinPeakDistance', 0.4);

fprintf('Detected HR: %.1f bpm from %d R-peaks\n', viewer.HeartRateBPM, numel(viewer.RPeakTimes));

%% 2. Publication Graphics — Confusion Matrix + ROC (synthetic classifier demo)
yTrue = randi([0 1], 200, 1);
scores = rand(200,1) + 0.3*yTrue;
yPred = double(scores > 0.55);

figCM = neuramed.publication.PublicationFigures.confusionMatrix(yTrue, yPred, ["Non-Stress","Stress"]);
[figROC, auc] = neuramed.publication.PublicationFigures.rocCurve(yTrue, scores, 1);
fprintf('AUC = %.3f\n', auc);

%% 3. Export Utilities — high-resolution package for a journal submission
outDir = fullfile(fileparts(mfilename('fullpath')), 'output');
neuramed.utils.ExportManager.batchExport(figCM, 'confusion_matrix', outDir);
neuramed.utils.ExportManager.batchExport(figROC, 'roc_curve', outDir);
fprintf('Exported figures to: %s\n', outDir);

%% 4. GUI Framework — launch the full clinical dashboard reference app
app = NeuraMedDashboardApp(); %#ok<NASGU>
