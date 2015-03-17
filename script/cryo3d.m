% script to run the whole pipeline
% all the parameters are set here

%% Most frequent edited parameters

pathout = 'G:\workspace\db-hongwei\dselected_1\';
pathdata = 'G:\20150205_sdp\';
caching = 1; % 1 for caching on, 0 caching off, -1 automatic caching
dtheta = 12;
maskfile = 'G:\20150205_sdp\mask-0031-ds2-0803.mrc';
maxmem = 30624;

numthreads = 6;
rotstep = 3;
transmax = 4;

slash = pathout(end);
if (~isequal(slash, '\') && ~isequal(slash, '/'))
    pathout = [pathout '/\']; % windows and linux
end

%% Preprocessing

structfile = [pathdata 'run1_class001.mrc'];
stackfile = [pathdata 'stackfile_selected_1.mrcs'];
ctffile = [];
lpf = 30;
sigma = 1;
ds = 2; % downsampling of initial
downsample = 2;

structfile = init_volume(pathout, structfile, lpf, sigma, ds);
coordfile = coordinate_axes(pathout, dtheta);
imfile = preprocess_images(pathout, stackfile, ctffile, downsample);

%% Best Match

% Parameters for only using part of the data
substep = 0;
reconhalf = 0;
reconstartind = 0;
% Initial Model and Related Parameters
pf = 1;
pixfromedge = 4;
% System Parameters
dispflag = 0;
% Algorithm parameters
f = 0.0001;
numruns = 2;
maxnumiter = 10;
convtol = 0.01;
normprojint = 1;
% Transformation Search Parameters
rotstart = 0.5;
rotend = 359.9;
transdelta = 1;
transwidth = 1;
% Output parameters
alignims = 1;
% Generate config file
configfile = generate_config(pathout, imfile, ctffile, substep, reconhalf, reconstartind, ...
    structfile, coordfile, maskfile, pf, pixfromedge, maxmem, numthreads, dispflag, ...
    f, numruns, maxnumiter, convtol, normprojint, rotstart, rotstep, rotend, transmax, transdelta, transwidth, ...
    alignims);

best_match(pathout, configfile, caching);