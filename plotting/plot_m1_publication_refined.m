function plot_m1_publication_refined(modelName)
%PLOT_M1_PUBLICATION_REFINED Refined M1-only figures for paper presentation.
%
% The original Myplot_OE_paper figures are kept unchanged. This script
% creates a cleaner visual set focused on the proposed method.

    if nargin < 1 || isempty(modelName)
        modelName = 'abl_M1_proposed';
    end

    outDir = fullfile('figures_OE', [modelName, '_refined']);
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    set(groot, 'defaultFigureVisible', 'off');
    set_refined_defaults();

    d = load_case(modelName);
    C = refined_colors();

    plot_refined_trajectory(d, C, outDir);
    plot_refined_observer(d, C, outDir);
    plot_refined_ppc(d, C, outDir);
    plot_refined_control_zoom(d, C, outDir);
    plot_refined_safety(d, C, outDir);

    fprintf('Refined M1 figures generated in %s\n', outDir);
end

%% ========================= figures =========================
function plot_refined_trajectory(d, C, outDir)
    fig = figure('Name', 'Refined trajectory', 'Units', 'centimeters', ...
        'Position', [2, 2, 16.5, 13.2]);
    ax = axes(fig); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
    style_axes(ax);
    ax.GridAlpha = 0.14;
    ax.MinorGridAlpha = 0.06;

    plot(ax, d.p0(:,1), d.p0(:,2), '--', 'Color', [0.05 0.05 0.05], ...
        'LineWidth', 2.0, 'DisplayName', 'Target $p_0$');

    for i = 1:6
        valid = d.validMask(:,i);
        if i > 4
            col = 0.55 + 0.45 * C.agent(i,:);
            lw = 1.1;
        else
            col = C.agent(i,:);
            lw = 1.65;
        end
        plot(ax, d.pAgent(valid,1,i), d.pAgent(valid,2,i), '-', ...
            'Color', col, 'LineWidth', lw, 'DisplayName', sprintf('USV%d', i));
        k0 = find(valid, 1, 'first');
        k1 = find(valid, 1, 'last');
        scatter(ax, d.pAgent(k0,1,i), d.pAgent(k0,2,i), 22, col, 'filled', ...
            'MarkerFaceAlpha', 0.75, 'HandleVisibility', 'off');
        scatter(ax, d.pAgent(k1,1,i), d.pAgent(k1,2,i), 38, col, 'o', ...
            'LineWidth', 1.0, 'HandleVisibility', 'off');
    end

    snapTimes = [0 20 40 50 65 80];
    for s = 1:numel(snapTimes)
        [~, idx] = min(abs(d.t - snapTimes(s)));
        active = find(d.validMask(idx,:));
        pts = squeeze(d.pAgent(idx,:,active)).';
        if size(pts,1) >= 3
            hullIdx = convhull(pts(:,1), pts(:,2));
            plot(ax, pts(hullIdx,1), pts(hullIdx,2), '-.', 'Color', C.snapshot, ...
                'LineWidth', 1.45, 'HandleVisibility', 'off');
        end
        plot(ax, d.p0(idx,1), d.p0(idx,2), 'p', 'Color', C.snapshot, ...
            'MarkerFaceColor', C.snapshot, 'MarkerSize', 8, 'HandleVisibility', 'off');
        for q = 1:numel(active)
            id = active(q);
            plot(ax, [d.p0(idx,1), d.pAgent(idx,1,id)], ...
                [d.p0(idx,2), d.pAgent(idx,2,id)], ':', ...
                'Color', [C.snapshot 0.25], 'LineWidth', 0.7, 'HandleVisibility', 'off');
        end
    end

    xlabel(ax, '$x$ (m)');
    ylabel(ax, '$y$ (m)');
    axis(ax, 'equal');
    xlim(ax, [-30 170]);
    ylim(ax, [-35 90]);
    legend(ax, 'Location', 'southoutside', 'NumColumns', 4, 'Box', 'off');
    save_refined(fig, outDir, 'FigR1_Trajectory_Refined');
end

function plot_refined_observer(d, C, outDir)
    fig = figure('Name', 'Observer estimates', 'Units', 'centimeters', ...
        'Position', [2, 2, 16.8, 18.0]);
    tl = tiledlayout(fig, 3, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
    labels = arrayfun(@(i) sprintf('USV%d', i), 1:6, 'UniformOutput', false);

    axErr = nexttile(tl, 1); hold(axErr, 'on'); box(axErr, 'on'); grid(axErr, 'on');
    style_axes(axErr);
    hAgents = gobjects(6,1);
    for i = 1:6
        valid = d.validMask(:,i);
        hAgents(i) = plot(axErr, d.t(valid), d.obsErr(valid,i), '-', ...
            'Color', C.agent(i,:), 'LineWidth', 1.15, 'DisplayName', labels{i});
    end
    xline(axErr, d.switchTime, '-.', 'Color', C.dark, 'LineWidth', 0.9, ...
        'HandleVisibility', 'off');
    ylabel(axErr, '$\|\hat p_{0,i}-p_0\|$ (m)');
    xlim(axErr, [0 80]);

    axX = nexttile(tl, 2); hold(axX, 'on'); box(axX, 'on'); grid(axX, 'on');
    style_axes(axX);
    plot(axX, d.t, d.p0(:,1), 'k--', 'LineWidth', 1.6, ...
        'DisplayName', 'Target');
    for i = 1:6
        valid = d.validMask(:,i);
        plot(axX, d.t(valid), d.pHat(valid,1,i), '-', 'Color', C.agent(i,:), ...
            'LineWidth', 1.05, 'HandleVisibility', 'off');
    end
    xline(axX, d.switchTime, '-.', 'Color', C.dark, 'LineWidth', 0.9, ...
        'HandleVisibility', 'off');
    ylabel(axX, '$x$ position (m)');
    xlim(axX, [0 80]);

    axY = nexttile(tl, 3); hold(axY, 'on'); box(axY, 'on'); grid(axY, 'on');
    style_axes(axY);
    hTarget = plot(axY, d.t, d.p0(:,2), 'k--', 'LineWidth', 1.6, ...
        'DisplayName', 'Target');
    for i = 1:6
        valid = d.validMask(:,i);
        plot(axY, d.t(valid), d.pHat(valid,2,i), '-', 'Color', C.agent(i,:), ...
            'LineWidth', 1.05, 'HandleVisibility', 'off');
    end
    xline(axY, d.switchTime, '-.', 'Color', C.dark, 'LineWidth', 0.9, ...
        'HandleVisibility', 'off');
    ylabel(axY, '$y$ position (m)');
    xlabel(axY, 'Time (s)');
    xlim(axY, [0 80]);

    lgd = legend(axErr, [hTarget; hAgents], [{'Target'}, labels], ...
        'Orientation', 'horizontal', 'NumColumns', 4, 'Box', 'off', 'FontSize', 8.5);
    lgd.Layout.Tile = 'south';
    save_refined(fig, outDir, 'FigR2_Observer_Refined');
end

function plot_refined_ppc(d, C, outDir)
    fig = figure('Name', 'Refined PPC', 'Units', 'centimeters', ...
        'Position', [2, 2, 16.8, 12.2]);
    tl = tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
    activeIds = find(d.activeAfter);

    for k = 1:numel(activeIds)
        i = activeIds(k);
        ax = nexttile(tl, k); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
        style_axes(ax);
        tt = d.t;
        lower = d.bounds(:,1,i);
        upper = d.bounds(:,2,i);
        fill(ax, [tt; flipud(tt)], [lower; flipud(upper)], C.boundFill, ...
            'FaceAlpha', 0.35, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        plot(ax, tt, lower, '--', 'Color', C.red, 'LineWidth', 0.9, 'HandleVisibility', 'off');
        plot(ax, tt, upper, '--', 'Color', C.red, 'LineWidth', 0.9, 'HandleVisibility', 'off');
        plot(ax, tt, d.rho(:,i), '-', 'Color', C.agent(i,:), 'LineWidth', 1.7);
        xline(ax, d.switchTime, '-.', 'Color', C.dark, 'LineWidth', 0.8, 'HandleVisibility', 'off');
        xlim(ax, [0 80]);
        ylim(ax, [-2 20]);
        title(ax, sprintf('USV%d', i), 'FontWeight', 'normal');
        if mod(k,2) == 1
            ylabel(ax, '$\rho_{e,i}$ (m)');
        end
        if k > 2
            xlabel(ax, 'Time (s)');
        end
    end
    save_refined(fig, outDir, 'FigR3_PPC_Active_Refined');
end

function plot_refined_control_zoom(d, C, outDir)
    fig = figure('Name', 'Control inputs with magnified steady state', ...
        'Units', 'centimeters', 'Position', [2, 2, 16.8, 13.2]);
    tl = tiledlayout(fig, 2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
    tauU = smoothdata(d.tauU, 1, 'movmean', 11);
    tauR = smoothdata(d.tauR, 1, 'movmean', 11);
    zoomWin = d.t > 65 & d.t < 75;

    ax1 = nexttile(tl, 1); hold(ax1, 'on'); box(ax1, 'on'); grid(ax1, 'on');
    style_axes(ax1);
    for i = 1:6
        valid = d.validMask(:,i);
        plot(ax1, d.t(valid), tauU(valid,i), 'Color', C.agent(i,:), 'LineWidth', 1.0);
    end
    yline(ax1, d.tauULimit, 'r--', 'LineWidth', 1.1, 'HandleVisibility', 'off');
    yline(ax1, -d.tauULimit, 'r--', 'LineWidth', 1.1, 'HandleVisibility', 'off');
    xlim(ax1, [0 80]); ylim(ax1, 1.25 * [-d.tauULimit d.tauULimit]);
    ylabel(ax1, '$\tau_{u,i}$ (N)');

    ax2 = nexttile(tl, 2); hold(ax2, 'on'); box(ax2, 'on'); grid(ax2, 'on');
    style_axes(ax2);
    for i = 1:6
        valid = d.validMask(:,i);
        plot(ax2, d.t(valid), tauR(valid,i), 'Color', C.agent(i,:), 'LineWidth', 1.0);
    end
    yline(ax2, d.tauRLimit, 'r--', 'LineWidth', 1.1, 'HandleVisibility', 'off');
    yline(ax2, -d.tauRLimit, 'r--', 'LineWidth', 1.1, 'HandleVisibility', 'off');
    xlim(ax2, [0 80]); ylim(ax2, 1.25 * [-d.tauRLimit d.tauRLimit]);
    xlabel(ax2, 'Time (s)'); ylabel(ax2, '$\tau_{r,i}$ (Nm)');

    insetU = axes(fig, 'Position', [0.785 0.79 0.145 0.115]);
    plot_control_inset(insetU, d, tauU, C, zoomWin, '$\tau_{u,i}$');
    insetR = axes(fig, 'Position', [0.785 0.335 0.145 0.115]);
    plot_control_inset(insetR, d, tauR, C, zoomWin, '$\tau_{r,i}$');

    save_refined(fig, outDir, 'FigR4_ControlZoom_Refined');
end

function plot_control_inset(ax, d, tau, C, win, yText)
    hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on'); style_axes(ax);
    active = find(d.activeAfter);
    for i = active
        plot(ax, d.t(win), tau(win,i), 'Color', C.agent(i,:), 'LineWidth', 1.0);
    end
    xlim(ax, [65 75]);
    xticks(ax, [65 70 75]);
    vals = tau(win,active);
    lo = min(vals, [], 'all'); hi = max(vals, [], 'all');
    pad = max(0.12 * (hi-lo), 0.6);
    ylim(ax, [lo-pad hi+pad]);
    ylabel(ax, yText, 'FontSize', 7.5);
    ax.FontSize = 7.2;
    ax.Layer = 'top';
    ax.XColor = [0 0 0];
    ax.YColor = [0 0 0];
    ax.Color = [1 1 1];
    ax.LineWidth = 1.05;
    ax.Clipping = 'on';
    ax.GridColor = [0.60 0.60 0.60];
    ax.GridAlpha = 0.24;
end

function plot_refined_safety(d, C, outDir)
    fig = figure('Name', 'Refined safety', 'Units', 'centimeters', ...
        'Position', [2, 2, 16.2, 9.2]);
    ax = axes(fig); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
    style_axes(ax);

    pairColors = lines(size(d.pairDist, 2));
    for k = 1:size(d.pairDist, 2)
        plot(ax, d.t, d.pairDist(:,k), '-', 'Color', [pairColors(k,:) 0.45], ...
            'LineWidth', 1.0, 'HandleVisibility', 'off');
    end
    plot(ax, d.t, d.minPairActive, '-', 'Color', C.blue, 'LineWidth', 2.2, ...
        'DisplayName', 'Minimum active distance');
    yline(ax, 10, '--', 'Color', C.red, 'LineWidth', 1.3, ...
        'DisplayName', '$d_{\rm avoid}=10$ m');
    inactiveIds = find(~d.activeAfter);
    eventText = sprintf('USVs %s misbehave (removed)', ...
        strjoin(string(inactiveIds), ', '));
    xline(ax, d.switchTime, '-.', 'Color', C.dark, 'LineWidth', 1.2, ...
        'HandleVisibility', 'off');
    plot(ax, d.switchTime, 67, 'v', 'Color', C.dark, 'MarkerFaceColor', C.dark, ...
        'MarkerSize', 6, 'HandleVisibility', 'off');
    text(ax, d.switchTime + 1.2, 65.5, eventText, 'FontSize', 8.5, ...
        'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');
    xlabel(ax, 'Time (s)');
    ylabel(ax, 'Inter-USV distance (m)');
    xlim(ax, [0 80]);
    ylim(ax, [8 80]);
    legend(ax, 'Location', 'northeast', 'Box', 'off');
    save_refined(fig, outDir, 'FigR5_Safety_Refined');
end

%% ========================= data =========================
function d = load_case(modelName)
    resFile = fullfile('sim_results', [modelName, '_res.mat']);
    metricFile = fullfile('sim_results', [modelName, '_paper_metrics.mat']);
    S = load(resFile);
    M = load(metricFile);
    D = S.out;
    metrics = M.paper_metrics;

    tRaw = D.agent1.time(:);
    numPts = 8000;
    t = linspace(tRaw(1), tRaw(end), numPts).';
    numAgents = 6;
    p0 = interp_vec2(D.p0, tRaw, t);
    pAgent = nan(numPts, 2, numAgents);
    pHat = nan(numPts, 2, numAgents);
    rho = nan(numPts, numAgents);
    bounds = nan(numPts, 2, numAgents);
    tauU = nan(numPts, numAgents);
    tauR = nan(numPts, numAgents);

    for i = 1:numAgents
        pAgent(:,:,i) = interp_vec2(D.(sprintf('agent%d', i)), tRaw, t);
        pHat(:,:,i) = interp_vec2(D.(sprintf('p_hat_%d', i)), tRaw, t);
        rho(:,i) = interp_scalar(D.(sprintf('rho_e%d', i)), tRaw, t);
        bounds(:,:,i) = interp_vec2(D.(sprintf('B_rho%d', i)), tRaw, t);
        tauU(:,i) = interp_scalar(D.(sprintf('t_u%d', i)), tRaw, t);
        tauR(:,i) = interp_scalar(D.(sprintf('t_r%d', i)), tRaw, t);
    end

    activeAfter = logical(metrics.active_flags(:).');
    switchTime = metrics.switch_time;
    validMask = true(numPts, numAgents);
    validMask(t >= switchTime, ~activeAfter) = false;

    obsErr = nan(numPts, numAgents);
    for i = 1:numAgents
        obsErr(:,i) = vecnorm(pHat(:,:,i) - p0, 2, 2);
    end
    obsErrMasked = obsErr;
    obsErrMasked(~validMask) = NaN;

    [pairDist, minPair] = pair_distances(pAgent, validMask);

    d = struct();
    d.t = t;
    d.p0 = p0;
    d.pAgent = pAgent;
    d.pHat = pHat;
    d.rho = rho;
    d.bounds = bounds;
    d.tauU = tauU;
    d.tauR = tauR;
    d.tauULimit = metrics.tau_u_limit;
    d.tauRLimit = metrics.tau_r_limit;
    d.activeAfter = activeAfter;
    d.switchTime = switchTime;
    d.validMask = validMask;
    d.obsErr = obsErr;
    d.obsMaxActive = max(obsErrMasked, [], 2, 'omitnan');
    d.obsMeanActive = mean(obsErrMasked, 2, 'omitnan');
    d.pairDist = pairDist;
    d.minPairActive = minPair;
end

function [pairDist, minPair] = pair_distances(pAgent, validMask)
    pairs = nchoosek(1:6, 2);
    numPts = size(pAgent, 1);
    pairDist = nan(numPts, size(pairs,1));
    for k = 1:size(pairs,1)
        i = pairs(k,1);
        j = pairs(k,2);
        d = vecnorm(pAgent(:,:,i) - pAgent(:,:,j), 2, 2);
        d(~(validMask(:,i) & validMask(:,j))) = NaN;
        pairDist(:,k) = d;
    end
    minPair = min(pairDist, [], 2, 'omitnan');
end

%% ========================= signal helpers =========================
function y = interp_scalar(sig, tRaw, tRef)
    if isfield(sig, 'time') && ~isempty(sig.time)
        t = sig.time(:);
    else
        t = linspace(tRaw(1), tRaw(end), numel(sig.signals.values)).';
    end
    raw = squeeze(sig.signals.values);
    y = interp1(t, raw(:), tRef, 'linear', 'extrap');
end

function y = interp_vec2(sig, tRaw, tRef)
    if isfield(sig, 'time') && ~isempty(sig.time)
        t = sig.time(:);
    else
        t = tRaw;
    end
    raw = force_to_Nx2(sig.signals.values);
    if numel(t) ~= size(raw, 1)
        t = linspace(tRaw(1), tRaw(end), size(raw, 1)).';
    end
    y = interp1(t, raw, tRef, 'linear', 'extrap');
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
    else
        error('Unrecognized vector signal shape: [%s]', num2str(sz));
    end
end

%% ========================= style =========================
function C = refined_colors()
    C.agent = [0.000 0.447 0.741;
               0.850 0.325 0.098;
               0.929 0.694 0.125;
               0.494 0.184 0.556;
               0.466 0.674 0.188;
               0.301 0.745 0.933];
    C.blue = [0.000 0.360 0.660];
    C.red = [0.790 0.120 0.140];
    C.dark = [0.15 0.15 0.15];
    C.snapshot = [0.78 0.05 0.08];
    C.boundFill = [0.82 0.86 0.90];
end

function set_refined_defaults()
    set(groot, 'defaultAxesFontName', 'Times New Roman');
    set(groot, 'defaultTextFontName', 'Times New Roman');
    set(groot, 'defaultLegendInterpreter', 'latex');
    set(groot, 'defaultTextInterpreter', 'latex');
    set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
end

function style_axes(ax)
    set(ax, 'TickDir', 'in', ...
        'LineWidth', 0.95, ...
        'XMinorTick', 'on', ...
        'YMinorTick', 'on', ...
        'FontSize', 10.5, ...
        'FontName', 'Times New Roman');
end

function save_refined(fig, outDir, baseName)
    exportgraphics(fig, fullfile(outDir, [baseName, '.eps']), 'ContentType', 'vector');
    exportgraphics(fig, fullfile(outDir, [baseName, '.jpg']), 'Resolution', 600);
end
