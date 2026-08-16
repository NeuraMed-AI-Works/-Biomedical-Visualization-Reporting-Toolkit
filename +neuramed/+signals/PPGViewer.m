classdef PPGViewer < neuramed.signals.SignalViewerBase
    % PPGVIEWER Photoplethysmography viewer with pulse-peak detection and
    % a pluggable SpO2 estimator hook (for MAX30101-derived Red/IR ratio,
    % e.g. Neurix wristband integration).

    properties (SetAccess = private)
        PulseTimes double = []
        PulseRateBPM double = NaN
        SpO2Estimate double = NaN
    end

    methods
        function obj = PPGViewer(parent, varargin)
            obj@neuramed.signals.SignalViewerBase(parent, varargin{:});
            obj.Config.Title  = "PPG Viewer";
            obj.Config.YLabel = "Amplitude (a.u.)";
        end

        function detectPulses(obj, minPeakDistanceSec)
            arguments
                obj
                minPeakDistanceSec (1,1) double = 0.4
            end
            if isempty(obj.Data.Signal)
                warning('NeuraMed:NoData', 'Load PPG data before calling detectPulses.');
                return
            end
            sig = obj.Data.Signal(:,1);
            fs = obj.Data.Fs;
            [~, locs] = findpeaks(sig, 'MinPeakDistance', round(minPeakDistanceSec*fs), ...
                'MinPeakHeight', mean(sig)+0.3*std(sig));
            obj.PulseTimes = obj.Data.Time(locs);
            if numel(obj.PulseTimes) > 1
                obj.PulseRateBPM = 60 / median(diff(obj.PulseTimes));
            end
            obj.clearAnnotations();
            for i = 1:numel(obj.PulseTimes)
                obj.addAnnotation(obj.PulseTimes(i), "Pulse", "marker");
            end
        end

        function spo2 = estimateSpO2(obj, redSignal, irSignal)
            % ESTIMATESPO2 Ratio-of-ratios estimate. Replace calibration
            % coefficients (A,B) with device-calibrated values from bench
            % testing against a reference pulse oximeter before clinical use.
            arguments
                obj
                redSignal (:,1) double
                irSignal (:,1) double
            end
            acRed = std(redSignal); dcRed = mean(redSignal);
            acIr  = std(irSignal);  dcIr  = mean(irSignal);
            R = (acRed/dcRed) / (acIr/dcIr);
            A = 110; B = 25; % placeholder calibration constants
            spo2 = A - B * R;
            spo2 = max(min(spo2, 100), 0);
            obj.SpO2Estimate = spo2;
        end
    end
end
