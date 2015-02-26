% script to test big data functions

%% memmapfile function
clear;
clc;

gb = 0.9;
nimg = 1000;
npro = 300;
nrot = 360;
ntra = 150;

dr = nrot;
dt = floor(gb*1024^3/(4*nimg*npro*nrot));
if (dt == 0)
    % most probably will not happen, otherwise will have to split along rotation
    dt = 1;
    dr = floor(gb*1024^3/(4*nimg*npro));
end

tic;
chunk = rand(nimg, npro, dr, dt);
toc;

% allocate memory by fwrite
tic;
pathcache = '/home/cryo-em-3d/cryo3d/test/cache/';
fname = '_.dat';
fid = fopen([pathcache fname], 'Wb');
fwrite(fid, chunk, 'double');
fclose(fid);
toc;

m = memmapfile([pathcache fname], 'Format', 'double',...
        'Writable', true);
    
fprintf('loop of reading and writing:\n');

for i = 1:10
    tic;
    data = reshape(m.Data,nimg,npro,dr,dt);
    toc;
    fprintf('matrix equality: %i\n', isequal(data,chunk));
    
    tic;
    chunk = rand(nimg, npro, dr, dt);
    m.Data = chunk;
    toc;
end

% last matrix read
tic;
data = reshape(m.Data,nimg,npro,dr,dt);
toc;
fprintf('matrix equality: %i\n', isequal(data,chunk));

%% matfile

% tic;
% chunk = rand(nimg, npro, dr, dt);
% toc;
% 
% tic;
% fname = '_.mat';
% save([pathcache fname], 'chunk');
% toc;
% 
% tic;
% m = matfile([pathcache fname]);
% data_m2 = m.chunk;
% toc;