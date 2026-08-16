classdef test_SignalViewers < matlab.unittest.TestCase
    % TEST_SIGNALVIEWERS Validates data loading, R-peak/pulse/onset
    % detection, and measurement tools for Module 1 viewers.
    % Run with: results = runtests('test_SignalViewers')

    properties
        Fig
    end

    methods (TestMethodSetup)
        function setup(tc)
            tc.Fig = uifigure('Visible', 'off');
        end
    end

    methods (TestMethodTeardown)
        function teardown(tc)
            if isvalid(tc.Fig); delete(tc.Fig); end
        end
    end

    methods (Test)
        function testECGRPeakDetection(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            fs = 250; t = (0:1/fs:8)';
            ecg = 0.6*sin(2*pi*1.2*t) .* (mod(t,0.83) < 0.15);
            v = neuramed.signals.ECGViewer(g);
            v.initialize();
            v.loadData(t, ecg, fs);
            v.detectRPeaks();
            tc.verifyGreaterThan(numel(v.RPeakTimes), 3);
            tc.verifyGreaterThan(v.HeartRateBPM, 30);
            tc.verifyLessThan(v.HeartRateBPM, 220);
        end

        function testEEGBandPower(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            fs = 256; t = (0:1/fs:4)';
            eeg = sin(2*pi*10*t); % pure alpha tone
            v = neuramed.signals.EEGViewer(g);
            v.initialize();
            v.loadData(t, eeg, fs);
            tbl = v.computeBandPower(1);
            [~, idxMax] = max(tbl.Power);
            tc.verifyEqual(tbl.Band(idxMax), "alpha");
        end

        function testEMGOnsetDetection(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            fs = 1000; t = (0:1/fs:5)';
            emg = 0.02*randn(size(t));
            emg(2000:2500) = emg(2000:2500) + 0.5; % synthetic burst
            v = neuramed.signals.EMGViewer(g);
            v.initialize();
            v.loadData(t, emg, fs);
            onsets = v.detectOnsets(2.0);
            tc.verifyNotEmpty(onsets);
        end

        function testPPGPulseDetection(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            fs = 100; t = (0:1/fs:10)';
            ppg = sin(2*pi*1.2*t) + 0.02*randn(size(t));
            v = neuramed.signals.PPGViewer(g);
            v.initialize();
            v.loadData(t, ppg, fs);
            v.detectPulses();
            tc.verifyGreaterThan(numel(v.PulseTimes), 5);
        end

        function testMeasurementTool(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            fs = 100; t = (0:1/fs:5)';
            sig = sin(2*pi*t);
            v = neuramed.signals.ECGViewer(g);
            v.initialize();
            v.loadData(t, sig, fs);
            m = v.measure(1.0, 1.8);
            tc.verifyEqual(m.dt, 0.8, 'AbsTol', 1e-9);
        end

        function testAnnotationRoundTrip(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            fs = 100; t = (0:1/fs:2)';
            sig = zeros(size(t));
            v = neuramed.signals.ECGViewer(g);
            v.initialize();
            v.loadData(t, sig, fs);
            v.addAnnotation(1.0, "TestMark", "marker", "unit test");
            tc.verifyEqual(height(v.Annotations), 1);
            v.clearAnnotations();
            tc.verifyEqual(height(v.Annotations), 0);
        end
    end
end
