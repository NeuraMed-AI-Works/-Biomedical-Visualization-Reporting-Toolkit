classdef ExportManager
    % EXPORTMANAGER Single entry point for every export format the
    % toolkit needs to support. Every viewer/dashboard/report module
    % should call through here rather than calling saveas/exportgraphics
    % directly, so file-naming, resolution, and metadata stay consistent
    % across all Neura-Med AI products.

    methods (Static)
        function exportFigure(fig, filePathNoExt, formats, dpi)
            arguments
                fig
                filePathNoExt (1,1) string
                formats string = "png"
                dpi (1,1) double = 300
            end
            for f = formats
                path = filePathNoExt + "." + f;
                switch lower(f)
                    case {"png","jpg","jpeg","tif","tiff"}
                        exportgraphics(fig, path, 'Resolution', dpi);
                    case "pdf"
                        exportgraphics(fig, path, 'ContentType', 'vector', 'Resolution', dpi);
                    case {"svg","eps"}
                        set(fig, 'Renderer', 'painters');
                        print(fig, path, ['-d' char(lower(f))], '-vector');
                    otherwise
                        warning('NeuraMed:UnsupportedFormat', 'Unsupported figure format: %s', f);
                end
            end
        end

        function exportData(data, filePathNoExt, formats)
            % EXPORTDATA data may be a table, struct, or numeric array.
            % formats: "mat","csv","xlsx"
            arguments
                data
                filePathNoExt (1,1) string
                formats string = "csv"
            end
            for f = formats
                path = filePathNoExt + "." + f;
                switch lower(f)
                    case "mat"
                        exportedData = data; %#ok<NASGU>
                        save(path, 'exportedData');
                    case "csv"
                        if istable(data)
                            writetable(data, path);
                        else
                            writematrix(data, path);
                        end
                    case {"xlsx","xls"}
                        if istable(data)
                            writetable(data, path);
                        else
                            writematrix(data, path);
                        end
                    otherwise
                        warning('NeuraMed:UnsupportedFormat', 'Unsupported data format: %s', f);
                end
            end
        end

        function path = exportReport(reportGenObj)
            % EXPORTREPORT Convenience wrapper: closes a ReportGenerator
            % (finalizing PDF/DOCX to disk) and returns its output path.
            arguments
                reportGenObj neuramed.reporting.ReportGenerator
            end
            reportGenObj.close();
            path = reportGenObj.OutputPath;
        end

        function batchExport(fig, baseName, outputDir)
            % BATCHEXPORT One-call "give me everything" export used for
            % final publication packaging: PNG (300dpi), PDF (vector),
            % SVG (vector), and EPS (vector) all at once.
            arguments
                fig
                baseName (1,1) string
                outputDir (1,1) string = "."
            end
            if ~isfolder(outputDir); mkdir(outputDir); end
            fullBase = fullfile(outputDir, baseName);
            neuramed.utils.ExportManager.exportFigure(fig, fullBase, ["png","pdf","svg","eps"], 600);
        end
    end
end
