classdef test_CoreAndUtils < matlab.unittest.TestCase
    % TEST_COREANDUTILS Validates ThemeManager palette integrity,
    % PublicationFigures outputs, and ExportManager file creation.

    methods (Test)
        function testThemePalettesHaveRequiredFields(tc)
            requiredFields = ["Background","Surface","GridLine","TextPrimary", ...
                               "TextSecondary","Accent","Warning","Critical","ChannelColors"];
            for themeName = ["Light","Dark"]
                pal = neuramed.core.ThemeManager.palette(themeName);
                for f = requiredFields
                    tc.verifyTrue(isfield(pal, f), sprintf('Missing field %s in %s theme', f, themeName));
                end
                tc.verifySize(pal.ChannelColors, [7 3]);
            end
        end

        function testConfusionMatrixFigure(tc)
            yTrue = [0 0 1 1 0 1 1 0]';
            yPred = [0 1 1 1 0 1 0 0]';
            fig = neuramed.publication.PublicationFigures.confusionMatrix(yTrue, yPred);
            tc.verifyTrue(isvalid(fig));
            close(fig);
        end

        function testROCCurveAUCRange(tc)
            labels = randi([0 1], 100, 1);
            scores = rand(100,1) + 0.4*labels;
            [fig, auc] = neuramed.publication.PublicationFigures.rocCurve(labels, scores, 1);
            tc.verifyGreaterThanOrEqual(auc, 0);
            tc.verifyLessThanOrEqual(auc, 1);
            close(fig);
        end

        function testExportFigureCreatesFile(tc)
            fig = figure('Visible', 'off');
            plot(1:10, rand(1,10));
            tmpDir = tempname; mkdir(tmpDir);
            basePath = fullfile(tmpDir, "test_export");
            neuramed.utils.ExportManager.exportFigure(fig, basePath, "png", 150);
            tc.verifyTrue(isfile(basePath + ".png"));
            close(fig);
            rmdir(tmpDir, 's');
        end

        function testExportDataCSV(tc)
            tmpDir = tempname; mkdir(tmpDir);
            tbl = table((1:5)', rand(5,1), 'VariableNames', {'ID','Value'});
            basePath = fullfile(tmpDir, "test_data");
            neuramed.utils.ExportManager.exportData(tbl, basePath, "csv");
            tc.verifyTrue(isfile(basePath + ".csv"));
            rmdir(tmpDir, 's');
        end
    end
end
