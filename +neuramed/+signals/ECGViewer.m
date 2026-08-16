classdef ECGViewer < neuramed.signals.SignalViewerBase
    % ECGVIEWER Specialized viewer for electrocardiogram traces.
    %   Adds R-peak detection, instantaneous/average heart-rate readout,
    %   and one-click PQRST annotation labeling.

    properties (SetAccess = private)
        RPeakTimes  double = []
        HeartRateBPM double = NaN
    end

    methods
        function obj = ECGViewer(parent, varargin)
            obj@neuramed.signals.SignalViewerBase(parent, varargin{:});
            obj.Config.Title  = "ECG Viewer";
            obj.Config.YLabel = "Amplitude (mV)";
        end

        function detectRPeaks(obj, varargin)
            % DETECTRPEAKS Simple Pan-Tompkins-style peak picker.
            % Optional Name/Value: 'MinPeakDistance' (s), 'MinPeakHeight'
            p = inputParser;
            addParameter(p, 'MinPeakDistance', 0.3);
            addParameter(p, 'MinPeakHeight', []);
            parse(p, varargin{:});

            if isempty(obj.Data.Signal)
                warning('NeuraMed:NoData', 'Load ECG data before calling detectRPeaks.');
                return
            end
            sig = obj.Data.Signal(:,1);
            fs = obj.Data.Fs;
            minDistSamples = round(p.Results.MinPeakDistance * fs);

            if isempty(p.Results.MinPeakHeight)
                mph = mean(sig) + 0.5 * std(sig);
            else
                mph = p.Results.MinPeakHeight;
            end

            [~, locs] = findpeaks(sig, 'MinPeakDistance', minDistSamples, 'MinPeakHeight', mph);
            obj.RPeakTimes = obj.Data.Time(locs);

            if numel(obj.RPeakTimes) > 1
                rr = diff(obj.RPeakTimes);
                obj.HeartRateBPM = 60 / median(rr);
            else
                obj.HeartRateBPM = NaN;
            end

            obj.clearAnnotations();
            for i = 1:numel(obj.RPeakTimes)
                obj.addAnnotation(obj.RPeakTimes(i), "R", "marker");
            end
            obj.log("Detected %d R-peaks | HR ≈ %.1f bpm", numel(obj.RPeakTimes), obj.HeartRateBPM);
        end

        function rr = rrIntervals(obj)
            rr = diff(obj.RPeakTimes);
        end
    end
end
