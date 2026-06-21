function compare_fourpanel_final(modelList, switchTimes, satU, satR)
% ============================================================
% SCI-style 4-panel comparison figure
%
% Inputs:
%   modelList   : e.g. {'disturb','disturb1','disturb2'}
%   switchTimes : e.g. [10 50]
%   satU        : surge saturation bound, e.g. 60
%   satR        : yaw saturation bound,   e.g. 30
%
% Output:
%   figures_OE/Comparison/Comp_4Panel_Main.eps
%   figures_OE/Comparison/Comp_4Panel_Main.png
%
% Four subplots:
%   (a) Maximum observer error
%   (b) Guidance-center error
%   (c) Mean tracking error
%   (d) Maximum normalized control demand
% ============================================================

    if nargin < 1 || isempty(modelList)
        modelList = {'disturb','disturb1','disturb2'};
    end
    if nargin < 2
        switchTimes = [];
    end
    if nargin < 3 || isempty(satU)
        satU = 60;
    end
    if nargin < 4 || isempty(satR)
        satR = 30;
    end

    legend_names = {'Proposed method', ...
                    'Asymptotic fixed-gain controller', ...
                    'Linear weak observer'};

    colors = [0.00, 0.45, 0.74;
              0.85, 0.33, 0.10;
              0.47, 0.67, 0.19];
    styles = {'-','--','-.'};

    num_models = numel(modelList);
    num_agents = 6;
    num_pts = 6000;

    data_all = struct();
    valid_model = false(num_models,1);
    t_start_all = nan(num_models,1);
    t_end_all   = nan(num_models,1);

    %% =========================================================
    % 1) Find common time window from tout
    %% =========================================================
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
        error('No valid result files found. Failed to extract tout.');
    end

    t_ref = linspace(max(t_start_all(valid_model)), min(t_end_all(valid_model)), num_pts)';

    %% =========================================================
    % 2) Extract all four metrics
    %% =========================================================
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

        data_all(m).t = t_ref;

        % ---------- p0 ----------
        p0sig = get_signal(D, 'p0');
        [t_p0, p0_raw] = read_vec2(p0sig, tout);
        p0_ref = interp1(t_p0, p0_raw, t_ref, 'linear', 'extrap');

        % =====================================================
        % (a) Maximum observer error
        % =====================================================
        obs_mat = [];
        for i = 1:num_agents
            fname = sprintf('p_hat_%d', i);
            sig = get_signal(D, fname);
            [t_ph, ph_raw] = read_vec2(sig, tout);
            ph_ref = interp1(t_ph, ph_raw, t_ref, 'linear', 'extrap');
            obs_err_i = sqrt(sum((ph_ref - p0_ref).^2, 2));
            obs_mat = [obs_mat, obs_err_i]; %#ok<AGROW>
        end
        data_all(m).max_obs = max(obs_mat, [], 2);

        % =====================================================
        % (b) Guidance-center error
        %     norm( mean(p_d_i) - p0 )
        % =====================================================
        pd_all = zeros(num_pts, 2, num_agents);
        valid_pd = 0;
        for i = 1:num_agents
            fname = sprintf('p_d_%d', i);
            sig = get_signal(D, fname);
            if ~isempty(sig)
                [t_pd, pd_raw] = read_vec2(sig, tout);
                pd_ref = interp1(t_pd, pd_raw, t_ref, 'linear', 'extrap');
                valid_pd = valid_pd + 1;
                pd_all(:,:,valid_pd) = pd_ref;
            end
        end
        if valid_pd > 0
            pd_center = mean(pd_all(:,:,1:valid_pd), 3);
            center_err = sqrt(sum((pd_center - p0_ref).^2, 2));
            data_all(m).center_err = center_err;
        else
            warning('%s: no p_d_i signals found.', mName);
        end

        % =====================================================
        % (c) Mean tracking error
        % =====================================================
        rho_mat = [];
        for i = 1:num_agents
            fname = sprintf('rho_e%d', i);
            sig = get_signal(D, fname);
            [t_rho, rho_raw] = read_scalar(sig, tout);
            rho_ref = interp1(t_rho, abs(rho_raw), t_ref, 'linear', 'extrap');
            rho_mat = [rho_mat, rho_ref]; %#ok<AGROW>
        end
        data_all(m).mean_rho = mean(rho_mat, 2);

        % =====================================================
        % (d) Maximum normalized control demand
        % =====================================================
        gamma_mat = [];
        for i = 1:num_agents
            fu = sprintf('t_u%d', i);
            fr = sprintf('t_r%d', i);

            sig_u = get_signal(D, fu);
            sig_r = get_signal(D, fr);

            [t_u, tu_raw] = read_scalar(sig_u, tout);
            [t_r, tr_raw] = read_scalar(sig_r, tout);

            tu_ref = interp1(t_u, tu_raw, t_ref, 'linear', 'extrap');
            tr_ref = interp1(t_r, tr_raw, t_ref, 'linear', 'extrap');

            gamma_i = max(abs(tu_ref)/satU, abs(tr_ref)/satR);
            gamma_mat = [gamma_mat, gamma_i]; %#ok<AGROW>
        end
        data_all(m).max_gamma = max(gamma_mat, [], 2);
    end

    %% =========================================================
    % 3) Plot 2x2 figure
    %% =========================================================
    fig = figure('Units', 'centimeters', 'Position', [2, 2, 18, 13]);
    tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

    % ------------------ (a) Max observer error ------------------
    ax1 = nexttile(tl, 1); hold(ax1, 'on'); grid(ax1, 'on'); box(ax1, 'on');
    style_axes(ax1);
    for m = 1:num_models
        plot(ax1, data_all(m).t, data_all(m).max_obs, ...
            'Color', colors(m,:), 'LineStyle', styles{m}, ...
            'LineWidth', 2.0, 'DisplayName', legend_names{m});
    end
    add_switch_lines(ax1, switchTimes);
    xlabel(ax1, 'Time (s)', 'Interpreter', 'latex');
    ylabel(ax1, 'Maximum observer error (m)', 'Interpreter', 'latex');
    title(ax1, '(a) Maximum observer error', 'Interpreter', 'latex');

    % ------------------ (b) Guidance-center error ------------------
    ax2 = nexttile(tl, 2); hold(ax2, 'on'); grid(ax2, 'on'); box(ax2, 'on');
    style_axes(ax2);
    for m = 1:num_models
        plot(ax2, data_all(m).t, data_all(m).center_err, ...
            'Color', colors(m,:), 'LineStyle', styles{m}, ...
            'LineWidth', 2.0);
    end
    add_switch_lines(ax2, switchTimes);
    xlabel(ax2, 'Time (s)', 'Interpreter', 'latex');
    ylabel(ax2, 'Guidance-center error (m)', 'Interpreter', 'latex');
    title(ax2, '(b) Guidance-center error', 'Interpreter', 'latex');

    % ------------------ (c) Mean tracking error ------------------
    ax3 = nexttile(tl, 3); hold(ax3, 'on'); grid(ax3, 'on'); box(ax3, 'on');
    style_axes(ax3);
    for m = 1:num_models
        plot(ax3, data_all(m).t, data_all(m).mean_rho, ...
            'Color', colors(m,:), 'LineStyle', styles{m}, ...
            'LineWidth', 2.0);
    end
    add_switch_lines(ax3, switchTimes);
    xlabel(ax3, 'Time (s)', 'Interpreter', 'latex');
    ylabel(ax3, 'Mean tracking error (m)', 'Interpreter', 'latex');
    title(ax3, '(c) Mean tracking error', 'Interpreter', 'latex');

    % ------------------ (d) Max normalized control demand ------------------
    ax4 = nexttile(tl, 4); hold(ax4, 'on'); grid(ax4, 'on'); box(ax4, 'on');
    style_axes(ax4);
    for m = 1:num_models
        plot(ax4, data_all(m).t, data_all(m).max_gamma, ...
            'Color', colors(m,:), 'LineStyle', styles{m}, ...
            'LineWidth', 2.0);
    end
    yline(ax4, 1.0, 'k--', 'LineWidth', 1.1, 'HandleVisibility', 'off');
    add_switch_lines(ax4, switchTimes);
    xlabel(ax4, 'Time (s)', 'Interpreter', 'latex');
    ylabel(ax4, 'Maximum normalized demand', 'Interpreter', 'latex');
    title(ax4, '(d) Maximum normalized control demand', 'Interpreter', 'latex');

    % ------------------ global legend ------------------
    lgd = legend(ax1, 'Location', 'northoutside', ...
        'Orientation', 'horizontal', 'NumColumns', 3, ...
        'EdgeColor', 'none', 'Interpreter', 'latex');
    lgd.Layout.Tile = 'north';

    %% =========================================================
    % 4) Save figure
    %% =========================================================
    out_dir = fullfile('figures_OE', 'Comparison');
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end

    exportgraphics(fig, fullfile(out_dir, 'Comp_4Panel_Main.eps'), 'ContentType', 'vector');
    exportgraphics(fig, fullfile(out_dir, 'Comp_4Panel_Main.png'), 'Resolution', 600);

    fprintf('Figure saved to:\n');
    fprintf('%s\n', fullfile(out_dir, 'Comp_4Panel_Main.eps'));
    fprintf('%s\n', fullfile(out_dir, 'Comp_4Panel_Main.png'));
end

%% ==================== helper functions ====================

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

function add_switch_lines(ax, switchTimes)
    for k = 1:numel(switchTimes)
        xline(ax, switchTimes(k), 'k--', 'LineWidth', 1.0, ...
            'HandleVisibility', 'off');
    end
end

function style_axes(ax)
    set(ax, 'TickDir', 'in', ...
            'LineWidth', 1.1, ...
            'XMinorTick', 'on', ...
            'YMinorTick', 'on', ...
            'FontSize', 10, ...
            'FontName', 'Times New Roman');
end