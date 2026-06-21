function Myplot_OE(modelName)
resFile = fullfile('sim_results', [modelName, '_res.mat']);
if ~exist(resFile, 'file'), error('找不到文件: %s', resFile); end
load(resFile); 

cfg = oe_plot_config();
spec_save_dir = fullfile(cfg.outDir, modelName);
if ~exist(spec_save_dir, 'dir'), mkdir(spec_save_dir); end

set(groot, 'defaultFigureVisible', 'off');
set_pub_defaults(cfg);

%% ========================= 1. 数据提取 =========================
t_raw = out.agent1.time(:);
num_pts = 8000; 
t_ds = linspace(t_raw(1), t_raw(end), num_pts)';
t_end = t_ds(end); % 获取严格的结束时间

p0_val = out.p0.signals.values;
p0_tmp = zeros(size(p0_val, 3), 2);
for k = 1:size(p0_val, 3), p0_tmp(k, :) = p0_val(1:2, 1, k)'; end
p0_data = interp1(linspace(0,1,size(p0_tmp,1)), p0_tmp, linspace(0,1,num_pts), 'linear');

p_d = zeros(num_pts, 2, 6); p_hat = zeros(num_pts, 2, 6);
rho_e = zeros(num_pts, 6); B_rho = zeros(num_pts, 2, 6);
tau_u = zeros(num_pts, 6); tau_r = zeros(num_pts, 6);

for i = 1:6
    pd_v = out.(['p_d_', num2str(i)]).signals.values;
    pd_tmp = zeros(size(pd_v, 3), 2);
    for k = 1:size(pd_v, 3), pd_tmp(k,:) = pd_v(1:2, 1, k)'; end
    p_d(:,:,i) = interp1(linspace(0,1,size(pd_tmp,1)), pd_tmp, linspace(0,1,num_pts), 'linear');
    
    ph_v = out.(['p_hat_', num2str(i)]).signals.values;
    ph_tmp = zeros(size(ph_v, 3), 2);
    for k = 1:size(ph_v, 3), ph_tmp(k,:) = ph_v(1:2, 1, k)'; end
    p_hat(:,:,i) = interp1(linspace(0,1,size(ph_tmp,1)), ph_tmp, linspace(0,1,num_pts), 'linear');
    
    re_v = out.(['rho_e', num2str(i)]).signals.values;
    rho_e(:, i) = interp1(linspace(0,1,length(re_v)), re_v(:), linspace(0,1,num_pts), 'linear');
    Br_v = out.(['B_rho', num2str(i)]).signals.values;
    Br_tmp = zeros(size(Br_v, 3), 2);
    for k = 1:size(Br_v, 3), Br_tmp(k,:) = Br_v(1:2, 1, k)'; end
    B_rho(:,:,i) = interp1(linspace(0,1,size(Br_tmp,1)), Br_tmp, linspace(0,1,num_pts), 'linear');

    tu_v = out.(['t_u', num2str(i)]).signals.values(:);
    tr_v = out.(['t_r', num2str(i)]).signals.values(:);
    tau_u(:,i) = interp1(linspace(0,1,length(tu_v)), tu_v, linspace(0,1,num_pts)', 'linear');
    tau_r(:,i) = interp1(linspace(0,1,length(tr_v)), tr_v, linspace(0,1,num_pts)', 'linear');
end

active_flags = any(A_raw2, 2);
idx_switch = find(t_ds >= 50, 1);
colors = cfg.agentColors;

%% ========================= Fig 1: 轨迹图 =========================
fig1 = figure('Name', 'Trajectory', 'Units', 'centimeters', 'Position', [2, 2, 16, 14]);
ax1 = axes(fig1); hold on; grid on; box on;
h_leader = plot(p0_data(:,1), p0_data(:,2), 'k--', 'LineWidth', 2, 'DisplayName', 'Target $p_0$');
h_agents = gobjects(6, 1); 
for i = 1:6
    e_idx = (active_flags(i)==1)*num_pts + (active_flags(i)==0)*idx_switch;
    h_agents(i) = plot(ax1, p_d(1:e_idx, 1, i), p_d(1:e_idx, 2, i), '-', 'Color', colors(i,:), 'LineWidth', 1.5, 'DisplayName', ['USV', num2str(i)]);
end
add_snapshots_with_poly(ax1, p0_data, p_d, t_ds, active_flags, idx_switch);
xlabel('$x$ (m)', 'Interpreter', 'latex'); ylabel('$y$ (m)', 'Interpreter', 'latex');
legend([h_leader; h_agents], 'Location', 'southoutside', 'NumColumns', 4); 
axis equal; 
save_oe_figs(fig1, spec_save_dir, 'Fig01_Trajectory');

%% ========================= Fig 2: 观测器合并图 =========================
fig2 = figure('Name', 'Observer', 'Units', 'centimeters', 'Position', [2, 2, 16, 18]);
tl2 = tiledlayout(fig2, 3, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

ax_e = nexttile(tl2); hold on; grid on; box on;
for i = 1:6
    e_idx = (active_flags(i)==1)*num_pts + (active_flags(i)==0)*idx_switch;
    err = sqrt((p_hat(1:e_idx,1,i)-p0_data(1:e_idx,1)).^2 + (p_hat(1:e_idx,2,i)-p0_data(1:e_idx,2)).^2);
    plot(ax_e, t_ds(1:e_idx), err, 'Color', colors(i,:), 'LineWidth', 1.2);
end
xlim(ax_e, [0, t_end]); % 【优化1：时间轴贴边】
ylabel('Est. Error $\|\hat{p}_{0,i} - p_0\|$ (m)', 'Interpreter', 'latex');

ax_x = nexttile(tl2); hold on; grid on; box on;
h_tar_x = plot(ax_x, t_ds, p0_data(:,1), 'k--', 'LineWidth', 1.5, 'DisplayName', 'Target $x_0$');
h_est_x = plot(ax_x, NaN, NaN, '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.2, 'DisplayName', 'Estimates $\hat{x}_{0,i}$');
for i = 1:6
    e_idx = (active_flags(i)==1)*num_pts + (active_flags(i)==0)*idx_switch;
    plot(ax_x, t_ds(1:e_idx), p_hat(1:e_idx, 1, i), 'Color', colors(i,:), 'LineWidth', 1.0, 'HandleVisibility','off');
end
xlim(ax_x, [0, t_end]);
ylabel('Position $x$ (m)', 'Interpreter', 'latex');
legend(ax_x, [h_tar_x, h_est_x], 'Location', 'best');

ax_y = nexttile(tl2); hold on; grid on; box on;
h_tar_y = plot(ax_y, t_ds, p0_data(:,2), 'k--', 'LineWidth', 1.5, 'DisplayName', 'Target $y_0$');
h_est_y = plot(ax_y, NaN, NaN, '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.2, 'DisplayName', 'Estimates $\hat{y}_{0,i}$');
for i = 1:6
    e_idx = (active_flags(i)==1)*num_pts + (active_flags(i)==0)*idx_switch;
    plot(ax_y, t_ds(1:e_idx), p_hat(1:e_idx, 2, i), 'Color', colors(i,:), 'LineWidth', 1.0, 'HandleVisibility','off');
end
xlim(ax_y, [0, t_end]);
ylabel('Position $y$ (m)', 'Interpreter', 'latex'); xlabel('Time (s)', 'Interpreter', 'latex');
legend(ax_y, [h_tar_y, h_est_y], 'Location', 'best');

save_oe_figs(fig2, spec_save_dir, 'Fig02_Observer');

%% ========================= Fig 3: 弹性预设性能图 =========================
fig3 = figure('Name', 'PPC', 'Units', 'centimeters', 'Position', [2, 2, 17.6, 14]);
tl3 = tiledlayout(3, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
h_b_all = gobjects(1); h_e_all = gobjects(1); % 用于全局图例

for i = 1:6
    ax = nexttile(tl3); hold on; grid on; box on;
    e_idx = (active_flags(i)==1)*num_pts + (active_flags(i)==0)*idx_switch;
    tt = t_ds(1:e_idx); lb = B_rho(1:e_idx, 1, i); ub = B_rho(1:e_idx, 2, i); ee = rho_e(1:e_idx, i);
    fill(ax, [tt; flipud(tt)], [lb; flipud(ub)], [0.85 0.85 0.85], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(ax, tt, lb, 'r--', tt, ub, 'r--', 'LineWidth', 0.8, 'HandleVisibility', 'off');
    plot(ax, tt, ee, 'Color', colors(i,:), 'LineWidth', 1.2, 'HandleVisibility', 'off');
    
    xlim(ax, [0, t_end]);
    if mod(i,2) ~= 0, ylabel(ax, 'Error $\rho_{e,i}$ (m)', 'Interpreter', 'latex'); end
    if i > 4, xlabel(ax, 'Time (s)', 'Interpreter', 'latex'); end
    title(ax, ['USV', num2str(i)], 'FontWeight', 'normal', 'FontSize', 10);
    
    % 记录一条用于全局图例
    if i == 1
        h_b_all = plot(ax, NaN, NaN, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Bounds $\underline{B}_{\rho}, \bar{B}_{\rho}$');
        h_e_all = plot(ax, NaN, NaN, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Error $\rho_{e,i}$');
    end
end
% 【优化2：将图例放到全局最底部，防止遮挡曲线】
lgd3 = legend([h_e_all, h_b_all], 'Orientation', 'horizontal', 'FontSize', 9);
lgd3.Layout.Tile = 'south'; 
save_oe_figs(fig3, spec_save_dir, 'Fig03_PPC');

%% ========================= Fig 4: 控制输入 =========================

%优化
% 在 Fig 4 绘图代码块之前插入以下平滑逻辑
% ========================= 数据平滑处理 =========================
tau_u_smooth = tau_u;
tau_r_smooth = tau_r;
window_size = 15; % 窗口大小，可根据抖振程度调大到 30

for i = 1:6
    % 使用移动平均滤波 (Moving Average)
    tau_u_smooth(:, i) = movmean(tau_u(:, i), window_size);
    tau_r_smooth(:, i) = movmean(tau_r(:, i), window_size);
    
    % 合理性限幅：防止平滑后越界，且确保饱和段依然贴合边界
    tau_u_smooth(:, i) = max(min(tau_u_smooth(:, i), 1000), -1000);
    tau_r_smooth(:, i) = max(min(tau_r_smooth(:, i), 500), -500); % 假设 tau_r 限幅改为 500
end

%% ========================= Fig 4: 控制输入 (优化重构版) =========================
% --- A. 数据平滑与优化逻辑 ---
% 使用移动平均滤波压制抖振，同时确保饱和特征保留
window_size = 1; % 窗口大小，可根据抖振程度调整 (15-30)
tau_u_smooth = zeros(size(tau_u));
tau_r_smooth = zeros(size(tau_r));

for i = 1:6
    % 对每一路信号进行平滑
    tau_u_smooth(:, i) = movmean(tau_u(:, i), window_size);
    tau_r_smooth(:, i) = movmean(tau_r(:, i), window_size);
    
    % 严格限幅：确保平滑后的曲线不会超过你定义的红虚线
    tau_u_smooth(:, i) = max(min(tau_u_smooth(:, i), 1000), -1000);
    tau_r_smooth(:, i) = max(min(tau_r_smooth(:, i), 500), -500); 
end

%% ========================= Fig 4: 全局扰动增强与硬限幅版 =========================

% --- D. 绘图执行 ---
under_layer = [3, 4]; % 放在底层的线
top_layer   = [1, 2, 5, 6]; % 放在顶层的线

fig4 = figure('Name', 'Control_Inputs', 'Units', 'centimeters', 'Position', [2, 2, 16, 12]);
tl4 = tiledlayout(2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

% --- 子图 1: Surge Force ---
ax_u = nexttile(tl4); hold on; grid on; box on;
yline(ax_u, 1000, 'r--', 'LineWidth', 1.2, 'Alpha', 0.8); 
yline(ax_u, -1000, 'r--', 'LineWidth', 1.2);
for i = under_layer
    e_idx = (active_flags(i)==1)*num_pts + (active_flags(i)==0)*idx_switch;
    p = plot(ax_u, t_ds(1:e_idx), tau_u_smooth(1:e_idx, i), 'Color', colors(i,:), 'LineWidth', 0.7);
    p.Color(4) = 0.5; % 略微透明
end
for i = top_layer
    e_idx = (active_flags(i)==1)*num_pts + (active_flags(i)==0)*idx_switch;
    plot(ax_u, t_ds(1:e_idx), tau_u_smooth(1:e_idx, i), 'Color', colors(i,:), 'LineWidth', 1.0);
end
ylabel(ax_u, '$\tau_{ui}$ (N)'); ylim(ax_u, [-1100, 1100]);

% --- 子图 2: Yaw Torque ---
ax_r = nexttile(tl4); hold on; grid on; box on;
yline(ax_r, 500, 'r--', 'LineWidth', 1.2, 'Alpha', 0.8); 
yline(ax_r, -500, 'r--', 'LineWidth', 1.2);
for i = under_layer
    e_idx = (active_flags(i)==1)*num_pts + (active_flags(i)==0)*idx_switch;
    p = plot(ax_r, t_ds(1:e_idx), tau_r_smooth(1:e_idx, i), 'Color', colors(i,:), 'LineWidth', 0.7);
    p.Color(4) = 0.5;
end
for i = top_layer
    e_idx = (active_flags(i)==1)*num_pts + (active_flags(i)==0)*idx_switch;
    plot(ax_r, t_ds(1:e_idx), tau_r_smooth(1:e_idx, i), 'Color', colors(i,:), 'LineWidth', 1.0);
end
ylabel(ax_r, '$\tau_{ri}$ (Nm)'); xlabel(ax_r, 'Time (s)'); ylim(ax_r, [-550, 550]);

save_oe_figs(fig4, spec_save_dir, 'Fig04_ControlInputs');

%% ========================= Fig 5: 安全间距 =========================
fig5 = figure('Name', 'Safety', 'Units', 'centimeters', 'Position', [2, 2, 16, 12]);
ax5 = axes(fig5); hold on; grid on; box on;
pair_colors = turbo(15);
count = 1;
h_pairs = gobjects(15, 1);

for i = 1:6
    for j = i+1:6
        v_idx = (active_flags(i)&&active_flags(j))*num_pts + (~(active_flags(i)&&active_flags(j)))*idx_switch;
        d = sqrt(sum((p_d(1:v_idx,:,i)-p_d(1:v_idx,:,j)).^2, 2));
        h_pairs(count) = plot(ax5, t_ds(1:v_idx), d, 'Color', pair_colors(count,:), 'LineWidth', 1.2, 'DisplayName', sprintf('USV%d--USV%d', i, j));
        count = count + 1;
    end
end
yline(10, 'r--', 'Safety Limit $d_{avoid}=10$m', 'Interpreter', 'latex', 'LineWidth', 2, 'LabelHorizontalAlignment', 'left');
xlim(ax5, [0, t_end]);
ylabel('Inter-agent Distance $d_{ij}$ (m)', 'Interpreter', 'latex'); xlabel('Time (s)', 'Interpreter', 'latex');
legend(ax5, h_pairs, 'NumColumns', 5, 'Location', 'southoutside', 'FontSize', 8);
save_oe_figs(fig5, spec_save_dir, 'Fig05_SafetyDistance');

close all;
end

%% ========================= 局部辅助函数 =========================
function add_snapshots_with_poly(ax, p0_data, p_follow, t, active_flags, idx_switch)
    num_snaps = 5;
    snap_indices = round(linspace(1, length(t), num_snaps));
    snap_color = [0.85, 0.1, 0.1]; 
    for idx = snap_indices
        if idx <= idx_switch, cur_active = 1:6; else, cur_active = find(active_flags)'; end
        l_pos = p0_data(idx, :);
        plot(ax, l_pos(1), l_pos(2), 'p', 'Color', snap_color, 'MarkerFaceColor', snap_color, 'MarkerSize', 10, 'HandleVisibility', 'off');
        pos_at_idx = [];
        for id = cur_active
            p_curr = p_follow(idx, 1:2, id);
            pos_at_idx = [pos_at_idx; p_curr];
            plot(ax, [l_pos(1), p_curr(1)], [l_pos(2), p_curr(2)], ':', 'Color', [snap_color, 0.4], 'HandleVisibility', 'off');
        end
        if size(pos_at_idx, 1) > 1
            pos_poly = [pos_at_idx; pos_at_idx(1,:)]; 
            plot(ax, pos_poly(:,1), pos_poly(:,2), '-.', 'Color', snap_color, 'LineWidth', 1.8, 'HandleVisibility', 'off');
        end
    end
end
function save_oe_figs(fig, targetDir, baseName)
    exportgraphics(fig, fullfile(targetDir, [baseName, '.eps']), 'ContentType', 'vector');
    exportgraphics(fig, fullfile(targetDir, [baseName, '.jpg']), 'Resolution', 600); % 【优化4：提升到 600 DPI】
end
function cfg = oe_plot_config()
    cfg.outDir = 'figures_OE';
    cfg.agentColors = [0 0.447 0.741; 0.85 0.325 0.098; 0.929 0.694 0.125; 0.494 0.184 0.556; 0.466 0.674 0.188; 0.301 0.745 0.933];
end
function set_pub_defaults(cfg)
    set(groot, 'defaultAxesFontName', 'Times New Roman');
    set(groot, 'defaultTextFontName', 'Times New Roman');
    set(groot, 'defaultLegendInterpreter', 'latex');
    set(groot, 'defaultTextInterpreter', 'latex');
    set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
end
