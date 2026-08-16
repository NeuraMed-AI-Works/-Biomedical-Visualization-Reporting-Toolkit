classdef NeuraMedDashboardApp < matlab.apps.AppBase
    % NEURAMEDDASHBOARDAPP Reference application demonstrating the full
    % Neura-Med AI toolkit wired together: navigation sidebar, dark/light
    % theme toggle, and a live Clinical Dashboard populated with a
    % synthetic ECG/EEG session and a sample retinal image + heatmap.
    %
    % Run:  app = NeuraMedDashboardApp;

    properties (Access = public)
        UIFigure          matlab.ui.Figure
        MainGrid          matlab.ui.container.GridLayout
        NavPanel          matlab.ui.container.Panel
        NavGrid           matlab.ui.container.GridLayout
        NavButtons        matlab.ui.control.Button = matlab.ui.control.Button.empty
        ThemeSwitch       matlab.ui.control.Switch
        ContentPanel      matlab.ui.container.Panel
        Dashboard                    % neuramed.dashboard.ClinicalDashboard
        CurrentTheme      string = "Light"
    end

    methods (Access = private)

        function createComponents(app)
            % Explicitly pin the figure's Theme. Starting in R2025a,
            % uifigure automatically inherits the MATLAB desktop's
            % dark/light theme, which silently overrides our own
            % ThemeManager-driven colors and causes low-contrast/invisible
            % text when the desktop is in dark mode. Pinning Theme here
            % keeps the app's appearance fully controlled by CurrentTheme.
            themeArg = lower(app.CurrentTheme); % "light" or "dark"
            app.UIFigure = uifigure('Name', 'Neura-Med AI — Biomedical Visualization & Reporting Toolkit', ...
                'Theme', themeArg);
            app.UIFigure.Position = [80 60 1280 800];

            app.MainGrid = uigridlayout(app.UIFigure, [1 2]);
            app.MainGrid.ColumnWidth = {200, '1x'};
            app.MainGrid.Padding = [0 0 0 0];
            app.MainGrid.ColumnSpacing = 0;

            % --- Navigation sidebar ---
            app.NavPanel = uipanel(app.MainGrid);
            app.NavPanel.Layout.Column = 1;
            app.NavGrid = uigridlayout(app.NavPanel, [7 1]);
            app.NavGrid.RowHeight = {60, 44, 44, 44, 44, '1x', 60};

            logoLbl = uilabel(app.NavGrid, 'Text', sprintf("Neura-Med AI"), ...
                'FontSize', 16, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
            logoLbl.Layout.Row = 1;

            navLabels = ["Clinical Dashboard", "Signal Viewer", "Image Viewer", "Reports"];
            app.NavButtons = matlab.ui.control.Button.empty;
            for i = 1:numel(navLabels)
                b = uibutton(app.NavGrid, 'Text', navLabels(i));
                b.Layout.Row = i + 1;
                b.ButtonPushedFcn = @(src, evt) app.onNavClicked(navLabels(i));
                app.NavButtons(end+1) = b;
            end

            themeGrid = uigridlayout(app.NavGrid, [1 2]);
            themeGrid.Layout.Row = 7;
            uilabel(themeGrid, 'Text', 'Dark Mode');
            app.ThemeSwitch = uiswitch(themeGrid, 'slider');
            app.ThemeSwitch.ValueChangedFcn = @(src, evt) app.onThemeToggled();

            % --- Content area ---
            app.ContentPanel = uipanel(app.MainGrid);
            app.ContentPanel.Layout.Column = 2;
            contentGrid = uigridlayout(app.ContentPanel, [1 1]);

            app.Dashboard = neuramed.dashboard.ClinicalDashboard(contentGrid);

            % Attach the Signal Display panel's live viewer BEFORE
            % initialize() — ClinicalDashboard.buildUI() only re-parents
            % and builds SignalDisplay if it's already set at that point
            % (see ClinicalDashboard.m ~line 129). This reuses the same
            % ECGViewer class already validated standalone in
            % examples/RunFullDemo.m — no new viewer functionality added.
            app.Dashboard.SignalDisplay = neuramed.signals.ECGViewer([], 'Theme', app.CurrentTheme);

            app.Dashboard.initialize();
        end

        function onNavClicked(app, section)
            % Simple placeholder router — in a full product build, swap
            % app.ContentPanel's child grid for a dedicated
            % SignalViewerBase / MedicalImageViewer / ReportGenerator
            % screen per section. Kept minimal here to stay a clear,
            % extensible reference implementation.
            app.Dashboard.log("Navigated to: %s", section);
            uialert(app.UIFigure, sprintf("Section '%s' — wire this to its dedicated module view.", section), ...
                "Navigation", "Icon", "info");
        end

        function onThemeToggled(app)
            if app.ThemeSwitch.Value == "On"
                app.CurrentTheme = "Dark";
            else
                app.CurrentTheme = "Light";
            end
            app.UIFigure.Theme = lower(app.CurrentTheme);
            neuramed.core.ThemeManager.applyFigureTheme(app.UIFigure, app.CurrentTheme);
            app.Dashboard.setTheme(app.CurrentTheme);
        end

        function loadDemoData(app)
            % Synthetic ECG demo signal so the dashboard is populated on
            % first launch without requiring real patient data.
            fs = 250; t = (0:1/fs:10)';
            ecg = 0.6*sin(2*pi*1.2*t) .* (mod(t,0.83) < 0.15) + 0.05*randn(size(t));

            % Populate the dashboard's own Signal Display panel — same
            % ECGViewer API used standalone in RunFullDemo.m, just now
            % rendering inside the dashboard instead of a separate window.
            app.Dashboard.SignalDisplay.loadData(t, ecg, fs, {'Lead II'});
            app.Dashboard.SignalDisplay.detectRPeaks('MinPeakDistance', 0.4);

            app.Dashboard.setPatient(struct('Name', "Demo Subject", 'ID', "NM-0001", ...
                'Age', 24, 'Sex', "F", 'Device', "Neurix Head Patch v1", 'RecordedAt', datetime('now')));
            app.Dashboard.setPrediction("Elevated Stress", 0.82, "Moderate");
            app.Dashboard.setAlarm("Normal", "Session nominal.");
            for i = 1:20
                app.Dashboard.pushTrendPoint(i, 60 + 10*sin(i/3) + randn(), "Stress Index");
            end
            app.Dashboard.setSummary("Auto-generated: subject shows mild elevation in beta-band " + ...
                "EEG power consistent with moderate acute stress. No critical alarms triggered during session.");
        end
    end

    methods (Access = public)
        function app = NeuraMedDashboardApp()
            app.createComponents();
            app.loadDemoData();
            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end
end
