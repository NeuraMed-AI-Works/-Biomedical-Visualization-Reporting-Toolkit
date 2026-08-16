classdef PublicationFigures
    % PUBLICATIONFIGURES Static utility library for IEEE/journal-quality
    % scientific figures: confusion matrices, ROC curves, training curves,
    % accuracy comparisons, and generic statistical bar/box charts. Every
    % method returns the figure handle so it can be piped straight into
    % ReportGenerator.addFigure() or ExportManager.export().

    methods (Static)
        function fig = confusionMatrix(yTrue, yPred, classNames)
            arguments
                yTrue
                yPred
                classNames = []
            end
            fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 5.5 4.5]);
            if isempty(classNames)
                cm = confusionchart(yTrue, yPred);
            else
                % Build the numeric confusion matrix explicitly, then use
                % the (matrix, labels) form of confusionchart. Passing
                % 'ClassLabels' as a name-value pair alongside raw label
                % vectors trips a read-only-property error on some
                % releases (incl. R2025a) — the matrix+labels form is the
                % documented-safe path for custom class names.
                [cmat, order] = confusionmat(yTrue, yPred);
                classNames = string(classNames);
                if numel(classNames) ~= numel(order)
                    error('NeuraMed:ClassLabelMismatch', ...
                        ['classNames has %d entries but %d classes were found in the data. ' ...
                         'Provide one label per unique class, in ascending sort order of the raw labels.'], ...
                        numel(classNames), numel(order));
                end
                cm = confusionchart(cmat, classNames);
            end
            cm.Title = 'Confusion Matrix';
            cm.RowSummary = 'row-normalized';
            cm.ColumnSummary = 'column-normalized';
            cm.FontName = 'Segoe UI';
        end

        function [fig, auc] = rocCurve(labels, scores, positiveClass)
            arguments
                labels
                scores (:,1) double
                positiveClass = 1
            end
            [fpr, tpr, ~, auc] = perfcurve(labels, scores, positiveClass);
            fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 5 4.5]);
            plot(fpr, tpr, 'LineWidth', 2, 'Color', [0.086 0.463 0.824]); hold on;
            plot([0 1], [0 1], '--', 'Color', [0.6 0.6 0.6]);
            xlabel('False Positive Rate'); ylabel('True Positive Rate');
            title(sprintf('ROC Curve (AUC = %.3f)', auc));
            grid on; axis square; legend('Model', 'Chance', 'Location', 'southeast');
            set(gca, 'FontName', 'Segoe UI', 'FontSize', 10, 'Box', 'on');
        end

        function fig = trainingCurves(epochs, trainLoss, valLoss, trainAcc, valAcc)
            arguments
                epochs (:,1) double
                trainLoss (:,1) double
                valLoss (:,1) double
                trainAcc (:,1) double = []
                valAcc (:,1) double = []
            end
            hasAcc = ~isempty(trainAcc);
            fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 9 3.6]);
            subplot(1, 1 + hasAcc, 1);
            plot(epochs, trainLoss, '-o', 'LineWidth', 1.5, 'MarkerSize', 3); hold on;
            plot(epochs, valLoss, '-s', 'LineWidth', 1.5, 'MarkerSize', 3);
            xlabel('Epoch'); ylabel('Loss'); title('Training vs Validation Loss');
            legend('Train', 'Validation', 'Location', 'best'); grid on;
            set(gca, 'FontName', 'Segoe UI');
            if hasAcc
                subplot(1,2,2);
                plot(epochs, trainAcc, '-o', 'LineWidth', 1.5, 'MarkerSize', 3); hold on;
                plot(epochs, valAcc, '-s', 'LineWidth', 1.5, 'MarkerSize', 3);
                xlabel('Epoch'); ylabel('Accuracy'); title('Training vs Validation Accuracy');
                legend('Train', 'Validation', 'Location', 'best'); grid on;
                set(gca, 'FontName', 'Segoe UI');
            end
        end

        function fig = accuracyComparison(modelNames, accuracies)
            arguments
                modelNames string
                accuracies (:,1) double
            end
            fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 6 4]);
            b = bar(categorical(modelNames), accuracies, 'FaceColor', [0.086 0.463 0.824]);
            ylabel('Accuracy (%)'); title('Model Accuracy Comparison'); ylim([0 100]);
            grid on; set(gca, 'FontName', 'Segoe UI');
            xtips = b.XEndPoints; ytips = b.YEndPoints;
            text(xtips, ytips + 1.5, string(round(accuracies,2)), ...
                'HorizontalAlignment', 'center', 'FontSize', 9);
        end

        function fig = statisticalBoxplot(dataCell, groupNames, yLabelStr)
            arguments
                dataCell cell
                groupNames string
                yLabelStr (1,1) string = "Value"
            end
            fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 5.5 4]);
            allData = []; allGroups = [];
            for i = 1:numel(dataCell)
                allData = [allData; dataCell{i}(:)]; %#ok<AGROW>
                allGroups = [allGroups; repmat(groupNames(i), numel(dataCell{i}), 1)]; %#ok<AGROW>
            end
            boxplot(allData, allGroups);
            ylabel(yLabelStr); grid on; set(gca, 'FontName', 'Segoe UI');
            title('Statistical Comparison');
        end

        function exportHighRes(fig, filePathNoExt, formats, dpi)
            arguments
                fig
                filePathNoExt (1,1) string
                formats string = ["png","pdf"]
                dpi (1,1) double = 600
            end
            neuramed.utils.ExportManager.exportFigure(fig, filePathNoExt, formats, dpi);
        end
    end
end
