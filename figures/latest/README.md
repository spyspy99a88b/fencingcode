# Latest Figures

This folder mirrors the latest approved JPG figures from the current simulation workflow.

- `refined/`: latest M1 publication-refined figures.
- `highlight/`: latest M1 highlight figures.
- `ablation/`: latest default pairwise ablation figures.

After changing a plotting script and regenerating figures, run:

```powershell
.\sync_latest_figures.ps1 -CommitMessage "Update latest figures"
```

The script copies current JPG files into this folder, mirrors them to the local GitHub checkout under `figures/latest/`, updates the relevant plotting sources, commits, and pushes `main`.

