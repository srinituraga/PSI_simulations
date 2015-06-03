function batch_simulate

%default options
opts.verbose = false;  %show some numbers and pictures during the simulation?

opts.image.fn = 'Live2-2-2013_13-19-31.tif';
opts.image.dr = [fileparts(which('simulate_scope')) filesep];
opts.framerate = 1; %frames/millisecond
opts.samplerate = 4000; %sample rate in projections (i.e. laser pulses)/millisecond; this should be the laser rep rate
opts.sim.dur = 10; %duration of simulation, milliseconds

opts.sim.amp = 10; %amplitude of signals, df/F0
opts.sim.dynamics = 'random';   %'smooth' for motion and activity varying slowly in time, or 'random' for a random bag of frames

opts.image.XYscale = 0.2; %voxel size of loaded image/standard 2P acquisition, microns
opts.image.Zscale = 1.5; %voxel size of loaded image/standard 2P acquisition, microns

opts.motion.amp.XY = 5; %5; %amplitude of sample motion, pixels/axis
opts.motion.amp.Z = 1; %amplitude of sample motion, pixels/axis
opts.motion.speed = 20; %timescale of motion; higher numbers are slower. Only applies if opts.sim.dynamics='smooth'
opts.motion.limit = 50; %50; %we are capping the simulated motion at this value, in pixels

opts.do3D = false; %are we simulating 2D or 3D imaging?
opts.Ptype = '4lines'; %what projection scheme are we simulating? 2lines, 4lines, etc.

opts.scope.darkrate = 0.5; %dark photon rate, per millisecond
opts.scope.PMTsigma = 0.5; %single photon pulse height variability of PMT/detector; sigma of gaussian, in photon eqivalents
opts.scope.readnoise = 0.3; % gaussian noise of the post-detector readout circuitry, in photon equivalents
opts.scope.brightness = 10; %average photons per pulse, per pixel, across the mask, at a dF/F0 of 0. This is ~0.5 photons/pulse for typical 2p imaging. We should be able to increase by a factor of ~35, because we deliver pulses ~80x slower.

%Debugging options:
opts.debug.magic_align = true; %just give the correct motion parameters to the reconstruction algorithm
opts.debug.nonoise = false; % set all noise to 0



Ps = [2 4]; %projection types to simulate
Bs = [1 5 10 20]; %brightness levels to simulate

opts.simname = 'ProjectionTypesAndBrightness';
Pcorrs = cell(length(Ps), length(Bs));
for p_ix = 1:length(Ps)
    opts.Ptype = [int2str(Ps(p_ix)) 'lines'];
for B_ix=1:length(Bs)
    opts.scope.brightness = Bs(B_ix);
    [ground_truth, M, obs, recon, opts] = simulate_scope(opts);
    Pcorrs{p_ix,B_ix} = recon_performance(ground_truth, M, obs, recon, opts);
end

mean_corr = cellfun(@mean, Pcorrs);
err_corr = cellfun(@(x)(std(x)./sqrt(length(x))), Pcorrs);

keyboard
end