function varargout = sfp_imana(what, varargin)
% function varargout = sfp_imana(what, varargin)
%
% Code for data analysis of fMRI dataset on motor planning of single finger
% movements. Produces the figures in the biorxiv "Motor planning brings
% human primary somatosensory cortex into action-specific preparatory
% states" by Ariani, Pruszynski, Diedrichsen (2021).
%
% last edit: 2021.05.23 - gariani@uwo.ca

% ------------------------- General info ----------------------------------
base_dir = '../data/';
surf_dir = [base_dir '/surf'];
ROI_name = {'S1_LH', 'M1_LH', 'SPLa_LH'};
subj_vec = [1:10, 12:23];
% ------------------------- Plotting sty ----------------------------------
% colors
cbs_red = [213 94 0]/255;
cbs_blue = [0 114 178]/255;
red = [222,45,38]/255;
darkgray = [50,50,50]/255;
gray = [150,150,150]/255;
black = [0,0,0]/255;
% defaults
fs = 28;
lw = 6;
ms = 12;
% styles
forcesty = style.custom({cbs_red, cbs_blue}, 'markertype','none', 'linewidth',lw, 'errorcolor',gray, 'errorbars','shade');
ts_sing = style.custom({cbs_red, cbs_blue}, 'markertype','none', 'linewidth',lw, 'linestyle','-');
pcmsty = style.custom({darkgray}, 'markertype','none', 'markersize',ms, 'linewidth',lw, 'errorbars','shade');
pcmsty2 = style.custom({darkgray}, 'sizedata',200, 'markersize',ms, 'linewidth',lw, 'errorbars','shade');
pcmsty3 = style.custom({red}, 'linewidth',2);
%legends
condleg = {'plan single', 'exe single'};
corrleg = {'SINGLE: plan-exe'};

% ------------------------- Analysis Cases --------------------------------
switch(what)
    case 'timeseries' % Fig 1B
        % ----------------------------------------------------------------
        % Plot BOLD timeseries for selected regions of interest (ROIs)
        roi = [2,3];
        vararginoptions(varargin, {'roi'});
        
        for r = 1:numel(roi)
            % Load data
            fname = fullfile(base_dir, sprintf('BOLD_timeseries-%s.mat', ROI_name{roi(r)}) );
            T = load(fname);
            pt = unique(T.prepTime);
            % Plot timeseries
            figure('Name',sprintf('ROI: %s timeseries', ROI_name{roi(r)})); set(gcf, 'Units','normalized', 'Position',[0.1,0.1,0.8,0.8], 'Resize','off', 'Renderer','painters');
            for ip = 1:numel(pt)
                subplot(1,3,ip);
                plt.trace(-T.pre:T.post, T.y_adj, 'split',[T.exeType], 'style',ts_sing, 'subset',T.prepTime==pt(ip), 'leg',{'No-go', 'Go'});
                xlabel('TR (sec)'); ylabel('Activity (a.u.)');
                xlim([-1 21]);
                ylim([-2 5]);
                axis square;
            end
            
            % Add cosmetics
            plt.match('y');
            for ip = 1:numel(pt)
                subplot(1,3,ip);
                drawline(0, 'dir','vert'); drawline(pt(ip), 'dir','vert'); drawline(0, 'dir','horz'); title(sprintf('Prep-time: %ds',pt(ip))); set(gca, 'fontsize',fs);
            end
        end
        
        % Return output
        varargout = {T};
    case 'profiles' % Fig 2EF
        % ----------------------------------------------------------------
        % Plot either activity (PSC) or distance profiles from surface maps
        hem   = {'L', 'R'}; % hemisphere: 1=LH 2=RH
        map   = 'psc'; % 'psc' or 'dist'
        % Specify virtual cross-section strip (start/end coords + width)
        from  = {[-43 86], [-87 43]}; % flat map (2D) coordinates in format: {[LH_x-start LH_y-start], [RH_x-start RH_y-start]}
        to    = {[87 58], [43 75]}; % flat map (2D) coordinates in format: {[LH_x-end   LH_y-end],   [RH_x-end   RH_y-end]}
        width = 20; % width (in mm) of the sampling along each side of the provided border or virtual line
        n_pts = abs(from{1}(1)-to{1}(1)); %Number of points on for the sampling on the virtual strip
        surf  = '164'; % 164k or 32k vertices
        stats = 0; % flag to indicate whether to calculate ROI-like stats or not
        vararginoptions(varargin,{'map', 'from', 'to', 'width', 'n_pts', 'surf', 'stats'});
        con = {'Planning', 'Execution'}; % conditions of interest
        nc  = numel(con);
        for h=1
            % open figure
            figure('Name', sprintf('Activity profile (%s) N=%02d', map, numel(subj_vec))); set(gcf, 'Units','normalized', 'Position',[0.1,0.1,0.8,0.8], 'Resize','off', 'Renderer','painters');
            surface = fullfile(surf_dir, sprintf('fs_LR.%sk.%s.flat.surf.gii', surf, hem{h}));
            
            T = [];
            mmetric_pmd = zeros(1);
            mmetric_m1 = zeros(1);
            mmetric_s1 = zeros(1);
            mmetric_spl = zeros(1);
            for c=1:nc
                % Select data
                fn = fullfile(surf_dir, sprintf('group.%s.%s.%s.func.gii', map, hem{h}, con{c}));
                
                % Perform cross-section (extract profile data)
                [Y, ~, coord] = surf_cross_section(surface, fn, 'from',from{h}, 'to',to{h}, 'width',width, 'n_point',n_pts);
                D.y  = Y';
                D.c  = ones(size(D.y, 1),1) * c;
                D.SN = subj_vec';
                T    = addstruct(T, D);
                
                % Perform stats (optional)
                if h==1 && stats==1
                    % Calc mean metric for this contrast and all ROIs
                    mmetric_pmd(:,c) = nanmean(Y(coord(:,1)>=-30 & coord(:,1)<0, :))';
                    mmetric_m1(:,c)  = nanmean(Y(coord(:,1)>=0 & coord(:,1)<17, :))';
                    mmetric_s1(:,c)  = nanmean(Y(coord(:,1)>=17 & coord(:,1)<46, :))';
                    mmetric_spl(:,c) = nanmean(Y(coord(:,1)>=46 & coord(:,1)<69, :))';
                    
                    % Within contrast t-tests
                    fprintf(1, '%s: %s vs zero\n', 'L-PMd', con{c});
                    ttest(mmetric_pmd(:,c), 0, 2, 'onesample');
                    fprintf(1, '\n');
                    fprintf(1, '%s: %s vs zero\n', 'L-M1', con{c});
                    ttest(mmetric_m1(:,c), 0, 2, 'onesample');
                    fprintf(1, '\n');
                    fprintf(1, '%s: %s vs zero\n', 'L-S1', con{c});
                    ttest(mmetric_s1(:,c), 0, 2, 'onesample');
                    fprintf(1, '\n');
                    fprintf(1, '%s: %s vs zero\n', 'L-aSPL', con{c});
                    ttest(mmetric_spl(:,c), 0, 2, 'onesample');
                    fprintf(1, '\n');
                    fprintf(1, '%s: L-S1 vs L-M1\n', con{c});
                    ttest(mmetric_s1(:,c), mmetric_m1(:,c), 2, 'paired');
                    fprintf(1, '\n');
                    
                    if c>1 && nc==2
                        % Perform 2-by-2 ANOVA (S1 vs M1 x plan vs exe)
                        A.metric = [mmetric_s1(:,1); mmetric_s1(:,2); mmetric_m1(:,1); mmetric_m1(:,2)];
                        A.SN = repmat((1:numel(subj_vec))', 4, 1);
                        A.phase = repmat( [ones(numel(subj_vec),1); ones(numel(subj_vec),1)*2], 2, 1);
                        A.roi = ceil( (1:numel(A.metric)) ./ numel(subj_vec)/2 )';
                        fprintf(1, '2-by-2 ANOVA: Region (L-S1, L-M1) vs Phase (plan, exe)\n');
                        T.ANOVA = anovaMixed(A.metric, A.SN,'within', [A.phase, A.roi], {'phase','roi'});
                        fprintf(1, '\n');
                    end
                end
            end
            
            % Plot the profiles
            T.x=coord(:,1);
            plt.trace(T.x, T.y, 'split',T.c, 'style',ts_sing, 'leg',con);
            ylabel(sprintf('Mean %s', map)); xlabel('Spatial coord');
            xlim([min(T.x), max(T.x)]);
            set(gca,'fontsize',fs);
            
            % Add cosmetics
            drawline(0, 'dir','horz'); % baseline
            drawline(-15,'dir','vert'); drawline(16,'dir','vert'); drawline(54,'dir','vert'); % 3 main sulci
            drawline(-30,'dir','vert', 'linestyle',':'); % PMd - start
            drawline(0,'dir','vert', 'linestyle',':'); % M1 - start
            drawline(45,'dir','vert', 'linestyle',':'); % S1 - end
            drawline(69,'dir','vert', 'linestyle',':'); % aSPL - end
            title(sprintf('%s %s', map, hem{h}))
        end
        
        % Return output
        varargout = {T};
    case 'force_avg' % Fig 3A
        % ----------------------------------------------------------------
        % Plot binned and averaged group finger-force data
        bin_size = 100; % in ms
        vararginoptions(varargin, {'bin_size'});
        
        % Load group force data
        fname = fullfile(base_dir, sprintf('force_data-group-%dms.mat', bin_size) );
        S = load(fname);
        
        % Create summary table across subjects
        D0 = [];
        D1 = [];
        D2 = [];
        for s = subj_vec
            PP = getrow(S.pre, S.pre.SN==s);
            P = getrow(S.plan, S.plan.SN==s);
            E = getrow(S.exe,  S.exe.SN==s);
            %pre-cue
            T0 = tapply(PP, {'preT_bin', 'finger', 'seqNum', 'exeType'},...
                {PP.pre, 'nanmean', 'name','preF'},...
                'subset', ismember(PP.finger,[1,3,5]) & ismember(PP.seqNum,[1,2,3]));
            T0.SN = ones(numel(T0.preF),1)*s;
            %plan
            T1 = tapply(P, {'prepTime_bin', 'finger', 'seqNum', 'exeType'},...
                {P.PF, 'nanmean', 'name','PF'},...
                'subset', ismember(P.finger,[1,3,5]) & ismember(P.seqNum,[1,2,3]));
            T1.SN = ones(numel(T1.PF),1)*s;
            %exe
            T2 = tapply(E, {'exeTime_bin', 'finger', 'seqNum', 'exeType'},...
                {E.EF, 'nanmean', 'name','EF'},...
                'subset', ismember(E.finger,[1,3,5]) & ismember(E.seqNum,[1,2,3]));
            T2.SN = ones(numel(T2.EF),1)*s;
            D0 = addstruct(D0, T0);
            D1 = addstruct(D1, T1);
            D2 = addstruct(D2, T2);
        end
        
        PP1 = tapply(D0, {'SN', 'preT_bin', 'exeType'},...
            {D0.preF, 'nanmean', 'name','preF'}, 'subset',D0.seqNum==1 & D0.finger==1);
        P1 = tapply(D1, {'SN', 'prepTime_bin', 'exeType'},...
            {D1.PF, 'nanmean', 'name','PF'}, 'subset',D1.seqNum==1 & D1.finger==1);
        E1 = tapply(D2, {'SN', 'exeTime_bin', 'exeType'},...
            {D2.EF, 'nanmean', 'name','EF'}, 'subset',D2.seqNum==1 & D2.finger==1);
        
        PP2 = tapply(D0, {'SN', 'preT_bin', 'exeType'},...
            {D0.preF, 'nanmean', 'name','preF'}, 'subset',D0.seqNum==2 & D0.finger==3);
        P2 = tapply(D1, {'SN', 'prepTime_bin', 'exeType'},...
            {D1.PF, 'nanmean', 'name','PF'}, 'subset',D1.seqNum==2 & D1.finger==3);
        E2 = tapply(D2, {'SN', 'exeTime_bin', 'exeType'},...
            {D2.EF, 'nanmean', 'name','EF'}, 'subset',D2.seqNum==2 & D2.finger==3);
        
        PP3 = tapply(D0, {'SN', 'preT_bin', 'exeType'},...
            {D0.preF, 'nanmean', 'name','preF'}, 'subset',D0.seqNum==3 & D0.finger==5);
        P3 = tapply(D1, {'SN', 'prepTime_bin', 'exeType'},...
            {D1.PF, 'nanmean', 'name','PF'}, 'subset',D1.seqNum==3 & D1.finger==5);
        E3 = tapply(D2, {'SN', 'exeTime_bin', 'exeType'},...
            {D2.EF, 'nanmean', 'name','EF'}, 'subset',D2.seqNum==3 & D2.finger==5);
        
        % Do the plotting
        figure('Name', sprintf('Group force data N=%02d', numel(subj_vec))); set(gcf, 'Units','normalized', 'Position',[0.1,0.1,0.8,0.8], 'Resize','off', 'Renderer','painters');
        subplot(311)
        plt.line(PP1.preT_bin/(1000/bin_size), PP1.preF, 'split',PP1.exeType, 'style',forcesty); hold on;
        plt.line(P1.prepTime_bin/(1000/bin_size), P1.PF, 'split',P1.exeType, 'style',forcesty); hold on;
        plt.line(E1.exeTime_bin/(1000/bin_size), E1.EF, 'split',E1.exeType, 'style',forcesty);
        xticks('auto');
        xlabel('Time (sec)'); ylabel('Avg force (N)');
        set(gca,'fontsize',fs, 'fontname','helvetica');
        xlim([-0.5 11.5])
        ylim([-0.1 1.6])
        drawline(0, 'dir','horz', 'linestyle','-');
        drawline(0, 'dir','vert', 'linestyle',':');
        drawline([4,6,8], 'dir','vert', 'linestyle','--');
        drawline(1, 'dir','horz', 'linestyle','-');
        
        subplot(312)
        plt.line(PP2.preT_bin/(1000/bin_size), PP2.preF, 'split',PP2.exeType, 'style',forcesty); hold on;
        plt.line(P2.prepTime_bin/(1000/bin_size), P2.PF, 'split',P2.exeType, 'style',forcesty); hold on;
        plt.line(E2.exeTime_bin/(1000/bin_size), E2.EF, 'split',E2.exeType, 'style',forcesty);
        xticks('auto');
        xlabel('Time (sec)'); ylabel('Avg force (N)');
        set(gca,'fontsize',fs, 'fontname','helvetica');
        xlim([-0.5 11.5])
        ylim([-0.1 1.6])
        drawline(0, 'dir','horz', 'linestyle','-');
        drawline(0, 'dir','vert', 'linestyle',':');
        drawline([4,6,8], 'dir','vert', 'linestyle','--');
        drawline(1, 'dir','horz', 'linestyle','-');
        
        subplot(313)
        plt.line(PP3.preT_bin/(1000/bin_size), PP3.preF, 'split',PP3.exeType, 'style',forcesty); hold on;
        plt.line(P3.prepTime_bin/(1000/bin_size), P3.PF, 'split',P3.exeType, 'style',forcesty); hold on;
        plt.line(E3.exeTime_bin/(1000/bin_size), E3.EF, 'split',E3.exeType, 'style',forcesty);
        xticks('auto');
        xlabel('Time (sec)'); ylabel('Avg force (N)');
        set(gca,'fontsize',fs, 'fontname','helvetica');
        xlim([-0.5 11.5])
        ylim([-0.1 1.6])
        drawline(0, 'dir','horz', 'linestyle','-');
        drawline(0, 'dir','vert', 'linestyle',':');
        drawline([4,6,8], 'dir','vert', 'linestyle','--');
        drawline(1, 'dir','horz', 'linestyle','-');
    case 'force_trial' % Fig 3B
        % ----------------------------------------------------------------
        % Plot single-trial finger force traces from example participant
        sn = 15;
        vararginoptions(varargin, {'sn'});
        
        % Load data for this participant
        D = dload( fullfile(base_dir, sprintf('force_data-s%02d.dat', sn)) );
        MOV = movload( fullfile(base_dir, sprintf('force_data-s%02d-b%02d.mov', D.SN(1,1), D.BN(1,1)))); %load MOV file
        
        % Select trial(s)
        for t = 4
            mov1    = MOV{t};
            mov2    = MOV{t+1};
            mov12   = [mov1; mov2];
            time    = [mov1(:,3)-mov1(end,3); mov2(:,3)]/1000;
            force   = smooth_kernel(mov12(:, [9,10,11,12,13]), 4);
            
            % Plot trial
            figure('Name', 'Example trial'); set(gcf, 'Units','normalized', 'Position',[0.1,0.1,0.8,0.8], 'Resize','off', 'Renderer','painters');
            plot(time,force,'LineWidth',lw);
            title('Force traces for RIGHT hand presses','FontSize',fs, 'FontName','Helvetica');
            xlabel('Time (sec)'); ylabel('Force (N)'); set(gca,'FontSize',fs, 'FontName','Helvetica');
            legend({'Thumb', 'Index', 'Middle', 'Ring', 'Little'},'FontSize',fs, 'FontName','Helvetica', 'Location','North');
            xlim([-0.5 D.prepTime(t+1)/1000+D.MT(t+1)/1000+0.5])
            ylim([-0.5 4])
            drawline(0, 'dir','vert', 'linestyle',':');
            drawline(D.prepTime(t+1)/1000, 'dir','vert', 'linestyle','--');
            drawline(0, 'dir','horz', 'linestyle','-.');
            drawline(0.5, 'dir','horz', 'linestyle','-.');
            drawline(1, 'dir','horz', 'linestyle','-');
            drawline(D.prepTime(t+1)/1000+D.RT(t+1)/1000, 'dir','vert', 'linestyle','-');
            drawline(D.prepTime(t+1)/1000+D.MT(t+1)/1000, 'dir','vert', 'linestyle','-');
            axis square;
        end
    case 'dist_corr' % Fig 3CD
        % ----------------------------------------------------------------
        % Plot corr between neural (roi) and behavioral (force) distances
        sn  = subj_vec;
        roi = [2,1];
        parcelType = 'Brodmann'; % '162tessels' or 'Brodmann'
        betaChoice = 'multi_pw'; % 'uni_pw', 'multi_pw' or 'raw'
        bin_size = 100; % in ms
        vararginoptions(varargin, {'sn', 'roi', 'parcelType', 'betaChoice', 'bin_size'});
        
        % Load behav force distance data
        b_fname = fullfile(base_dir, sprintf('dist_force-%dms.mat', bin_size)); % includes both avg finger force and SD of finger force for each trial phase (plan/exe)
        F = load(b_fname);
        
        % Load ROI neural distance data
        d_fname = fullfile(base_dir, sprintf('dist_roi-%s-%s.mat', parcelType, betaChoice));
        D = load(d_fname);
        
        % Summarize data
        nRois       = numel(roi);
        nSubs       = numel(sn);
        nSeqTypes   = numel(unique(D.seqType(D.seqType>0)));
        nPhases     = numel(unique(D.phase(D.phase>0)));
        S = struct();
        for s = 1 : nSubs
            for r = 1 : nRois
                T.cond = 0;
                for st = 1 : nSeqTypes
                    for ph = 1 : nPhases
                        R           = getrow(D, (D.SN == subj_vec(s) & D.region==roi(r)) );
                        ind         = false(12); ind(R.phase==ph & R.seqType==st, R.phase==ph & R.seqType==st) = true;
                        T.avg_dist  = nanmean( R.RDM(tril(ind,-1)) );
                        T.SN        = subj_vec(s);
                        T.ROI       = roi(r);
                        T.seqType   = st;
                        T.phase     = ph;
                        T.cond      = T.cond + 1;
                        S           = addstruct(S, T);
                    end
                end
            end
        end
        condvec = [1,2];
        
        % Plot correlation between behav dist and neural dist
        figure('Name', sprintf('Corr between distances N=%02d', nSubs)); set(gcf, 'Units','normalized', 'Position',[0.1,0.1,0.8,0.8], 'Resize','off', 'Renderer','painters');
        count = 1;
        for c = condvec
            for r = roi
                N = tapply(S, {'SN'}, {S.avg_dist, 'nanmean', 'name','dist'}, 'subset',S.cond==c & S.ROI==r);
                B = tapply(F, {'SN'}, {F.avgDist_uw, 'nanmean', 'name','dist'}, 'subset',F.ct==c);
                subplot(numel(condvec),numel(roi),count);
                if c == 1 || c == 3
                    distcorrsty = style.custom({cbs_red}, 'linewidth',lw, 'sizedata',200);
                else
                    distcorrsty = style.custom({cbs_blue}, 'linewidth',lw, 'sizedata',200);
                end
                [O.r2{c,r}, O.b{c,r}, O.t{c,r}, O.p{c,r}] = plt.scatter(B.dist, N.dist, 'style',distcorrsty, 'regression','linear');
                hold on; drawline(0, 'dir','vert', 'linestyle',':'); drawline(0, 'dir','horz', 'linestyle',':'); hold off;
                xlabel('Behavioral distance (finger forces)'); ylabel('Neural distance (voxel activity)'); set(gca,'fontsize',fs);
                title(sprintf('%s %s',condleg{c}, ROI_name{r}));
                count = count + 1;
            end
        end
        
        % Return output
        varargout={O};
    case 'RDM_MDS' % Fig 4ABC
        % ----------------------------------------------------------------
        % Plot representational dissimilarity matrices (RDM) and the
        % corresponding multi-dimensional scaling (MDS) for selected ROIs
        sn  = subj_vec;
        roi = [2,1];
        vararginoptions(varargin, {'sn', 'roi'});
        nroi=numel(roi);
        figure('Name', sprintf('RDM and MDS N=%02d', numel(sn)));
        set(gcf, 'Units','normalized', 'Position',[0.1,0.1,0.8,0.8], 'Resize','off', 'Renderer','painters');
        
        for r=1:nroi
            % Load data
            fname = fullfile(base_dir, sprintf('PCM-group_data-%s.mat', ROI_name{roi(r)}));
            load(fname, 'G_hat');
            Gm = mean(G_hat,3); % mean estimate across subjs
            nConds = size(Gm,1);
            H = eye(nConds)-ones(nConds)/nConds; % centering matrix
            Gc = H*Gm*H'; % centered second moment matrix
            C = pcm_indicatorMatrix('allpairs', 1:nConds);
            RDM = squareform(diag(C*Gc*C'));
            [Y0, ~] = pcm_classicalMDS(Gc);
            [Y1, ~] = pcm_classicalMDS(Gc);
            
            % Style setup
            spl = [zeros(3,1); ones(3,1)];
            colors = {cbs_red, cbs_blue};
            label = {'1', '3', '5', '1', '3', '5'};
            ms = 12;
            ls = 20;
            lw = 3;
            
            % Do the plotting of RDM
            subplot(3,nroi,r);
            imagesc(RDM, [0 0.3]);
            colorbar;
            axis image;
            title( sprintf('%s', ROI_name{roi(r)})); set(gca,'fontsize',fs);
            
            % Do the plotting of MDS
            subplot(3,nroi,nroi+r);
            % 3D scatter plot
            scatterplot3(Y0(1:end,1),Y0(1:end,2),Y0(1:end,3),'split',spl, 'markersize',ms, 'markercolor',colors, 'markerfill',colors, 'label',label, 'labelcolor',colors, 'labelsize',ls);
            % link the single digit points for clarification
            indx=[1:3 1]';
            line(Y0(indx,1),Y0(indx,2),Y0(indx,3),'color',colors{1}, 'linewidth',lw);
            hold on
            indx=[4:6 4]';
            line(Y0(indx,1),Y0(indx,2),Y0(indx,3),'color',colors{2}, 'linewidth',lw);
            % rest crosshairs
            grid off
            hold on; plot3(0,0,0,'+','MarkerFaceColor',black,'MarkerEdgeColor',black,'MarkerSize',ms+3, 'LineWidth',lw);
            hold off; xlabel('PC 1'); ylabel('PC 2'); zlabel('PC 3'); set(gca,'fontsize',fs);
            axis equal
            
            % Do the plotting of MDS
            subplot(3,nroi,nroi*2+r);
            scatterplot3(Y1(1:end,1),Y1(1:end,2),Y1(1:end,3),'split',spl, 'markersize',ms, 'markercolor',colors, 'markerfill',colors, 'label',label, 'labelcolor',colors, 'labelsize',ls);
            % link the single digit points for clarification
            indx=[1:3 1]';
            line(Y1(indx,1),Y1(indx,2),Y1(indx,3),'color',colors{1}, 'linewidth',lw);
            hold on
            indx=[4:6 4]';
            line(Y1(indx,1),Y1(indx,2),Y1(indx,3),'color',colors{2}, 'linewidth',lw);
            % rest crosshairs
            grid off
            hold on; plot3(0,0,0,'+','MarkerFaceColor',black,'MarkerEdgeColor',black,'MarkerSize',ms+3, 'LineWidth',lw);
            hold off; xlabel('PC 1'); ylabel('PC 2'); zlabel('PC 3'); set(gca,'fontsize',fs);
            axis equal
        end
    case 'PCM_corr' % Fig 4D
        % ----------------------------------------------------------------
        % Plot log-likelihood results for different PCM correlation models
        % in selected ROIs
        roi = [2,1];
        vararginoptions(varargin, {'roi'});
        
        % Load data
        fname = fullfile(base_dir, 'PCM-corr_models.mat');
        load(fname, 'O');
        
        % Open figure
        figure('Name', 'Corr-analysis results per ROI'); set(gcf, 'Units','normalized', 'Position',[0.1,0.1,0.8,0.8], 'Resize','off', 'Renderer','painters');
        t = zeros(1); p = zeros(1);
        
        for r = 1:numel(roi)
            % Do the plotting
            subplot(1,numel(roi),r);
            [~,~] = plt.trace(O{roi(r)}.corrmodels, O{roi(r)}.Lwom, 'style',pcmsty, 'leg',corrleg, 'leglocation','northwest');
            xticks(0:0.1:1);
            ylim([-13 7]);
            xlim([-0.1 1.1]);
            title(sprintf('%s', ROI_name{roi(r)}));
            
            % Add individual data points
            [~, idx] = max(O{roi(r)}.Lwom, [], 2);
            wm = O{roi(r)}.corrmodels(idx);
            hold on;
            plt.scatter(wm', -6 + 1.*randn(22,1), 'style',pcmsty2, 'regression','none');
            hold on;
            plt.hist(wm', 'style',pcmsty3, 'percent',0, 'numcat',1000);
            ylim([-13 15]);
            xlim([-0.1 1.1]);
            wm_mean = nanmean(wm);
            wm_sem = std(wm)/sqrt(length(wm));
            wm_t = tinv([0.025  0.975],length(wm)-1); % T-score
            wm_ci = wm_mean + wm_t*wm_sem; % 95% confidence intervals
            drawline(wm_mean, 'dir','vert', 'linestyle','-');
            drawline(wm_ci, 'dir','vert', 'linestyle',':');
            
            % Perform cross-val stats on corr models for multiple ROIs
            TT = [];
            R = O{roi(r)};
            for s = 1:numel(R.SN)
                % Use training data to find the peak
                [~, peak_ind] = max( mean(R.Lwom(R.SN~=s, :),1), [], 2);
                
                % Read the log bayes factor from left-out test data
                T.Lwom(1,1) = R.Lwom(R.SN==s, peak_ind);
                T.model(1,1) = peak_ind;
                T.model_corr(1,1) = R.corrmodels(peak_ind);
                T.SN(1,1) = s;
                T.ROI(1,1) = roi(r);
                
                TT = addstruct(TT, T);
            end
            
            % Perform stats
            for m = 1:size(R.Lwom,2)
                [t(m,r), p(m,r)] = ttest(TT.Lwom, R.Lwom(:,m), 1, 'paired');
            end
            
            % Add cosmetics
            sig_cm = R.corrmodels(p(:,r)>0.05);
            drawline(sig_cm(1), 'dir','vert', 'linestyle','--');
            drawline(sig_cm(end), 'dir','vert', 'linestyle','--');
            hold on;
            plt.scatter(sig_cm', ones(numel(sig_cm),1)*5, 'style',pcmsty2, 'regression','none');
            xlabel('Correlation models'); ylabel('Log-model evidence relative to avg log-model evidence)'); set(gca,'fontsize',fs); %axis square;
            
            % Print out results on command window
            fprintf('Region %s:\n', ROI_name{roi(r)});
            fprintf('Winning model: %2.3f ? %2.3f\n', wm_mean, wm_sem);
            fprintf('Winning model vs zero, t: %2.3f   p-val: %2.4f\n', t(1,r), p(1,r));
            fprintf('Winning model vs one,  t: %2.3f   p-val: %2.4f\n', t(end,r), p(end,r));
            fprintf('Last sig model: %2.3f  t: %2.3f   p-val: %2.4f\n', sig_cm(1), t(R.corrmodels==sig_cm(1),r), p(R.corrmodels==sig_cm(1),r));
            fprintf('\n');
        end
    otherwise
        fprintf('%s: no such case.\n',what)
end
end
