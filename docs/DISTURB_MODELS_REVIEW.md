# Disturb Simulink Models Review

## What was installed/configured

- No MATLAB/Simulink MCP plugin is available in the current Codex plugin marketplace.
- A local Codex skill was added at:
  `C:\Users\Administrator\.codex\skills\matlab-simulink\SKILL.md`
- MATLAB is available locally:
  - MATLAB R2023b: `23.2.0.2365128`
  - Simulink: `23.2`
  - Executable: `D:\matlab\bin\matlab.exe`

Restart Codex after this session if you want the new `matlab-simulink` skill to appear in the auto-discovered skill list.

## Models run

The following models were run successfully with `savere(modelName)`:

- `disturb.slx`
- `disturb1.slx`
- `disturb2.slx`

All three use:

- `StopTime = 80`
- `Solver = ode45`
- `FixedStep = auto`

The runs completed without simulation errors. MATLAB only reported EPS vector export warnings from `exportgraphics`, which affect plotting performance/file complexity, not simulation correctness.

Generated/updated outputs:

- `sim_results/disturb_res.mat`
- `sim_results/disturb1_res.mat`
- `sim_results/disturb2_res.mat`
- `figures_OE/disturb/*`
- `figures_OE/disturb1/*`
- `figures_OE/disturb2/*`
- `figures_OE/Comparison/ABC_Vertical_Combined.eps`
- `figures_OE/Comparison/ABC_Vertical_Combined.png`

## Numeric summary

Computed with `analyze_disturb_metrics.m`.

| model | obsMaxPost | obsEnd | centerPost | rhoPost | minPdDist | minActDist | satFrac |
|---|---:|---:|---:|---:|---:|---:|---:|
| `disturb` | 0.1912 | 0.05367 | 1.164 | 0.1661 | 11.18 | 10.76 | 0.007811 |
| `nn2023b1` | 0.1912 | 0.05367 | 1.889 | 0.1498 | 11.18 | 10.74 | 0.008025 |
| `disturb1` | 0.1912 | 0.05367 | 35.01 | 1.884 | 7.331 | 7.346 | 0.07196 |
| `disturb2` | 1.882 | 0.9888 | 2.12 | 1.781 | 11.18 | 8.484 | 0.0396 |

Column meanings:

- `obsMaxPost`: maximum active-set observer error after agent removal at `t=50`.
- `obsEnd`: final active-set maximum observer error.
- `centerPost`: mean active-set guidance-center error after `t=50`.
- `rhoPost`: mean active-set range tracking error after `t=50`.
- `minPdDist`: minimum active-set desired-position pair distance.
- `minActDist`: minimum active-set actual-position pair distance.
- `satFrac`: fraction of active samples where either surge or yaw command is near saturation.

## Interpretation

### `disturb`

This is the strongest candidate for the paper's main disturbance case.

It has:

- small post-switch observer residual,
- low post-switch guidance-center error,
- low mean tracking error,
- desired and actual distances above `10 m`,
- low saturation fraction.

This supports the paper narrative.

### `disturb2`

This is a reasonable observer-ablation baseline.

Extracted follower code shows all six follower blocks changed:

```matlab
% proposed/disturb:
dv_hat_i = -kp * eta_iv - Omega_bar * sig_eta_iv;

% disturb2:
dv_hat_i = -kp * eta_iv;
```

That cleanly removes the nonlinear robust observer term. The metrics reflect this:

- `obsMaxPost` grows from `0.1912` to `1.882`,
- `obsEnd` grows from `0.05367` to `0.9888`,
- `rhoPost` grows from `0.1661` to `1.781`.

So `disturb2` is defensible as a "linear weak observer" baseline.

### `disturb1`

This baseline is currently problematic.

It appears intended to represent a fixed-gain/asymptotic guidance baseline. Four follower blocks use:

```matlab
v_d_i = 0.2 * v_hat_i - 0.05 * p_tilde_d_i + sum_avoid;
```

But two follower blocks still use the proposed law:

```matlab
v_d_i = v_hat_i - k_gain *(p_tilde_d_i -sum_avoid);
```

That means `disturb1` is not a clean all-agent ablation. It is a mixed-controller case.

The metrics are much worse:

- `centerPost = 35.01`
- `rhoPost = 1.884`
- `minPdDist = 7.331`
- `minActDist = 7.346`
- `satFrac = 0.07196`

This makes it visually useful as a bad baseline, but risky for a paper if described as a clean, fair fixed-gain comparison.

## Comparison-script issue

`compare_abc_vertical_active_set.m` uses two different baseline lists:

```matlab
modelList_AC = {'disturb','disturb1','disturb2'};
modelList_B  = {'disturb','nn2023b1','disturb2'};
```

So panel (b), guidance-center error, compares `disturb` against `nn2023b1`, not `disturb1`.

This is a major provenance issue:

- The paper text says the disturbance-enhanced `disturb` family is the main comparison.
- `nn2023b1` is from the non-disturbance / prettier-figure family.
- The metric table shows `nn2023b1` is much closer to `disturb` than `disturb1`.

If panel (b) is intentionally using `nn2023b1`, the caption and text must say so. If not intentional, change `modelList_B` to:

```matlab
modelList_B = {'disturb','disturb1','disturb2'};
```

## Code problems and risks

1. **Baseline A is not clean**
   - `disturb1` has a mixed guidance law across follower blocks.
   - Fix by making all six follower blocks use the same intended baseline law.

2. **Comparison figure mixes disturbance and non-disturbance models**
   - `compare_abc_vertical_active_set.m` uses `nn2023b1` for panel (b).
   - This should be corrected or explicitly justified.

3. **Actual safety is weaker than desired safety**
   - `Myplot_OE.m` Fig. 5 computes distances from `p_d`, not actual `agent` positions.
   - The new metric script shows actual distances:
     - `disturb`: minimum actual distance `10.76`, OK.
     - `disturb2`: minimum actual distance `8.484`, below `10`.
     - `disturb1`: minimum actual distance `7.346`, below `10`.
   - If paper Fig. 5 is described as actual inter-agent distance, the plotting script should be changed.

4. **Layer-3 implementation differs from final paper notation**
   - Code uses `kappa_rho/kappa_psi`, hard saturation, and `S_rho/S_psi`.
   - Paper describes scalar `sigma_i` and arctangent smooth saturation approximation.
   - This is acceptable only if the paper has been adapted from the code, not if the code is claimed as exact implementation of the final equations.

5. **Low-level controller restart is commented out**
   - In `LowLevel_Controller`, the `t=50` restart block for `rho_e_0`, `psi_e_0`, and `t_local=t-50` is commented.
   - The current controller uses `t_local=t`.
   - If the paper claims low-level prescribed-performance restart after topology changes, this is not currently implemented.

6. **Model parameter mismatch with manuscript summary**
   - Extracted dynamics use:
     - `m11=24.9`, `m22=32.7`, `m33=2.86`
     - `Du=11`, `Dv=16`, `Dr=0.6`
   - The paper handoff summary mentions slightly different table values.
   - Reconcile before submission.

7. **Duplicated MATLAB Function blocks**
   - The core algorithms are copied into multiple embedded MATLAB Function blocks.
   - Manual edits can easily update only some agents.
   - This already appears to have happened in `disturb1`.

## Recommendation

For the paper comparison, keep `disturb2` as the observer-ablation baseline, but repair or redesign `disturb1`.

Best options:

1. Clean fixed-gain guidance baseline:
   - all six followers use the same non-prescribed/fixed-gain guidance law,
   - observer and low-level controller remain the same,
   - then compare active-set center error and tracking error.

2. Clean full fixed-gain baseline:
   - remove prescribed-time singular terms from guidance and tracking consistently,
   - keep saturation and disturbances,
   - describe exactly which terms are removed.

3. If using `nn2023b1` for visual reasons:
   - do not call it a disturbance-case baseline,
   - explain in caption/text that panel (b) comes from a nominal visual comparison.

Current safest statement:

> `disturb2` is a valid weak-observer baseline; `disturb1` demonstrates degradation under weakened guidance but should be cleaned before being used as a formal fair baseline.

