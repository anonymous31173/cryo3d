function comp_SSDs_fast_best_match_wrapper( fname, resfname )
%   To use as a part of cryo3d together with rshell-mat -
%   to parallelize ssds heavy computations
%   2015 Victoria Rudakova, vicrucann@gmail.com

fprintf('The data file provided: %s\n', fname);
load(fname);

ssdi = inf(numprojc, numcurrim, r_end - r_begin, numst,'single');

fprintf('The calculation loop for r in range [%i %i] and t in range [%i %i]\n', r_begin, r_end, 1, numst);
for r = r_begin:r_end
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
        currips = currprojcoeffs*(ipsi(:, :, r - r_begin + 1, currt) * ic);
        %currips = currprojcoeffs*(ips(:,:,r,currt)*ic);
        
        %                   % Calculate scale and adjust
        s = currips ./ currprojnorms / 2;
        s(s < minscale) = minscale;
        s(s > maxscale) = maxscale;
        % Calculate the ssds between each projection and image
        ssdi(:, :, r - r_begin + 1, t) = currimnorms + s.^2.*currprojnorms - s.*currips;
    end
end
fprintf('loop-1 terminated\n');
minidc = zeros(1,numcurrim);
minval = zeros(1,numcurrim);
for i = 1:numcurrim
    currssdi = squeeze(ssdi(:,i,:,:));
    [minval(i), minidc(i)] = min(currssdi(:));
end
fprintf('loop-2 terminated\n');
%wh = whos('ssdi');
%fid = fopen(resfname,'Wb');
%fwrite(fid, ssdi, wh.class);
%fclose(fid);
%save(resfname, 'ssdi', '-v7.3'); % fwrite is faster?
save(resfname, 'minval', 'minidc');
fprintf('output variable saved\n');
end
