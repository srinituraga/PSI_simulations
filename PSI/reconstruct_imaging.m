function R = reconstruct_imaging(obs,opts)
%Estimates the intensity pattern of the sample given the observations
switch opts.Ptype
    case '4lines'
        %the expected projection:
        EXP = obs.IM(:)'*opts.P; %Expected data. In final form, this will take into account the dF/F0 in previous frame, etc.
        
        %segment the morphological image
        disp('     Segmenting morphological image...')
        R.SEG = segment_2D(obs.IM, opts);
        
        %extize variables for fitting
        R.S = zeros(size(R.SEG.seg,2), opts.nframes);
        dX_est = zeros(1, opts.nframes);
        dY_est = zeros(1, opts.nframes);
        maxlag = 2*opts.motion.limit; %maximum xy motion we're willing to correct, in pixels
        for frame = 1:opts.nframes
            %Register the projections roughly by cross-correlation
            %This is sensitive to edge effects and cannot take into account
            %variations in intensity across the FOV. 
            %We'll come up with a better method soon, i.e. maximum likelihood over photon counts
            
            %MAXIMUM LIKELIHOOD:
            %gradient descent in likelihood function starting at 0 motion
            %and same dF/F0 as previous timepoint
            %penalize rapid decreases in dF/F0 and very large increases
            %penalize rapid acceleration
            %use Poisson photon statistics
            
            XC = zeros(4,2*maxlag+1);
            for ax = 1:4 %for each projection axis
                ax_ixs = (ax-1)*opts.R + 1:ax*opts.R; %the data indices that correspond to this axis
                XC(ax,:) = xcorr(obs.data_in(ax_ixs,frame),EXP(ax_ixs), maxlag); %compute crosscorrelation
                XC(ax,:) = XC(ax,:)./mean(XC(ax,:)); %normalize to mean over a set displacement
                if ax>2
                    %resample to account for indexing scheme below
                    F = griddedInterpolant(sqrt(2)*(-maxlag:maxlag), XC(ax,:));
                    XC(ax,:) = F(-maxlag:maxlag);
                end
            end
            
            %for each pair of Xshift and Yshift, compute the sum of the
            %relevant xcorr functions, to produce a 2d objective function:
            [Xshift, Yshift] = meshgrid(-maxlag/2:maxlag/2);
            REG = XC(1,Xshift+maxlag+1) + XC(2, Yshift+maxlag+1) + XC(3, Xshift-Yshift+maxlag+1) + XC(4, -Xshift-Yshift+maxlag+1);
            [~, maxix] = max(REG);
            
            dX_est(frame) = Xshift(maxix);
            dY_est(frame) = Yshift(maxix);
            
            if opts.debug.magic_align
                disp('       Magic align:')
                disp(['        [dX_est dX]: [' num2str(dX_est(frame))  ' ' int2str(round(opts.debug.GT.motion.pos(1,frame))) ']'] )
                disp(['        [dY_est dY]: [' num2str(dY_est(frame))  ' ' int2str(round(opts.debug.GT.motion.pos(2,frame))) ']'] )
                dX_est(frame) = round(opts.debug.GT.motion.pos(1,frame));
                dY_est(frame) = round(opts.debug.GT.motion.pos(2,frame));
            end
            
            %Now do reconstruction
            shifted = apply_motion(obs.IM, [dX_est, dY_est]);
            shiftedBW = apply_motion(R.SEG.bw, [dX_est, dY_est]);
            
            %background intensity
            BG = shifted;
            BG(shiftedBW) = 0;
            
            %Note: we may want to estimate the background intensity with an
            %additional variable-
            %currently background is treated as static intensity. This
            %leaves a small challenge of predicting from the initial
            %morphology image what the photon counts will be in the fast
            %imaging, to subtract correctly. Solution to this will probably
            %be to estimate the scale factor by treating the background as
            %just another seed region (at least for a first pass of
            %estimation)
            
            %background subtracted data:
            D_bs = obs.data_in(:,frame) - opts.P'*BG(:);
           
            %We want to perform a matrix division with the #datapoints x #seeds matrix, but we have
            %to build that matrix first; kinda tricky, because the normal approach would involve
            %going through an npixels x npixels matrix to apply the motion. We'll apply
            %the motion with some vectorized code over a 3d array, apply_motion
            
            %for every seed, we need a map of that seed onto the shifted
            %mask pixels via the function apply_motion
            disp('     Computing inverse...')
            IM_seg = zeros(size(obs.IM,1),size(obs.IM,2), size(R.SEG.seg,2));%extize
            IM_seg(repmat(R.SEG.bw,1,1,size(R.SEG.seg,2))) = R.SEG.seg; %IM_seg is a BIG matrix. no better general way? make sparse?
            IM_seg = apply_motion(IM_seg, [dX_est, dY_est]); %IM_seg, shifted
            P_shift = opts.P' * reshape(IM_seg, [size(IM_seg,1)*size(IM_seg,2), size(R.SEG.seg,2)]);
 
            %estimate using pseudoinverse
            %P_inv = pinv(P_shift);
            %S = P_inv*D_bs;
             
            %estimate with nonnegative constraint
            R.S(:,frame) = lsqnonneg(P_shift, D_bs); %S is the estimate of the seed intensities
        end
        R.dX = dX_est; R.dY = dY_est;
    otherwise
        error('Invalid projection method');
end
end