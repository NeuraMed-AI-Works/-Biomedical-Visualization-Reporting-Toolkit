classdef test_ImageAndReporting < matlab.unittest.TestCase
    % TEST_IMAGEANDREPORTING Automated (headless) coverage for Module 2
    % (MedicalImageViewer, MultiPanelViewer) and Module 4 (ReportGenerator).
    % Run with: results = runtests('test_ImageAndReporting')
    %
    % Interactive-only paths (freehand ROI, live mouse-driven rectangle/
    % ellipse/polygon drawing) are not exercised here since they require
    % a human; see examples/ValidateImageAndReportModules.m's ROI check,
    % which uses the programmatic-position path added specifically to
    % make ROI selection testable headlessly.

    properties
        Fig
        SampleImageRGB
        SampleImageGray
        SampleHeatmap
        SampleSegMask
    end

    methods (TestMethodSetup)
        function setup(tc)
            tc.Fig = uifigure('Visible', 'off');
            N = 100;
            [X, Y] = meshgrid(1:N, 1:N);
            cx = N/2; cy = N/2;
            d = sqrt((X-cx).^2 + (Y-cy).^2);
            img = zeros(N, N, 3, 'uint8');
            img(:,:,1) = uint8(180*(d<40));
            img(:,:,2) = uint8(60*(d<40));
            img(:,:,3) = uint8(40*(d<40));
            tc.SampleImageRGB = img;
            tc.SampleImageGray = uint8(200*(d<40));
            tc.SampleHeatmap = exp(-(d.^2)/(2*20^2));
            tc.SampleSegMask = d < 15;
        end
    end

    methods (TestMethodTeardown)
        function teardown(tc)
            if isvalid(tc.Fig); delete(tc.Fig); end
        end
    end

    methods (Test)
        %% Module 2 — Image Visualization

        function testLoadRGBImage(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            iv = neuramed.imaging.MedicalImageViewer(g);
            iv.initialize();
            iv.loadImage(tc.SampleImageRGB);
            tc.verifyEqual(size(iv.Image, 3), 3);
        end

        function testLoadGrayscaleImageForcedTrueColor(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            iv = neuramed.imaging.MedicalImageViewer(g);
            iv.initialize();
            iv.loadImage(tc.SampleImageGray);
            tc.verifyEqual(size(iv.Image, 3), 3, ...
                'Grayscale images must be forced to true-color to avoid axes-colormap bleed into the base image.');
        end

        function testHeatmapOverlayNoError(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            iv = neuramed.imaging.MedicalImageViewer(g);
            iv.initialize();
            iv.loadImage(tc.SampleImageGray);
            iv.setOverlay(tc.SampleHeatmap, "heatmap");
            tc.verifyEqual(iv.Config.OverlayKind, "heatmap");
        end

        function testSegmentationOverlayNoError(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            iv = neuramed.imaging.MedicalImageViewer(g);
            iv.initialize();
            iv.loadImage(tc.SampleImageRGB);
            iv.setOverlay(double(tc.SampleSegMask), "segmentation");
            tc.verifyEqual(iv.Config.OverlayKind, "segmentation");
        end

        function testOverlaySizeMismatchThrows(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            iv = neuramed.imaging.MedicalImageViewer(g);
            iv.initialize();
            iv.loadImage(tc.SampleImageRGB);
            tc.verifyError(@() iv.setOverlay(ones(5,5), "heatmap"), 'NeuraMed:OverlaySizeMismatch');
        end

        function testOverlayBeforeImageThrows(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            iv = neuramed.imaging.MedicalImageViewer(g);
            iv.initialize();
            tc.verifyError(@() iv.setOverlay(tc.SampleHeatmap, "heatmap"), 'NeuraMed:NoImage');
        end

        function testProgrammaticROISelection(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            iv = neuramed.imaging.MedicalImageViewer(g);
            iv.initialize();
            iv.loadImage(tc.SampleImageRGB);
            roi = iv.selectROI("rectangle", [30 30 40 40]);
            tc.verifyTrue(isvalid(roi));
        end

        function testROIStats(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            iv = neuramed.imaging.MedicalImageViewer(g);
            iv.initialize();
            iv.loadImage(tc.SampleImageRGB);
            iv.selectROI("rectangle", [30 30 40 40]);
            stats = iv.roiStats();
            tc.verifyTrue(isfield(stats, 'Mean'));
            tc.verifyGreaterThanOrEqual(stats.PixelCount, 1);
        end

        function testHistogramFigureCreated(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            iv = neuramed.imaging.MedicalImageViewer(g);
            iv.initialize();
            iv.loadImage(tc.SampleImageRGB);
            hFig = iv.showHistogram();
            tc.verifyTrue(isvalid(hFig));
            close(hFig);
        end

        function testMultiPanelBuildsAllPanels(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            mpv = neuramed.imaging.MultiPanelViewer(g);
            iv1 = neuramed.imaging.MedicalImageViewer([]);
            iv1.loadImage(tc.SampleImageRGB);
            iv2 = neuramed.imaging.MedicalImageViewer([]);
            iv2.loadImage(tc.SampleImageRGB);
            mpv.addPanel(iv1, "A");
            mpv.addPanel(iv2, "B");
            mpv.initialize();
            tc.verifyTrue(iv1.IsBuilt);
            tc.verifyTrue(iv2.IsBuilt);
        end

        function testMultiPanelDynamicAddAfterInitialize(tc)
            g = uigridlayout(tc.Fig, [1 1]);
            mpv = neuramed.imaging.MultiPanelViewer(g);
            iv1 = neuramed.imaging.MedicalImageViewer([]);
            iv1.loadImage(tc.SampleImageRGB);
            mpv.addPanel(iv1, "A");
            mpv.initialize();

            iv2 = neuramed.imaging.MedicalImageViewer([]);
            iv2.loadImage(tc.SampleImageGray);
            mpv.addPanel(iv2, "B");   % added AFTER initialize()
            tc.verifyTrue(iv2.IsBuilt, ...
                'Panels added after initialize() must still be parented and built.');
        end

        %% Module 4 — Report Generation

        function testReportGeneratorConstructs(tc)
            tmpDir = tempname; mkdir(tmpDir);
            rg = neuramed.reporting.ReportGenerator(fullfile(tmpDir, "test_report"), "pdf");
            tc.verifyClass(rg, 'neuramed.reporting.ReportGenerator');
            rmdir(tmpDir, 's');
        end

        function testFullReportPipelineProducesValidPDF(tc)
            if ~(license('test', 'MATLAB_Report_Generator') && ~isempty(which('mlreportgen.dom.Document')))
                tc.assumeFail('MATLAB Report Generator not installed on this system — skipping.');
            end
            tmpDir = tempname; mkdir(tmpDir);
            base = fullfile(tmpDir, "test_full_report");
            rg = neuramed.reporting.ReportGenerator(base, "pdf");

            rg.addTitlePage("Test Report", struct('Name', "Test", 'ID', "T-1"));
            rg.addSummary("Findings", "Synthetic test summary.");

            fig = figure('Visible', 'off');
            plot(1:10, rand(1,10));
            rg.addFigure(fig, "Test Figure");
            close(fig);

            tbl = table("Positive", 0.9, 'VariableNames', {'Prediction','Confidence'});
            rg.addTable(tbl, "Test Table");
            rg.addRecommendations(["Recommendation A", "Recommendation B"]);
            rg.close();

            tc.verifyTrue(isfile(rg.OutputPath));
            info = dir(rg.OutputPath);
            tc.verifyGreaterThan(info.bytes, 1000);

            fid = fopen(rg.OutputPath, 'r');
            header = fread(fid, 4, '*char')';
            fclose(fid);
            tc.verifyEqual(header, '%PDF');

            rmdir(tmpDir, 's');
        end
    end
end
