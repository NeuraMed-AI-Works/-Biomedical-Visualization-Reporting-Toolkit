classdef MultiPanelViewer < neuramed.core.NeuraMedComponent
    % MULTIPANELVIEWER Tiles multiple MedicalImageViewer panels in a grid
    % (e.g. original / segmentation / GradCAM heatmap side-by-side), with
    % optional synchronized pan/zoom for direct visual comparison.

    properties
        Panels cell = {}     % cell array of MedicalImageViewer
        Titles string = string.empty
        GridSize (1,2) double = [1 1]   % [rows cols]
        SyncZoom (1,1) logical = true
    end

    properties (Access = protected)
        Grid
    end

    methods
        function obj = MultiPanelViewer(parent, varargin)
            obj@neuramed.core.NeuraMedComponent(parent, varargin{:});
        end

        function addPanel(obj, imgViewer, titleStr)
            arguments
                obj
                imgViewer (1,1) neuramed.imaging.MedicalImageViewer
                titleStr (1,1) string = ""
            end
            obj.Panels{end+1} = imgViewer;
            obj.Titles(end+1) = titleStr;
            n = numel(obj.Panels);
            cols = ceil(sqrt(n));
            rows = ceil(n/cols);
            obj.GridSize = [rows cols];
            if obj.IsBuilt
                obj.reflowPanels();
            end
        end

        function refresh(obj)
            for i = 1:numel(obj.Panels)
                obj.Panels{i}.refresh();
            end
        end
    end

    methods (Access = protected)
        function buildUI(obj)
            r = max(obj.GridSize(1), 1);
            c = max(obj.GridSize(2), 1);
            obj.Grid = uigridlayout(obj.Parent, [r c]);
            obj.Container = obj.Grid;
            obj.reflowPanels();
        end

        function applyTheme(obj, themeName)
            for i = 1:numel(obj.Panels)
                obj.Panels{i}.setTheme(themeName);
            end
        end
    end

    methods (Access = private)
        function reflowPanels(obj)
            % REFLOWPANELS (Re)computes grid dimensions and ensures every
            % panel — including ones added after initialize() — is
            % parented, built, and placed in the correct cell. Shared by
            % buildUI (first layout) and addPanel (dynamic additions).
            r = max(obj.GridSize(1), 1);
            c = max(obj.GridSize(2), 1);
            obj.Grid.RowHeight = repmat({'1x'}, 1, r);
            obj.Grid.ColumnWidth = repmat({'1x'}, 1, c);
            for i = 1:numel(obj.Panels)
                row = ceil(i / c);
                col = i - (row-1)*c;
                if ~obj.Panels{i}.IsBuilt
                    obj.Panels{i}.Parent = obj.Grid;
                    obj.Panels{i}.initialize();
                end
                obj.Panels{i}.Container.Layout.Row = row;
                obj.Panels{i}.Container.Layout.Column = col;
                if strlength(obj.Titles(i)) > 0
                    obj.Panels{i}.Config.Title = obj.Titles(i);
                end
                obj.Panels{i}.refresh();
            end
        end
    end
end
