function summaryTbl = compare_ablation_paper(modelList, labels, layoutMode)
%COMPARE_ABLATION_PAPER Layer-wise ablation comparison against M1.
%
% This comparison is intentionally not a single generic metric plot.
% Each baseline is compared with M1 Proposed using the signal that best
% exposes the ablated layer:
%   M2: observer recovery after the topology switch
%   M3: formation/guidance tracking after fixed assignment
%   M4: PPC violation and saturation demand under rigid bounds
%
% Outputs:
%   figures_OE/Comparison_Ablation/FigC1_Observer_M1_vs_M2.*
%   figures_OE/Comparison_Ablation/FigC2_Guidance_M1_vs_M3.*
%   figures_OE/Comparison_Ablation/FigC3_RigidPPC_M1_vs_M4.*
%   figures_OE/Comparison_Ablation/FigC4_Ablation_Summary.*
%   sim_results/ablation_compare_summary.csv
%   sim_results/ablation_compare_summary.mat

    if nargin < 1 || isempty(modelList)
        modelList = {'abl_M1_proposed', ...
                     'abl_M2_fixedObserver', ...
                     'abl_M3_fixedGuidance', ...
                     'abl_M4_rigidPPC'};
    end
    if nargin < 2 || isempty(labels)
        labels = {'M1 Proposed', ...
                  'M2 Fixed-gain observer', ...
                  'M3 Fixed-assignment guidance', ...
                  'M4 Rigid PPC'};
    end
    if nargin < 3 || isempty(layoutMode)
        layoutMode = 'pairwise';
    end

    outDir = fullfile('figures_OE', 'Comparison_Ablation');
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end
    if ~exist('sim_results', 'dir')
        mkdir('sim_results');
    end

    set(groot, 'defaultFigureVisible', 'off');
    set_plot_defaults();

    colors = [0.000, 0.447, 0.741;
              0.850, 0.325, 0.098;
              0.466, 0.674, 0.188;
              0.494, 0.184, 0.556];
    styles = {'-', '--', '-.', ':'};

    data = load_ablation_case(modelList{1}, labels{1});
    data(numel(modelList), 1) = data;
    for k = 2:numel(modelList)
        data(k) = load_ablation_case(modelList{k}, labels{k});
    end

    summaryTbl = build_summary_table(data);
    writetable(summaryTbl, fullfile('sim_results', 'ablation_compare_summary.csv'));
    save(fullfile('sim_results', 'ablation_compare_summary.mat'), ...
        'data', 'summaryTbl', 'modelList', 'labels');

    if strcmpi(layoutMode, 'compact')
        plot_ablation_threepanel(data, colors, styles, outDir);
        plot_overall_profile(summaryTbl, colors, outDir);
    else
        plot_observer_pair(data, colors, styles, outDir);
        plot_guidance_pair(data, colors, styles, outDir);
        plot_rigid_ppc_pair(data, colors, styles, outDir);
        plot_ablation_summary(summaryTbl, colors, outDir);
    end

    fprintf('Ablation comparison generated in %s\n', outDir);
    disp(summaryTbl);
end

%% ========================= plotting =========================
function plot_observer_pair(data, colors, styles, outDir)
    fig = figure('Name', 'M1 vs M2 observer', 'Units', 'centimeters', ...
        'Position', [2, 2, 16.8, 10.2]);
    ax = axes(fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); style_axes(ax);
    win = data(1).t >= 45 & data(1).t <= 70;
    plot(ax, data(1).t(win), data(1).obsMaxActive(win), ...
        'Color', colors(1,:), 'LineStyle', styles{1}, 'LineWidth', 2.2, ...
        'DisplayName', 'M1 Proposed');
    plot(ax, data(2).t(win), data(2).obsMaxActive(win), ...
        'Color', colors(2,:), 'LineStyle', styles{2}, 'LineWidth', 2.2, ...
        'DisplayName', 'M2 Fixed-gain observer');
    xline(ax, data(1).switchTime, '-.', 'Color', [0.15 0.15 0.15], ...
        'LineWidth', 1.0, 'HandleVisibility', 'off');
    xlabel(ax, 'Time (s)'); ylabel(ax, 'Max active observer error (m)');
    title(ax, '(a) Observer recovery after topology switch', 'FontWeight', 'normal');
    xlim(ax, [45 70]); ylim(ax, [0 0.25]);
    legend(ax, 'Location', 'northeast', 'Box', 'off');
    save_compare_fig(fig, outDir, 'FigC1_Observer_M1_vs_M2');
end

function plot_guidance_pair(data, colors, styles, outDir)
    fig = figure('Name', 'M1 vs M3 guidance', 'Units', 'centimeters', ...
        'Position', [2, 2, 16.8, 13.5]);
    tl = tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
    win = data(1).t >= 45 & data(1).t <= 80;

    ax1 = nexttile(tl, 1); hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on'); style_axes(ax1);
    plot(ax1, data(1).t(win), data(1).formMaxActive(win), 'Color', colors(1,:), ...
        'LineStyle', styles{1}, 'LineWidth', 2.1, 'DisplayName', 'M1 Proposed');
    plot(ax1, data(3).t(win), data(3).formMaxActive(win), 'Color', colors(3,:), ...
        'LineStyle', styles{3}, 'LineWidth', 2.1, 'DisplayName', 'M3 Fixed-assignment guidance');
    xline(ax1, data(1).switchTime, '-.', 'Color', [0.15 0.15 0.15], 'HandleVisibility', 'off');
    ylabel(ax1, 'Max formation error (m)'); xlim(ax1, [45 80]);
    title(ax1, '(b1) Fixed assignment increases formation tracking load', 'FontWeight', 'normal');
    legend(ax1, 'Location', 'northeast', 'Box', 'off');

    ax2 = nexttile(tl, 2); hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on'); style_axes(ax2);
    plot(ax2, data(1).t(win), data(1).pairSpreadActive(win), 'Color', colors(1,:), ...
        'LineStyle', styles{1}, 'LineWidth', 2.1);
    plot(ax2, data(3).t(win), data(3).pairSpreadActive(win), 'Color', colors(3,:), ...
        'LineStyle', styles{3}, 'LineWidth', 2.1);
    xline(ax2, data(1).switchTime, '-.', 'Color', [0.15 0.15 0.15], 'HandleVisibility', 'off');
    xlabel(ax2, 'Time (s)'); ylabel(ax2, 'Active pair-distance spread (m)');
    title(ax2, '(b2) Formation geometry consistency', 'FontWeight', 'normal');
    xlim(ax2, [45 80]);
    save_compare_fig(fig, outDir, 'FigC2_Guidance_M1_vs_M3');
end

function plot_rigid_ppc_pair(data, colors, styles, outDir)
    fig = figure('Name', 'M1 vs M4 rigid PPC', 'Units', 'centimeters', ...
        'Position', [2, 2, 16.8, 13.5]);
    tl = tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
    win = data(1).t >= 45 & data(1).t <= 80;

    ax1 = nexttile(tl, 1); hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on'); style_axes(ax1);
    plot(ax1, data(1).t(win), data(1).ppcVioMaxActive(win), 'Color', colors(1,:), ...
        'LineStyle', styles{1}, 'LineWidth', 2.1, 'DisplayName', 'M1 Proposed');
    plot(ax1, data(4).t(win), data(4).ppcVioMaxActive(win), 'Color', colors(4,:), ...
        'LineStyle', styles{4}, 'LineWidth', 2.2, 'DisplayName', 'M4 Rigid PPC');
    xline(ax1, data(1).switchTime, '-.', 'Color', [0.15 0.15 0.15], 'HandleVisibility', 'off');
    ylabel(ax1, 'Max PPC violation (m)'); xlim(ax1, [45 80]);
    title(ax1, '(c1) Rigid PPC violation under saturation', 'FontWeight', 'normal');
    legend(ax1, 'Location', 'southwest', 'Box', 'off');

    ax2 = nexttile(tl, 2); hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on'); style_axes(ax2);
    plot(ax2, data(1).t(win), data(1).normDemandMaxActive(win), 'Color', colors(1,:), ...
        'LineStyle', styles{1}, 'LineWidth', 1.8);
    plot(ax2, data(4).t(win), data(4).normDemandMaxActive(win), 'Color', colors(4,:), ...
        'LineStyle', styles{4}, 'LineWidth', 1.8);
    xline(ax2, data(1).switchTime, '-.', 'Color', [0.15 0.15 0.15], 'HandleVisibility', 'off');
    xlabel(ax2, 'Time (s)'); ylabel(ax2, 'Max normalized control demand');
    title(ax2, '(c2) Control demand relative to saturation limits', 'FontWeight', 'normal');
    xlim(ax2, [45 80]); ylim(ax2, [0 1]);
    save_compare_fig(fig, outDir, 'FigC3_RigidPPC_M1_vs_M4');
end

function plot_ablation_summary(summaryTbl, colors, outDir)
    fig = figure('Name', 'Ablation summary', 'Units', 'centimeters', ...
        'Position', [2, 2, 17.2, 14.5]);
    tl = tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    methods = categorical({'M1','M2','M3','M4'});
    values = {summaryTbl.MaxPPCViolation_m, summaryTbl.MinSafetyDistance_m, ...
        summaryTbl.PostSwitchControlRMS, 100*summaryTbl.SaturationRatio};
    titles = {'PPC constraint violation', 'Safety margin', ...
        'Post-switch control burden', 'Saturation activity'};
    ylabels = {'Max PPC violation (m)', 'Minimum distance (m)', ...
        'RMS normalized demand', 'Samples near saturation (\%)'};
    for k = 1:4
        ax = nexttile(tl, k); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on'); style_axes(ax);
        b = bar(ax, methods, values{k}, 'FaceColor', 'flat'); b.CData = colors;
        title(ax, titles{k}, 'FontWeight', 'normal'); ylabel(ax, ylabels{k});
        if k == 2
            yline(ax, 10, 'r--', 'LineWidth', 1.1);
        end
    end
    save_compare_fig(fig, outDir, 'FigC4_Ablation_Summary');
end

function plot_ablation_threepanel(data, colors, styles, outDir)
    fig = figure('Name', 'Ablation three-panel', 'Units', 'centimeters', ...
        'Position', [2, 2, 17.2, 17.5]);
    tl = tiledlayout(fig, 3, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

    % M2: observer layer
    ax1 = nexttile(tl, 1); hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on');
    style_axes(ax1);
    win = data(1).t >= 45 & data(1).t <= 70;
    plot(ax1, data(1).t(win), data(1).obsMaxActive(win), ...
        'Color', colors(1,:), 'LineStyle', styles{1}, 'LineWidth', 2.2, ...
        'DisplayName', 'M1 Proposed');
    plot(ax1, data(2).t(win), data(2).obsMaxActive(win), ...
        'Color', colors(2,:), 'LineStyle', styles{2}, 'LineWidth', 2.2, ...
        'DisplayName', 'M2 Fixed observer');
    xline(ax1, data(1).switchTime, '-.', 'Color', [0.15 0.15 0.15], ...
        'LineWidth', 1.0, 'HandleVisibility', 'off');
    ylabel(ax1, 'Max observer error (m)');
    title(ax1, '(a) Observer layer: restart gain accelerates recovery', ...
        'FontWeight', 'normal');
    legend(ax1, 'Location', 'northeast', 'Box', 'off');
    xlim(ax1, [45 70]);

    % M3: guidance layer
    ax2 = nexttile(tl, 2); hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on');
    style_axes(ax2);
    win = data(1).t >= 45 & data(1).t <= 80;
    plot(ax2, data(1).t(win), data(1).formMaxActive(win), ...
        'Color', colors(1,:), 'LineStyle', styles{1}, 'LineWidth', 2.2, ...
        'DisplayName', 'M1 Proposed');
    plot(ax2, data(3).t(win), data(3).formMaxActive(win), ...
        'Color', colors(3,:), 'LineStyle', styles{3}, 'LineWidth', 2.2, ...
        'DisplayName', 'M3 Fixed assignment');
    xline(ax2, data(1).switchTime, '-.', 'Color', [0.15 0.15 0.15], ...
        'LineWidth', 1.0, 'HandleVisibility', 'off');
    ylabel(ax2, 'Max formation error (m)');
    title(ax2, '(b) Guidance layer: self-ordering prevents assignment conflict', ...
        'FontWeight', 'normal');
    legend(ax2, 'Location', 'northeast', 'Box', 'off');
    xlim(ax2, [45 80]);

    % M4: tracking layer
    ax3 = nexttile(tl, 3); hold(ax3, 'on'); grid(ax3, 'on'); box(ax3, 'on');
    style_axes(ax3);
    plot(ax3, data(1).t(win), data(1).ppcVioMaxActive(win), ...
        'Color', colors(1,:), 'LineStyle', styles{1}, 'LineWidth', 2.2, ...
        'DisplayName', 'M1 Proposed');
    plot(ax3, data(4).t(win), data(4).ppcVioMaxActive(win), ...
        'Color', colors(4,:), 'LineStyle', styles{4}, 'LineWidth', 2.4, ...
        'DisplayName', 'M4 Rigid PPC');
    xline(ax3, data(1).switchTime, '-.', 'Color', [0.15 0.15 0.15], ...
        'LineWidth', 1.0, 'HandleVisibility', 'off');
    xlabel(ax3, 'Time (s)');
    ylabel(ax3, 'Max PPC violation (m)');
    title(ax3, '(c) Tracking layer: elastic PPC avoids rigid-bound failure', ...
        'FontWeight', 'normal');
    legend(ax3, 'Location', 'southwest', 'Box', 'off');
    xlim(ax3, [45 80]);

    save_compare_fig(fig, outDir, 'FigC1_Ablation_ThreePanel');
end

function plot_overall_profile(summaryTbl, colors, outDir)
    fig = figure('Name', 'Overall ablation profile', 'Units', 'centimeters', ...
        'Position', [2, 2, 17.5, 10.5]);
    tl = tiledlayout(fig, 1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    methods = {'M1','M2','M3','M4'};
    costNames = {'PPC vio.', 'Formation', 'Ctrl RMS', 'Sat. ratio'};
    costRaw = [summaryTbl.MaxPPCViolation_m, ...
               summaryTbl.PostSwitchMeanFormationError_m, ...
               summaryTbl.PostSwitchControlRMS, ...
               summaryTbl.SaturationRatio];
    normCost = costRaw ./ max(costRaw, [], 1);
    normCost(~isfinite(normCost)) = 0;

    ax1 = nexttile(tl, 1); hold(ax1, 'on'); box(ax1, 'on');
    imagesc(ax1, normCost);
    colormap(ax1, soft_cost_colormap());
    clim(ax1, [0 1]);
    axis(ax1, 'tight');
    ax1.YTick = 1:numel(methods);
    ax1.YTickLabel = methods;
    ax1.YDir = 'reverse';
    ax1.XTick = 1:numel(costNames);
    ax1.XTickLabel = costNames;
    ax1.XTickLabelRotation = 25;
    ax1.TickLength = [0 0];
    ax1.FontName = 'Times New Roman';
    ax1.FontSize = 10.5;
    title(ax1, '(a) Normalized performance cost', 'FontWeight', 'normal');
    for r = 1:size(normCost,1)
        for c = 1:size(normCost,2)
            if normCost(r,c) > 0.55
                txtColor = [1 1 1];
            else
                txtColor = [0.12 0.12 0.12];
            end
            text(ax1, c, r, sprintf('%.2f', normCost(r,c)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
                'FontName', 'Times New Roman', 'FontSize', 9.5, ...
                'Color', txtColor);
        end
    end

    ax2 = nexttile(tl, 2); hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on');
    style_axes(ax2);
    yyaxis(ax2, 'left');
    b = bar(ax2, categorical(methods), summaryTbl.MinSafetyDistance_m, ...
        'FaceColor', 'flat');
    b.CData = colors;
    yline(ax2, 10, '--', 'Color', [0.80 0.10 0.10], 'LineWidth', 1.2);
    ylabel(ax2, 'Minimum distance (m)');
    ylim(ax2, [8 18]);
    ax2.YColor = [0.05 0.05 0.05];

    yyaxis(ax2, 'right');
    plot(ax2, categorical(methods), 100 * summaryTbl.SaturationRatio, ...
        'o-', 'Color', [0.20 0.20 0.20], 'MarkerFaceColor', [0.20 0.20 0.20], ...
        'LineWidth', 1.5, 'MarkerSize', 5);
    ylabel(ax2, 'Near-saturation samples (\%)');
    ylim(ax2, [0 65]);
    ax2.YColor = [0.20 0.20 0.20];
    title(ax2, '(b) Safety margin and saturation activity', 'FontWeight', 'normal');
    xlabel(ax2, 'Method');

    save_compare_fig(fig, outDir, 'FigC2_Overall_Profile');
end

function cmap = soft_cost_colormap()
    base = [0.965 0.975 0.985;
            0.785 0.870 0.930;
            0.420 0.640 0.820;
            0.125 0.330 0.580];
    x = linspace(0, 1, size(base,1));
    xi = linspace(0, 1, 256);
    cmap = interp1(x, base, xi);
end

%% ========================= extraction =========================
function c = load_ablation_case(modelName, label)
    resFile = fullfile('sim_results', [modelName, '_res.mat']);
    if ~exist(resFile, 'file')
        error('Result file not found: %s', resFile);
    end

    S = load(resFile);
    D = get_main_container(S);
    tout = get_numeric_signal(D, 'tout');
    if isempty(tout)
        tout = get_signal(D, 'agent1').time;
    end
    tout = tout(:);

    metrics = load_metrics(modelName);
    if isfield(metrics, 'switch_time')
        switchTime = metrics.switch_time;
    else
        switchTime = 50;
    end
    if isfield(metrics, 'active_flags')
        activeAfter = logical(metrics.active_flags(:).');
    else
        activeAfter = [true true true true false false];
    end
    if isfield(metrics, 'tau_u_limit')
        tauULim = metrics.tau_u_limit;
    else
        tauULim = 800;
    end
    if isfield(metrics, 'tau_r_limit')
        tauRLim = metrics.tau_r_limit;
    else
        tauRLim = 400;
    end

    numPts = 8000;
    numAgents = 6;
    t = linspace(tout(1), tout(end), numPts).';
    activeMask = true(numPts, numAgents);
    activeMask(t >= switchTime, ~activeAfter) = false;
    activeCount = sum(activeMask, 2);

    p0 = interp_vec2(D, 'p0', tout, t);
    pAgent = nan(numPts, 2, numAgents);
    pHat = nan(numPts, 2, numAgents);
    pDes = nan(numPts, 2, numAgents);
    rho = nan(numPts, numAgents);
    bounds = nan(numPts, 2, numAgents);
    tauU = nan(numPts, numAgents);
    tauR = nan(numPts, numAgents);

    for i = 1:numAgents
        pAgent(:,:,i) = interp_vec2(D, sprintf('agent%d', i), tout, t);
        pHat(:,:,i) = interp_vec2(D, sprintf('p_hat_%d', i), tout, t);
        pDes(:,:,i) = interp_vec2(D, sprintf('p_d_%d', i), tout, t);
        rho(:,i) = interp_scalar(D, sprintf('rho_e%d', i), tout, t);
        bounds(:,:,i) = interp_vec2(D, sprintf('B_rho%d', i), tout, t);
        tauU(:,i) = interp_scalar(D, sprintf('t_u%d', i), tout, t);
        tauR(:,i) = interp_scalar(D, sprintf('t_r%d', i), tout, t);
    end

    obsErr = nan(numPts, numAgents);
    formErr = nan(numPts, numAgents);
    ppcVio = nan(numPts, numAgents);
    normDemand = nan(numPts, numAgents);
    for i = 1:numAgents
        obsErr(:,i) = vecnorm(pHat(:,:,i) - p0, 2, 2);
        formErr(:,i) = vecnorm(pAgent(:,:,i) - pDes(:,:,i), 2, 2);
        lower = bounds(:,1,i);
        upper = bounds(:,2,i);
        ppcVio(:,i) = max([rho(:,i) - upper, lower - rho(:,i), zeros(numPts,1)], [], 2);
        normDemand(:,i) = max(abs(tauU(:,i)) ./ tauULim, abs(tauR(:,i)) ./ tauRLim);
    end
    obsErr(~activeMask) = NaN;
    formErr(~activeMask) = NaN;
    ppcVio(~activeMask) = NaN;
    normDemand(~activeMask) = NaN;

    c.modelName = modelName;
    c.label = label;
    c.t = t;
    c.switchTime = switchTime;
    c.activeAfter = activeAfter;
    c.activeMask = activeMask;
    c.activeCount = activeCount;
    c.tauULim = tauULim;
    c.tauRLim = tauRLim;
    c.p0 = p0;
    c.pAgent = pAgent;
    c.pHat = pHat;
    c.pDes = pDes;
    c.rho = rho;
    c.bounds = bounds;
    c.tauU = tauU;
    c.tauR = tauR;
    c.obsMaxActive = max(obsErr, [], 2, 'omitnan');
    c.obsMeanActive = mean(obsErr, 2, 'omitnan');
    c.formMaxActive = max(formErr, [], 2, 'omitnan');
    c.formMeanActive = mean(formErr, 2, 'omitnan');
    c.ppcVioMaxActive = max(ppcVio, [], 2, 'omitnan');
    c.normDemandMaxActive = max(normDemand, [], 2, 'omitnan');
    c.normDemandRMSActive = sqrt(mean(normDemand.^2, 2, 'omitnan'));
    c.pairMinActive = compute_min_pair_distance(pAgent, activeMask);
    c.pairSpreadActive = compute_pair_spread(pAgent, activeMask);
end

function metrics = load_metrics(modelName)
    metrics = struct();
    f = fullfile('sim_results', [modelName, '_paper_metrics.mat']);
    if exist(f, 'file')
        S = load(f);
        if isfield(S, 'paper_metrics')
            metrics = S.paper_metrics;
        end
    end
end

function summaryTbl = build_summary_table(data)
    n = numel(data);
    method = strings(n,1);
    maxPPC = nan(n,1);
    minDist = nan(n,1);
    postRMS = nan(n,1);
    satRatio = nan(n,1);
    obsPeakAfterSwitch = nan(n,1);
    formMeanAfterSwitch = nan(n,1);

    for k = 1:n
        d = data(k);
        method(k) = string(d.label);
        post = d.t >= d.switchTime;
        maxPPC(k) = max(d.ppcVioMaxActive, [], 'omitnan');
        minDist(k) = min(d.pairMinActive, [], 'omitnan');
        postRMS(k) = mean(d.normDemandRMSActive(post), 'omitnan');
        satRatio(k) = mean(d.normDemandMaxActive(post) >= 0.98, 'omitnan');
        obsPeakAfterSwitch(k) = max(d.obsMaxActive(post), [], 'omitnan');
        formMeanAfterSwitch(k) = mean(d.formMeanActive(post), 'omitnan');
    end

    summaryTbl = table(method, maxPPC, minDist, postRMS, satRatio, ...
        obsPeakAfterSwitch, formMeanAfterSwitch, ...
        'VariableNames', {'Method', 'MaxPPCViolation_m', ...
        'MinSafetyDistance_m', 'PostSwitchControlRMS', 'SaturationRatio', ...
        'PostSwitchPeakObserverError_m', 'PostSwitchMeanFormationError_m'});
end

function y = compute_min_pair_distance(pAgent, activeMask)
    numPts = size(pAgent, 1);
    y = nan(numPts, 1);
    for k = 1:numPts
        idx = find(activeMask(k,:));
        vals = [];
        for a = 1:numel(idx)
            for b = a+1:numel(idx)
                i = idx(a); j = idx(b);
                vals(end+1,1) = norm(pAgent(k,:,i) - pAgent(k,:,j)); %#ok<AGROW>
            end
        end
        if ~isempty(vals)
            y(k) = min(vals);
        end
    end
end

function y = compute_pair_spread(pAgent, activeMask)
    numPts = size(pAgent, 1);
    y = nan(numPts, 1);
    for k = 1:numPts
        idx = find(activeMask(k,:));
        vals = [];
        for a = 1:numel(idx)
            for b = a+1:numel(idx)
                i = idx(a); j = idx(b);
                vals(end+1,1) = norm(pAgent(k,:,i) - pAgent(k,:,j)); %#ok<AGROW>
            end
        end
        if ~isempty(vals)
            y(k) = max(vals) - min(vals);
        end
    end
end

%% ========================= signal helpers =========================
function y = interp_vec2(D, name, tout, tRef)
    sig = get_signal(D, name);
    [t, raw] = read_vec2(sig, tout);
    y = interp1(t, raw, tRef, 'linear', 'extrap');
end

function y = interp_scalar(D, name, tout, tRef)
    sig = get_signal(D, name);
    [t, raw] = read_scalar(sig, tout);
    y = interp1(t, raw, tRef, 'linear', 'extrap');
end

function D = get_main_container(S)
    if isfield(S, 'out')
        D = S.out;
    else
        D = S;
    end
end

function val = get_numeric_signal(D, name)
    val = [];
    if isstruct(D) && isfield(D, name)
        val = D.(name);
        return;
    end
    try
        val = D.get(name);
        if ~isempty(val)
            return;
        end
    catch
    end
    try
        val = D.(name);
    catch
    end
end

function sig = get_signal(D, name)
    sig = [];
    if isstruct(D) && isfield(D, name)
        sig = D.(name);
        return;
    end
    try
        sig = D.get(name);
        if ~isempty(sig)
            return;
        end
    catch
    end
    try
        sig = D.(name);
    catch
    end
    if isempty(sig)
        error('Signal not found: %s', name);
    end
end

function [t, y] = read_scalar(sig, tout)
    if isstruct(sig)
        if isfield(sig, 'time') && ~isempty(sig.time)
            t = sig.time(:);
        else
            t = tout(:);
        end
        y = squeeze(sig.signals.values);
        y = y(:);
        return;
    end
    try
        t = sig.Time(:);
        y = squeeze(sig.Data);
        y = y(:);
        return;
    catch
    end
    error('Unsupported scalar signal format.');
end

function [t, y] = read_vec2(sig, tout)
    if isstruct(sig)
        if isfield(sig, 'time') && ~isempty(sig.time)
            t = sig.time(:);
        else
            t = tout(:);
        end
        y = force_to_Nx2(sig.signals.values);
        if size(y,1) ~= numel(t) && numel(t) == numel(tout)
            t = linspace(tout(1), tout(end), size(y,1)).';
        end
        return;
    end
    try
        t = sig.Time(:);
        y = force_to_Nx2(sig.Data);
        return;
    catch
    end
    error('Unsupported vector signal format.');
end

function y = force_to_Nx2(v)
    sz = size(v);
    if ismatrix(v) && size(v,2) >= 2
        y = v(:,1:2);
    elseif ismatrix(v) && size(v,1) >= 2
        y = v(1:2,:).';
    elseif ndims(v) == 3 && sz(1) >= 2 && sz(2) == 1
        y = squeeze(v(1:2,1,:)).';
    elseif ndims(v) == 3 && sz(1) == 1 && sz(2) >= 2
        y = squeeze(v(1,1:2,:)).';
    elseif ndims(v) == 3 && sz(2) == 1 && sz(3) >= 2
        y = squeeze(v(:,1,1:2));
    else
        error('Unrecognized vector signal shape: [%s]', num2str(sz));
    end
end

%% ========================= style =========================
function save_compare_fig(fig, outDir, baseName)
    exportgraphics(fig, fullfile(outDir, [baseName, '.eps']), 'ContentType', 'vector');
    exportgraphics(fig, fullfile(outDir, [baseName, '.jpg']), 'Resolution', 600);
end

function set_plot_defaults()
    set(groot, 'defaultAxesFontName', 'Times New Roman');
    set(groot, 'defaultTextFontName', 'Times New Roman');
    set(groot, 'defaultLegendInterpreter', 'latex');
    set(groot, 'defaultTextInterpreter', 'latex');
    set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
end

function style_axes(ax)
    set(ax, 'TickDir', 'in', ...
        'LineWidth', 1.05, ...
        'XMinorTick', 'on', ...
        'YMinorTick', 'on', ...
        'FontSize', 10.5, ...
        'FontName', 'Times New Roman');
end
