function setupNeuraMedToolkit()
%SETUPNEURAMEDTOOLKIT Add the Neura-Med AI toolkit to the MATLAB path.
%   Run once per session (or add to your startup.m):
%       setupNeuraMedToolkit()
%
%   Requires MATLAB R2021b+ (uses arguments blocks, string arrays,
%   uigridlayout). Image Processing Toolbox required for Module 2.
%   MATLAB Report Generator required for DOCX/rich-PDF reports in
%   Module 4 (falls back gracefully if absent).

root = fileparts(mfilename('fullpath'));
addpath(root);
addpath(fullfile(root, 'apps'));
addpath(fullfile(root, 'examples'));
addpath(fullfile(root, 'tests'));
fprintf('Neura-Med AI Toolkit added to path: %s\n', root);

reqs = ["MATLAB", "Image Processing Toolbox"];
v = ver;
installed = string({v.Name});
for r = reqs
    if any(contains(installed, r))
        fprintf('  [OK] %s found\n', r);
    else
        fprintf('  [!!] %s NOT found — some Module 2 features may be limited\n', r);
    end
end

if license('test', 'MATLAB_Report_Generator') && ~isempty(which('mlreportgen.dom.Document'))
    fprintf('  [OK] MATLAB Report Generator found\n');
else
    fprintf('  [i] MATLAB Report Generator not detected — Module 4 will fall back to basic export.\n');
end
end
