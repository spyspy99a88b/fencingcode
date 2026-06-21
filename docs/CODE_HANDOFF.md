# Handoff: fencing code

## Project source

- Local path: `C:\Users\Administrator\Documents\fencing latex\fencing code`
- Related paper path: `C:\Users\Administrator\Documents\fencing latex\fencing-paper`
- Code folder name on disk: `fencing code` with a space, not `fencingcode`
- Main implementation style: Simulink models (`.slx`) plus MATLAB scripts for initialization, batch simulation, result saving, plotting, and comparison figures.

## Paper-code relationship

The paper presents a three-layer framework:

1. restart-based prescribed-time distributed target observer,
2. label-free/self-ordering desired-motion generation,
3. elastic prescribed-performance tracking under actuator saturation.

The code implements the same broad simulation stack, but it is not a one-to-one transcription of the final manuscript equations. The most important mismatch is in Layer 3:

- The final paper uses a scalar width-relaxation variable `sigma_i(t)` and discusses a smooth arctangent saturation approximation.
- The current Simulink code uses channel-wise variables `kappa_rho`, `kappa_psi`, hard clipping saturation, and auxiliary saturation states `S_rho`, `S_psi`.

So this code should be treated as the simulation/figure-generation implementation behind the paper, not as a clean reference implementation of every final theorem statement.

## Top-level repository contents

### Core Simulink models

- `nn2023b.slx`: earlier/main nominal model; smaller file than the later `disturb*.slx` models.
- `nn2023b1.slx`: variant model used in comparison scripts.
- `nn2023b2.slx`: variant model used in saved results.
- `disturb.slx`: main disturbance-enhanced proposed-method model used by the final OE plotting/comparison scripts.
- `disturb1.slx`: comparison/baseline variant; guidance law is weakened to a fixed/asymptotic style.
- `disturb2.slx`: comparison/baseline variant; observer robust term is removed or weakened in at least some follower blocks.

The `.slxc` files are Simulink cache artifacts for the corresponding `.slx` models.

### MATLAB scripts

- `ini.m`: loads initial conditions, topology matrices, pinning vectors, desired formation offsets, and algorithm switches into the MATLAB base workspace.
- `savere.m`: automation wrapper; runs `ini.m`, loads a Simulink model, executes `sim`, saves `sim_results/<model>_res.mat`, and calls `Myplot_OE(modelName)`.
- `Myplot_OE.m`: publication/Ocean Engineering style plotting function. It reads saved simulation results and exports five main figures.
- `Myplot.m`: older exploratory plotting script with more diagnostic plots and Chinese annotations.
- `compare_main_OE_v2.m`: single-metric comparison plotting helper for observer error, mean observer error, or mean tracking error.
- `compare_fourpanel_final.m`: four-panel comparison figure: observer error, guidance-center error, mean tracking error, normalized control demand.
- `compare_abc_vertical_active_set.m`: final vertical three-panel comparison figure using active-set metrics after agent removal.

### Data and figures

- `sim_results/`: saved simulation outputs, including `disturb_res.mat`, `disturb1_res.mat`, `disturb2_res.mat`, `nn2023b*_res.mat`, and `comp_main_res.mat`.
- `figures_OE/`: exported figures for paper use.
- `figures_OE/nn2023b/`: five main paper-style figures from the `nn2023b` run.
- `figures_OE/disturb*/`: five main paper-style figures from disturbance/baseline variants.
- `figures_OE/Comparison/`: comparison-study EPS/PNG/JPG files such as `compare.eps`, `ABC_Vertical_Combined.png`, and `Comp_4Panel_Main.eps`.
- `untitled.fig`: MATLAB figure file, likely an older/manual figure artifact.
- `slprj/`: Simulink generated build/cache/report directory. It is useful for inspection but should not be treated as source.

## Simulation setup from `ini.m`

`ini.m` defines the base scenario:

- Target initial state:
  - `p00 = [-7; -2]`
  - `v00 = [0.1; 0.1]`
- Six followers.
- Initial topology `A_raw1`: connected six-agent graph.
- Post-change topology `A_raw2`: agents 5 and 6 are isolated/removed; agents 1-4 remain active.
- Pinning vectors:
  - `beta1 = [0; 1; 0; 0; 1; 1]`
  - `beta2 = [0; 1; 1; 0; 0; 0]`
- Desired radius/spacing scale:
  - `R = 10`
  - `p_off_set1`: six-point nominal polygon offsets.
  - `p_off_set2`: four-agent post-switch polygon idea, but in the current follower code the offset is multiplied by zero.
- Initial estimates and desired positions are deliberately scattered to show convergence.
- Algorithm switches exist:
  - `USE_RESTART`
  - `USE_SELF_ORDER`
  - `USE_PPC`
  - `USE_SAT`

Important caveat: the extracted Simulink MATLAB Function code does not visibly branch on these `USE_*` switches. They may be remnants, used through model-level switches, or currently inactive.

## Main run workflow

Typical workflow:

```matlab
cd('C:\Users\Administrator\Documents\fencing latex\fencing code')
savere('disturb')
```

What `savere(modelName)` does:

1. runs `ini.m`,
2. loads `<modelName>.slx`,
3. runs `out = sim(modelName, 'ReturnWorkspaceOutputs', 'on')`,
4. saves `out` and `A_raw2` to `sim_results/<modelName>_res.mat`,
5. calls `Myplot_OE(modelName)` to export figures into `figures_OE/<modelName>/`.

For comparison figures, first ensure the relevant result files exist in `sim_results/`, then run:

```matlab
compare_abc_vertical_active_set()
compare_fourpanel_final({'disturb','disturb1','disturb2'}, [10 50], 1000, 500)
```

Note: `compare_fourpanel_final` defaults to `satU=60`, `satR=30`, but the main model uses `1000` and `500` as hard saturation limits. Pass the paper values explicitly if using that panel.

## Simulink internals

The `.slx` files are zip containers. Inspection of `nn2023b.slx` shows the important MATLAB Function / Stateflow charts:

- `MATLAB Function2 / Leader_Model`
- `MATLAB Function1`, `MATLAB Function3`, `MATLAB Function5`, `MATLAB Function11`, `MATLAB Function6`, `MATLAB Function7`: six copies of `Follower_Model`
- repeated `Controler1 / LowLevel_Controller` blocks for the USV subsystems
- repeated `Subsystem/Guidence` blocks for LOS heading/range-error generation
- repeated `USV*/MATLAB Function` blocks for physical USV dynamics

The six follower blocks are mostly duplicated with small parameter differences, especially in the guidance gain constant.

## Layer 1: target observer implementation

Implemented inside each `Follower_Model` block.

Core variables:

- `p_hat_i`, `v_hat_i`: local target position/velocity estimates.
- `p_hat_all`, `v_hat_all`: stacked estimates of all followers.
- `A_row`: current adjacency matrix/row input.
- `beta`: pinning vector.
- `eta_ip`, `eta_iv`: consensus/pinning observer errors.

Core law:

```matlab
eta_ip = sum_p + beta(id) * (p_hat_i - p0);
eta_iv = sum_v + beta(id) * (v_hat_i - v0);

if t_local < Ta - 0.001
    kp = kp_l + 1/(2*phi_p) + 2/(Ta - t_local);
else
    kp = kp_l + 1/(2*phi_p);
end

dp_hat_i = v_hat_i - kp * eta_ip;
dv_hat_i = -kp * eta_iv - Omega_bar * sign(eta_iv);
```

Main parameters:

- `Ta = 5.0`
- `kp_l = 0.5`
- `phi_p = 2.0`
- `Omega_bar = 4`

Restart mechanism:

- Each follower block uses persistent `tk` and `A_row_prev`.
- When `A_row` changes, `tk = t`.
- `t_local = t - tk`.
- The observer gain is restarted via the singular term `2/(Ta - t_local)`.

Paper alignment:

- Matches the paper's restart-based prescribed-time observer at a simulation level.
- Uses a practical cutoff `Ta - 0.001` to avoid division by zero.
- Uses component-wise `sign(eta_iv)`.

Paper mismatch/caution:

- The paper writes the observer in stacked graph notation with `Psi=(L+B)\otimes I_2`; the code implements it locally row-by-row.
- The code only detects changes in each local `A_row`, not a globally synchronized event variable.

## Layer 2: desired-motion/self-ordering guidance implementation

Also implemented inside each `Follower_Model` block.

Core law:

```matlab
if t_local < Tp - 0.001
    k_gain = k1 + c + lambda/(Tp - t_local);
else
    k_gain = k1 + c;
end

p_tilde_d_i = p_d_i - p_hat_i - 0*p_offset(:,id);
v_d_i = v_hat_i - k_gain * (p_tilde_d_i - sum_avoid);
dp_d_i = v_d_i;
```

Main parameters:

- `Tp = 10.0`
- `k1 = 0.1`
- `lambda = 1.0`
- `d_avoid = 10`
- `mu = 20`
- `m_gain = 100`

Repulsion implementation:

For each neighbor `j` with `A_row(id,j)>0`, the code computes:

```matlab
alpha_val = 1/(norm_p - d_avoid) - 1/(mu - d_avoid)
sum_avoid = sum_avoid + m_gain * alpha_val * (p_d_ij / norm_p)
```

The same repulsion calculation is also applied between `p_d_i` and `p_hat_i`, so the desired point is pushed away from the estimated target when it falls inside the repulsion annulus.

Important implementation detail:

- `p_offset(:,id)` is multiplied by zero:

```matlab
p_tilde_d_i = p_d_i - p_hat_i - 0*p_offset(:,id);
```

This means the current code is truly label-free in the sense that fixed formation offsets are disabled. The polygon emerges from attraction to the target estimate plus inter-agent repulsion, not from assigned offset slots.

Baseline differences:

- Proposed-style models use:

```matlab
v_d_i = v_hat_i - k_gain * (p_tilde_d_i - sum_avoid);
```

- `disturb1.slx` uses a weaker/asymptotic style:

```matlab
v_d_i = 0.2 * v_hat_i - 0.05 * p_tilde_d_i + sum_avoid;
```

Paper alignment:

- Supports restart-based guidance, self-ordering behavior, and active-edge repulsion.
- Uses `Ta=5`, `Tp=10`, `d=10`, `r/mu=20`, matching the manuscript's simulation parameters.

Paper mismatch/caution:

- The paper's repulsion potential is written as an edge potential with formal gradient and barrier proof. The code uses a direct pairwise repulsion term with a practical zeroing rule when `norm_p <= d_avoid` or `norm_p > mu`.
- The code uses `mu` for repulsion range; the paper uses `r`.

## Target model

Implemented in `Leader_Model`:

```matlab
dp0 = v0;
dv0 = [0.08*sin(0.05*t); 0.08*cos(0.05*t)];
```

This matches the paper's bounded-acceleration moving target idea.

## LOS guidance block

Implemented in repeated `Guidence` blocks.

Inputs include actual position `(x,y)`, desired signal `desire`, and heading `psi`.

Core outputs:

- `psid`: desired heading.
- `psi_e = psi - psid`
- `rhoe = sqrt((x-xd)^2 + (y-yd)^2)`
- `xd`, `yd`: desired position components.

Heading is computed with a velocity-biased line-of-sight expression:

```matlab
p = atan2(10000*ye + 10*dyd, 10000*xe + 10*dxd);
```

The block also includes a persistent unwrap counter to avoid jumps near `-pi/pi`.

Paper alignment:

- Supports the paper's regularized/LOS heading concept operationally.

Paper mismatch/caution:

- The manuscript's final LOS formula is more polished and includes regularization assumptions. The code uses a very large position-error weight (`10000`) and a smaller velocity feedforward weight (`10`).

## Layer 3: low-level tracking controller implementation

Implemented in repeated `LowLevel_Controller` blocks.

Key inputs:

- `psi_d`, `dpsid`, `ddpsid`
- `psi_e`, `rho_e`
- `desire`
- `u`, `v`, `r`
- adaptive estimates `mu_rho_hat`, `mu_psi_hat`
- elastic/saturation states `kappa_rho`, `kappa_psi`, `chi_*`, `S_rho`, `S_psi`

Main tracking parameters:

- `Tc_rho = 10`
- `Tc_psi = 2`
- `upsilon_rho_0 = 10`
- `upsilon_rho_inf = 0.2`
- `upsilon_psi_0 = 2*pi/5`
- `upsilon_psi_inf = 0.02`
- `m11 = 24.9`
- `m33 = 2.86`
- `tau_bu_rho = 1000`
- `tau_bu_psi = 500`

Base performance funnels:

```matlab
ups_rho = (upsilon_rho_0 - upsilon_rho_inf) * iota_rho + upsilon_rho_inf;
ups_psi = (upsilon_psi_0 - upsilon_psi_inf) * iota_psi + upsilon_psi_inf;
```

Elastic channel-wise bounds:

```matlab
d_kappa_rho = -k_rho_1 * kappa_rho + k_rho_2 * (chi_rho_1 + chi_rho_2);
B_rho = b_rho + tanh(kappa_rho) * Omega_rho;

d_kappa_psi = -k_psi_1 * kappa_psi + k_psi_2 * (chi_psi_1 + chi_psi_2);
B_psi = b_psi + tanh(kappa_psi) * Omega_psi;
```

Barrier transform:

```matlab
theta_rho = (rho_e - B_rho_lower) / (B_rho_upper - B_rho_lower);
phi_tan_rho = tan(pi * (theta_rho - 0.5));
```

The same structure is used for `psi`.

Robust/adaptive part:

- Uses a small radial-basis-like helper `NN(theta)` with 50 elements.
- Uses adaptive estimates `mu_rho_hat`, `mu_psi_hat`.
- Uses `tanh(...)` robust smoothing terms.

Control command and saturation:

```matlab
tau_u = -(1/g) * (...);
tau_r = -(1/h) * (...);

tau_sat_psi = max(min(tau_r, tau_bu_psi), -tau_bu_psi);
d_S_psi = -S_psi + G_psi * (tau_sat_psi - tau_r);

tau_sat_rho = max(min(tau_u, tau_bu_rho), -tau_bu_rho);
d_S_rho = -S_rho + G_rho * (tau_sat_rho - tau_u);
```

Paper alignment:

- Captures prescribed-performance funnels, tangent barrier variables, robust adaptive control, actuator saturation, and saturation-compensation auxiliary states.

Paper mismatch/caution:

- The code uses hard saturation, not the paper's arctangent smooth approximation.
- The code uses separate `kappa_rho/kappa_psi` width shifts rather than the final paper's scalar `sigma_i`.
- Low-level controller restart after topology change is commented out. The code currently sets `t_local = t`; the block that would reset `rho_e_0`, `psi_e_0`, and `t_local=t-50` is commented. This differs from the paper's general restart narrative.
- The code uses simplified scalar input gains:
  - `g = cos(psi_e)/m11`
  - `h = 1/m33`
  rather than a fully explicit matrix `G_i`.

## USV dynamics implementation

Implemented in repeated `USV*/MATLAB Function` blocks.

Core model:

```matlab
m11 = 24.9; m22 = 32.7; m33 = 2.86;
Du = 11; Dv = 16; Dr = 0.6;

x_dot = u*cos(psi) - v*sin(psi);
y_dot = u*sin(psi) + v*cos(psi);
psi_dot = r;

u_dot = (m22*v*r - Du*u + tau_u + tau_wu) / m11;
v_dot = (-m11*u*r - Dv*v + tau_wv) / m22;
r_dot = ((m11-m22)*u*v - Dr*r + tau_r + tau_wr) / m33;
```

Disturbance variants:

- `nn2023b*` models use small disturbances such as `tau_wu = 0.01*sin(0.1*t)`.
- `disturb*` models use larger disturbances such as `tau_wu = 0.1*sin(0.1*t)`.

Paper mismatch/caution:

- Paper table lists `m22=33.80`, `d11=12`, `d22=17`, `d33=0.50` in the handoff summary, while the extracted Simulink dynamics use `m22=32.7`, `Du=11`, `Dv=16`, `Dr=0.6`.
- This should be reconciled before final submission if the simulation parameter table is expected to be exact.

## Plotting pipeline

### `Myplot_OE.m`

Reads `sim_results/<model>_res.mat` and generates five main figures:

1. `Fig01_Trajectory`: desired trajectories and snapshots.
2. `Fig02_Observer`: observer error and target/estimate x-y traces.
3. `Fig03_PPC`: range tracking errors inside elastic bounds.
4. `Fig04_ControlInputs`: surge/yaw commands with saturation limits.
5. `Fig05_SafetyDistance`: inter-agent distances.

Important caveat:

- `Fig05_SafetyDistance` computes distances from `p_d`, the desired positions, not from actual USV positions.
- The figure label/caption in the paper should therefore avoid claiming actual all-pairs collision avoidance unless actual-position distances are separately plotted or substituted.

### `Myplot.m`

Older diagnostic script:

- plots desired trajectories,
- observer errors and estimates,
- desired inter-agent distances,
- control inputs,
- heading and range PPC bounds,
- actual trajectories and actual inter-agent distances.

This script is useful for debugging because it contains both desired-level and actual-level distance plots, but it is less polished for publication.

## Comparison-study pipeline

### `compare_main_OE_v2.m`

General helper for a single metric:

- `max_obs`
- `mean_obs`
- `mean_rho`

Default models:

```matlab
{'disturb','disturb1','disturb2'}
```

Legend names:

1. Proposed method
2. Asymptotic fixed-gain controller
3. Linear weak observer

### `compare_fourpanel_final.m`

Generates a 2x2 figure with:

1. maximum observer error,
2. guidance-center error,
3. mean tracking error,
4. maximum normalized control demand.

Caution:

- It averages guidance-center error over all six `p_d_i`, regardless of agent removal, unless modified.
- Its default saturation bounds are `60` and `30`, which do not match the main model's `1000` and `500`.

### `compare_abc_vertical_active_set.m`

Most aligned with the final manuscript's comparison story because it uses the active set after agent loss:

- switch lines at `10` and `50`,
- drop time `50`,
- removed agents `[5 6]`,
- panel (a) and (c): `{'disturb','disturb1','disturb2'}`,
- panel (b): `{'disturb','nn2023b1','disturb2'}`.

Metrics:

- maximum observer error over active set,
- guidance-center error over active set,
- mean tracking error over active set.

Outputs:

- `figures_OE/Comparison/ABC_Vertical_Combined.eps`
- `figures_OE/Comparison/ABC_Vertical_Combined.png`

## Result files and figure provenance

Likely final-paper figures:

- `figures_OE/nn2023b/Fig01_Trajectory.eps`
- `figures_OE/nn2023b/Fig02_Observer.eps`
- `figures_OE/nn2023b/Fig03_PPC.eps`
- `figures_OE/nn2023b/Fig04_ControlInputs.eps`
- `figures_OE/nn2023b/Fig05_SafetyDistance.eps`

Alternative/disturbance-version figures:

- `figures_OE/disturb/Fig01_Trajectory.eps`
- `figures_OE/disturb/Fig02_Observer.eps`
- `figures_OE/disturb/Fig03_PPC.eps`
- `figures_OE/disturb/Fig04_ControlInputs.eps`
- `figures_OE/disturb/Fig05_SafetyDistance.eps`

Comparison figures:

- `figures_OE/Comparison/compare.eps`
- `figures_OE/Comparison/ABC_Vertical_Combined.png`
- `figures_OE/Comparison/Comp_4Panel_Main.eps`

Before paper submission, verify which of these exact files are copied into `fencing-paper`.

## Technical sensitivities found in code

1. Folder naming: scripts and paths must use `fencing code`, not `fencingcode`.
2. The Simulink code contains duplicated MATLAB Function blocks. If changing a law, update all six follower/controller/dynamics copies or refactor carefully.
3. `p_offset` is currently disabled by `0*p_offset(:,id)`.
4. Low-level restart at `t=50` is commented out.
5. `Fig05_SafetyDistance` in `Myplot_OE.m` plots desired distances, not actual USV distances.
6. `compare_fourpanel_final.m` has default saturation normalization bounds that may not match the paper.
7. The code's Layer 3 elastic mechanism differs from the final manuscript notation.
8. The code's USV parameters differ slightly from the paper handoff/table summary.
9. Simulink-generated `slprj/` and `.slxc` files are not source; avoid editing them manually.
10. Many scripts assume result signal names such as `p_hat_1`, `p_d_1`, `rho_e1`, `B_rho1`, `t_u1`, and `t_r1`.

## Suggested next work

1. Decide whether the final paper should cite the `nn2023b` figures or the `disturb` figures.
2. Reconcile the parameter table in `main.tex` with the actual Simulink dynamics parameters.
3. If the final theorem uses scalar `sigma_i` and arctangent saturation, either update the Simulink controller or explicitly treat the current code as a simulation predecessor.
4. If the paper claims actual safety distance, update `Myplot_OE.m` Fig. 5 to use actual `agent{i}` positions rather than `p_d`.
5. If restart behavior in Layer 3 matters for the simulation narrative, re-enable and generalize the low-level restart logic instead of keeping the `t=50` block commented.
6. Add a lightweight README command sequence:

```matlab
run('ini.m')
savere('disturb')
compare_abc_vertical_active_set()
```

## Quick mental map

- Want to change initial scenario/topology: edit `ini.m`.
- Want to rerun a model and regenerate five figures: call `savere('<modelName>')`.
- Want to change observer/guidance law: edit each `Follower_Model` block inside the relevant `.slx`.
- Want to change PPC/saturation controller: edit each `LowLevel_Controller` block inside the relevant `.slx`.
- Want to change physical USV model/disturbance: edit each `USV*/MATLAB Function` dynamics block.
- Want to change final plot style or figure content: edit `Myplot_OE.m`.
- Want active-set comparison figures: use `compare_abc_vertical_active_set.m`.
