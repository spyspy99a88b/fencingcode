function metrics = analyze_disturb_metrics(modelList)
%ANALYZE_DISTURB_METRICS Summarize disturbance-model simulation metrics.
%   Reads sim_results/<model>_res.mat and prints active-set observer,
%   guidance, tracking, distance, and saturation statistics.

if nargin < 1 || isempty(modelList)
    modelList = {'disturb','disturb1','disturb2'};
end

numAgents = 6;
dropTime = 50;
removedAgents = [5 6];
satU = 1000;
satR = 500;

metrics = struct([]);

fprintf('\n%-10s %-12s %-12s %-12s %-12s %-12s %-12s %-12s\n', ...
    'model', 'obsMaxPost', 'obsEnd', 'centerPost', 'rhoPost', ...
    'minPdDist', 'minActDist', 'satFrac');

for m = 1:numel(modelList)
    modelName = char(modelList{m});
    resFile = fullfile('sim_results', [modelName, '_res.mat']);
    S = load(resFile);
    out = S.out;
    t = out.tout(:);

    p0 = readVec2(getSig(out, 'p0'), t);
    p0 = interpTo(t, p0, t);

    activeMask = true(numel(t), numAgents);
    activeMask(t >= dropTime, removedAgents) = false;
    postMask = t >= dropTime;

    obsErr = nan(numel(t), numAgents);
    pd = nan(numel(t), 2, numAgents);
    pa = nan(numel(t), 2, numAgents);
    rho = nan(numel(t), numAgents);
    tauU = nan(numel(t), numAgents);
    tauR = nan(numel(t), numAgents);

    for i = 1:numAgents
        ph = readVec2(getSig(out, sprintf('p_hat_%d', i)), t);
        pdi = readVec2(getSig(out, sprintf('p_d_%d', i)), t);
        pai = readAgent(getSig(out, sprintf('agent%d', i)), t);
        rhoi = readScalar(getSig(out, sprintf('rho_e%d', i)), t);
        tui = readScalar(getSig(out, sprintf('t_u%d', i)), t);
        tri = readScalar(getSig(out, sprintf('t_r%d', i)), t);

        ph = interpTo(t, ph, t);
        pdi = interpTo(t, pdi, t);
        pai = interpTo(t, pai, t);

        obsErr(:, i) = sqrt(sum((ph - p0).^2, 2));
        pd(:, :, i) = pdi;
        pa(:, :, i) = pai;
        rho(:, i) = abs(interp1(t, rhoi, t, 'linear', 'extrap'));
        tauU(:, i) = interp1(t, tui, t, 'linear', 'extrap');
        tauR(:, i) = interp1(t, tri, t, 'linear', 'extrap');
    end

    obsActive = obsErr;
    obsActive(~activeMask) = NaN;
    obsMaxActive = max(obsActive, [], 2, 'omitnan');

    centerErr = nan(numel(t), 1);
    for k = 1:numel(t)
        ids = find(activeMask(k, :));
        center = mean(pd(k, :, ids), 3);
        centerErr(k) = norm(center(:)' - p0(k, :));
    end

    rhoActive = rho;
    rhoActive(~activeMask) = NaN;
    rhoMeanActive = mean(rhoActive, 2, 'omitnan');

    minPdDist = minPairDistance(pd, activeMask);
    minActDist = minPairDistance(pa, activeMask);

    satMask = abs(tauU) >= 0.999 * satU | abs(tauR) >= 0.999 * satR;
    satMask(~activeMask) = false;
    satFrac = nnz(satMask) / nnz(activeMask);

    metrics(m).model = modelName;
    metrics(m).obsMaxPost = max(obsMaxActive(postMask), [], 'omitnan');
    metrics(m).obsEnd = obsMaxActive(end);
    metrics(m).centerPostMean = mean(centerErr(postMask), 'omitnan');
    metrics(m).rhoPostMean = mean(rhoMeanActive(postMask), 'omitnan');
    metrics(m).minDesiredDistance = min(minPdDist, [], 'omitnan');
    metrics(m).minActualDistance = min(minActDist, [], 'omitnan');
    metrics(m).saturationFraction = satFrac;

    fprintf('%-10s %-12.4g %-12.4g %-12.4g %-12.4g %-12.4g %-12.4g %-12.4g\n', ...
        modelName, metrics(m).obsMaxPost, metrics(m).obsEnd, ...
        metrics(m).centerPostMean, metrics(m).rhoPostMean, ...
        metrics(m).minDesiredDistance, metrics(m).minActualDistance, satFrac);
end
end

function sig = getSig(out, name)
sig = out.get(name);
end

function y = readScalar(sig, defaultT)
v = squeeze(sig.signals.values);
y = v(:);
if numel(y) ~= numel(defaultT)
    t = signalTime(sig, defaultT);
    y = interp1(t, y, defaultT, 'linear', 'extrap');
end
end

function y = readVec2(sig, defaultT)
v = sig.signals.values;
sz = size(v);
if ismatrix(v) && size(v, 2) == 2
    y = v;
elseif ismatrix(v) && size(v, 1) == 2
    y = v.';
elseif ndims(v) == 3 && sz(1) == 2 && sz(2) == 1
    y = squeeze(v(:, 1, :)).';
elseif ndims(v) == 3 && sz(1) == 1 && sz(2) == 2
    y = squeeze(v(1, :, :)).';
elseif ndims(v) == 3 && sz(2) == 1 && sz(3) == 2
    y = squeeze(v(:, 1, :));
else
    error('Unsupported vector signal shape [%s].', num2str(sz));
end
if size(y, 1) ~= numel(defaultT)
    t = signalTime(sig, defaultT);
    y = interpTo(t, y, defaultT);
end
end

function y = readAgent(sig, defaultT)
v = sig.signals.values;
if size(v, 2) >= 2
    y = v(:, 1:2);
else
    y = readVec2(sig, defaultT);
end
if size(y, 1) ~= numel(defaultT)
    t = signalTime(sig, defaultT);
    y = interpTo(t, y, defaultT);
end
end

function t = signalTime(sig, defaultT)
if isfield(sig, 'time') && ~isempty(sig.time)
    t = sig.time(:);
else
    t = defaultT(:);
end
end

function yq = interpTo(t, y, tq)
yq = interp1(t(:), y, tq(:), 'linear', 'extrap');
end

function dmin = minPairDistance(p, activeMask)
n = size(p, 1);
numAgents = size(p, 3);
dmin = nan(n, 1);
for k = 1:n
    ids = find(activeMask(k, :));
    vals = [];
    for a = 1:numel(ids)
        for b = a+1:numel(ids)
            pa = p(k, :, ids(a));
            pb = p(k, :, ids(b));
            vals(end+1, 1) = norm(pa(:) - pb(:)); %#ok<AGROW>
        end
    end
    if ~isempty(vals)
        dmin(k) = min(vals);
    end
end
end
