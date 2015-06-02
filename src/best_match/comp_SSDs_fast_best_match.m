% Function to be used with fast_best_match code
% Calculates the sum of squared differences between projections and images
% and finds the best match for each image
% The function is edited to be compatible with caching data structure

function [projinds,rotinds,SSDs,transinds,scales] = comp_SSDs_fast_best_match(projnorms,projcoeffs,imcoeffs,ips,ctfinds,numim,numctf,numproj,numrot,searchtrans,imnorms,maxmem,...
    ipaddrs,login,ppath,varmat,sleeptime,resfold,printout,pathout)

% Initializations
projinds = -ones(numim,1);
rotinds = zeros(numim,1);
SSDs = zeros(numim,1);
transinds = zeros(numim,1);
scales = zeros(numim,1);
numst = size(searchtrans,1);
searchtrans = searchtrans';
currmem = monitor_memory_whos;
minscale = 1.0;
maxscale = 1.0;

% For each CTF class
for c = 1:numctf
    
    % Get the relevant indices and norms for the current CTF
    inds = c:numctf:numproj;
    numprojc = length(inds);
    onesprojc = ones(numprojc,1,'int8');
    projnormsc = projnorms(inds);
    currprojcoeffs = projcoeffs(inds,:);
    cis = find(ctfinds == c)';
    searchtransu = unique(searchtrans(cis,:),'rows');
    numstu = size(searchtransu,1);
   
    % For each set of translations
    fprintf('\nNumber of set of translations: %i\n', numstu);
    for st = 1:numstu
        currtrans = searchtransu(st,:);
        sinds = find(ismember(searchtrans(cis,:),currtrans,'rows'));
        
        % Determine number of images to process per batch for handling limited memory
        numsinds = length(sinds);
        numbatches = ceil((numprojc*numsinds*numrot*numst + numprojc*numrot*numst)*4/1048576 / (maxmem - currmem - 550));
        if numbatches < 1
            numbatches = numsinds;
        elseif numbatches > 1
            numbatches = numbatches + 1; %%%% Changed to deal with memory
        end
        batchsize = ceil(numsinds / numbatches);
        numbatches = ceil(numsinds / batchsize);
        fprintf('\nNumber of images per batch to process: %i\n', numbatches);
        
        % For each batch of images
        for b = 1:numbatches
            
            % Get the indices of the images
            if b == numbatches
                curriminds = cis(sinds((b-1)*batchsize+1:end));
            else
                if (b*batchsize > length(sinds))
                    ind = b*batchsize
                    length(sinds)
                end
                curriminds = cis(sinds((b-1)*batchsize+1:b*batchsize));
            end
            numcurrim = length(curriminds);
            
            % Setup ssds matrix, rep proj norms, and get current imcoeffs
            ssds = inf(numprojc,numcurrim,numrot,numst,'single');
            currprojnorms = projnormsc(:,ones(numcurrim,1));
            ic = imcoeffs(curriminds,:)';
            
            % if using distributor, break data
            [ncluster ~] = find(ipaddrs==' ');
            ncluster = size(ncluster,2)+1;
            if ncluster == 1 % if distributor is not used
                % For each rotation
                for r = 1:numrot
                    % For each translation in the current search set
                    for t = 1:numst
                        % Check if translation exists
                        currt = currtrans(t);
                        if currt < 1
                            continue;
                        end
                        
                        % Set up the current image norms
                        currimnorms = imnorms(currt,curriminds);
                        currimnorms = currimnorms(onesprojc,:);
                        
                        % First calculate the inner products between
                        % projections and current images
                        currips = currprojcoeffs*(ips.read_cached_array([0,0,r,currt])*ic);
                        %currips = currprojcoeffs*(ips(:,:,r,currt)*ic);
                        
                        %                   % Calculate scale and adjust
                        s = currips ./ currprojnorms / 2;
                        s(s < minscale) = minscale;
                        s(s > maxscale) = maxscale;
                        
                        % Calculate the ssds between each projection and image
                        ssds(:,:,r,t) = currimnorms + s.^2.*currprojnorms - s.*currips;
                    end
                end
            else % if distributor is used
                
                % split and save data to files
                fprintf('\n\nCalculation using remotes: splitting data \n');
                numrot_ = ceil(numrot / ncluster);
                numrot_l = numrot - numrot_*(ncluster-1); % size of last might be different
                for i=1:ncluster
                    r_begin = (i-1)*numrot_ + 1;
                    dims = ips.dimension;
                    if i~=ncluster
                        r_end = numrot_ * i;
                        dims(ips.broken)=numrot_;
                    else % the last cluster
                        r_end = numrot;
                        dims(ips.broken)=numrot_l;
                    end
                    mm = memmapfile([ips.path ips.vname '_' num2str(i) '.dat'], 'Format', ips.type);
                    ipsi = reshape(mm.Data, dims);
                    save([pathout varmat int2str(i) '.mat'], 'r_begin', 'r_end', 'numst', 'currtrans', 'curriminds', 'onesprojc', 'currprojcoeffs', 'ic',...
                        'currprojnorms', 'minscale', 'maxscale', 'imnorms', 'numprojc', 'numcurrim', 'numrot', 'ipsi');
                end
                clear ipsi mm;
                % launch the bash scripts
                remmat = 'comp_SSDs_fast_best_match_wrapper';
                currfold = pwd;
                cd('../src/rshell-mat/');
                distrfold = pwd;
                distrfold = fixslash(distrfold);
                cd(currfold);
                cd('../src/best_match/');
                srcfold = pwd;
                srcfold = fixslash(srcfold);
                cd(currfold);
                bashscript = [distrfold 'dhead.sh'];
                pathsrc = srcfold;
                system(['chmod u+x ' bashscript]);
                if printout
                    cmdStr = [bashscript ' ' login ' ' ppath ' ' ipaddrs ' ' pathsrc ' ' remmat ' ' pathout ' ' varmat ' '...
                        distrfold ' ' int2str(sleeptime) ' ' resfold];
                else
                    cmdStr = [bashscript ' ' login ' ' ppath ' ' ipaddrs ' '...
                        pathsrc ' ' remmat ' ' pathout ' ' varmat ' ' distrfold ' ' int2str(sleeptime) ' ' resfold '>' remmat '.log 2>&1'];
                end
                % perform the command
                system(cmdStr);
                
                % merge the results (ssds = [ssdi1 ssdi2 ...])
                fprintf('Merging the result data...');
                for i=1:ncluster
                    %load([resfold '/' 'result_' varmat int2str(i) '.mat']);
                    mm = memmapfile([resfold '/' 'result_' varmat int2str(i) '.mat'], 'Format', ips.type);
                    dims = [numprojc,numcurrim,numrot,numst];
                    if i~=ncluster
                        dims(ips.broken)=numrot_;
                        ssdi = reshape(mm.Data, dims);
                        ssds(:,:, (i-1)*numrot_+1 : numrot_ * i, :) = ssdi;
                    else
                        dims(ips.broken)=numrot_l;
                        ssdi = reshape(mm.Data, dims);
                        ssds(:,:, (i-1)*numrot_ + 1 : numrot, :) = ssdi;
                    end
                end
                clear ssdi mm;
                fprintf('done\n');
            end
                 
            % For each image in the batch
            pind = zeros(1,numcurrim);
            rind = zeros(1,numcurrim);
            tind = zeros(1,numcurrim);
            for i = 1:numcurrim
                % Find the min ssd and get the indices of the parameters of
                % the best batch
                currssds = squeeze(ssds(:,i,:,:));
                [SSDs(curriminds(i)),minind] = min(currssds(:));
                [pind(i),rind(i),tind(i)] = ind2sub([numprojc,numrot,numst],minind);
                projinds(curriminds(i)) = inds(pind(i));
                rotinds(curriminds(i)) = rind(i);
                transinds(curriminds(i)) = currtrans(tind(i));
                
                % Calculate scale that gave the min ssd
                %scales(curriminds(i)) = currprojcoeffs(pind(i),:)*ips(:,:,rind(i),currtrans(tind(i)))*...
                %    imcoeffs(curriminds(i),:)' / projnormsc(pind(i)) / 2;
            end
            
            % to calculate scales, need to sort by rind so that to have sequensial access to ips
            [s_rind, i_rind] = sort(rind);
            s_pind = pind(i_rind);
            s_tind = tind(i_rind);
            s_curriminds = curriminds(i_rind);
            for i = 1:numcurrim
                scales(s_curriminds(i)) = currprojcoeffs(s_pind(i),:)* ips.read_cached_array([0, 0, s_rind(i), currtrans(s_tind(i)) ]) *...
                    imcoeffs(s_curriminds(i),:)' / projnormsc(s_pind(i))/2;
            end
            
            clear ssds currssds currprojnorms ic currimnorms
        end
        progress_bar(st, numstu);
    end
    fprintf('\n');
end

scales(scales < minscale) = minscale;
scales(scales > maxscale) = maxscale;
end

function foldname = fixslash(foldname)
slash = foldname(end);
if (~isequal(slash, '\') && ~isequal(slash, '/'))
    archstr = computer('arch');
    if (isequal(archstr(1:3), 'win')) % Windows
        foldname = [foldname '\'];
    else % Linux
        foldname = [foldname '/'];
    end
end
end

