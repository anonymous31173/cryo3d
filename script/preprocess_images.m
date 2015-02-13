% Function for pre-processing the particle images, including phase flipping,
% prewhitening, and normalizing the intensities to have 0 mean, 1 std dev

% Nicha C. Dvornek 02/2015

% Input parameters, example:
% stackfile = 'G:\db-frank\stack_ds4.mrc'; % examples
% ctffile = 'G:\db-frank\stack_ds4_5ctfs.mat';
% npsfile = 'G:\db-frank\NPS.txt';
% Apix = 1.045; % pixel size of micrograph in Angstroms

function passed = preprocess_images(stackfile, ctffile, npsfile, Apix, downsample, pwflag, pfflag)

passed = 0;
addpath(fullfile(cd, '../src/preprocessing'));
addpath(fullfile(cd, '../src/mrc'));

% Data and Params
if (nargin < 7)
    pfflag = 1; % Flag for whether or not to phase flip the images
end
if (nargin < 6)
    pwflag = 1; % Flag for whether or not to prewhiten the images
end
if (nargin < 5)
    downsample = 1; % Factor by which to downsample
end
 

%% Load things

disp('Loading CTF info, NPS info, and image stack');

% Load CTF things
load(ctffile,'ctfinds','ctfParams');
K = size(ctfParams,1);

% Load NPS info
% THIS IS HOW I READ IT IN FOR THE EXAMPLE FILE - NOT SURE IF THERE IS A
% STANDARD FILE TYPE THAT IS TO BE READ IN
f = importdata(npsfile);
dqe_freq = f.data(:,1)/(2*Apix);
nps = f.data(:,3);
clear f

% Load image stack
[noisyims_raw, h] = ReadMRC(stackfile);
Apixstack = h.pixA;
imgSx = size(noisyims_raw,1);
noisyims = zeros(size(noisyims_raw),'single');

% Make each image zero mean
numim = size(noisyims_raw,3);
for i = 1:numim
    noisyims_raw(:,:,i) = noisyims_raw(:,:,i) - mean(reshape(noisyims_raw(:,:,i),imgSx^2,1));
end

%% IMAGE PROCESSING

% For each CTF cluster
for i = 1:K
    
    fprintf('CTF CLUSTER: %d\n',i);

    % Get all images from stack
    singleSet = noisyims_raw(:,:,ctfinds == i);
    numinset = size(singleSet,3);
    montageSx = ceil(sqrt(size(singleSet,3)));
    montageHandle = montage(reshape(singleSet,[imgSx, imgSx, 1, numinset]),'Size',[montageSx montageSx],'DisplayRange',[]);
    clear singleSet
    singleMontage = getimage(montageHandle);
    close
    
    % Do phase flipping if flag is set
    if pfflag 
        % Create CTF image
        ctfImg = CTF(montageSx*imgSx,Apixstack,ctfParams{i,1});

        % Make into phase flipping image
        ctfImg(ctfImg<0) = -1; 
        ctfImg(ctfImg>0) = 1;
        ctfImg           = ctfImg.*-1;

        % Phase flip 
        fprintf('  Phase Flipping Images...');
        singleMontage = real(ifft2(ifftshift(ctfImg.*fftshift(fft2(singleMontage)))));
        clear ctfImg
        fprintf('DONE.\n');       
    end
    
    % Do prewhitening if flag is set
    if pwflag       
        % Pre-whitening each "micrograph" bc whole set is too much memory
        fprintf('  Create prewhitening filter....\n');
        sm_size = size(singleMontage,1);
        f_ind = get_freq_axis(Apixstack,sm_size);
        pfilt = interp1(dqe_freq,1./sqrt(nps),1./f_ind);
        [x, y] = ndgrid(single(-sm_size/2:sm_size/2-1)); % zero at element n/2+1.
        R = sqrt(x.^2 + y.^2);
        clear x y
        pfilt2d = interp1(0:sm_size/2-1,pfilt,R(:));
        clear R
        pfilt2d(isnan(pfilt2d)) = pfilt(end);
        pfilt2d = reshape(pfilt2d,[sm_size,sm_size]);
        fprintf('  Prewhiten the images...\n');
        singleMontage = real(ifft2(ifftshift(pfilt2d.*fftshift(fft2(singleMontage)))));
        clear pfilt2d      
    end
    
    % Rearrange montage image back into stack and normalize intensities
    fprintf('  Normalize image intensities...\n');
    tempset = zeros(imgSx,imgSx,numinset,'single');
    idx = 1;
    for j = 1 : imgSx : size(singleMontage,1)
        for k = 1 : imgSx : size(singleMontage,1)
            temp = singleMontage(j:j+(imgSx-1),k:k+(imgSx-1));
            tempset(:,:,idx) = (temp - mean(temp(:))) ./ std(temp(:));
            idx = idx + 1;
        end
    end
    noisyims(:,:,ctfinds == i) = tempset(:,:,1:numinset);
    clear singleMontage tempset

    fprintf('DONE.\n');
    
end

% Downsample each image
if downsample > 1
    tempnoisyims = noisyims;
    newimgSx = floor(imgSx/downsample);
    if mod(newimgSx,2) ~= 0
        newimgSx = newimgSx + 1;
    end
    noisyims = zeros(newimgSx,newimgSx,size(tempnoisyims,3),'single');
    for i = 1:size(noisyims,3)
        temp = DownsampleGeneral(tempnoisyims(:,:,i),newimgSx,1);
        noisyims(:,:,i) = (temp - mean(temp(:))) ./ std(temp(:));
    end
    clear tempnoisyims temp
end


%% SAVE THE PROCESSED IMAGES

f = strfind(stackfile,'.mrc');
savefile = stackfile(1:f-1);
if pfflag
    savefile = [savefile '_pf'];
end
if pwflag
    savefile = [savefile '_pw'];
end
if downsample > 1
    saefile = [savefile '_ds' num2str(downsample)];
end
savefile = [savefile '_norm.mrc'];
writeMRC(noisyims,Apixstack,savefile);
passed = 1;
