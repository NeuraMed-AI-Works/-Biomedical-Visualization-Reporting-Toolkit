classdef (Abstract) NeuraMedComponent < handle
    % NEURAMEDCOMPONENT Abstract base class for all Neura-Med AI UI components.
    %
    %   Every viewer, dashboard panel, and reusable widget in the toolkit
    %   inherits from this class. It provides:
    %     - a shared parent-container contract (works inside any uifigure,
    %       uipanel, or App Designer app)
    %     - theme propagation (Dark / Light)
    %     - a consistent build/refresh/destroy lifecycle
    %     - standardized event notification (data cursor, ROI, alarms, etc.)
    %
    %   Subclasses MUST implement:
    %     buildUI(obj)      -> construct graphics objects
    %     refresh(obj)      -> redraw using current Data/Config
    %     applyTheme(obj,t) -> restyle graphics objects for theme t
    %
    % Neura-Med AI Biomedical Visualization & Reporting Toolkit
    % (c) Neura-Med AI. All rights reserved.

    properties (SetAccess = protected)
        Parent          % any valid graphics container: uifigure, uipanel, or uigridlayout
        Container       % handle to uipanel/uigridlayout this component owns
        Theme    (1,1) string = "Light"
        Tag      (1,1) string = ""
        IsBuilt  (1,1) logical = false
    end

    properties (Access = protected)
        ListenersInternal = event.listener.empty
    end

    events
        ComponentReady          % fired once buildUI completes
        DataChanged             % fired whenever underlying Data is set
        UserAnnotation          % fired when the user adds/edits an annotation
        AlarmRaised              % fired by clinical components (e.g. dashboard)
        StatusMessage            % generic status/log string for host apps to display
    end

    methods
        function obj = NeuraMedComponent(parent, varargin)
            arguments
                parent
            end
            arguments (Repeating)
                varargin
            end
            obj.Parent = parent;
            p = inputParser;
            p.KeepUnmatched = true;
            addParameter(p, 'Theme', "Light");
            addParameter(p, 'Tag', "");
            parse(p, varargin{:});
            obj.Theme = string(p.Results.Theme);
            obj.Tag   = string(p.Results.Tag);
        end

        function initialize(obj)
            % INITIALIZE Standard lifecycle entry point. Call this once
            % after construction instead of calling buildUI directly, so
            % lifecycle hooks and error handling stay consistent.
            if obj.IsBuilt
                return
            end
            try
                obj.buildUI();
                obj.applyTheme(obj.Theme);
                obj.IsBuilt = true;
                notify(obj, 'ComponentReady');
            catch ME
                error('NeuraMed:ComponentBuildFailed', ...
                    'Failed to build %s: %s', class(obj), ME.message);
            end
        end

        function setTheme(obj, themeName)
            arguments
                obj
                themeName (1,1) string {mustBeMember(themeName, ["Light","Dark"])}
            end
            obj.Theme = themeName;
            if obj.IsBuilt
                obj.applyTheme(themeName);
            end
        end

        function log(obj, msg, varargin)
            % LOG Emit a StatusMessage event; host apps can subscribe to
            % pipe this into a status bar or log file.
            txt = sprintf(msg, varargin{:});
            notify(obj, 'StatusMessage', neuramed.core.NeuraMedEventData(txt));
        end

        function delete(obj)
            if ~isempty(obj.ListenersInternal)
                delete(obj.ListenersInternal(isvalid(obj.ListenersInternal)));
            end
            if ~isempty(obj.Container) && isvalid(obj.Container)
                delete(obj.Container);
            end
        end
    end

    methods (Abstract, Access = protected)
        buildUI(obj)
        applyTheme(obj, themeName)
    end

    methods (Abstract)
        refresh(obj)
    end
end
