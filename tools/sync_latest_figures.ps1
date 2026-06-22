param(
    [string]$CommitMessage = "Update latest figures"
)

$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$workspaceRoot = Split-Path -Parent $projectRoot
$repoRoot = Join-Path $workspaceRoot 'fencingcode-upload'
$localLatest = Join-Path $projectRoot 'figures_latest'
$repoLatest = Join-Path $repoRoot 'figures\latest'

if (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.git'))) {
    throw "GitHub checkout not found: $repoRoot"
}

$destinations = @(
    (Join-Path $localLatest 'refined'),
    (Join-Path $localLatest 'highlight'),
    (Join-Path $localLatest 'ablation'),
    (Join-Path $repoLatest 'refined'),
    (Join-Path $repoLatest 'highlight'),
    (Join-Path $repoLatest 'ablation'),
    (Join-Path $repoRoot 'tools')
)
$destinations | ForEach-Object {
    New-Item -ItemType Directory -Force -Path $_ | Out-Null
}

function Copy-LatestGroup {
    param(
        [string]$SourceDir,
        [string]$Group,
        [string[]]$Names
    )

    $localDest = Join-Path $localLatest $Group
    $repoDest = Join-Path $repoLatest $Group
    foreach ($name in $Names) {
        $source = Join-Path $SourceDir $name
        if (-not (Test-Path -LiteralPath $source)) {
            throw "Latest figure not found: $source"
        }
        Copy-Item -LiteralPath $source -Destination (Join-Path $localDest $name) -Force
        Copy-Item -LiteralPath $source -Destination (Join-Path $repoDest $name) -Force
    }
}

$refinedNames = @(
    'FigR1_Trajectory_Refined.jpg',
    'FigR2_Observer_Refined.jpg',
    'FigR3_PPC_Active_Refined.jpg',
    'FigR4_ControlZoom_Refined.jpg',
    'FigR5_Safety_Refined.jpg'
)
$highlightNames = @(
    'FigH1_Spatiotemporal_Trajectory.jpg',
    'FigH2_Topology_Reconstruction_Frames.jpg'
)
$ablationNames = @(
    'FigC1_Observer_M1_vs_M2.jpg',
    'FigC2_Guidance_M1_vs_M3.jpg',
    'FigC3_RigidPPC_M1_vs_M4.jpg',
    'FigC4_Ablation_Summary.jpg'
)

Copy-LatestGroup -SourceDir (Join-Path $projectRoot 'figures_OE\abl_M1_proposed_refined') -Group 'refined' -Names $refinedNames
Copy-LatestGroup -SourceDir (Join-Path $projectRoot 'figures_OE\abl_M1_proposed_highlight') -Group 'highlight' -Names $highlightNames
Copy-LatestGroup -SourceDir (Join-Path $projectRoot 'figures_OE\Comparison_Ablation') -Group 'ablation' -Names $ablationNames

Copy-Item -LiteralPath (Join-Path $localLatest 'README.md') -Destination (Join-Path $repoLatest 'README.md') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'plot_m1_publication_refined.m') -Destination (Join-Path $repoRoot 'plotting\plot_m1_publication_refined.m') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'plot_m1_highlight_figures.m') -Destination (Join-Path $repoRoot 'plotting\plot_m1_highlight_figures.m') -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'compare_ablation_paper.m') -Destination (Join-Path $repoRoot 'plotting\compare_ablation_paper.m') -Force
Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $repoRoot 'tools\sync_latest_figures.ps1') -Force

git -C $repoRoot add -- figures/latest plotting/plot_m1_publication_refined.m plotting/plot_m1_highlight_figures.m plotting/compare_ablation_paper.m tools/sync_latest_figures.ps1
$staged = git -C $repoRoot diff --cached --name-only
if (-not $staged) {
    Write-Output 'Latest figures are already synchronized; nothing to push.'
    exit 0
}

git -C $repoRoot commit -m $CommitMessage
git -C $repoRoot push origin main
git -C $repoRoot status -sb
