classdef EMGViewer < neuramed.signals.SignalViewerBase
    % EMGVIEWER Electromyography viewer with RMS envelope + burst onset
    % detection for muscle-activity annotation.

    properties (SetAccess = private)
        EnvelopeSignal double = []
        OnsetTimes double = []
    end

    methods
        function obj = EMGViewer(parent, varargin)
            obj@neuramed.signals.SignalViewerBase(parent, varargin{:});
            obj.Config.Title  = "EMG Viewer";
            obj.Config.YLabel = "Amplitude (mV)";
        end

        function env = computeEnvelope(obj, windowSec)
            arguments
                obj
                windowSec (1,1) double = 0.05
            end
            if isempty(obj.Data.Signal)
                warning('NeuraMed:NoData', 'Load EMG data before calling computeEnvelope.');
                env = []; return
            end
            fs = obj.Data.Fs;
            w = max(1, round(windowSec * fs));
            sig = obj.Data.Signal(:,1);
            env = sqrt(movmean(sig.^2, w));
            obj.EnvelopeSignal = env;
        end

        function onsets = detectOnsets(obj, thresholdFactor)
            arguments
                obj
                thresholdFactor (1,1) double = 2.0
            end
            if isempty(obj.EnvelopeSignal)
                obj.computeEnvelope();
            end
            env = obj.EnvelopeSignal;
            thr = mean(env) + thresholdFactor * std(env);
            aboveThr = env > thr;
            riseIdx = find(diff([0; aboveThr]) == 1);
            obj.OnsetTimes = obj.Data.Time(riseIdx);
            obj.clearAnnotations();
            for i = 1:numel(obj.OnsetTimes)
                obj.addAnnotation(obj.OnsetTimes(i), "Onset", "marker");
            end
            onsets = obj.OnsetTimes;
        end
    end
end
