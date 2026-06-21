function savere_paper(modelName)
    modelName = char(modelName);
    fprintf('### Paper-aligned simulation started: %s ###\n', modelName);

    if exist('ini_paper.m', 'file')
        fprintf('-> Running ini_paper.m...\n');
        evalin('base', 'run(''ini_paper.m'')');
    elseif exist('ini.m', 'file')
        fprintf('-> Running ini.m...\n');
        evalin('base', 'run(''ini.m'')');
    else
        warning('ini.m not found. The model may miss workspace variables.');
    end

    try
        load_system(modelName);
        set_param(modelName, 'SimulationMode', 'normal');
        out = sim(modelName, 'ReturnWorkspaceOutputs', 'on');
        close_system(modelName, 0);
    catch ME
        fprintf('Simulation failed:\n%s\n', ME.message);
        if bdIsLoaded(modelName), close_system(modelName, 0); end
        rethrow(ME);
    end

    resDir = 'sim_results';
    if ~exist(resDir, 'dir'), mkdir(resDir); end
    savePath = fullfile(resDir, [modelName, '_res.mat']);

    try
        A_raw2 = evalin('base', 'A_raw2');
    catch
        A_raw2 = [];
    end

    provenance = struct();
    provenance.modelName = modelName;
    provenance.createdBy = 'savere_paper.m';
    provenance.tau_limits = detect_tau_limits(modelName);
    provenance.notes = { ...
        'Model copied from disturb.slx for paper-aligned validation.', ...
        'USV dynamics parameters aligned to the manuscript table.', ...
        'Initial desired positions are spread by ini_paper.m to improve display margins.', ...
        'Low-level PPC keeps its original time base; observer/guidance handle the scheduled topology restart.', ...
        'Myplot_OE_paper plots actual USV trajectories and actual inter-USV distances.'};

    save(savePath, 'out', 'A_raw2', 'provenance', '-v7.3');
    fprintf('-> Saved result: %s\n', savePath);

    fprintf('-> Generating paper-aligned figures...\n');
    Myplot_OE_paper(modelName);
    fprintf('### Paper-aligned simulation completed ###\n');
end

function tau_limits = detect_tau_limits(modelName)
    tau_limits = struct('u', 1000, 'r', 500);
    try
        load_system(modelName);
        rt = sfroot;
        charts = rt.find('-isa', 'Stateflow.EMChart');
        paths = arrayfun(@(c)c.Path, charts, 'UniformOutput', false);
        idx = find(endsWith(paths, '/Controler1'), 1);
        if ~isempty(idx)
            script = charts(idx).Script;
            u_match = regexp(script, 'tau_bu_rho\s*=\s*([0-9.]+)', 'tokens', 'once');
            r_match = regexp(script, 'tau_bu_psi\s*=\s*([0-9.]+)', 'tokens', 'once');
            if ~isempty(u_match), tau_limits.u = str2double(u_match{1}); end
            if ~isempty(r_match), tau_limits.r = str2double(r_match{1}); end
        end
        close_system(modelName, 0);
    catch
        if bdIsLoaded(modelName), close_system(modelName, 0); end
    end
end
