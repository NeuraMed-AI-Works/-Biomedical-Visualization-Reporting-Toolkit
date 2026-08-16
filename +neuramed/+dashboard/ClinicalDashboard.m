classdef ClinicalDashboard < neuramed.core.NeuraMedComponent
    % CLINICALDASHBOARD Full bedside/clinical-review layout composing:
    %   - Patient Information Panel
    %   - Signal Display (via MultiChannelViewer)
    %   - Image Display (via MedicalImageViewer)
    %   - Disease Prediction Panel + Confidence Indicator (gauge)
    %   - Trend Graph (e.g. stress index / HR over time)
    %   - Alarm Indicator
    %   - Clinical Summary (free text, auto-fillable from ReportGenerator)
    %
    % This is the layout every Neura-Med AI bedside / review app should
    % subclass or instantiate directly inside an App Designer figure.

    properties
        PatientInfo struct = struct('Name', "", 'ID', "", 'Age', [], 'Sex', "", ...
                                     'Device', "", 'RecordedAt', NaT)
        Prediction struct = struct('Label', "—", 'Confidence', 0, 'RiskLevel', "Low")
        TrendData struct = struct('Time', [], 'Value', [], 'Label', "Metric")
        SignalDisplay      % neuramed.signals.MultiChannelViewer
        ImageDisplay       % neuramed.imaging.MedicalImageViewer
        AlarmState (1,1) string {mustBeMember(AlarmState, ["Normal","Warning","Critical"])} = "Normal"
        SummaryText (1,1) string = ""
    end

    properties (Access = protected)
        Grid
        PatientPanel
        PatientValueLabels   % 4x1 array of uilabel handles: Name/ID/AgeSex/Device values, built once
        PredictionPanel
        ConfidenceGauge
        TrendAxes
        AlarmLamp
        AlarmLabel
        SummaryArea
        SignalContainer
        ImageContainer
    end

    methods
        function obj = ClinicalDashboard(parent, varargin)
            obj@neuramed.core.NeuraMedComponent(parent, varargin{:});
        end

        function setPatient(obj, s)
            obj.PatientInfo = s;
            obj.renderPatientInfo();
        end

        function setPrediction(obj, label, confidence, riskLevel)
            arguments
                obj
                label (1,1) string
                confidence (1,1) double {mustBeInRange(confidence,0,1)}
                riskLevel (1,1) string {mustBeMember(riskLevel, ["Low","Moderate","High"])} = "Low"
            end
            obj.Prediction = struct('Label', label, 'Confidence', confidence, 'RiskLevel', riskLevel);
            obj.renderPrediction();
        end

        function setAlarm(obj, state, message)
            arguments
                obj
                state (1,1) string {mustBeMember(state, ["Normal","Warning","Critical"])}
                message (1,1) string = ""
            end
            obj.AlarmState = state;
            obj.renderAlarm(message);
            if state ~= "Normal"
                notify(obj, 'AlarmRaised', neuramed.core.NeuraMedEventData(struct('State', state, 'Message', message)));
            end
        end

        function pushTrendPoint(obj, t, v, label)
            arguments
                obj
                t (1,1) double
                v (1,1) double
                label (1,1) string = "Metric"
            end
            obj.TrendData.Time(end+1) = t;
            obj.TrendData.Value(end+1) = v;
            obj.TrendData.Label = label;
            obj.renderTrend();
        end

        function setSummary(obj, text)
            obj.SummaryText = text;
            if ~isempty(obj.SummaryArea) && isvalid(obj.SummaryArea)
                obj.SummaryArea.Value = char(text);
            end
        end

        function refresh(obj)
            obj.renderPatientInfo();
            obj.renderPrediction();
            obj.renderAlarm("");
            obj.renderTrend();
        end
    end

    methods (Access = protected)
        function buildUI(obj)
            obj.Grid = uigridlayout(obj.Parent, [3 3]);
            obj.Grid.RowHeight   = {230, '2x', '1x'};
            obj.Grid.ColumnWidth = {'1.3x', '1x', '1x'};
            obj.Grid.RowSpacing = 8; obj.Grid.ColumnSpacing = 8;
            obj.Container = obj.Grid;

            % --- Row 1: Patient info + Alarm + Prediction/Confidence ---
            obj.buildPatientCard([1 1]);
            obj.buildAlarmCard([1 2]);
            obj.buildPredictionCard([1 3]);

            % --- Row 2: Signal display + Image display ---
            sigCard = obj.buildCardPanel("Signal Display", [2 1], [1 2]);
            obj.SignalContainer = sigCard;
            imgCard = obj.buildCardPanel("Image Display", [2 3]);
            obj.ImageContainer = imgCard;

            % --- Row 3: Trend graph + Clinical summary ---
            trendCard = obj.buildCardPanel("Trend Graph", [3 1], [1 1]);
            obj.TrendAxes = uiaxes(trendCard);
            obj.TrendAxes.Layout.Row = 1; obj.TrendAxes.Layout.Column = 1;

            summaryCard = obj.buildCardPanel("Clinical Summary", [3 2], [1 2]);
            obj.SummaryArea = uitextarea(summaryCard, 'Value', "Auto-generated clinical summary will appear here.");
            obj.SummaryArea.Layout.Row = 1; obj.SummaryArea.Layout.Column = 1;

            if ~isempty(obj.SignalDisplay)
                obj.SignalDisplay.Parent = obj.SignalContainer;
                obj.SignalDisplay.initialize();
            end
            if ~isempty(obj.ImageDisplay)
                obj.ImageDisplay.Parent = obj.ImageContainer;
                obj.ImageDisplay.initialize();
            end

            obj.renderPatientInfo();
            obj.renderPrediction();
            obj.renderAlarm("System nominal.");
        end

        function applyTheme(obj, themeName)
            pal = neuramed.core.ThemeManager.palette(themeName);
            if ~isempty(obj.Grid) && isvalid(obj.Grid)
                obj.Grid.BackgroundColor = pal.Background;
            end
            if ~isempty(obj.TrendAxes) && isvalid(obj.TrendAxes)
                obj.TrendAxes.Color = pal.Surface;
                obj.TrendAxes.XColor = pal.TextSecondary;
                obj.TrendAxes.YColor = pal.TextSecondary;
            end
            if ~isempty(obj.SignalDisplay); obj.SignalDisplay.setTheme(themeName); end
            if ~isempty(obj.ImageDisplay); obj.ImageDisplay.setTheme(themeName); end
        end
    end

    methods (Access = private)
        function panel = buildCardPanel(obj, titleStr, rowcol, span)
            if nargin < 4; span = [1 1]; end
            pal = neuramed.core.ThemeManager.palette(obj.Theme);
            outer = uipanel(obj.Grid, 'Title', titleStr, 'FontWeight', 'bold', ...
                'BackgroundColor', pal.Surface, 'BorderType', 'line');
            outer.Layout.Row = rowcol(1):rowcol(1)+span(1)-1;
            outer.Layout.Column = rowcol(2):rowcol(2)+span(2)-1;
            panel = uigridlayout(outer, [1 1]);
        end

        function buildAlarmCard(obj, rowcol)
            outer = obj.buildCardPanel("Alarm Status", rowcol);
            outer.RowHeight = {'1x'};
            g = uigridlayout(outer, [1 2]);
            g.Layout.Row = 1; g.Layout.Column = 1;
            obj.AlarmLamp = uilamp(g, 'Color', [0.2 0.75 0.35]);
            obj.AlarmLabel = uilabel(g, 'Text', "Normal", 'FontSize', 14, 'FontWeight', 'bold');
        end

        function buildPredictionCard(obj, rowcol)
            outer = obj.buildCardPanel("Disease Prediction", rowcol);
            g = uigridlayout(outer, [2 1]);
            g.RowHeight = {28, '1x'};
            g.Layout.Row = 1; g.Layout.Column = 1;
            obj.PredictionPanel = uilabel(g, 'Text', "—", 'FontSize', 15, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center');
            obj.PredictionPanel.Layout.Row = 1;
            obj.ConfidenceGauge = uigauge(g, 'Limits', [0 100]);
            obj.ConfidenceGauge.Layout.Row = 2;
        end

        function buildPatientCard(obj, rowcol)
            outer = obj.buildCardPanel("Patient Information", rowcol);
            obj.PatientPanel = outer;
            pal = neuramed.core.ThemeManager.palette(obj.Theme);
            g = uigridlayout(outer, [4 2]);
            g.Layout.Row = 1; g.Layout.Column = 1;
            g.RowHeight = repmat({26}, 1, 4);
            g.ColumnWidth = {90, '1x'};
            g.RowSpacing = 4;

            keys = ["Name:", "ID:", "Age / Sex:", "Device:"];
            obj.PatientValueLabels = matlab.ui.control.Label.empty;
            for i = 1:4
                lblKey = uilabel(g, 'Text', keys(i), 'FontWeight', 'bold', 'FontColor', pal.TextPrimary);
                lblKey.Layout.Row = i; lblKey.Layout.Column = 1;
                lblVal = uilabel(g, 'Text', "—", 'FontColor', pal.TextPrimary);
                lblVal.Layout.Row = i; lblVal.Layout.Column = 2;
                obj.PatientValueLabels(i) = lblVal;
            end
        end

        function renderPatientInfo(obj)
            if isempty(obj.PatientValueLabels) || any(~isvalid(obj.PatientValueLabels))
                return
            end
            info = obj.PatientInfo;
            values = [string(info.Name), string(info.ID), ...
                      sprintf("%s / %s", obj.numOrDash(info.Age), string(info.Sex)), ...
                      string(info.Device)];
            for i = 1:4
                v = values(i);
                if strlength(v) == 0; v = "—"; end
                obj.PatientValueLabels(i).Text = v;
            end
        end

        function renderPrediction(obj)
            if isempty(obj.PredictionPanel) || ~isvalid(obj.PredictionPanel); return; end
            pal = neuramed.core.ThemeManager.palette(obj.Theme);
            p = obj.Prediction;
            obj.PredictionPanel.Text = sprintf("%s  (%s risk)", p.Label, p.RiskLevel);
            switch p.RiskLevel
                case "Low";      obj.PredictionPanel.FontColor = pal.AccentAlt;
                case "Moderate"; obj.PredictionPanel.FontColor = pal.Warning;
                case "High";     obj.PredictionPanel.FontColor = pal.Critical;
            end
            obj.ConfidenceGauge.Value = round(p.Confidence * 100);
        end

        function renderAlarm(obj, message)
            pal = neuramed.core.ThemeManager.palette(obj.Theme);
            if isempty(obj.AlarmLamp) || ~isvalid(obj.AlarmLamp); return; end
            switch obj.AlarmState
                case "Normal";   obj.AlarmLamp.Color = pal.AccentAlt; txt = "Normal";
                case "Warning";  obj.AlarmLamp.Color = pal.Warning;   txt = "Warning";
                case "Critical"; obj.AlarmLamp.Color = pal.Critical;  txt = "CRITICAL";
            end
            if strlength(message) > 0
                txt = sprintf("%s — %s", txt, message);
            end
            obj.AlarmLabel.Text = txt;
        end

        function renderTrend(obj)
            if isempty(obj.TrendAxes) || ~isvalid(obj.TrendAxes) || isempty(obj.TrendData.Time)
                return
            end
            pal = neuramed.core.ThemeManager.palette(obj.Theme);
            plot(obj.TrendAxes, obj.TrendData.Time, obj.TrendData.Value, ...
                'Color', pal.Accent, 'LineWidth', 1.6, 'Marker', 'o', 'MarkerSize', 3);
            ylabel(obj.TrendAxes, obj.TrendData.Label);
            xlabel(obj.TrendAxes, "Time");
            grid(obj.TrendAxes, 'on');
        end
    end

    methods (Static, Access = private)
        function s = numOrDash(v)
            if isempty(v)
                s = "—";
            else
                s = string(v);
            end
        end
    end
end
