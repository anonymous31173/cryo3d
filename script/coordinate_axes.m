function passed = coordinate_axes(dbpath, dtheta,disp_flag,fig_num)

passed = 0;
addpath(fullfile(cd, '../src/best_match'));
coord_axes = create_approx_uniform_axes_whole_sphere(dtheta,disp_flag,fig_num);
save([dbpath '/coord_axes_' num2str(dtheta) '.mat'], 'coord_axes');

passed = 1;