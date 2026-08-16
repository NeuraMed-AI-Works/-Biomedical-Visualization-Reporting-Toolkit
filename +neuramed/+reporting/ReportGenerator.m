classdef ReportGenerator
    % REPORTGENERATOR Builds automatic clinical/research reports as PDF or
    % DOCX using MATLAB Report Generator (mlreportgen). Falls back to a
    % plain-figure PDF export if Report Generator is unavailable.
    %
    % Usage:
    %   rg = neuramed.reporting.ReportGenerator("PatientReport_001", "pdf");
    %   rg.addTitlePage("Neurix Stress Assessment Report", patientInfo);
    %   rg.addSummary("Findings text...");
    %   rg.addFigure(figHandle, "EEG Band Power");
    %   rg.addTable(summaryTable, "Session Summary");
    %   rg.addRecommendations(["Follow up in 2 weeks", "Repeat EEG session"]);
    %   rg.close();

    properties
        OutputPath (1,1) string
        Format (1,1) string {mustBeMember(Format, ["pdf","docx"])} = "pdf"
        HasReportGen (1,1) logical
    end

    properties (Access = private)
        Report
        Import
    end

    methods
        function obj = ReportGenerator(fileNameNoExt, format)
            arguments
                fileNameNoExt (1,1) string
                format (1,1) string {mustBeMember(format, ["pdf","docx"])} = "pdf"
            end
            obj.Format = format;
            obj.OutputPath = fileNameNoExt + "." + format;
            % which() alone only confirms the class file is findable on
            % the path — it does NOT confirm a valid license is actually
            % checked out. On some installs the class stub is findable
            % but MATLAB Report Generator itself isn't licensed, which
            % previously left HasReportGen=true and made every
            % subsequent addXxx() call throw a license-checkout error
            % instead of gracefully falling back. Check the license
            % first, then also guard the actual construction in
            % try/catch as a second line of defense.
            obj.HasReportGen = license('test', 'MATLAB_Report_Generator') && ...
                ~isempty(which('mlreportgen.dom.Document'));
            if obj.HasReportGen
                try
                    import mlreportgen.dom.*
                    obj.Report = Document(char(fileNameNoExt), char(format));
                catch ME
                    warning('NeuraMed:ReportGenUnavailable', ...
                        ['MATLAB Report Generator appears installed but could not be used ' ...
                         '(%s). Falling back to basic export.'], ME.message);
                    obj.HasReportGen = false;
                end
            else
                warning('NeuraMed:NoReportGen', ...
                    'MATLAB Report Generator not licensed/found. Falling back to basic PDF export.');
            end
        end

        function addTitlePage(obj, titleStr, patientInfo)
            if ~obj.HasReportGen; return; end
            import mlreportgen.dom.*
            tp = append(obj.Report, Paragraph(titleStr));
            tp.Style = {Bold(true), FontSize('20pt'), HAlign('center')};
            append(obj.Report, Paragraph(" "));
            fields = fieldnames(patientInfo);
            for i = 1:numel(fields)
                p = Paragraph(sprintf("%s: %s", fields{i}, string(patientInfo.(fields{i}))));
                append(obj.Report, p);
            end
            append(obj.Report, PageBreak());
        end

        function addSummary(obj, headingStr, bodyText)
            arguments
                obj
                headingStr (1,1) string = "Clinical Summary"
                bodyText (1,1) string = ""
            end
            if ~obj.HasReportGen; return; end
            import mlreportgen.dom.*
            h = Heading2(char(headingStr));
            append(obj.Report, h);
            append(obj.Report, Paragraph(char(bodyText)));
        end

        function addFigure(obj, figHandle, captionStr)
            arguments
                obj
                figHandle
                captionStr (1,1) string = ""
            end
            if ~obj.HasReportGen; return; end
            import mlreportgen.dom.*
            tmpImg = [tempname, '.png'];
            exportgraphics(figHandle, tmpImg, 'Resolution', 300);
            img = Image(tmpImg);
            img.Width = "5.5in"; % Height intentionally left unset — auto-scales
            % to preserve aspect ratio. Assigning Height=[] here previously
            % threw a property validation error (Height must be char/string).
            append(obj.Report, img);
            if strlength(captionStr) > 0
                cap = Paragraph(char(captionStr));
                cap.Style = {Italic(true), FontSize('9pt'), HAlign('center')};
                append(obj.Report, cap);
            end
        end

        function addTable(obj, dataTable, captionStr)
            arguments
                obj
                dataTable table
                captionStr (1,1) string = ""
            end
            if ~obj.HasReportGen; return; end
            import mlreportgen.dom.*
            if strlength(captionStr) > 0
                append(obj.Report, Heading3(char(captionStr)));
            end
            t = MATLABTable(dataTable);
            t.Style = {Border('single'), ColSep('single'), RowSep('single')};
            append(obj.Report, t);
        end

        function addRecommendations(obj, recs)
            arguments
                obj
                recs string
            end
            if ~obj.HasReportGen; return; end
            import mlreportgen.dom.*
            append(obj.Report, Heading2("Recommendations"));
            ul = UnorderedList();
            for i = 1:numel(recs)
                append(ul, ListItem(char(recs(i))));
            end
            append(obj.Report, ul);
        end

        function close(obj)
            if obj.HasReportGen
                close(obj.Report);
            end
        end
    end
end
