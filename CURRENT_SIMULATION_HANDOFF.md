# 当前仿真程序完整交接说明

> 最后核对日期：2026-06-23
> 当前代码目录：`C:\Users\Administrator\Documents\fencing latex\fencing code`
> 论文目录：`C:\Users\Administrator\Documents\fencing latex\fencing-paper`

## 1. 本文件的地位

本文件描述当前实际使用的仿真、消融实验、保存结果和绘图流程。后续工作应优先以本文件和以下四个模型为准：

- `abl_M1_proposed.slx`
- `abl_M2_fixedObserver.slx`
- `abl_M3_fixedGuidance.slx`
- `abl_M4_rigidPPC.slx`

旧文件 `CODE_HANDOFF.md`、`DISTURB_MODELS_REVIEW.md` 和论文目录中的 `HANDOFF.md` 仍有参考价值，但其中部分模型名、饱和限制和绘图入口已经过时。例如旧文档常写 `1000 N / 500 Nm`，当前四个消融模型实际使用 `800 N / 400 Nm`。

最近的工作主要是绘图精修，没有重新运行四个 Simulink 模型。2026-06-23 的最新工作集中在三维时空围捕轨迹图 `FigH1_Spatiotemporal_Trajectory`，该图已被用户指定为最终版仿真一号图。因此：

- `.slx` 和 `sim_results/*_res.mat` 决定仿真数据；
- 绘图脚本的更新时间可能晚于结果文件；
- 图片更新不等于仿真结果更新。
- 当前仿真一号图最终版 PDF：`C:\Users\Administrator\Documents\fencing latex\fencing code\figures_OE\abl_M1_proposed_highlight\FigH1_Spatiotemporal_Trajectory.pdf`。

## 2. 研究问题和程序结构

程序模拟 6 艘欠驱动 USV 对移动目标进行围捕，在通信拓扑变化、USV 退出、环境扰动和执行器饱和条件下完成目标估计、期望运动生成和低层跟踪。

总体分为三层：

1. **Observer layer**：restart-based prescribed-time distributed target observer。
2. **Guidance layer**：label-free/self-ordering desired-motion generation。
3. **Tracking layer**：elastic prescribed-performance control under actuator saturation。

M1 是完整方法。M2、M3、M4 每次只移除一层的关键机制，用于消融实验。

## 2.1 入口文件和功能总表

| 文件 | 当前功能 | 是否推荐作为主入口 |
|---|---|---|
| `ini.m` | 旧/通用初始化；设置目标、拓扑、pinning、初始 observer 和 desired states | 仅旧流程 |
| `ini_paper.m` | 论文对齐初始化；保持算法参数，调整初始 desired positions 以改善展示 | 是 |
| `savere.m` | 运行 `ini.m`、仿真、保存结果、调用旧 `Myplot_OE` | 否，兼容旧流程 |
| `savere_paper.m` | 运行 `ini_paper.m`、仿真、保存 provenance、调用 `Myplot_OE_paper` | 是，推荐仿真入口 |
| `Myplot_OE.m` | 旧 OE 风格绘图；部分图以 desired positions 为主 | 仅历史兼容 |
| `Myplot_OE_paper.m` | 从已保存结果生成原始论文图和 metrics；轨迹/安全距离使用实际 USV 位置 | 是 |
| `plot_m1_publication_refined.m` | 生成 M1 精修主文图 | 是 |
| `plot_m1_highlight_figures.m` | 生成 XYT 时空图和四时刻拓扑重构图 | 是 |
| `compare_ablation_paper.m` | 读取 M1--M4 保存结果，计算指标、写 CSV/MAT、生成消融图 | 是 |
| `analyze_disturb_metrics.m` | 旧 disturb/disturb1/disturb2 指标分析，默认 1000/500 | 否，需改参数后才能用于当前模型 |
| `compare_main_OE_v2.m` | 旧单指标比较 | 历史工具 |
| `compare_fourpanel_final.m` | 旧四面板比较 | 历史工具 |
| `compare_abc_vertical_active_set.m` | 旧 active-set 三面板比较 | 历史工具 |
| `Myplot.m` | 早期探索性诊断脚本，依赖工作区变量 `out` | 调试备用 |

`ini_paper.m` 当前 initial desired positions：

```matlab
p_d_10 = [ 12; -18];
p_d_20 = [ 22;   2];
p_d_30 = [-20;  16];
p_d_40 = [-36;   2];
p_d_50 = [-30; -22];
p_d_60 = [  0; -30];
```

这些只是初值，不是固定编队槽位。M1 中固定 `p_offset` 仍被乘以零。

## 3. 当前主场景

### 3.1 仿真时间与事件

- 仿真时间：`0--80 s`
- 模型 `StopTime`：`80`
- 拓扑变化/USV 退出时刻：`t = 50 s`
- 切换前 active set：`{1,2,3,4,5,6}`
- 切换后 active set：`{1,2,3,4}`
- USV5、USV6 在 `t=50 s` 后从 active graph 中移除。

USV5、USV6 的物理状态仍可能存在于保存日志中，但主绘图和消融指标在 `t>=50 s` 后会将它们屏蔽。不能把日志中仍存在的信号误解为它们仍参与协同控制。

### 3.2 目标初始状态

由 `ini.m` / `ini_paper.m` 设置：

```matlab
p00 = [-7; -2];
v00 = [0.1; 0.1];
```

目标动力学使用双积分形式，目标加速度为有界时变信号。

### 3.3 通信拓扑

切换前：

```matlab
A_raw1 = [0 1 1 0 1 1;
          1 0 1 1 0 1;
          1 1 0 1 0 0;
          0 1 1 0 1 0;
          1 0 0 1 0 1;
          1 1 0 0 1 0];
```

切换后：

```matlab
A_raw2 = [0 1 0 1 0 0;
          1 0 1 1 0 0;
          0 1 0 1 0 0;
          1 1 1 0 0 0;
          0 0 0 0 0 0;
          0 0 0 0 0 0];
```

目标 pinning：

```matlab
beta1 = [0; 1; 0; 0; 1; 1];
beta2 = [0; 1; 1; 0; 0; 0];
```

### 3.4 USV 动力学参数

当前 M1 的六个动力学 MATLAB Function 脚本完全一致：

```matlab
m11 = 24.9;
m22 = 33.8;
m33 = 2.86;
Du  = 12;
Dv  = 17;
Dr  = 0.5;
```

动力学形式：

```matlab
x_dot   = u*cos(psi) - v*sin(psi);
y_dot   = u*sin(psi) + v*cos(psi);
psi_dot = r;

u_dot = (m22*v*r - Du*u + tau_u + tau_wu)/m11;
v_dot = (-m11*u*r - Dv*v + tau_wv)/m22;
r_dot = ((m11-m22)*u*v - Dr*r + tau_r + tau_wr)/m33;
```

### 3.5 环境扰动

四个消融模型中每艘 USV 使用相同扰动：

```matlab
tau_wu = 0.50*sin(0.1*t);
tau_wv = 0.50*cos(0.1*t);
tau_wr = 0.50*sin(0.2*t);
```

因此当前扰动幅值为 `0.50`，不是早期模型中的 `0.01`、`0.1`、`0.3` 或 `1.0`。

### 3.6 执行器限制

当前四个消融模型统一使用：

```matlab
tau_bu_rho = 800;  % surge force limit, N
tau_bu_psi = 400;  % yaw moment limit, Nm
```

控制器使用硬裁剪：

```matlab
tau_sat_rho = max(min(tau_u,  800), -800);
tau_sat_psi = max(min(tau_r,  400), -400);
```

## 4. 三层算法的当前实现

### 4.1 Restart observer

每艘 USV 的 follower MATLAB Function 内维护：

- `persistent tk`
- `persistent A_row_prev`

当本地邻接行 `A_row` 变化时：

```matlab
tk = t;
t_local = t - tk;
```

主要参数：

```matlab
kp_l      = 0.5;
phi_p     = 2.0;
Ta        = 5.0;
Omega_bar = 4;
```

M1 observer gain：

```matlab
if t_local < Ta - 0.001
    kp = kp_l + 1/(2*phi_p) + 2/(Ta-t_local);
else
    kp = kp_l + 1/(2*phi_p);
end
```

Observer law：

```matlab
dp_hat_i = v_hat_i - kp*eta_ip;
dv_hat_i = -kp*eta_iv - Omega_bar*sign(eta_iv);
```

`Ta-0.001` 是防止分母为零的实现保护。

### 4.2 Self-ordering guidance

主要参数：

```matlab
k1      = 0.1;
lambda  = 1.0;
Tp      = 10.0;
d_avoid = 10;
mu      = 20;
m_gain  = 100;
```

Restart guidance gain：

```matlab
if t_local < Tp - 0.2
    k_gain = k1 + 0.01 + lambda/(Tp-t_local);
else
    k_gain = k1 + 0.01;
end
```

M1 没有使用固定编号编队偏置：

```matlab
p_tilde_d_i = p_d_i - p_hat_i - 0*p_offset(:,id);
```

围捕几何由目标吸引、邻接 USV 期望点之间的排斥和目标排斥共同形成。主要输出：

```matlab
v_d_i  = v_hat_i - k_gain*(p_tilde_d_i-sum_avoid);
dp_d_i = v_d_i;
```

注意：这是期望轨迹层的 self-ordering，不是显式匈牙利分配，也不是固定槽位匹配。

### 4.3 Elastic PPC tracking

主要性能参数：

```matlab
upsilon_rho_0   = 10;
upsilon_rho_inf = 0.2;
upsilon_psi_0   = 2*pi/5;
upsilon_psi_inf = 0.02;
Tc_rho          = 10;
Tc_psi          = 2;
k_rho_1 = 1.0;
k_rho_2 = 1.0;
k_psi_1 = 1.0;
k_psi_2 = 1.0;
```

M1 的弹性边界：

```matlab
d_kappa_rho = -k_rho_1*kappa_rho + k_rho_2*(chi_rho_1+chi_rho_2);
B_rho = b_rho + tanh(kappa_rho)*Omega_rho;

d_kappa_psi = -k_psi_1*kappa_psi + k_psi_2*(chi_psi_1+chi_psi_2);
B_psi = b_psi + tanh(kappa_psi)*Omega_psi;
```

控制器还包括：

- tangent/barrier error transform；
- robust adaptive terms；
- RBF-like `NN(theta)`；
- saturation auxiliary states `S_rho`、`S_psi`；
- saturation mismatch compensation；
- 硬饱和输出。

## 5. 四个消融模型

### 5.1 M1 Proposed

文件：`abl_M1_proposed.slx`

完整启用：

- restart prescribed-time observer；
- self-ordering guidance；
- elastic PPC；
- topology change；
- disturbance amplitude `0.50`；
- hard saturation `800/400`。

这是当前主结果和所有精修图的唯一基准模型。

### 5.2 M2 Fixed-gain observer

文件：`abl_M2_fixedObserver.slx`

只修改 observer gain：

```matlab
kp = kp_l + 1/(2*phi_p) = 0.75;
```

保持不变：

- observer robust `sign` term；
- restart guidance；
- self-ordering guidance；
- elastic PPC；
- topology、扰动、饱和限制。

用途：验证 topology switch 后 restart observer gain 的恢复作用。

### 5.3 M3 Fixed-assignment guidance

文件：`abl_M3_fixedGuidance.slx`

只修改 guidance：

```matlab
active = (sum(A_row,1)' + sum(A_row,2) + beta) > 0;
Na = max(1,sum(active));
idx_fixed = max(1,sum(active(1:id)));
R_f = 30;
theta_fixed = 2*pi*(idx_fixed-1)/Na;
p_fixed_i = p_hat_i + R_f*[cos(theta_fixed);sin(theta_fixed)];
p_tilde_d_i = p_d_i-p_fixed_i;
v_d_i = v_hat_i-k_gain*p_tilde_d_i;
```

保持不变：

- M1 observer；
- elastic PPC；
- topology、扰动、饱和限制。

用途：验证 label-free/self-ordering guidance 的作用。

注意：M3 使用 `R_f=30`，这是当前模型的实际值。

### 5.4 M4 Rigid PPC

文件：`abl_M4_rigidPPC.slx`

只修改 performance bounds：

```matlab
B_rho   = b_rho;
d_B_rho = d_b_rho;
B_psi   = b_psi;
d_B_psi = d_b_psi;
```

M4 中 `d_kappa_*` 仍会计算，但不再进入 `B_rho/B_psi`，因此弹性放宽对实际边界失效。

保持不变：

- M1 observer；
- M1 self-ordering guidance；
- topology、扰动、饱和限制。

用途：验证 actuator saturation 条件下 elastic PPC 的作用。

## 6. 当前保存结果

四个主结果文件：

- `sim_results/abl_M1_proposed_res.mat`
- `sim_results/abl_M2_fixedObserver_res.mat`
- `sim_results/abl_M3_fixedGuidance_res.mat`
- `sim_results/abl_M4_rigidPPC_res.mat`

对应绘图指标：

- `sim_results/abl_M1_proposed_paper_metrics.mat`
- `sim_results/abl_M2_fixedObserver_paper_metrics.mat`
- `sim_results/abl_M3_fixedGuidance_paper_metrics.mat`
- `sim_results/abl_M4_rigidPPC_paper_metrics.mat`

消融汇总：

- `sim_results/ablation_compare_summary.csv`
- `sim_results/ablation_compare_summary.mat`

### 6.1 当前消融指标

| Method | Max PPC violation (m) | Min actual safety distance (m) | Post-switch control RMS | Saturation ratio | Post-switch peak observer error (m) | Post-switch mean formation error (m) |
|---|---:|---:|---:|---:|---:|---:|
| M1 Proposed | 0.00007498 | 11.584 | 0.06228 | 0.0080 | 0.19113 | 0.26605 |
| M2 Fixed-gain observer | 1.9427 | 12.638 | 0.06552 | 0.00567 | 0.19464 | 0.27056 |
| M3 Fixed-assignment guidance | 6.6647 | 16.199 | 0.45856 | 0.5600 | 0.19113 | 2.5640 |
| M4 Rigid PPC | 7.1780 | 13.023 | 0.30231 | 0.13133 | 0.19113 | 3.0939 |

指标用于相对消融解释，不应仅凭单一数值宣称某个 baseline 全面更优或更差。例如 M3 的最小距离较大，主要是其固定半径和编队偏差更大，并不表示整体跟踪性能更好。

## 7. 保存信号约定

绘图脚本依赖以下命名：

- `agent1` ... `agent6`：实际 USV 状态，前两列为位置；
- `p0`：目标位置；
- `p_hat_1` ... `p_hat_6`：各 USV 的目标位置估计；
- `p_d_1` ... `p_d_6`：各 USV 的期望位置；
- `rho_e1` ... `rho_e6`：range tracking error；
- `B_rho1` ... `B_rho6`：range performance bounds；
- `t_u1` ... `t_u6`：surge control；
- `t_r1` ... `t_r6`：yaw control；
- `tout`：部分结果中存在的统一时间；若不存在，绘图使用 `agent1.time`。

结果文件较大，单个约 `72--79 MB`。不要把 `ablation_compare_summary.mat` 当作只有表格的小文件，它还保存了重采样后的 comparison data。

## 8. 标准运行流程

### 8.1 仅重新绘图，不运行 Simulink

这是当前最安全、最快的流程：

```matlab
cd('C:\Users\Administrator\Documents\fencing latex\fencing code')

Myplot_OE_paper('abl_M1_proposed');
plot_m1_publication_refined('abl_M1_proposed');
plot_m1_highlight_figures('abl_M1_proposed');
compare_ablation_paper();
```

### 8.2 重新运行单个模型

```matlab
cd('C:\Users\Administrator\Documents\fencing latex\fencing code')
savere_paper('abl_M1_proposed')
```

`savere_paper` 会：

1. 优先运行 `ini_paper.m`；
2. 加载模型；
3. normal mode 仿真；
4. 保存 `sim_results/<model>_res.mat`；
5. 保存 provenance；
6. 运行 `Myplot_OE_paper(modelName)`。

重新跑四个消融模型后，应再次运行：

```matlab
Myplot_OE_paper('abl_M1_proposed');
Myplot_OE_paper('abl_M2_fixedObserver');
Myplot_OE_paper('abl_M3_fixedGuidance');
Myplot_OE_paper('abl_M4_rigidPPC');
compare_ablation_paper();
```

然后再生成 M1 的精修和亮点图。

### 8.3 命令行批处理

MATLAB 预期路径：`D:\matlab\bin\matlab.exe`

```powershell
D:\matlab\bin\matlab.exe -batch "cd('C:\Users\Administrator\Documents\fencing latex\fencing code'); savere_paper('abl_M1_proposed'); exit"
```

完整仿真可能耗时较长。不要在不确认的情况下覆盖四个现有 `_res.mat`。

## 9. 当前绘图功能

### 9.1 `Myplot_OE_paper.m`

输出目录：`figures_OE/<modelName>/`

输出：

1. `Fig01_Trajectory`：实际 USV 轨迹和围捕快照；
2. `Fig02_Observer`：observer norm error、目标/估计 x、目标/估计 y；
3. `Fig03_PPC`：六艘 USV 的 range PPC；
4. `Fig04_ControlInputs`：完整控制输入；
5. `Fig04b_ControlInputsZoom`：稳定段局部控制输入；
6. `Fig05_SafetyDistance`：实际艇间距离。

图例命名已经统一为 `USV1`、`USV2` 等无空格形式。

### 9.2 `plot_m1_publication_refined.m`

默认模型：`abl_M1_proposed`

输出目录：`figures_OE/abl_M1_proposed_refined/`

输出：

- `FigR1_Trajectory_Refined`：精修实际轨迹；
- `FigR2_Observer_Refined`：三行 observer/x/y 图，含 Target 和 USV1--USV6 图例；用户已确认当前 `figures_latest/refined/FigR2_Observer_Refined.jpg` 为最终版；
- `FigR3_PPC_Active_Refined`：当前版本不对，论文图应显示 6 艘 USV，而不是只显示切换后仍 active 的 USV1--USV4；后续需要重新修改该图；
- `FigR4_ControlZoom_Refined`：主控制输入 + 两个嵌入式放大窗；用户指定使用 `C:\Users\Administrator\Documents\fencing latex\fencing code\figures_latest\refined\FigR4_ControlZoom_Refined.jpg`；
- `FigR5_Safety_Refined`：实际艇间距、最小 active distance 和失效事件；用户已确认当前 `figures_latest/refined/FigR5_Safety_Refined.jpg` 为最终版。

当前 refined 图状态：

- R2：最终版；
- R3：未通过，需要改成 6 艘船全部展示；
- R4：使用 `figures_latest/refined/FigR4_ControlZoom_Refined.jpg`；
- R5：最终版。

当前 Tau 图约定：

- 主横轴 `0--80 s`；
- 主饱和边界 `+/-800 N`、`+/-400 Nm`；
- 主曲线使用 `movmean` 窗口 11；
- 放大窗只画 `65--75 s`；
- 放大窗无标题；
- 放大窗边框为纯黑色，axes layer 置顶；
- 曲线被 clip，不覆盖黑色坐标框；
- 上窗位于主图约 `(70 s, 500 N)`；
- 下窗位于主图约 `(70 s, 250 Nm)`。

当前 Safety 图约定：

- 任何涉及 USV5/USV6 的 pair distance 在 `t=50 s` 截止；
- active minimum distance 继续画到 80 s；
- `t=50 s` 标注 `USVs 5, 6 misbehave (removed)`；
- safety threshold 为 `10 m`。

### 9.3 `plot_m1_highlight_figures.m`

输出目录：`figures_OE/abl_M1_proposed_highlight/`

#### FigH1: Spatiotemporal trajectory

文件：`FigH1_Spatiotemporal_Trajectory`

用户已指定以下文件作为最终版仿真一号图：

```text
C:\Users\Administrator\Documents\fencing latex\fencing code\figures_OE\abl_M1_proposed_highlight\FigH1_Spatiotemporal_Trajectory.pdf
```

同名输出包括：

- `FigH1_Spatiotemporal_Trajectory.eps`：矢量 EPS，用于 LaTeX 或矢量后期；
- `FigH1_Spatiotemporal_Trajectory.jpg`：600 dpi 预览位图；
- `FigH1_Spatiotemporal_Trajectory.pdf`：600 dpi 位图 PDF，便于论文软件中编辑和查看。

当前约定：

- 三维坐标为 `(x,y,t)`；
- 图标题已删除；
- Target 为黑色虚线；
- USV1--USV4 为较强主色；
- USV5、USV6 使用较柔和的鼠尾草绿和钢青色，线宽略低；
- 时间管面使用弱透明度；
- xoy 底面使用浅蓝海水风格真彩色平面和淡波纹线；
- 多边形时刻：`[0,15,30,45,60,75] s`；
- 50 s 前多边形包含 6 个 active USV；
- 60/75 s 只包含 USV1--USV4，因此是四边形，不应称为六边形；
- 同一时刻的 polygon、nodes、`t=xx s` 标签使用同一时间颜色；
- 节点无白色外圈；
- `t=0` 的 xoy 底面节点已恢复显示，与其他时刻截面一致；底面中心 target 不额外标记；
- 标签位于对应 `z=t` 平面；
- 标签 x 坐标为 `max(x_polygon)+20 m`；
- x 轴自动扩展，避免标签裁切；
- 时间 colormap 为自定义靛蓝--蓝--青绿--黄绿--金色；
- `t=50 s, USV5, USV6 misbehaved` 红色标注位于 45 s 截面左上方空白区域；
- 标注有一个短箭头指向 50 s 截面中心，箭头已缩短并沿反方向平移，避免贴住主轨迹；
- 坐标范围已经回退到放宽前版本，只额外扩展 x 轴以容纳右侧 `t=xx s` 标签。

#### FigH2: Topology reconstruction frames

文件：`FigH2_Topology_Reconstruction_Frames`

四个时刻：

- 45 s：pre-switch；
- 50 s：topology switch and removal；
- 55 s：restart and self-ordering；
- 70 s：reconstructed steady formation。

图中显示：

- 实际 USV；
- desired slots；
- communication links；
- target-pinned links；
- target；
- 50 s 时 USV5/USV6 removal 标记。

拓扑边严格来自 `A_raw1/A_raw2`，pinning 严格来自 `beta1/beta2`。

### 9.4 `compare_ablation_paper.m`

默认：

```matlab
compare_ablation_paper()
```

默认输出旧式四张分层图：

1. `FigC1_Observer_M1_vs_M2`；
2. `FigC2_Guidance_M1_vs_M3`；
3. `FigC3_RigidPPC_M1_vs_M4`；
4. `FigC4_Ablation_Summary`。

可选 compact 布局：

```matlab
compare_ablation_paper([], [], 'compact')
```

输出：

- `FigC1_Ablation_ThreePanel`；
- `FigC2_Overall_Profile`。

默认应使用 pairwise 四张图；compact 两张图仅作为保留方案。

## 10. 历史模型和旧工具

以下模型主要用于此前的 disturbance/tau 调参，不是当前最终消融模型：

- `disturb.slx`
- `disturb1.slx`
- `disturb2.slx`
- `disturb_paper.slx`
- `disturb_paper_lowtau*.slx`
- `disturb_paper_tau700.slx`
- `disturb_paper_final.slx`
- `disturb_paper_d05_base.slx`
- `disturb_paper_d05_final.slx`
- `nn2023b*.slx`

保留这些文件用于追溯，不建议继续在它们上面做最终论文改动。

旧 comparison scripts：

- `compare_main_OE_v2.m`
- `compare_fourpanel_final.m`
- `compare_abc_vertical_active_set.m`

这些脚本仍可运行，但默认模型或饱和参数可能属于旧场景。当前消融优先使用 `compare_ablation_paper.m`。

`analyze_disturb_metrics.m` 默认使用旧模型和 `1000/500` 饱和限制，不应直接用于 `abl_M1`--`abl_M4`，除非先修改其默认参数。

## 11. 模型内部结构陷阱

### 11.1 子系统编号不是连续 USV 编号

当前六个实际动力学子系统路径是：

- `USV1`
- `USV2`
- `USV3`
- `USV7`
- `USV8`
- `USV9`

它们在保存信号和论文中仍对应 USV1--USV6。不要因为子系统名为 USV7/8/9 就认为模型有 9 艘船。

### 11.2 重复 MATLAB Function blocks

每个模型包含：

- 6 份 follower/observer/guidance；
- 6 份 low-level controller；
- 6 份 USV dynamics。

修改算法时必须检查并更新全部副本。推荐使用 MATLAB/Stateflow API 修改并保存，不要直接编辑 `.slx` zip/XML。

当前 M1 已核实：

- 六个 controller scripts 完全一致；
- 六个 dynamics scripts 完全一致；
- 六个 follower scripts 使用同一逻辑。

### 11.3 `USE_*` 开关

`ini.m` 中定义：

```matlab
USE_RESTART    = 1;
USE_SELF_ORDER = 1;
USE_PPC        = 1;
USE_SAT        = 1;
```

但嵌入 MATLAB Function 代码不一定直接读取这些变量。当前四个消融是通过复制模型并实际修改内部脚本实现的，不应仅切换 `USE_*` 就认为消融生效。

## 12. 论文与代码的关键差异

1. 论文最终表述偏向标量 relaxation variable `sigma_i`；代码使用 channel-wise `kappa_rho/kappa_psi`。
2. 论文可能描述 smooth arctangent saturation；代码实际使用 hard clipping。
3. M4 通过令实际 bounds 等于 rigid bounds 实现，`d_kappa_*` 状态并未物理删除。
4. 程序安全图展示实际 USV 距离，但理论安全结论主要是 desired/active-edge 层面；论文文字不要扩大为无条件 all-pairs actual collision avoidance theorem。
5. 当前代码饱和限制是 `800/400`；论文若仍写 `1000/500`，必须统一。
6. 当前扰动幅值是 `0.50`；论文图注和参数表应与此一致。
7. 当前 M3 固定围捕半径是 `30 m`。

## 13. 图像和论文同步

绘图脚本只写入 `fencing code/figures_OE`，不会自动复制到 `fencing-paper`。

当前最新认可图片镜像目录：

```text
C:\Users\Administrator\Documents\fencing latex\fencing code\figures_latest
```

该目录下：

- `refined/` 保存最新 M1 主文精修图；
- `highlight/` 保存最新 M1 亮点图，其中 `FigH1_Spatiotemporal_Trajectory` 对应最终版仿真一号图；
- `ablation/` 保存最新默认 pairwise 消融图。

论文提交前必须人工确认：

1. `main.tex` 实际引用的文件名；
2. 引用的是原始图、refined 图还是 highlight 图；
3. EPS/JPG 是否来自同一次绘图；
4. 图注中的 tau limits、disturbance 和 active set 是否一致；
5. 图例全部使用 `USV1`、`USV2` 等统一写法。

## 14. 已知非错误警告

导出复杂 EPS 时 MATLAB 可能提示：

```text
Vectorized content may take a long time to create...
```

这是复杂曲线和透明面的 vector export 提示，不代表绘图失败。JPG 使用 600 dpi，EPS 使用 vector content。

## 15. 修改后的验证清单

任何模型改动后至少执行：

1. 检查六个 follower blocks 是否一致或按计划不同；
2. 检查六个 controller blocks；
3. 检查六个 dynamics blocks；
4. 确认 disturbance 三通道和六艘船一致；
5. 确认 tau limits 为目标值；
6. 运行模型并保存新的 `_res.mat`；
7. 运行 `Myplot_OE_paper` 生成 metrics；
8. 运行 refined/highlight plots；
9. 运行 `compare_ablation_paper`；
10. 检查最小距离、PPC violation、saturation ratio；
11. 视觉检查 EPS/JPG；
12. 更新本 handoff 中的日期和结果表。

## 16. 推荐继续工作的顺序

1. 先决定论文最终采用 `800/400` 还是其他 tau limits。
2. 若改 tau 或 disturbance，四个消融模型必须同步修改并全部重跑。
3. 不要只重跑 M1 后继续使用旧 M2--M4 comparison。
4. 确认论文参数表与 M1 模型内部参数一致。
5. 确认 M3 的 `R_f=30` 是否符合论文 baseline 定义。
6. 最后再固定主文图、亮点图和 comparison 图文件名。

## 17. 最短操作速查

只重新出当前图片：

```matlab
cd('C:\Users\Administrator\Documents\fencing latex\fencing code')
Myplot_OE_paper('abl_M1_proposed')
plot_m1_publication_refined('abl_M1_proposed')
plot_m1_highlight_figures('abl_M1_proposed')
compare_ablation_paper()
```

重新运行完整四组消融：

```matlab
savere_paper('abl_M1_proposed')
savere_paper('abl_M2_fixedObserver')
savere_paper('abl_M3_fixedGuidance')
savere_paper('abl_M4_rigidPPC')

plot_m1_publication_refined('abl_M1_proposed')
plot_m1_highlight_figures('abl_M1_proposed')
compare_ablation_paper()
```

## 18. 当前结论

当前可复现主线是：

- M1 在 disturbance amplitude `0.50`、tau limits `800/400` 和 `t=50 s` active-set reduction 下保持良好围捕与跟踪；
- M2 隔离 observer restart gain；
- M3 隔离 self-ordering guidance；
- M4 隔离 elastic PPC；
- 保存结果、消融表和绘图脚本已经形成完整链路；
- 2026-06-23 已固定 `FigH1_Spatiotemporal_Trajectory.pdf` 为最终版仿真一号图；
- 后续最大的风险不是缺少功能，而是混用旧模型、旧参数、旧结果和新图片。

任何接手者应先确认自己操作的是 `abl_M1`--`abl_M4`，再开始修改。
