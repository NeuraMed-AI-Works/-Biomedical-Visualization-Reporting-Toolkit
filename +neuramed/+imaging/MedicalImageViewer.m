classdef MedicalImageViewer < neuramed.core.NeuraMedComponent
    % MEDICALIMAGEVIEWER Unified viewer for medical images (fundus, OCT,
    % X-ray, MRI slice, etc.) with ROI selection, mask/heatmap overlay,
    % segmentation-boundary display, and histogram inspection.
    %
    % Used by: OcuScan-style retinal analysis, Neurix EEG spectrogram
    % overlay, glaucoma GradCAM explainability figures, etc.

    properties
        Image           uint8 = []      % HxWx3 or HxW
        OverlayMask     double = []      % HxW, values in [0,1] (heatmap) or logical (segmentation)
        OverlayAlpha    (1,1) double {mustBeInRange(OverlayAlpha,0,1)} = 0.45
        OverlayColormap (1,1) string = "jet"
        ROI             = []            % images.roi.* handle once drawn
        Config struct = struct('Title', "Medical Image Viewer", 'ShowColorbar', true)
    end

    properties (Access = protected)
        Axes
        ImgHandle
        OverlayHandle
        Colorbar
    end

    methods
        function obj = MedicalImageViewer(parent, varargin)
            obj@neuramed.core.NeuraMedComponent(parent, varargin{:});
        end

        function loadImage(obj, img)
            imgU8 = im2uint8(img);
            if size(imgU8, 3) == 1
                % Force true-color so a later heatmap overlay's axes
                % colormap (e.g. 'jet') cannot also recolor the base
                % image — 2D arrays are colormap-indexed by imshow,
                % 3-channel arrays are not.
                imgU8 = repmat(imgU8, [1 1 3]);
            end
            obj.Image = imgU8;
            if obj.IsBuilt
                obj.refresh();
            end
            notify(obj, 'DataChanged');
        end

        function setOverlay(obj, mask, kind)
            % SETOVERLAY kind = "heatmap" (continuous, e.g. GradCAM) or
            % "segmentation" (logical mask, drawn as boundary + fill).
            arguments
                obj
                mask double
                kind (1,1) string {mustBeMember(kind, ["heatmap","segmentation"])} = "heatmap"
            end
            if isempty(obj.Image)
                error('NeuraMed:NoImage', 'Call loadImage() before setOverlay().');
            end
            imgSize = size(obj.Image, [1 2]);
            maskSize = size(mask, [1 2]);
            if ~isequal(imgSize, maskSize)
                error('NeuraMed:OverlaySizeMismatch', ...
                    'Overlay mask is %dx%d but the loaded image is %dx%d — they must match.', ...
                    maskSize(1), maskSize(2), imgSize(1), imgSize(2));
            end
            obj.OverlayMask = mask;
            obj.Config.OverlayKind = kind;
            obj.refresh();
        end

        function clearOverlay(obj)
            obj.OverlayMask = [];
            obj.refresh();
        end

        function roiObj = selectROI(obj, shape, position)
            % SELECTROI Interactive by default (waits for the user to
            % draw on the axes). For automated scripts/tests, pass an
            % explicit position to create the ROI programmatically
            % instead of blocking on mouse input:
            %   rectangle/polygon: position = [x y w h] (rectangle) or
            %                      an Nx2 vertex matrix (polygon)
            %   ellipse:           position = [cx cy semiX semiY]
            arguments
                obj
                shape (1,1) string {mustBeMember(shape, ["rectangle","ellipse","freehand","polygon"])} = "rectangle"
                position double = []
            end
            if isempty(position)
                switch shape
                    case "rectangle"; roiObj = drawrectangle(obj.Axes);
                    case "ellipse";   roiObj = drawellipse(obj.Axes);
                    case "freehand";  roiObj = drawfreehand(obj.Axes);
                    case "polygon";   roiObj = drawpolygon(obj.Axes);
                end
            else
                switch shape
                    case "rectangle"
                        roiObj = drawrectangle(obj.Axes, 'Position', position);
                    case "ellipse"
                        roiObj = drawellipse(obj.Axes, 'Center', position(1:2), 'SemiAxes', position(3:4));
                    case "polygon"
                        roiObj = drawpolygon(obj.Axes, 'Position', position);
                    case "freehand"
                        error('NeuraMed:UnsupportedProgrammaticShape', ...
                            'Freehand ROIs require interactive drawing; omit the position argument for freehand.');
                end
            end
            obj.ROI = roiObj;
        end

        function stats = roiStats(obj)
            % ROISTATS Mean/std/area of pixel intensities inside the ROI.
            if isempty(obj.ROI) || ~isvalid(obj.ROI)
                error('NeuraMed:NoROI', 'Call selectROI() first.');
            end
            mask = createMask(obj.ROI);
            gray = im2double(obj.rgb2gray_safe(obj.Image));
            vals = gray(mask);
            stats = struct('Mean', mean(vals), 'Std', std(vals), ...
                'PixelCount', nnz(mask), 'AreaFraction', nnz(mask)/numel(mask));
        end

        function fig = showHistogram(obj)
            % SHOWHISTOGRAM Opens a standalone intensity histogram figure
            % (kept separate so it can be exported independently via
            % ExportManager for publication supplementary figures).
            fig = uifigure('Name', 'Intensity Histogram', 'Position', [200 200 480 360]);
            ax = uiaxes(fig, 'Position', [40 40 400 290]);
            gray = im2double(obj.rgb2gray_safe(obj.Image));
            histogram(ax, gray(:), 64, 'FaceColor', [0.26 0.46 0.82], 'EdgeColor', 'none');
            title(ax, "Pixel Intensity Histogram");
            xlabel(ax, "Normalized Intensity"); ylabel(ax, "Count");
        end

        function refresh(obj)
            if isempty(obj.Image) || isempty(obj.Axes) || ~isvalid(obj.Axes)
                return
            end
            cla(obj.Axes);
            obj.ImgHandle = imshow(obj.Image, 'Parent', obj.Axes);
            hold(obj.Axes, 'on');
            if ~isempty(obj.OverlayMask)
                kind = "heatmap";
                if isfield(obj.Config, 'OverlayKind'); kind = obj.Config.OverlayKind; end
                if kind == "heatmap"
                    obj.OverlayHandle = imagesc(obj.Axes, obj.OverlayMask);
                    colormap(obj.Axes, obj.OverlayColormap);
                    set(obj.OverlayHandle, 'AlphaData', obj.OverlayAlpha * (obj.OverlayMask > 0.05));
                    if obj.Config.ShowColorbar
                        obj.Colorbar = colorbar(obj.Axes);
                    end
                else % segmentation
                    boundaries = bwboundaries(obj.OverlayMask > 0.5);
                    for k = 1:numel(boundaries)
                        b = boundaries{k};
                        plot(obj.Axes, b(:,2), b(:,1), 'Color', [1 0.3 0.2], 'LineWidth', 1.6);
                    end
                end
            end
            hold(obj.Axes, 'off');
            title(obj.Axes, obj.Config.Title);
            axis(obj.Axes, 'image');
        end
    end

    methods (Access = protected)
        function buildUI(obj)
            g = uigridlayout(obj.Parent, [1 1]);
            g.Padding = [2 2 2 2];
            obj.Container = g;
            obj.Axes = uiaxes(g);
            obj.Axes.Toolbar.Visible = 'on';
        end

        function applyTheme(obj, themeName)
            pal = neuramed.core.ThemeManager.palette(themeName);
            if ~isempty(obj.Axes) && isvalid(obj.Axes)
                obj.Axes.Color = pal.Background;
                obj.Axes.Title.Color = pal.TextPrimary;
            end
        end
    end

    methods (Static, Access = private)
        function g = rgb2gray_safe(img)
            if ndims(img) == 3
                g = rgb2gray(img);
            else
                g = img;
            end
        end
    end
end
