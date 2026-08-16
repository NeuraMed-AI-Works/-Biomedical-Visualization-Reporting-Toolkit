classdef MultiChannelViewer < neuramed.core.NeuraMedComponent
    % MULTICHANNELVIEWER Stacks multiple SignalViewerBase-derived viewers
    % (e.g. ECG + EEG + PPG together) in a synchronized, linked-x-axis
    % scrollable panel — used by ClinicalDashboard's SignalDisplay region.

    properties
        Viewers cell = {}   % cell array of SignalViewerBase objects
        Labels string = string.empty
    end

    properties (Access = protected)
        Grid
    end

    methods
        function obj = MultiChannelViewer(parent, varargin)
            obj@neuramed.core.NeuraMedComponent(parent, varargin{:});
        end

        function addViewer(obj, viewerObj, label)
            arguments
                obj
                viewerObj (1,1) neuramed.signals.SignalViewerBase
                label (1,1) string = ""
            end
            obj.Viewers{end+1} = viewerObj;
            obj.Labels(end+1) = label;
            if obj.IsBuilt
                obj.refresh();
            end
        end

        function linkAxes(obj)
            % LINKAXES Synchronize x-zoom/pan across all stacked viewers.
            axesList = matlab.graphics.axis.Axes.empty;
            for i = 1:numel(obj.Viewers)
                ax = obj.Viewers{i}.getAxesHandle();
                if ~isempty(ax)
                    axesList(end+1) = ax; %#ok<AGROW>
                end
            end
            if numel(axesList) > 1
                linkaxes(axesList, 'x');
            end
        end

        function refresh(obj)
            for i = 1:numel(obj.Viewers)
                obj.Viewers{i}.refresh();
            end
        end
    end

    methods (Access = protected)
        function buildUI(obj)
            n = max(numel(obj.Viewers), 1);
            obj.Grid = uigridlayout(obj.Parent, [n 1]);
            obj.Grid.RowHeight = repmat({'1x'}, 1, n);
            obj.Container = obj.Grid;
            for i = 1:numel(obj.Viewers)
                obj.Viewers{i}.Parent = obj.Grid;
                obj.Viewers{i}.initialize();
                obj.Viewers{i}.Container.Layout.Row = i;
            end
            obj.linkAxes();
        end

        function applyTheme(obj, themeName)
            for i = 1:numel(obj.Viewers)
                obj.Viewers{i}.setTheme(themeName);
            end
        end
    end
end
