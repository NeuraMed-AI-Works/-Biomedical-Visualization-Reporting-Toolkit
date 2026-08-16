classdef EEGViewer < neuramed.signals.SignalViewerBase
    % EEGVIEWER Multi-channel EEG viewer with band-power computation
    % (delta/theta/alpha/beta/gamma) used e.g. by the Neurix stress model.

    properties (Constant)
        Bands = struct('delta',[0.5 4], 'theta',[4 8], 'alpha',[8 13], ...
                        'beta',[13 30], 'gamma',[30 45])
    end

    properties (SetAccess = private)
        BandPower table = table()
    end

    methods
        function obj = EEGViewer(parent, varargin)
            obj@neuramed.signals.SignalViewerBase(parent, varargin{:});
            obj.Config.Title  = "EEG Viewer";
            obj.Config.YLabel = "Amplitude (µV)";
        end

        function tbl = computeBandPower(obj, channelIdx)
            arguments
                obj
                channelIdx (1,1) double = 1
            end
            if isempty(obj.Data.Signal)
                warning('NeuraMed:NoData', 'Load EEG data before calling computeBandPower.');
                tbl = table(); return
            end
            sig = obj.Data.Signal(:, channelIdx);
            fs = obj.Data.Fs;
            n = numel(sig);
            f = (0:n-1) * (fs/n);
            P = abs(fft(sig .* hann(n))).^2 / n;

            names = fieldnames(obj.Bands);
            pw = zeros(numel(names), 1);
            for i = 1:numel(names)
                rng = obj.Bands.(names{i});
                mask = f >= rng(1) & f < rng(2);
                pw(i) = sum(P(mask));
            end
            tbl = table(string(names), pw, 'VariableNames', {'Band','Power'});
            obj.BandPower = tbl;
        end

        function stackMontage(obj, offsetFactor)
            % STACKMONTAGE Vertically offsets each channel so a multi-lead
            % montage is readable in one axes (classic EEG paper-style view).
            arguments
                obj
                offsetFactor (1,1) double = 3
            end
            if isempty(obj.Data.Signal); return; end
            sig = obj.Data.Signal;
            spread = std(sig(:)) * offsetFactor;
            nCh = size(sig, 2);
            offsets = (nCh-1:-1:0) * spread;
            obj.Data.Signal = sig + offsets;
            obj.refresh();
        end
    end
end
