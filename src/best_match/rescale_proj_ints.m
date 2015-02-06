% Rescale projections to 0 mean 1 std and then scale to image range

function proj_struct = rescale_proj_ints(proj_struct,noisyims)

prcmin = 3;
prcmax = 97;

% for j = 1:size(proj_struct,3)
%     temp = proj_struct(:,:,j);
%     proj_struct(:,:,j) = (temp - mean(temp(:))) ./ std(temp(:));
% end

proj_struct = (proj_struct - mean(proj_struct(:))) ./ std(proj_struct(:));

mean_proj = mean(proj_struct,3);
proj_min = prctile(mean_proj(:),prcmin);
proj_max = prctile(mean_proj(:),prcmax);
proj_range = proj_max - proj_min;


mean_ni = mean(noisyims,3);
im_min = prctile(mean_ni(:),prcmin);
im_max = prctile(mean_ni(:),prcmax);
im_range = im_max - im_min;

proj_struct = (proj_struct - proj_min) ./ proj_range .* im_range + im_min;
