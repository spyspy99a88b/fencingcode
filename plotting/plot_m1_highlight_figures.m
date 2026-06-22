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
            draw_target_icon_3d(ax, d.p0(k,1), d.p0(k,2), d.t(k), 4.7);
            for ii = 1:numel(active)
                usvId = active(ii);
                hdg = atan2(d.p0(k,2)-ySnap(ii), d.p0(k,1)-xSnap(ii));
                draw_usv_icon_3d(ax, xSnap(ii), ySnap(ii), d.t(k), hdg, C(usvId,:), 4.8);
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

function draw_target_icon_3d(ax, x0, y0, z0, scale)
    th = linspace(0, 2*pi, 80);
    red = [0.86 0.10 0.12];
    fill3(ax, x0 + scale*cos(th), y0 + scale*sin(th), z0 + 0.65*ones(size(th)), ...
        [1.00 0.78 0.74], 'FaceAlpha', 0.94, 'EdgeColor', red, ...
        'LineWidth', 1.25, 'HandleVisibility', 'off');
    plot3(ax, x0 + 0.58*scale*cos(th), y0 + 0.58*scale*sin(th), ...
        z0 + 0.68*ones(size(th)), '-', 'Color', red, 'LineWidth', 1.05, ...
        'HandleVisibility', 'off');
    plot3(ax, [x0-scale x0+scale], [y0 y0], [z0+0.70 z0+0.70], '-', ...
        'Color', red, 'LineWidth', 1.05, 'HandleVisibility', 'off');
    plot3(ax, [x0 x0], [y0-scale y0+scale], [z0+0.70 z0+0.70], '-', ...
        'Color', red, 'LineWidth', 1.05, 'HandleVisibility', 'off');
end

function draw_usv_icon_3d(ax, x0, y0, z0, heading, color, scale)
    hull = scale .* [1.10 0.00; 0.32 0.56; -0.92 0.38; -0.68 0.00; -0.92 -0.38; 0.32 -0.56];
    deck = scale .* [0.32 0.00; -0.25 0.23; -0.50 0.00; -0.25 -0.23];
    R = [cos(heading) -sin(heading); sin(heading) cos(heading)];
    hull = hull*R.';
    deck = deck*R.';
    patch(ax, x0+hull(:,1), y0+hull(:,2), z0+0.82*ones(size(hull,1),1), color, ...
        'FaceAlpha', 0.98, 'EdgeColor', [0.10 0.13 0.16], 'LineWidth', 0.75, ...
        'HandleVisibility', 'off');
    patch(ax, x0+deck(:,1), y0+deck(:,2), z0+0.88*ones(size(deck,1),1), ...
        min(color+0.30, 1), 'FaceAlpha', 0.82, 'EdgeColor', 'none', ...
        'HandleVisibility', 'off');
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
