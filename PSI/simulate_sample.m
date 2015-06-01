function GT = simulate_sample(opts)
%Simulates the 'Ground Truth' parameters GT
%   GT.motion: the sample motion
%   GT.seg: The segmentation of the image into seed regions
%   GT.activity: The activity trace of each seed

%read in an image which represents the neuron
disp('    Reading image data...')
if opts.do3D
    A = tiffread2([opts.image.dr opts.image.fn]);
    GT.IM = cell2mat(reshape({A.data},1,1,[]));
    
    %normalize the image to have the correct brightness
    %find regions inside the neuron
    %background subtract
    
    %threshold = 2 standard deviations of each plane?
    bw = false(size(GT.IM));
    I2 = zeros(size(GT.IM));
    for plane = 1:size(GT.IM,3)
        I2tmp = imtophat(medfilt2(GT.IM(:,:,plane)),strel('disk',4/opts.image.XYscale));
        thresh = prctile(I2tmp(:), 99)*0.5; %need a better thresholding method
        bw(:,:,plane) = I2tmp>thresh;
        I2(:,:,plane) = I2tmp;
    end
    mean_int = mean(double(I2(bw)));
    GT.IM = double(GT.IM)*opts.scope.brightness/mean_int;
    
    clear I2tmp I2 bw%free up memory
else
    imnums = 41:45;
    A = tiffread2([opts.image.dr opts.image.fn], min(imnums), max(imnums));
    GT.IM = max(cell2mat(reshape({A.data},1,1,[])),[],3);
    
    %normalize the image to have the correct brightness
    %find regions inside the neuron
    %background subtract
    I2 = imtophat(medfilt2(GT.IM),strel('disk',4/opts.image.XYscale)); %radius of 4 microns
    thresh = prctile(I2(:), 99)*0.5;
    bw = I2>thresh;
    mean_int = mean(double(I2(bw)));
    GT.IM = double(GT.IM)*opts.scope.brightness/mean_int;
end

%MOTION
GT.motion.pos = nan(3,opts.sim.dur);
for dim = 1:3
    if dim<3
        motion = opts.motion.amp.XY;
    else
        motion = opts.motion.amp.Z;
    end
    if strcmpi(opts.sim.dynamics, 'smooth')
        series = smooth(max(-opts.motion.limit/motion, min(opts.motion.limit/motion, sqrt(opts.motion.speed).*randn(1, 2*opts.motion.speed+opts.sim.dur))), opts.motion.speed);
        GT.motion.pos(dim,:) = motion .* series(opts.motion.speed+1:(end-opts.motion.speed));
    elseif strcmpi(opts.sim.dynamics, 'random')
        GT.motion.pos(dim,:) = max(-opts.motion.limit, min(opts.motion.limit, motion .* randn(1, opts.sim.dur)));
    else
        error('Option [opts.sim.dynamics] should be set to either ''smooth'' or ''random''');
    end
end

%SEGMENTATION
%A segmentation is a sparse npixels x nsegments array. Nonzero elements
%are considered 'inside' the cell
if opts.do3D
    GT.seg = segment_3D(GT.IM, opts);
else
    GT.seg = segment_2D(GT.IM, opts);
end

GT.nseeds = size(GT.seg.seg, 2);

%ACTIVITY
%generate a random smooth non-negative timeseries for each 'ground
%truth' seed
kernel = normpdf([-50*opts.framerate:50*opts.framerate], 0, 10*opts.framerate); %kernel in frames
kernel = kernel./max(kernel);
if strcmpi(opts.sim.dynamics, 'smooth')
    GT.activity = opts.sim.amp .* convn(poissrnd(1/(50*opts.framerate), GT.nseeds, opts.nframes), kernel ,'same');
else %random
    GT.activity = opts.sim.amp .* convn(poissrnd(1/(50*opts.framerate), GT.nseeds, max(500*length(kernel), opts.nframes)), kernel ,'same');
    GT.activity = GT.activity(:, randperm(size(GT.activity,2), opts.nframes));
end
end