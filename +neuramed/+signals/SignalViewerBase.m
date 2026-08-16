classdef (Abstract) SignalViewerBase < neuramed.core.NeuraMedComponent
    % SIGNALVIEWERBASE Shared engine for ECG/EEG/EMG/PPG/MultiChannel viewers.
    %
    %   Provides: axes + toolbar scaffold, interactive zoom/pan, cursor
    %   measurement (dt, dAmplitude, instantaneous rate), annotation
    %   markers, and channel-color management via ThemeManager. Concrete
    %   viewers (ECGViewer, EEGViewer, ...) only need to supply signal-type
    %   specific defaults (units, typical filters, annotation vocabulary).
    %
    % Properties are set via Config; Data is a table or struct array with
    % fields: Time (seconds, double vector), Signal (double vector or
    % matrix [samples x channels]), Fs (sampling rate, Hz), ChannelNames.

    properties
        Data            struct = struct('Time', [], 'Signal', [], 'Fs', 1000, 'ChannelNames', {{}})
        Config          struct = struct('YLabel', "Amplitude (mV)", ...
                                         'Title', "Signal Viewer", ...
                                         'GridOn', true, ...
                                         'ShowLegend', true)
        Annotations     table = table('Size',[0 4], ...
                                       'VariableTypes', {'double','string','string','string'}, ...
                                       'VariableNames', {'Time','Label','Type','Note'})
        SelectedWindow  (1,2) double = [NaN NaN]   % [tStart tEnd] currently visible, seconds
    end

    properties (Access = protected)
        Axes
        Lines
        AnnotationMarkers
        MeasureLine1
        MeasureLine2
        MeasureText
        Toolbar
        InfoLabel
    end

    methods
        function obj = SignalViewerBase(parent, varargin)
            obj@neuramed.core.NeuraMedComponent(parent, varargin{:});
        end

        function loadData(obj, timeVec, signalMat, fs, channelNames)
            arguments
                obj
                timeVec (:,1) double
                signalMat double
                fs (1,1) double {mustBePositive} = 1000
                channelNames = {}
            end
            if isempty(channelNames)
                nCh = size(signalMat, 2);
                channelNames = arrayfun(@(i) sprintf("Ch%d", i), 1:nCh, 'UniformOutput', false);
            end
            obj.Data.Time = timeVec;
            obj.Data.Signal = signalMat;
            obj.Data.Fs = fs;
            obj.Data.ChannelNames = channelNames;
            if obj.IsBuilt
                obj.refresh();
            end
            notify(obj, 'DataChanged');
        end

        function addAnnotation(obj, timeSec, label, type, note)
            arguments
                obj
                timeSec (1,1) double
                label (1,1) string
                type (1,1) string = "marker"
                note (1,1) string = ""
            end
            newRow = {timeSec, label, type, note};
            obj.Annotations = [obj.Annotations; newRow];
            obj.drawAnnotations();
            notify(obj, 'UserAnnotation', neuramed.core.NeuraMedEventData(newRow));
        end

        function clearAnnotations(obj)
            obj.Annotations(:,:) = [];
            obj.drawAnnotations();
        end

        function zoomToWindow(obj, tStart, tEnd)
            arguments
                obj
                tStart (1,1) double
                tEnd (1,1) double
            end
            obj.SelectedWindow = [tStart tEnd];
            if ~isempty(obj.Axes) && isvalid(obj.Axes)
                xlim(obj.Axes, [tStart tEnd]);
            end
        end

        function resetZoom(obj)
            if ~isempty(obj.Data.Time)
                obj.zoomToWindow(obj.Data.Time(1), obj.Data.Time(end));
            end
        end

        function m = measure(obj, t1, t2)
            % MEASURE Return struct with dt, mean rate (1/dt in bpm-style
            % units where relevant), and amplitude delta between two
            % cursor times. Useful for RR-interval / latency measurement.
            arguments
                obj
                t1 (1,1) double
                t2 (1,1) double
            end
            dt = abs(t2 - t1);
            idx1 = obj.nearestIndex(t1);
            idx2 = obj.nearestIndex(t2);
            sig = obj.Data.Signal;
            if isempty(sig)
                m = struct('dt', dt, 'dAmplitude', NaN, 'rateBPM', NaN);
                return
            end
            amp1 = sig(idx1, 1); amp2 = sig(idx2, 1);
            m = struct( ...
                'dt', dt, ...
                'dAmplitude', amp2 - amp1, ...
                'rateBPM', 60 / dt);
            obj.drawMeasurement(t1, t2, m);
        end

        function refresh(obj)
            obj.plotSignals();
            obj.drawAnnotations();
        end

        function ax = getAxesHandle(obj)
            % GETAXESHANDLE Public accessor so composite components
            % (e.g. MultiChannelViewer) can link zoom/pan across viewers.
            ax = obj.Axes;
        end
    end

    methods (Access = protected)
        function buildUI(obj)
            grid = uigridlayout(obj.Parent, [2 1]);
            grid.RowHeight = {'1x', 24};
            grid.ColumnWidth = {'1x'};
            grid.Padding = [4 4 4 4];
            grid.RowSpacing = 2;
            obj.Container = grid;

            obj.Axes = uiaxes(grid);
            obj.Axes.Layout.Row = 1;
            obj.Axes.Layout.Column = 1;
            title(obj.Axes, obj.Config.Title);
            xlabel(obj.Axes, "Time (s)");
            ylabel(obj.Axes, obj.Config.YLabel);
            obj.Axes.Toolbar.Visible = 'on';
            enableDefaultInteractivity(obj.Axes);
            disableDefaultInteractivity(obj.Axes); %#ok - reset then enable specific modes below
            axtoolbar(obj.Axes, {'zoomin','zoomout','pan','restoreview','export'});
            obj.Axes.Interactions = [zoomInteraction, panInteraction, dataTipInteraction];

            obj.InfoLabel = uilabel(grid, "Text", "Click two points on the signal, then call measure(t1,t2) for interval/amplitude readouts.");
            obj.InfoLabel.Layout.Row = 2;
            obj.InfoLabel.FontSize = 10;

            obj.Lines = matlab.graphics.chart.primitive.Line.empty;
            obj.AnnotationMarkers = gobjects(0);
        end

        function applyTheme(obj, themeName)
            pal = neuramed.core.ThemeManager.palette(themeName);
            fonts = neuramed.core.ThemeManager.typography();
            if isempty(obj.Axes) || ~isvalid(obj.Axes)
                return
            end
            obj.Axes.Color = pal.Surface;
            obj.Axes.XColor = pal.TextSecondary;
            obj.Axes.YColor = pal.TextSecondary;
            obj.Axes.GridColor = pal.GridLine;
            obj.Axes.GridAlpha = 0.5;
            obj.Axes.Title.Color = pal.TextPrimary;
            obj.Axes.FontName = fonts.Family;
            grid(obj.Axes, obj.Config.GridOn);
            if ~isempty(obj.Lines)
                colors = pal.ChannelColors;
                for i = 1:numel(obj.Lines)
                    if isvalid(obj.Lines(i))
                        obj.Lines(i).Color = colors(mod(i-1, size(colors,1)) + 1, :);
                    end
                end
            end
        end

        function plotSignals(obj)
            if isempty(obj.Data.Time) || isempty(obj.Data.Signal)
                return
            end
            cla(obj.Axes);
            pal = neuramed.core.ThemeManager.palette(obj.Theme);
            colors = pal.ChannelColors;
            nCh = size(obj.Data.Signal, 2);
            obj.Lines = gobjects(1, nCh);
            hold(obj.Axes, 'on');
            for c = 1:nCh
                obj.Lines(c) = plot(obj.Axes, obj.Data.Time, obj.Data.Signal(:,c), ...
                    'Color', colors(mod(c-1,size(colors,1))+1,:), 'LineWidth', 1.1, ...
                    'DisplayName', string(obj.Data.ChannelNames{c}));
            end
            hold(obj.Axes, 'off');
            if obj.Config.ShowLegend && nCh > 1
                legend(obj.Axes, 'show', 'Location', 'northeastoutside');
            else
                legend(obj.Axes, 'off');
            end
            if any(isnan(obj.SelectedWindow))
                xlim(obj.Axes, [obj.Data.Time(1), obj.Data.Time(end)]);
            else
                xlim(obj.Axes, obj.SelectedWindow);
            end
        end

        function drawAnnotations(obj)
            if isempty(obj.Axes) || ~isvalid(obj.Axes)
                return
            end
            delete(obj.AnnotationMarkers(isgraphics(obj.AnnotationMarkers)));
            obj.AnnotationMarkers = gobjects(0);
            if isempty(obj.Annotations)
                return
            end
            pal = neuramed.core.ThemeManager.palette(obj.Theme);
            yl = ylim(obj.Axes);
            hold(obj.Axes, 'on');
            for i = 1:height(obj.Annotations)
                t = obj.Annotations.Time(i);
                lbl = obj.Annotations.Label(i);
                clr = pal.Warning;
                if obj.Annotations.Type(i) == "critical"
                    clr = pal.Critical;
                end
                h = xline(obj.Axes, t, '--', lbl, 'Color', clr, 'LabelOrientation', 'horizontal');
                obj.AnnotationMarkers(end+1) = h; %#ok<AGROW>
            end
            hold(obj.Axes, 'off');
            ylim(obj.Axes, yl);
        end

        function drawMeasurement(obj, t1, t2, m)
            pal = neuramed.core.ThemeManager.palette(obj.Theme);
            if ~isempty(obj.MeasureLine1) && isgraphics(obj.MeasureLine1); delete(obj.MeasureLine1); end
            if ~isempty(obj.MeasureLine2) && isgraphics(obj.MeasureLine2); delete(obj.MeasureLine2); end
            hold(obj.Axes, 'on');
            obj.MeasureLine1 = xline(obj.Axes, t1, ':', 'Color', pal.Accent, 'LineWidth', 1.4);
            obj.MeasureLine2 = xline(obj.Axes, t2, ':', 'Color', pal.Accent, 'LineWidth', 1.4);
            hold(obj.Axes, 'off');
            obj.InfoLabel.Text = sprintf("Δt = %.4f s | rate ≈ %.1f /min | ΔAmplitude = %.4f", ...
                m.dt, m.rateBPM, m.dAmplitude);
        end

        function idx = nearestIndex(obj, t)
            [~, idx] = min(abs(obj.Data.Time - t));
        end
    end
end
