function plot_m1_highlight_figures(modelName)
%PLOT_M1_HIGHLIGHT_FIGURES Generate the spatiotemporal and topology highlights.

    if nargin < 1 || isempty(modelName)
        modelName = 'abl_M1_proposed';
    end

    set(groot, 'defaultFigureVisible', 'off');
    set(groot, 'defaultAxesFontName', 'Times New Roman');
    set(groot, 'defaultTextFontName', 'Times New Roman');
    set(groot, 'defaultTextInterpreter', 'latex');
    set(groot, 'defaultAxesTickLabelInterpreter', 'latex');
    set(groot, 'defaultLegendInterpreter', 'latex');

    outDir = fullfile('figures_OE', [modelName, '_highlight']);
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    d = load_highlight_data(modelName);
    C = highlight_usv_colors();
    plot_spatiotemporal_trajectory(d, C, outDir);
    plot_topology_movie_frames(d, C, outDir);
    fprintf('Highlight figures generated in %s\n', outDir);
end

function plot_spatiotemporal_trajectory(d, C, outDir)
    fig = figure('Name', 'Spatiotemporal fencing trajectory', ...
        'Units', 'centimeters', 'Position', [2 2 17.5 14.5], 'Color', 'w');
    ax = axes(fig); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
    style_axes(ax);

    timeMap = highlight_time_colormap(256);
    oceanHandle = draw_ocean_floor(ax, d);
    theta = linspace(0, 2*pi, 64).';
    tubeIdx = 1:30:numel(d.t);
    X = d.p0(tubeIdx,1).' + d.radius*cos(theta);
    Y = d.p0(tubeIdx,2).' + d.radius*sin(theta);
    Z = repmat(d.t(tubeIdx).', numel(theta), 1);
    surf(ax, X, Y, Z, Z, 'FaceAlpha', 0.08, 'EdgeAlpha', 0.025, ...
        'FaceColor', 'interp', 'HandleVisibility', 'off');
    colormap(ax, timeMap);

    plot3(ax, d.p0(:,1), d.p0(:,2), d.t, 'k--', 'LineWidth', 2.2, ...
        'DisplayName', 'Target');
    h = gobjects(6,1);
    for i = 1:6
        valid = d.validMask(:,i);
        if i <= 4
            lineWidth = 1.80;
        else
            lineWidth = 1.35;
        end
        h(i) = plot3(ax, d.pAgent(valid,1,i), d.pAgent(valid,2,i), d.t(valid), ...
            '-', 'Color', C(i,:), 'LineWidth', lineWidth, ...
            'DisplayName', sprintf('USV%d', i));
    end

    polygonTimes = [0 15 30 45 60 75];
    maxLabelX = -inf;
    for s = 1:numel(polygonTimes)
        ts = polygonTimes(s);
        [~, k] = min(abs(d.t-ts));
        active = find(d.validMask(k,:));
        xSnap = reshape(d.pAgent(k,1,active), [], 1);
        ySnap = reshape(d.pAgent(k,2,active), [], 1);
        angle = atan2(ySnap-d.p0(k,2), xSnap-d.p0(k,1));
        [~, order] = sort(angle);
        xPoly = [xSnap(order); xSnap(order(1))];
        yPoly = [ySnap(order); ySnap(order(1))];
        zPoly = repmat(d.t(k), numel(xPoly), 1);
        timeColor = interp1(linspace(d.t(1),d.t(end),256), timeMap, d.t(k));
        patch(ax, xPoly, yPoly, zPoly, timeColor, 'FaceAlpha', 0.18, ...
            'EdgeColor', timeColor, 'LineWidth', 2.35, 'HandleVisibility', 'off');
        if ts == 0
            draw_submarine_icon_3d(ax, d.p0(k,1), d.p0(k,2), d.t(k), 0, 24);
            for ii = 1:numel(active)
                hdg = atan2(d.p0(k,2)-ySnap(ii), d.p0(k,1)-xSnap(ii));
                draw_usv_icon_3d(ax, xSnap(ii), ySnap(ii), d.t(k), hdg, 18);
            end
        else
            scatter3(ax, xSnap, ySnap, repmat(d.t(k),numel(active),1), ...
                42, repmat(timeColor,numel(active),1), 'filled', ...
                'MarkerEdgeColor', 'none', 'HandleVisibility', 'off');
        end
        labelX = max(xSnap)+20;
        maxLabelX = max(maxLabelX, labelX);
        text(ax, labelX, mean(ySnap), d.t(k), ...
            sprintf('$t=%.0f$ s', ts), 'FontSize', 8.5, ...
            'FontWeight', 'bold', 'Color', timeColor, ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
    end
    xlabel(ax, '$x$ (m)'); ylabel(ax, '$y$ (m)'); zlabel(ax, 'Time (s)');
    title(ax, 'Spatiotemporal evolution of the enclosing formation', ...
        'FontWeight', 'normal');
    view(ax, 42, 26); axis(ax, 'tight');
    xBounds = xlim(ax);
    xlim(ax, [xBounds(1), max(xBounds(2),maxLabelX+15)]);
    uistack(oceanHandle, 'bottom');
    ax.GridAlpha = 0.18;
    legend(ax, [h; findobj(ax,'DisplayName','Target')], ...
        'Location', 'northeast', 'NumColumns', 2, 'Box', 'off');
    cb = colorbar(ax, 'eastoutside');
    cb.Label.String = 'Time (s)';
    clim(ax, [d.t(1) d.t(end)]);
    save_figure(fig, outDir, 'FigH1_Spatiotemporal_Trajectory');
end

function draw_usv_icon_3d(ax, x0, y0, z0, heading, width)
    % Geometry and colors follow fig_assets/usv_icon.eps.
    z = z0 + 1.15;
    draw_icon_stroke(ax, x0, y0, z, heading, width, ...
        bezier_path([18 18], [50 12], [86 12], [122 18], 40), [0.45 0.63 0.74], 0.55);
    draw_icon_stroke(ax, x0, y0, z, heading, width, ...
        bezier_path([28 10], [58 6], [98 6], [132 11], 40), [0.45 0.63 0.74], 0.50);
    draw_icon_patch(ax, x0, y0, z, heading, width, ...
        [28 32; 42 17; 125 17; 145 36; 129 45; 47 45], [0.03 0.15 0.22], 0.92);
    draw_icon_patch(ax, x0, y0, z, heading, width, ...
        [20 40; 40 24; 121 24; 146 43; 127 54; 44 54], [0.02 0.35 0.56], 0.98);
    draw_icon_patch(ax, x0, y0, z, heading, width, ...
        [34 44; 48 34; 118 34; 133 44; 123 48; 47 48], [0.18 0.65 0.82], 0.98);
    draw_icon_patch(ax, x0, y0, z, heading, width, ...
        [105 50; 124 44; 137 46; 124 52], [0.77 0.91 0.95], 0.98);
    draw_icon_patch(ax, x0, y0, z, heading, width, ...
        [58 54; 70 69; 104 69; 116 54], [0.88 0.95 0.98], 0.98);
    draw_icon_patch(ax, x0, y0, z, heading, width, ...
        [74 63; 82 63; 82 57; 69 57], [0.05 0.24 0.35], 0.98);
    draw_icon_patch(ax, x0, y0, z, heading, width, ...
        [88 63; 101 63; 106 57; 88 57], [0.05 0.24 0.35], 0.98);
    draw_icon_stroke(ax, x0, y0, z, heading, width, [87 69; 87 81], [0.08 0.18 0.25], 0.85);
    draw_icon_stroke(ax, x0, y0, z, heading, width, [76 78; 98 78], [0.08 0.18 0.25], 0.65);
    draw_icon_stroke(ax, x0, y0, z, heading, width, [87 81; 93 86], [0.08 0.18 0.25], 0.65);
    draw_icon_patch(ax, x0, y0, z, heading, width, ...
        [91 85; 93 83; 95 85; 93 87], [0.95 0.40 0.15], 0.98);
    draw_icon_stroke(ax, x0, y0, z, heading, width, [40 54; 126 54], [0.92 0.98 1.00], 0.45);
end

function draw_submarine_icon_3d(ax, x0, y0, z0, heading, width)
    % Geometry and colors follow fig_assets/submarine_icon.eps.
    z = z0 + 1.20;
    draw_icon_stroke(ax, x0, y0, z, heading, width, ...
        bezier_path([18 64], [50 60], [84 60], [124 64], 40), [0.48 0.61 0.67], 0.45);
    draw_icon_stroke(ax, x0, y0, z, heading, width, ...
        bezier_path([30 20], [70 16], [107 16], [140 20], 40), [0.48 0.61 0.67], 0.45);
    draw_icon_patch(ax, x0, y0, z, heading, width, [21 45; 8 55; 7 45; 8 35], [0.35 0.19 0.15], 0.95);
    draw_icon_patch(ax, x0, y0, z, heading, width, [24 45; 13 31; 25 35; 34 45], [0.35 0.19 0.15], 0.95);
    draw_icon_patch(ax, x0, y0, z, heading, width, [24 45; 13 59; 25 55; 34 45], [0.35 0.19 0.15], 0.95);
    bodyShadow = [bezier_path([24 39],[41 23],[108 23],[136 39],24); ...
                  bezier_path([136 39],[146 45],[146 51],[136 55],16); ...
                  bezier_path([136 55],[106 68],[42 65],[24 51],24); ...
                  bezier_path([24 51],[16 45],[16 43],[24 39],16)];
    draw_icon_patch(ax, x0, y0, z, heading, width, bodyShadow, [0.18 0.10 0.09], 0.95);
    body = [bezier_path([22 43],[42 27],[108 27],[137 42],24); ...
            bezier_path([137 42],[148 48],[148 54],[137 59],16); ...
            bezier_path([137 59],[106 71],[43 67],[22 54],24); ...
            bezier_path([22 54],[13 49],[13 47],[22 43],16)];
    draw_icon_patch(ax, x0, y0, z, heading, width, body, [0.55 0.16 0.12], 0.98);
    highlight = [bezier_path([34 44],[56 34],[103 34],[128 44],22); ...
                 bezier_path([128 44],[136 47],[136 50],[128 52],12); ...
                 bezier_path([128 52],[96 47],[62 47],[34 52],22); ...
                 bezier_path([34 52],[27 50],[27 47],[34 44],12)];
    draw_icon_patch(ax, x0, y0, z, heading, width, highlight, [0.88 0.38 0.22], 0.98);
    draw_icon_patch(ax, x0, y0, z, heading, width, [72 60; 80 77; 106 77; 114 59], [0.40 0.12 0.11], 0.98);
    draw_icon_patch(ax, x0, y0, z, heading, width, [80 66; 86 73; 103 73; 108 65], [0.76 0.28 0.19], 0.98);
    draw_icon_stroke(ax, x0, y0, z, heading, width, [93 77; 93 84; 111 84], [0.22 0.13 0.12], 0.65);
    draw_icon_patch(ax, x0, y0, z, heading, width, ellipse_path(64, 51, 6, 6, 30), [0.97 0.78 0.45], 0.98);
    draw_icon_patch(ax, x0, y0, z, heading, width, ellipse_path(88, 52, 6, 6, 30), [0.97 0.78 0.45], 0.98);
    draw_icon_patch(ax, x0, y0, z, heading, width, ellipse_path(112, 52, 6, 6, 30), [0.97 0.78 0.45], 0.98);
    draw_icon_stroke(ax, x0, y0, z, heading, width, [133 50; 143 50], [0.98 0.92 0.72], 0.45);
    draw_icon_stroke(ax, x0, y0, z, heading, width, [138 45; 138 55], [0.98 0.92 0.72], 0.45);
    draw_icon_stroke(ax, x0, y0, z, heading, width, ellipse_path(138, 50, 8, 8, 60), [0.98 0.92 0.72], 0.45);
end

function draw_icon_patch(ax, x0, y0, z0, heading, width, pts, color, alphaVal)
    [x, y] = icon_transform(pts, x0, y0, heading, width);
    patch(ax, x, y, z0*ones(size(x)), color, 'FaceAlpha', alphaVal, ...
        'EdgeColor', 'none', 'HandleVisibility', 'off');
end

function draw_icon_stroke(ax, x0, y0, z0, heading, width, pts, color, lineWidth)
    [x, y] = icon_transform(pts, x0, y0, heading, width);
    plot3(ax, x, y, z0*ones(size(x)), '-', 'Color', color, ...
        'LineWidth', lineWidth, 'HandleVisibility', 'off');
end

function [x, y] = icon_transform(pts, x0, y0, heading, width)
    scale = width/160;
    centered = [(pts(:,1)-80)*scale, (pts(:,2)-45)*scale];
    R = [cos(heading) -sin(heading); sin(heading) cos(heading)];
    rotated = centered*R.';
    x = x0 + rotated(:,1);
    y = y0 + rotated(:,2);
end

function pts = bezier_path(p0, p1, p2, p3, n)
    u = linspace(0, 1, n).';
    pts = (1-u).^3*p0 + 3*(1-u).^2.*u*p1 + 3*(1-u).*u.^2*p2 + u.^3*p3;
end

function pts = ellipse_path(cx, cy, rx, ry, n)
    th = linspace(0, 2*pi, n).';
    pts = [cx + rx*cos(th), cy + ry*sin(th)];
end

function oceanHandle = draw_ocean_floor(ax, d)
    xAll = [d.p0(:,1); reshape(d.pAgent(:,1,:), [], 1)];
    yAll = [d.p0(:,2); reshape(d.pAgent(:,2,:), [], 1)];
    xAll = xAll(isfinite(xAll));
    yAll = yAll(isfinite(yAll));
    padX = 18;
    padY = 16;
    xLim = [min(xAll)-padX, max(xAll)+48];
    yLim = [min(yAll)-padY, max(yAll)+padY];

    nx = 120;
    ny = 96;
    [Xw, Yw] = meshgrid(linspace(xLim(1), xLim(2), nx), ...
                        linspace(yLim(1), yLim(2), ny));
    wave = 0.5 + 0.5*sin(0.075*Xw + 0.11*Yw) .* cos(0.055*Xw - 0.095*Yw);
    ripple = 0.5 + 0.5*sin(0.18*Xw - 0.04*Yw);
    texture = 0.72*wave + 0.28*ripple;
    shallow = reshape([0.78 0.93 0.98], 1, 1, 3);
    deep = reshape([0.42 0.76 0.88], 1, 1, 3);
    Cw = shallow.*(1-texture) + deep.*texture;
    Zw = zeros(size(Xw));
    oceanHandle = surf(ax, Xw, Yw, Zw, Cw, ...
        'FaceColor', 'texturemap', 'EdgeColor', 'none', ...
        'FaceAlpha', 0.58, 'AmbientStrength', 0.65, ...
        'DiffuseStrength', 0.35, 'HandleVisibility', 'off');

    waveColor = [0.72 0.93 0.99];
    for yy = linspace(yLim(1)+5, yLim(2)-5, 10)
        xx = linspace(xLim(1), xLim(2), 260);
        yyLine = yy + 1.0*sin(0.055*xx + 0.12*yy);
        plot3(ax, xx, yyLine, 0.12*ones(size(xx)), '-', ...
            'Color', [waveColor 0.22], 'LineWidth', 0.55, ...
            'HandleVisibility', 'off');
    end
end

function plot_topology_movie_frames(d, C, outDir)
    A1 = [0 1 1 0 1 1; 1 0 1 1 0 1; 1 1 0 1 0 0; ...
          0 1 1 0 1 0; 1 0 0 1 0 1; 1 1 0 0 1 0];
    A2 = [0 1 0 1 0 0; 1 0 1 1 0 0; 0 1 0 1 0 0; ...
          1 1 1 0 0 0; 0 0 0 0 0 0; 0 0 0 0 0 0];
    beta1 = [0 1 0 0 1 1];
    beta2 = [0 1 1 0 0 0];
    frameTimes = [45 50 55 70];
    frameTitles = {'Pre-switch formation', 'Topology switch and removal', ...
                   'Restart and self-ordering', 'Reconstructed steady formation'};

    fig = figure('Name', 'Topology reconstruction frames', ...
        'Units', 'centimeters', 'Position', [2 2 18.2 14.5], 'Color', 'w');
    tl = tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

    for f = 1:4
        ax = nexttile(tl, f); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
        style_axes(ax); axis(ax, 'equal');
        [~, k] = min(abs(d.t-frameTimes(f)));
        rel = squeeze(d.pAgent(k,:,:)).' - d.p0(k,:);
        relDes = squeeze(d.pDes(k,:,:)).' - d.p0(k,:);

        if frameTimes(f) < d.switchTime
            A = A1; beta = beta1; active = 1:6; removed = [];
        else
            A = A2; beta = beta2; active = find(d.activeAfter); removed = find(~d.activeAfter);
        end

        ang = linspace(0,2*pi,240);
        plot(ax, d.radius*cos(ang), d.radius*sin(ang), '--', ...
            'Color', [0.55 0.58 0.62], 'LineWidth', 0.9, 'HandleVisibility', 'off');

        for i = 1:6
            for j = i+1:6
                if A(i,j) > 0
                    plot(ax, rel([i j],1), rel([i j],2), '-', ...
                        'Color', [0.58 0.61 0.65], 'LineWidth', 1.05, ...
                        'HandleVisibility', 'off');
                end
            end
        end
        for i = active
            if beta(i) > 0
                plot(ax, [0 rel(i,1)], [0 rel(i,2)], '--', ...
                    'Color', [0.82 0.20 0.16], 'LineWidth', 1.05, ...
                    'HandleVisibility', 'off');
            end
            plot(ax, [rel(i,1) relDes(i,1)], [rel(i,2) relDes(i,2)], ':', ...
                'Color', [C(i,:) 0.45], 'LineWidth', 0.8, 'HandleVisibility', 'off');
            plot(ax, relDes(i,1), relDes(i,2), 'o', 'Color', C(i,:), ...
                'MarkerSize', 7, 'LineWidth', 1.2, 'HandleVisibility', 'off');
            scatter(ax, rel(i,1), rel(i,2), 48, C(i,:), 'filled', ...
                'MarkerEdgeColor', 'w', 'LineWidth', 0.7, 'HandleVisibility', 'off');
            text(ax, rel(i,1)+0.8, rel(i,2)+0.8, sprintf('%d',i), ...
                'FontSize', 8.5, 'Color', C(i,:));
        end

        if f == 2
            for i = removed
                plot(ax, rel(i,1), rel(i,2), 'x', 'Color', [0.25 0.25 0.25], ...
                    'MarkerSize', 10, 'LineWidth', 2.0, 'HandleVisibility', 'off');
                text(ax, rel(i,1)+0.8, rel(i,2)-1.2, sprintf('%d removed',i), ...
                    'FontSize', 8, 'Color', [0.25 0.25 0.25]);
            end
        end

        plot(ax, 0, 0, 'p', 'MarkerSize', 12, 'MarkerFaceColor', [0.10 0.10 0.10], ...
            'MarkerEdgeColor', 'w', 'LineWidth', 0.7, 'HandleVisibility', 'off');
        xlim(ax, [-22 22]); ylim(ax, [-22 22]);
        xlabel(ax, '$x_i-x_0$ (m)'); ylabel(ax, '$y_i-y_0$ (m)');
        title(ax, sprintf('(%c) %s, $t=%.0f$ s', 'a'+f-1, frameTitles{f}, frameTimes(f)), ...
            'FontWeight', 'normal', 'FontSize', 10);
    end

    ax = nexttile(tl, 1);
    h1 = scatter(ax, nan, nan, 45, [0.2 0.45 0.75], 'filled', 'DisplayName', 'Actual USV');
    h2 = plot(ax, nan, nan, 'o', 'Color', [0.2 0.45 0.75], 'DisplayName', 'Desired slot');
    h3 = plot(ax, nan, nan, '-', 'Color', [0.58 0.61 0.65], 'DisplayName', 'Communication link');
    h4 = plot(ax, nan, nan, '--', 'Color', [0.82 0.20 0.16], 'DisplayName', 'Target-pinned link');
    h5 = plot(ax, nan, nan, 'p', 'MarkerFaceColor', [0.10 0.10 0.10], ...
        'MarkerEdgeColor', 'w', 'DisplayName', 'Target');
    lgd = legend(ax, [h1 h2 h3 h4 h5], 'Orientation', 'horizontal', ...
        'NumColumns', 5, 'Box', 'off', 'FontSize', 8.5);
    lgd.Layout.Tile = 'south';
    save_figure(fig, outDir, 'FigH2_Topology_Reconstruction_Frames');
end

function d = load_highlight_data(modelName)
    S = load(fullfile('sim_results', [modelName '_res.mat']));
    M = load(fullfile('sim_results', [modelName '_paper_metrics.mat']));
    D = S.out; metrics = M.paper_metrics;
    tRaw = D.agent1.time(:);
    t = linspace(tRaw(1), tRaw(end), 3500).';
    p0 = interp_vec2(D.p0, tRaw, t);
    pAgent = nan(numel(t),2,6);
    pDes = nan(numel(t),2,6);
    for i = 1:6
        pAgent(:,:,i) = interp_vec2(D.(sprintf('agent%d',i)), tRaw, t);
        pDes(:,:,i) = interp_vec2(D.(sprintf('p_d_%d',i)), tRaw, t);
    end
    activeAfter = logical(metrics.active_flags(:).');
    validMask = true(numel(t),6);
    validMask(t >= metrics.switch_time, ~activeAfter) = false;
    d.t = t; d.p0 = p0; d.pAgent = pAgent; d.pDes = pDes;
    d.activeAfter = activeAfter; d.validMask = validMask;
    d.switchTime = metrics.switch_time; d.radius = 10;
end

function y = interp_vec2(sig, tRaw, tRef)
    if isfield(sig,'time') && ~isempty(sig.time), t = sig.time(:); else, t = tRaw; end
    v = sig.signals.values; sz = size(v);
    if ismatrix(v) && sz(2) >= 2
        raw = v(:,1:2);
    elseif ndims(v) == 3 && sz(1) >= 2
        raw = squeeze(v(1:2,1,:)).';
    elseif ndims(v) == 3 && sz(2) >= 2
        raw = squeeze(v(1,1:2,:)).';
    else
        error('Unsupported signal shape [%s].', num2str(sz));
    end
    if numel(t) ~= size(raw,1)
        t = linspace(tRaw(1),tRaw(end),size(raw,1)).';
    end
    y = interp1(t,raw,tRef,'linear','extrap');
end

function style_axes(ax)
    set(ax, 'TickDir','in', 'LineWidth',0.95, 'FontSize',9.5, ...
        'XMinorTick','on', 'YMinorTick','on');
    ax.GridAlpha = 0.16;
end

function C = highlight_usv_colors()
    C = [0.055 0.310 0.545;  % USV1: deep blue
         0.820 0.300 0.120;  % USV2: vermilion
         0.900 0.590 0.080;  % USV3: warm gold
         0.455 0.235 0.545;  % USV4: plum
         0.405 0.555 0.430;  % USV5: muted sage (removed at 50 s)
         0.355 0.600 0.675]; % USV6: muted steel cyan (removed at 50 s)
end

function cmap = highlight_time_colormap(n)
    anchors = [0.235 0.170 0.430;
               0.100 0.350 0.620;
               0.055 0.565 0.560;
               0.490 0.710 0.330;
               0.930 0.690 0.135];
    cmap = interp1(linspace(0,1,size(anchors,1)), anchors, ...
        linspace(0,1,n), 'linear');
end

function save_figure(fig, outDir, baseName)
    exportgraphics(fig, fullfile(outDir,[baseName '.eps']), 'ContentType','vector');
    exportgraphics(fig, fullfile(outDir,[baseName '.jpg']), 'Resolution',600);
end
