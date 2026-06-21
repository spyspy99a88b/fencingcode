function compare_abc_vertical_active_set()
% ============================================================
% Publication-quality vertical 3-panel figure
%
% Panel (a): use {'disturb','disturb1','disturb2'}
% Panel (b): use {'disturb','nn2023b1','disturb2'}
% Panel (c): use {'disturb','disturb1','disturb2'}
%
% Metrics:
%   (a) Maximum observer error over active set
%   (b) Guidance-center error over active set
%   (c) Mean tracking error over active set
%
% Output:
%   figures_OE/Comparison/ABC_Vertical_Combined.eps
%   figures_OE/Comparison/ABC_Vertical_Combined.png
% ============================================================

    % ---------------- settings ----------------
    modelList_AC = {'disturb','disturb1','disturb2'};
    modelList_B  = {'disturb','nn2023b1','disturb2'};

    switchTimes   = [10 50];
    dropTime      = 50;
    removedAgents = [5 6];

    out_dir = fullfile('figures_OE', 'Comparison');
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end

    % ---------------- extract data ----------------
    dataAC = extract_active_set_metrics(modelList_AC, dropTime, removedAgents);
    dataB  = extract_active_set_metrics(modelList_B,  dropTime, removedAgents);

    % ---------------- style ----------------
    colors = [0.00, 0.45, 0.74;
              0.85, 0.33, 0.10;
              0.47, 0.67, 0.19];
    styles = {'-','--','-.'};

    % ---------------- main figure ----------------
    fig = figure('Units', 'centimeters', 'Position', [2, 2, 16.5, 24]);
    tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    % =========================================================
    % (a) Maximum observer error
    % =========================================================
    ax1 = nexttile(tl, 1);
    hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on');
    style_axes(ax1);

    for m = 1:numel(dataAC)
        plot(ax1, dataAC(m).t, dataAC(m).max_obs_active, ...
            'Color', colors(m,:), ...
            'LineStyle', styles{m}, ...
            'LineWidth', 2.3, ...
            'DisplayName', dataAC(m).name);
    end
    add_ref_lines(ax1, switchTimes, dropTime);
    xlabel(ax1, 'Time (s)', 'Interpreter', 'latex', 'FontSize', 14);
    ylabel(ax1, 'Maximum observer error (m)', 'Interpreter', 'latex', 'FontSize', 14);
    title(ax1, '(a) Maximum observer error', 'Interpreter', 'latex', 'FontSize', 16);

    % =========================================================
    % (b) Guidance-center error
    % =========================================================
    ax2 = nexttile(tl, 2);
    hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on');
    style_axes(ax2);

    for m = 1:numel(dataB)
        plot(ax2, dataB(m).t, dataB(m).center_err_active, ...
            'Color', colors(m,:), ...
            'LineStyle', styles{m}, ...
            'LineWidth', 2.3, ...
            'DisplayName', dataB(m).name);
    end
    add_ref_lines(ax2, switchTimes, dropTime);
    xlabel(ax2, 'Time (s)', 'Interpreter', 'latex', 'FontSize', 14);
    ylabel(ax2, 'Guidance-center error (m)', 'Interpreter', 'latex', 'FontSize', 14);
    title(ax2, '(b) Guidance-center error', 'Interpreter', 'latex', 'FontSize', 16);

    % =========================================================
    % (c) Mean tracking error
    % =========================================================
    ax3 = nexttile(tl, 3);
    hold(ax3, 'on'); grid(ax3, 'on'); box(ax3, 'on');
    style_axes(ax3);

    for m = 1:numel(dataAC)
        plot(ax3, dataAC(m).t, dataAC(m).mean_rho_active, ...
            'Color', colors(m,:), ...
            'LineStyle', styles{m}, ...
            'LineWidth', 2.3, ...
            'DisplayName', dataAC(m).name);
    end
    add_ref_lines(ax3, switchTimes, dropTime);
    xlabel(ax3, 'Time (s)', 'Interpreter', 'latex', 'FontSize', 14);
    ylabel(ax3, 'Mean tracking error (m)', 'Interpreter', 'latex', 'FontSize', 14);
    title(ax3, '(c) Mean tracking error', 'Interpreter', 'latex', 'FontSize', 16);

    % ---------------- one global legend ----------------
    lgd = legend(ax1, 'Location', 'northoutside', ...
        'Orientation', 'horizontal', ...
        'NumColumns', 3, ...
        'Interpreter', 'latex', ...
        'FontSize', 12, ...
        'EdgeColor', 'none');
    lgd.Layout.Tile = 'north';

    % ---------------- save ----------------
    epsPath = fullfile(out_dir, 'ABC_Vertical_Combined.eps');
    pngPath = fullfile(out_dir, 'ABC_Vertical_Combined.png');

    exportgraphics(fig, epsPath, 'ContentType', 'vector');
    exportgraphics(fig, pngPath, 'Resolution', 600);

    fprintf('Saved files:\n%s\n%s\n', epsPath, pngPath);
end

%% ============================================================
% Extract active-set metrics
%% ============================================================
function data_all = extract_active_set_metrics(modelList, dropTime, removedAgents)

    legend_names = {'Proposed method', ...
                    'Asymptotic fixed-gain controller', ...
                    'Linear weak observer'};

    num_models = numel(modelList);
    num_agents = 6;
    num_pts    = 6000;

    valid_model = false(num_models,1);
    t_start_all = nan(num_models,1);
    t_end_all   = nan(num_models,1);

    % ---------- common time window ----------
    for m = 1:num_models
        mName = char(modelList{m});
        resFile = fullfile('sim_results', [mName, '_res.mat']);
        if ~exist(resFile, 'file')
            warning('Result file not found: %s', resFile);
            continue;
        end

        S = load(resFile);
        D = get_main_container(S);
        tout = get_numeric_signal(D, 'tout');

        if isempty(tout)
            warning('Failed to read tout from %s', mName);
            continue;
        end

        tout = tout(:);
        t_start_all(m) = tout(1);
        t_end_all(m)   = tout(end);
        valid_model(m) = true;
    end

    if ~any(valid_model)
        error('No valid result files found.');
    end

    t_ref = linspace(max(t_start_all(valid_model)), min(t_end_all(valid_model)), num_pts)';

    % ---------- active set ----------
    active_mask = true(num_pts, num_agents);
    idx_drop = t_ref >= dropTime;
    active_mask(idx_drop, removedAgents) = false;
    N_act = sum(active_mask, 2);

    % ---------- extract ----------
    data_all = struct();
    for m = 1:num_models
        mName = char(modelList{m});
        resFile = fullfile('sim_results', [mName, '_res.mat']);
        if ~exist(resFile, 'file')
            continue;
        end

        S = load(resFile);
        D = get_main_container(S);
        tout = get_numeric_signal(D, 'tout');
        tout = tout(:);

        data_all(m).name = legend_names{m};
        data_all(m).t    = t_ref;
        data_all(m).N_act = N_act;

        % target p0
        p0sig = get_signal(D, 'p0');
        [t_p0, p0_raw] = read_vec2(p0sig, tout);
        p0_ref = interp1(t_p0, p0_raw, t_ref, 'linear', 'extrap');

        % (a) maximum observer error over active set
        obs_mat = nan(num_pts, num_agents);
        for i = 1:num_agents
            fname = sprintf('p_hat_%d', i);
            sig = get_signal(D, fname);
            [t_ph, ph_raw] = read_vec2(sig, tout);
            ph_ref = interp1(t_ph, ph_raw, t_ref, 'linear', 'extrap');
            obs_err_i = sqrt(sum((ph_ref - p0_ref).^2, 2));
            obs_mat(:, i) = obs_err_i;
        end
        obs_mat(~active_mask) = NaN;
        data_all(m).max_obs_active = max(obs_mat, [], 2, 'omitnan');
        data_all(m).max_obs_active(all(~active_mask,2)) = NaN;

        % (b) guidance-center error over active set
        pd_stack = nan(num_pts, 2, num_agents);
        for i = 1:num_agents
            fname = sprintf('p_d_%d', i);
            sig = get_signal(D, fname);
            [t_pd, pd_raw] = read_vec2(sig, tout);
            pd_ref = interp1(t_pd, pd_raw, t_ref, 'linear', 'extrap');
            pd_stack(:,:,i) = pd_ref;
        end

        pd_center = nan(num_pts, 2);
        for k = 1:num_pts
            act_idx = find(active_mask(k,:));
            pd_center(k,:) = mean(pd_stack(k,:,act_idx), 3);
        end
        data_all(m).center_err_active = sqrt(sum((pd_center - p0_ref).^2, 2));

        % (c) mean tracking error over active set
        rho_mat = nan(num_pts, num_agents);
        for i = 1:num_agents
            fname = sprintf('rho_e%d', i);
            sig = get_signal(D, fname);
            [t_rho, rho_raw] = read_scalar(sig, tout);
            rho_ref = interp1(t_rho, abs(rho_raw), t_ref, 'linear', 'extrap');
            rho_mat(:, i) = rho_ref;
        end
        rho_mat(~active_mask) = NaN;
        data_all(m).mean_rho_active = sum(rho_mat, 2, 'omitnan') ./ N_act;
    end
end

%% ============================================================
% Helpers
%% ============================================================
function D = get_main_container(S)
    if isfield(S, 'out')
        D = S.out;
    else
        D = S;
    end
end

function val = get_numeric_signal(D, name)
    val = [];

    if isstruct(D)
        if isfield(D, name)
            val = D.(name);
            return;
        end
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
        if ~isempty(val)
            return;
        end
    catch
    end
end

function sig = get_signal(D, name)
    sig = [];

    if isstruct(D)
        if isfield(D, name)
            sig = D.(name);
            return;
        end
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
        if ~isempty(sig)
            return;
        end
    catch
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

    if ismatrix(v) && size(v,2) == 2
        y = v;
        return;
    end

    if ismatrix(v) && size(v,1) == 2
        y = v.';
        return;
    end

    if ndims(v) == 3 && sz(1) == 2 && sz(2) == 1
        y = squeeze(v(:,1,:)).';
        return;
    end

    if ndims(v) == 3 && sz(1) == 1 && sz(2) == 2
        y = squeeze(v(1,:,:)).';
        return;
    end

    if ndims(v) == 3 && sz(2) == 1 && sz(3) == 2
        y = squeeze(v(:,1,:));
        return;
    end

    error('Unrecognized vector signal shape: [%s]', num2str(sz));
end

function style_axes(ax)
    set(ax, 'TickDir', 'in', ...
            'LineWidth', 1.1, ...
            'XMinorTick', 'on', ...
            'YMinorTick', 'on', ...
            'FontSize', 12, ...
            'FontName', 'Times New Roman');
end

function add_ref_lines(ax, switchTimes, dropTime)
    for k = 1:numel(switchTimes)
        xline(ax, switchTimes(k), '--', ...
            'Color', [0.35 0.35 0.35], ...
            'LineWidth', 1.0, ...
            'HandleVisibility', 'off');
    end
    xline(ax, dropTime, '-.', ...
        'Color', [0.25 0.25 0.25], ...
        'LineWidth', 1.1, ...
        'HandleVisibility', 'off');
end