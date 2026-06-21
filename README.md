# Fencing Control for Underactuated USVs

MATLAB/Simulink implementation of restart-based self-ordering fencing control for six underactuated USVs under topology changes, environmental disturbances, and actuator saturation.

## Current Models

- `models/abl_M1_proposed.slx`: complete proposed method.
- `models/abl_M2_fixedObserver.slx`: fixed-gain observer ablation.
- `models/abl_M3_fixedGuidance.slx`: fixed-assignment guidance ablation.
- `models/abl_M4_rigidPPC.slx`: rigid prescribed-performance ablation.

The current scenario uses an 80 s simulation, a topology change at 50 s, removal of USV5 and USV6 from the active graph, disturbance amplitude 0.50, and surge/yaw limits of 800 N and 400 Nm.

## Quick Start

Open MATLAB in the repository root, then run:

```matlab
addpath(genpath(pwd))
savere_paper('models/abl_M1_proposed')
```

For an existing saved result placed under `sim_results/`, generate figures with:

```matlab
Myplot_OE_paper('abl_M1_proposed')
plot_m1_publication_refined('abl_M1_proposed')
plot_m1_highlight_figures('abl_M1_proposed')
compare_ablation_paper()
```

Depending on MATLAB path handling, it may be simpler to copy or open a model from the repository root before running it. The original project runs all scripts and models from one folder.

## Repository Contents

- `models/`: current proposed and ablation Simulink models.
- `plotting/`: publication, refined, highlight, and ablation plotting scripts.
- `figures/`: selected current JPG previews.
- `CURRENT_SIMULATION_HANDOFF.md`: authoritative technical handoff and reproduction notes.
- `CODE_HANDOFF.md`: older implementation background.
- `DISTURB_MODELS_REVIEW.md`: historical disturbance-model review.

Large simulation `.mat` files, Simulink caches, generated build folders, and historical tuning models are intentionally excluded.

## Important

Read `CURRENT_SIMULATION_HANDOFF.md` before changing the models. The `.slx` files contain duplicated follower, controller, and dynamics MATLAB Function blocks that must be updated consistently.
