function compare_main_OE_v2(modelList, metricName, switchTimes)

    if nargin < 1 || isempty(modelList)
        modelList = {'disturb','disturb1','disturb2'};
    end
    if nargin < 2 || isempty(metricName)
        metricName = 'max_obs';
    end
    if nargin < 3
        switchTimes = [];
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

    %% 1) 用 tout 建公共时间轴
    for m = 1:num_models
        mName = char(modelList{m});
        resFile = fullfile('sim_results', [mName, '_res.mat']);
        if ~exist(resFile, 'file')
            warning('Result file not found: %s', resFile);
            continue;
        end

        S = load(resFile);
        if isfield(S, 'out')
            D = S.out;
        else
            D = S;
        end

        if isfield(D, 'tout')
            t_base = D.tout(:);
        else
            warning('No tout found in %s', mName);
            continue;
        end

        t_start_all(m) = t_base(1);
        t_end_all(m)   = t_base(end);
        valid_model(m) = true;
    end

    if ~any(valid_model)
        error('No valid result files found: no tout detected.');
    end

    t_ref = linspace(max(t_start_all(valid_model)), min(t_end_all(valid_model)), num_pts)';

    %% 2) 提取数据
    for m = 1:num_models
        mName = char(modelList{m});
        resFile = fullfile('sim_results', [mName, '_res.mat']);
        if ~exist(resFile, 'file')
            continue;
        end

        S = load(resFile);
        if isfield(S, 'out')
            D = S.out;
        else
            D = S;
        end

        data_all(m).t = t_ref;

        % p0
        [t_p0, p0_raw] = read_vec2(D.p0, D.tout);
        p0_ref = interp1(t_p0, p0_raw, t_ref, 'linear', 'extrap');

        % observer
        obs_mat = [];
        for i = 1:num_agents
            fname = sprintf('p_hat_%d', i);
            [t_ph, ph_raw] = read_vec2(D.(fname), D.tout);
            ph_ref = interp1(t_ph, ph_raw, t_ref, 'linear', 'extrap');
            obs_err_i = sqrt(sum((ph_ref - p0_ref).^2, 2));
            obs_mat = [obs_mat, obs_err_i]; %#ok<AGROW>
        end
        data_all(m).max_obs  = max(obs_mat, [], 2);
        data_all(m).mean_obs = mean(obs_mat, 2);

        % tracking
        rho_mat = [];
        for i = 1:num_agents
            fname = sprintf('rho_e%d', i);
            [t_rho, rho_raw] = read_scalar(D.(fname), D.tout);
            rho_ref = interp1(t_rho, abs(rho_raw), t_ref, 'linear', 'extrap');
            rho_mat = [rho_mat, rho_ref]; %#ok<AGROW>
        end
        data_all(m).mean_rho = mean(rho_mat, 2);
    end

    %% 3) 作图
    figure('Units','centimeters','Position',[2,2,16,11]);
    hold on; grid on; box on;

    for m = 1:num_models
        plot(data_all(m).t, data_all(m).(metricName), ...
            'Color', colors(m,:), ...
            'LineStyle', styles{m}, ...
            'LineWidth', 2.0, ...
            'DisplayName', legend_names{m});
    end

    for k = 1:numel(switchTimes)
        xline(switchTimes(k), 'k--', 'LineWidth', 1.0, 'HandleVisibility', 'off');
    end

    xlabel('Time (s)', 'Interpreter', 'latex');
    switch metricName
        case 'max_obs'
            ylabel('Maximum observer error (m)', 'Interpreter', 'latex');
        case 'mean_obs'
            ylabel('Mean observer error (m)', 'Interpreter', 'latex');
        case 'mean_rho'
            ylabel('Mean tracking error (m)', 'Interpreter', 'latex');
        otherwise
            ylabel(metricName, 'Interpreter', 'none');
    end

    legend('Location', 'best', 'Interpreter', 'latex');
    set(gca, 'TickDir', 'in', 'LineWidth', 1.1, 'FontName', 'Times New Roman');
end

function [t, y] = read_scalar(sig, tout)
    if isfield(sig, 'time') && ~isempty(sig.time)
        t = sig.time(:);
    else
        t = tout(:);
    end
    y = squeeze(sig.signals.values);
    y = y(:);
end

function [t, y] = read_vec2(sig, tout)
    if isfield(sig, 'time') && ~isempty(sig.time)
        t = sig.time(:);
    else
        t = tout(:);
    end

    v = sig.signals.values;
    sz = size(v);

    if ismatrix(v) && size(v,2) == 2
        y = v;
    elseif ismatrix(v) && size(v,1) == 2
        y = v.';
    elseif ndims(v) == 3 && sz(1) == 2 && sz(2) == 1
        y = squeeze(v(:,1,:)).';
    elseif ndims(v) == 3 && sz(1) == 1 && sz(2) == 2
        y = squeeze(v(1,:,:)).';
    elseif ndims(v) == 3 && sz(2) == 1 && sz(3) == 2
        y = squeeze(v(:,1,:));
    else
        error('Unrecognized vector signal shape: [%s]', num2str(sz));
    end
end