% =========================================================
% 完全按照你的习惯：按时间索引循环提取数据
% =========================================================
close all
%% 1. 数据读取
t = out.agent1.time; % 直接取系统统一的仿真时间，保证长度一定
N_steps = length(t);
N_agents = 6;

% 提取领航者原始矩阵 (通常格式为 2 x 1 x 75001)
p0_val = out.p0.signals.values;
v0_val = out.v0.signals.values;

% 领航者数据提取 (完美复刻你的代码习惯)
for k = 1:size(out.p0.time,1)
    p0_data(k, :) = p0_val(1:2, 1, k)';
    v0_data(k, :) = v0_val(1:2, 1, k)';
end

% 跟随者数据提取
for i = 1:N_agents
    % 动态读取每个模块的 signals.values 原始矩阵
    ph_val = out.(['p_hat_', num2str(i)]).signals.values;
    vh_val = out.(['v_hat_', num2str(i)]).signals.values;
    pd_val = out.(['p_d_', num2str(i)]).signals.values;
    
    % 按时间维度切片，转置后直接赋值，拒绝中间变量！
    for k = 1:N_steps
        p_hat(k, :, i) = ph_val(1:2, 1, k)';
        v_hat(k, :, i) = vh_val(1:2, 1, k)';
        p_d(k, :, i)   = pd_val(1:2, 1, k)';
    end
end

% 定义绘图颜色表
colors = lines(N_agents+1);

%% 2. 绘制 2D 运动轨迹图
% ==== 提前设置切换时间和存活判断 ====
t_switch = 50; 
% 找到 50s 对应的时间步长索引
idx_switch = find(t >= t_switch, 1); 
if isempty(idx_switch)
    idx_switch = N_steps; % 容错保护
end

% 根据 A_raw2 判断哪些智能体在 50s 后依然存活
% any(A_raw2, 2) 会检查每一行，如果不全为0则返回逻辑 1 (存活)
active_flags = any(A_raw2, 2); 

figure('Name', '2D 运动轨迹图上层', 'Position', [100, 100, 700, 600]);
hold on; grid on; box on;

% 领航者轨迹
plot(p0_data(:,1), p0_data(:,2), 'k--', 'LineWidth', 2, 'DisplayName', 'Leader p_0');
plot(p0_data(1,1), p0_data(1,2), 'ks', 'MarkerSize', 8, 'MarkerFaceColor', 'k', 'HandleVisibility', 'off'); 
plot(p0_data(end,1), p0_data(end,2), 'k*', 'MarkerSize', 8, 'HandleVisibility', 'off'); 

% 跟随者期望轨迹
for i = 1:N_agents
    % 判断该智能体画到哪一个时刻停止
    if active_flags(i)
        end_idx = N_steps;    % 存活，画到最后
    else
        end_idx = idx_switch; % 掉线，只画到 50s 切换时刻
    end
    
    % 只绘制从 1 到 end_idx 的轨迹
    plot(p_d(1:end_idx,1,i), p_d(1:end_idx,2,i), '-', 'Color', colors(i,:), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('USV%d desired', i));
    % 绘制起点圈圈
    plot(p_d(1,1,i), p_d(1,2,i), 'o', 'Color', colors(i,:), 'MarkerFaceColor', colors(i,:), 'HandleVisibility', 'off');
    % 绘制终点三角 (对于掉线的智能体，三角会停在它断开连接的位置)
    plot(p_d(end_idx,1,i), p_d(end_idx,2,i), '^', 'Color', colors(i,:), 'MarkerFaceColor', colors(i,:), 'MarkerSize', 6, 'HandleVisibility', 'off');
end

% ==================== 新增：随时间演变的队形快照连线 ====================
num_snapshots = 5; 
snapshot_indices = round(linspace(1, N_steps, num_snapshots)); 

% 定义快照的高亮颜色：大红色 (如果你想要大紫色，可以改成 [0.6, 0.1, 0.8])
snap_color = [0.85, 0.1, 0.1]; 

for idx = snapshot_indices
    % 1. 根据当前快照时间，判断该提取哪些跟随者
    if idx <= idx_switch
        current_active = 1:N_agents; % 50s 之前，所有存活
    else
        current_active = find(active_flags)'; % 50s 之后，只提取存活的
    end
    
    % 2. 提取并画出此时刻领航者(猎物)的位置
    leader_pos_x = p0_data(idx, 1);
    leader_pos_y = p0_data(idx, 2);
    % 用同色实心五角星标出领航者
    plot(leader_pos_x, leader_pos_y, 'p', 'Color', snap_color, ...
         'MarkerFaceColor', snap_color, 'MarkerSize', 12, 'HandleVisibility', 'off');
    
    % 3. 提取当前时刻参与连线的跟随者位置
    pos_at_idx = zeros(length(current_active), 2);
    for k = 1:length(current_active)
        agent_id = current_active(k);
        pos_at_idx(k, :) = p_d(idx, 1:2, agent_id);
       
        % 这样能完美体现出“中心目标与包围圈”的相对位置关系
        plot([leader_pos_x, pos_at_idx(k, 1)], [leader_pos_y, pos_at_idx(k, 2)], ...
             ':', 'Color', [snap_color, 0.4], 'LineWidth', 1, 'HandleVisibility', 'off');
    end
    
    % 4. 只有当存活节点大于1个时，才进行闭合连线画多边形阵型
    if size(pos_at_idx, 1) > 1
        % 闭合多边形：把第一个点的坐标加到矩阵最后一行
        pos_at_idx(end+1, :) = pos_at_idx(1, :); 
        
        % 画出这一时刻的队形连线 (使用大红色粗点划线)
        plot(pos_at_idx(:,1), pos_at_idx(:,2), 'Color', snap_color, ...
             'LineStyle', '-.', 'LineWidth', 2, 'HandleVisibility', 'off');
             
        % 画出多边形顶点的大圆点
        plot(pos_at_idx(:,1), pos_at_idx(:,2), '.', 'Color', snap_color, ...
             'MarkerSize', 20, 'HandleVisibility', 'off');
    end
end
% =====================================================================

%% 3. 绘制观测器位置估计误差
figure('Name', '观测器位置估计误差');
hold on; grid on; box on;

for i = 1:N_agents
    % 判断该智能体画到哪一个时刻停止
    if active_flags(i)
        end_idx = N_steps;
    else
        end_idx = idx_switch;
    end
    
    % 只计算并提取到 end_idx 的误差
    err_p = sqrt((p_hat(1:end_idx, 1, i) - p0_data(1:end_idx, 1)).^2 + ...
                 (p_hat(1:end_idx, 2, i) - p0_data(1:end_idx, 2)).^2);
                 
    % 时间 t 也要同步切片到 end_idx
    plot(t(1:end_idx), err_p, 'Color', colors(i,:), 'LineWidth', 1.5, 'DisplayName', sprintf('USV%d', i));
end
axis equal
xlabel('Time (s)');
ylabel('Estimation Error ||p_{hat} - p_0||');
title('移动目标规定时间观测器 - 位置估计误差');
legend('Location', 'northeast');


%% 3.1 绘制观测器位置估计
figure('Name', '观测器位置估计', 'Position', [850, 100, 600, 400]);

% --- X 轴位置估计 ---
subplot(2,1,1);
hold on; grid on; box on; % 网格和保持需要在 subplot 下方
plot(out.p0.time, p0_data(:,1), 'Color', '#A2142F', 'LineStyle', '--', 'LineWidth', 2, 'DisplayName', 'Leader'); % 领航者画全局深红色粗虚线

for i = 1:N_agents
    if active_flags(i), end_idx = N_steps; else, end_idx = idx_switch; end
    
    plot(t(1:end_idx), p_hat(1:end_idx, 1, i), 'Color', colors(i,:), ...
         'LineWidth', 1.5, 'DisplayName', sprintf('USV%d', i));
end
xlabel('Time (s)');
ylabel('x (m)');
title('移动目标规定时间观测器 - X 轴位置估计');
legend('Location', 'northeast');

% --- Y 轴位置估计 ---
subplot(2,1,2);
hold on; grid on; box on;
plot(t, p0_data(:,2), 'Color', '#A2142F', 'LineStyle', '--', 'LineWidth', 2, 'DisplayName', 'Leader');

for i = 1:N_agents
    if active_flags(i), end_idx = N_steps; else, end_idx = idx_switch; end
    
    plot(t(1:end_idx), p_hat(1:end_idx, 2, i), 'Color', colors(i,:), ...
         'LineWidth', 1.5, 'DisplayName', sprintf('USV%d', i));
end
xlabel('Time (s)');
ylabel('y (m)');
title('移动目标规定时间观测器 - Y 轴位置估计');
legend('Location', 'northeast');

%% 5. 绘制智能体间距离演化图 
figure('Name', '智能体间距离演化', 'Position', [100, 100, 800, 450]);

% --- 创建主坐标系 ---
axes_main = axes('Position', [0.1, 0.15, 0.85, 0.8]);
hold(axes_main, 'on'); grid(axes_main, 'on'); box(axes_main, 'on');
set(axes_main, 'GridLineStyle', '--', 'LineWidth', 1.2);

d_avoid = 20; % 安全距离 d (请根据你仿真里设定的真实安全距离修改)

% ================= 用户指定的通信拓扑连线对 =================
pairs_to_plot = [1, 2;
                 2, 3;
                 3, 4;
                 4, 5;
                 5, 6;
                 6, 1;
                 4, 1];
% ===========================================================
             
num_pairs = size(pairs_to_plot, 1);
dist_ij = zeros(N_steps, num_pairs);
hp = zeros(1, num_pairs);

% 预设一些鲜艳的颜色和线型
line_colors = lines(num_pairs); 
line_styles = {'-', '--', '-.'};

% 遍历指定的组合进行绘图
for k = 1:num_pairs
    i = pairs_to_plot(k, 1);
    j = pairs_to_plot(k, 2);
    
    % 判断这对智能体画到哪个时刻 (如果其中一个掉线了，就只画到切换时刻)
    if active_flags(i) && active_flags(j)
        end_idx = N_steps;
    else
        end_idx = idx_switch;
    end
    
    % 计算这两者之间的欧氏距离
    dist_ij(1:end_idx, k) = sqrt((p_d(1:end_idx,1,i) - p_d(1:end_idx,1,j)).^2 + ...
                                 (p_d(1:end_idx,2,i) - p_d(1:end_idx,2,j)).^2);
    
    % 轮换选择线型和颜色
    ls = line_styles{mod(k, 3) + 1};
    c = line_colors(k, :);
    
    % 在主图上画线
    hp(k) = plot(axes_main, t(1:end_idx), dist_ij(1:end_idx, k), ...
         'Color', c, 'LineStyle', ls, 'LineWidth', 1.5, ...
         'DisplayName', sprintf('||p_{%d%d}||', i, j));
end

% 画出红色的安全距离基准线 (加粗红色虚线)
h_d = plot(axes_main, t, d_avoid * ones(size(t)), 'r--', 'LineWidth', 2.5, 'DisplayName', 'd');

% 设置主图的图例和标签 (分4列显示，正好8个标签)
legend(axes_main, [hp, h_d], 'NumColumns', 4, 'Location', 'northeast', 'FontSize', 10);
xlabel(axes_main, 'Time (s)', 'FontSize', 12);
ylabel(axes_main, 'Distance (m)', 'FontSize', 12);
% ylim(axes_main, [0, 160]); 
% =====================================================================

N_steps = size(out.t_u1.time, 1);
N_agents = 6;

% 预分配内存 (好习惯，能大幅提升 MATLAB 运行速度)
tau_u = zeros(N_steps, N_agents);
tau_r = zeros(N_steps, N_agents);
psi_e = zeros(N_steps, N_agents);
rho_e = zeros(N_steps, N_agents);
B_psi = zeros(N_steps, 2, N_agents); % 第2维为2，代表 [下界, 上界]
B_rho = zeros(N_steps, 2, N_agents);
p_agent= zeros(N_steps, 2, N_agents);
% 提取原始张量 (避免在循环里频繁读取 out 结构体，提升速度)
tu_val = {out.t_u1.signals.values, out.t_u2.signals.values, out.t_u3.signals.values, out.t_u4.signals.values, out.t_u5.signals.values, out.t_u6.signals.values};
tr_val = {out.t_r1.signals.values, out.t_r2.signals.values, out.t_r3.signals.values, out.t_r4.signals.values, out.t_r5.signals.values, out.t_r6.signals.values};
psie_val = {out.psi_e1.signals.values, out.psi_e2.signals.values, out.psi_e3.signals.values, out.psi_e4.signals.values, out.psi_e5.signals.values, out.psi_e6.signals.values};
rhoe_val = {out.rho_e1.signals.values, out.rho_e2.signals.values, out.rho_e3.signals.values, out.rho_e4.signals.values, out.rho_e5.signals.values, out.rho_e6.signals.values};
Bpsi_val = {out.B_psi1.signals.values, out.B_psi2.signals.values, out.B_psi3.signals.values, out.B_psi4.signals.values, out.B_psi5.signals.values, out.B_psi6.signals.values};
Brho_val = {out.B_rho1.signals.values, out.B_rho2.signals.values, out.B_rho3.signals.values, out.B_rho4.signals.values, out.B_rho5.signals.values, out.B_rho6.signals.values};
p_agent_val = {out.agent1.signals.values, out.agent2.signals.values, out.agent3.signals.values, out.agent4.signals.values, out.agent5.signals.values, out.agent6.signals.values};
% 完美复刻你的数据提取习惯
for k = 1:size(out.t_u1.signals.values,1)
    for i = 1:N_agents
        % 提取 1D 数据 (单控制量和单误差)
        tau_u(k, i) = tu_val{i}(k,  1);
        tau_r(k, i) = tr_val{i}(k,  1);
        psi_e(k, i) = psie_val{i}(k,  1);
        rho_e(k, i) = rhoe_val{i}(k,  1);
        
        % 提取 2D 性能边界数据 (使用你的转置解包绝技)
        % Bpsi_val{i} 在第 k 步的大小是 2x1，转置后变成 1x2，存入 [下界, 上界]
        B_psi(k, :, i) = Bpsi_val{i}(1:2, 1, k)';
        B_rho(k, :, i) = Brho_val{i}(1:2, 1, k)';
        p_agent(k, :, i)   = p_agent_val{i}(k, 1:2)';
    end
end

%% ================= 预处理：如果你导出的是独立变量，取消下面的注释进行拼接 =================
%% 6. 绘制控制量输入 (tau_u 和 tau_r) - 1个图，2个子图
figure('Name', '控制量输入 (抗饱和限制)', 'Position', [100, 100, 800, 600]);

% --- 子图 1: 径向/纵向推力 tau_u ---
subplot(2, 1, 1);
hold on; grid on; box on;
for i = 1:N_agents
    if active_flags(i), end_idx = N_steps; else, end_idx = idx_switch; end
    plot(t(1:end_idx), tau_u(1:end_idx, i), 'Color', colors(i,:), ...
         'LineWidth', 1.5, 'DisplayName', sprintf('USV%d', i));
end
% 可选：画出饱和物理上限辅助线 (假设为 15)
% plot(t, 15*ones(size(t)), 'k--', 'LineWidth', 1.5, 'HandleVisibility', 'off');
% plot(t, -15*ones(size(t)), 'k--', 'LineWidth', 1.5, 'HandleVisibility', 'off');
xlabel('Time (s)', 'FontSize', 12);
ylabel('\tau_u (N)', 'FontSize', 12);
title('径向/纵向控制输入 \tau_u', 'FontSize', 12);
legend('Location', 'northeast', 'NumColumns', 3);

% --- 子图 2: 航向/偏航力矩 tau_r ---
subplot(2, 1, 2);
hold on; grid on; box on;
for i = 1:N_agents
    if active_flags(i), end_idx = N_steps; else, end_idx = idx_switch; end
    plot(t(1:end_idx), tau_r(1:end_idx, i), 'Color', colors(i,:), ...
         'LineWidth', 1.5, 'DisplayName', sprintf('USV%d', i));
end
xlabel('Time (s)', 'FontSize', 12);
ylabel('\tau_r (N\cdotm)', 'FontSize', 12);
title('航向/偏航控制力矩 \tau_r', 'FontSize', 12);
legend('Location', 'northeast', 'NumColumns', 3);

%% 7. 绘制航向跟踪误差 psi_e 及其预设性能边界 - 6个子图
figure('Name', '航向跟踪误差与性能边界', 'Position', [150, 150, 1000, 700]);
sgtitle('航向跟踪误差 \psi_e 与预设性能边界 B_{\psi}', 'FontSize', 14, 'FontWeight', 'bold');

for i = 1:N_agents
    subplot(3, 2, i);
    hold on; grid on; box on;
    
    if active_flags(i), end_idx = N_steps; else, end_idx = idx_switch; end
    
    % --- 提取当前子图的数据并确保为行向量 ---
    t_vec = reshape(t(1:end_idx), 1, []);
    lb_psi = reshape(B_psi(1:end_idx, 1, i), 1, []); % 下界 Lower Bound
    ub_psi = reshape(B_psi(1:end_idx, 2, i), 1, []); % 上界 Upper Bound
    
    % --- 构造填充多边形的 X 和 Y 坐标 ---
    % X轴：先正向走时间 t，再反向走时间 t
    % Y轴：先正向走下边界，再反向走上边界，闭合成一个多边形
    X_fill = [t_vec, fliplr(t_vec)];
    Y_fill = [lb_psi, fliplr(ub_psi)];
    
    % --- 1. 绘制半透明填充区域 ---
    fill(X_fill, Y_fill, 'r', 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'DisplayName', 'Performance Bound');
    
    % --- 2. (可选) 绘制边界的红色细虚线，增加边缘的质感 ---
    plot(t_vec, lb_psi, 'r--', 'LineWidth', 1.0, 'HandleVisibility', 'off');
    plot(t_vec, ub_psi, 'r--', 'LineWidth', 1.0, 'HandleVisibility', 'off');
    
    % --- 3. 画出真实误差 (对应智能体的颜色，实线，画在最上层) ---
    plot(t_vec, psi_e(1:end_idx, i), 'Color', colors(i,:), 'LineWidth', 1.5, 'DisplayName', sprintf('\\psi_{e,%d}', i));
    
    xlabel('Time (s)');
    ylabel(sprintf('\\psi_{e,%d} (rad)', i));
    title(sprintf('USV%d', i));
    
    % 为了防止 6 个图都有图例导致画面太挤，只在第一个图显示图例
    if i == 1
        legend('Location', 'northeast');
    end
end

%% 8. 绘制距离跟踪误差 rho_e 及其预设性能边界 - 6个子图
figure('Name', '距离跟踪误差与性能边界', 'Position', [200, 200, 1000, 700]);
sgtitle('距离跟踪误差 \rho_e 与预设性能边界 B_{\rho}', 'FontSize', 14, 'FontWeight', 'bold');

for i = 1:N_agents
    subplot(3, 2, i);
    hold on; grid on; box on;
    
    if active_flags(i), end_idx = N_steps; else, end_idx = idx_switch; end
    
    % --- 提取当前子图的数据并确保为行向量 ---
    t_vec = reshape(t(1:end_idx), 1, []);
    lb_rho = reshape(B_rho(1:end_idx, 1, i), 1, []); % 下界 Lower Bound
    ub_rho = reshape(B_rho(1:end_idx, 2, i), 1, []); % 上界 Upper Bound
    
    % --- 构造填充多边形的 X 和 Y 坐标 ---
    X_fill = [t_vec, fliplr(t_vec)];
    Y_fill = [lb_rho, fliplr(ub_rho)];
    
    % --- 1. 绘制半透明填充区域 ---
    % FaceAlpha 控制透明度，0.15 表示 15% 的不透明度，极其高雅
    fill(X_fill, Y_fill, 'r', 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'DisplayName', 'Performance Bound');
    
    % --- 2. (可选) 绘制边界的红色细虚线 ---
    plot(t_vec, lb_rho, 'r--', 'LineWidth', 1.0, 'HandleVisibility', 'off');
    plot(t_vec, ub_rho, 'r--', 'LineWidth', 1.0, 'HandleVisibility', 'off');
    
    % --- 3. 画出真实误差 (对应智能体的颜色，实线) ---
    plot(t_vec, rho_e(1:end_idx, i), 'Color', colors(i,:), 'LineWidth', 1.5, 'DisplayName', sprintf('\\rho_{e,%d}', i));
    
    xlabel('Time (s)');
    ylabel(sprintf('\\rho_{e,%d} (m)', i));
    title(sprintf('USV%d', i));
    
    if i == 1
        legend('Location', 'northeast');
    end
end

figure('Name', '2D 运动轨迹图实际', 'Position', [100, 100, 700, 600]);
hold on; grid on; box on;

% 领航者轨迹
plot(p0_data(:,1), p0_data(:,2), 'k--', 'LineWidth', 2, 'DisplayName', 'Leader p_0');
plot(p0_data(1,1), p0_data(1,2), 'ks', 'MarkerSize', 8, 'MarkerFaceColor', 'k', 'HandleVisibility', 'off'); 
plot(p0_data(end,1), p0_data(end,2), 'k*', 'MarkerSize', 8, 'HandleVisibility', 'off'); 

% 跟随者期望轨迹
for i = 1:N_agents
    % 判断该智能体画到哪一个时刻停止
    if active_flags(i)
        end_idx = N_steps;    % 存活，画到最后
    else
        end_idx = idx_switch; % 掉线，只画到 50s 切换时刻
    end
    
    % 只绘制从 1 到 end_idx 的轨迹
    plot(p_agent(1:end_idx,1,i), p_agent(1:end_idx,2,i), '-', 'Color', colors(i,:), 'LineWidth', 1.5, ...
        'DisplayName', sprintf('USV%d desired', i));
    % 绘制起点圈圈
    plot(p_agent(1,1,i), p_agent(1,2,i), 'o', 'Color', colors(i,:), 'MarkerFaceColor', colors(i,:), 'HandleVisibility', 'off');
    % 绘制终点三角 (对于掉线的智能体，三角会停在它断开连接的位置)
    plot(p_agent(end_idx,1,i), p_agent(end_idx,2,i), '^', 'Color', colors(i,:), 'MarkerFaceColor', colors(i,:), 'MarkerSize', 6, 'HandleVisibility', 'off');
end

% ==================== 新增：随时间演变的队形快照连线 ====================
num_snapshots = 5; 
snapshot_indices = round(linspace(1, N_steps, num_snapshots)); 

% 定义快照的高亮颜色：大红色 (如果你想要大紫色，可以改成 [0.6, 0.1, 0.8])
snap_color = [0.85, 0.1, 0.1]; 

for idx = snapshot_indices
    % 1. 根据当前快照时间，判断该提取哪些跟随者
    if idx <= idx_switch
        current_active = 1:N_agents; % 50s 之前，所有存活
    else
        current_active = find(active_flags)'; % 50s 之后，只提取存活的
    end
    
    % 2. 提取并画出此时刻领航者(猎物)的位置
    leader_pos_x = p0_data(idx, 1);
    leader_pos_y = p0_data(idx, 2);
    % 用同色实心五角星标出领航者
    plot(leader_pos_x, leader_pos_y, 'p', 'Color', snap_color, ...
         'MarkerFaceColor', snap_color, 'MarkerSize', 12, 'HandleVisibility', 'off');
    
    % 3. 提取当前时刻参与连线的跟随者位置
    pos_at_idx = zeros(length(current_active), 2);
    for k = 1:length(current_active)
        agent_id = current_active(k);
        pos_at_idx(k, :) = p_agent(idx, 1:2, agent_id);
       
        % 这样能完美体现出“中心目标与包围圈”的相对位置关系
        plot([leader_pos_x, pos_at_idx(k, 1)], [leader_pos_y, pos_at_idx(k, 2)], ...
             ':', 'Color', [snap_color, 0.4], 'LineWidth', 1, 'HandleVisibility', 'off');
    end
    
    % 4. 只有当存活节点大于1个时，才进行闭合连线画多边形阵型
    if size(pos_at_idx, 1) > 1
        % 闭合多边形：把第一个点的坐标加到矩阵最后一行
        pos_at_idx(end+1, :) = pos_at_idx(1, :); 
        
        % 画出这一时刻的队形连线 (使用大红色粗点划线)
        plot(pos_at_idx(:,1), pos_at_idx(:,2), 'Color', snap_color, ...
             'LineStyle', '-.', 'LineWidth', 2, 'HandleVisibility', 'off');
             
        % 画出多边形顶点的大圆点
        plot(pos_at_idx(:,1), pos_at_idx(:,2), '.', 'Color', snap_color, ...
             'MarkerSize', 20, 'HandleVisibility', 'off');
    end
end
% =====================================================================

%%  绘制智能体间距离演化图 
figure('Name', '实际智能体间距离演化', 'Position', [100, 100, 800, 450]);

% --- 创建主坐标系 ---
axes_main = axes('Position', [0.1, 0.15, 0.85, 0.8]);
hold(axes_main, 'on'); grid(axes_main, 'on'); box(axes_main, 'on');
set(axes_main, 'GridLineStyle', '--', 'LineWidth', 1.2);

d_avoid = 20; % 安全距离 d (请根据你仿真里设定的真实安全距离修改)

% ================= 用户指定的通信拓扑连线对 =================
pairs_to_plot = [1, 2;
                 2, 3;
                 3, 4;
                 4, 5;
                 5, 6;
                 6, 1;
                 4, 1];
% ===========================================================
             
num_pairs = size(pairs_to_plot, 1);
dist_ij = zeros(N_steps, num_pairs);
hp = zeros(1, num_pairs);

% 预设一些鲜艳的颜色和线型
line_colors = lines(num_pairs); 
line_styles = {'-', '--', '-.'};

% 遍历指定的组合进行绘图
for k = 1:num_pairs
    i = pairs_to_plot(k, 1);
    j = pairs_to_plot(k, 2);
    
    % 判断这对智能体画到哪个时刻 (如果其中一个掉线了，就只画到切换时刻)
    if active_flags(i) && active_flags(j)
        end_idx = N_steps;
    else
        end_idx = idx_switch;
    end
    
    % 计算这两者之间的欧氏距离
    dist_ij(1:end_idx, k) = sqrt((p_agent(1:end_idx,1,i) - p_agent(1:end_idx,1,j)).^2 + ...
                                 (p_agent(1:end_idx,2,i) - p_agent(1:end_idx,2,j)).^2);
    
    % 轮换选择线型和颜色
    ls = line_styles{mod(k, 3) + 1};
    c = line_colors(k, :);
    
    % 在主图上画线
    hp(k) = plot(axes_main, t(1:end_idx), dist_ij(1:end_idx, k), ...
         'Color', c, 'LineStyle', ls, 'LineWidth', 1.5, ...
         'DisplayName', sprintf('||p_{%d%d}||', i, j));
end

% 画出红色的安全距离基准线 (加粗红色虚线)
h_d = plot(axes_main, t, d_avoid * ones(size(t)), 'r--', 'LineWidth', 2.5, 'DisplayName', 'd');

% 设置主图的图例和标签 (分4列显示，正好8个标签)
legend(axes_main, [hp, h_d], 'NumColumns', 4, 'Location', 'northeast', 'FontSize', 10);
xlabel(axes_main, 'Time (s)', 'FontSize', 12);
ylabel(axes_main, 'Distance (m)', 'FontSize', 12);
% ylim(axes_main, [0, 160]); 
% =====================================================================
