function savere(modelName)
    % 1. 强制转换类型
    modelName = char(modelName); 
    
    fprintf('### 任务启动: %s ###\n', modelName);
    
    % 2. 执行初始化 (确保变量进入基础工作区)
    if exist('ini.m', 'file')
        fprintf('-> 正在执行初始化 ini.m...\n');
        evalin('base', 'run(''ini.m'')'); 
    else
        warning('未找到 ini.m，请确认文件是否存在。');
    end
    
    % 3. 自动运行仿真 (新版现代语法)
    fprintf('-> 正在后台运行 Simulink 仿真: %s.slx...\n', modelName);
    try
        % 加载模型到内存（不打开窗口）
        load_system(modelName);
        
        % 设置仿真选项：直接通过 set_param 修改模型配置，实现静默运行
        % 'FastRestart' 可以加速多次运行，'ReturnWorkspaceOutputs' 确保返回 out 对象
        set_param(modelName, 'SimulationMode', 'normal');
        
        % 核心：调用 sim 命令
        % 在新版中，直接用 out = sim(modelName) 即可，
        % 它会自动读取基础工作区的变量。
        out = sim(modelName, 'ReturnWorkspaceOutputs', 'on'); 
        
        % 仿真完后关闭模型 (0 表示不保存对模型文件的临时修改)
        close_system(modelName, 0); 
        
    catch ME
        fprintf('仿真出错，错误信息如下:\n%s\n', ME.message);
        % 即使出错也尝试关闭模型，防止内存占用
        if bdIsLoaded(modelName), close_system(modelName, 0); end
        return; 
    end
    
    % 4. 自动保存结果
    resDir = 'sim_results';
    if ~exist(resDir, 'dir'), mkdir(resDir); end
    savePath = fullfile(resDir, [modelName, '_res.mat']);
    
    % 获取 A_raw2 (ini.m 生成的变量)
    try
        A_raw2 = evalin('base', 'A_raw2');
    catch
        A_raw2 = [];
        warning('未在工作区找到 A_raw2 变量，请检查 ini.m 是否定义了该变量。');
    end
    
    save(savePath, 'out', 'A_raw2');
    fprintf('-> 仿真完成，数据已保存: %s\n', savePath);
    
    % 5. 自动调用绘图函数
    fprintf('-> 正在生成 OE 标准图表...\n');
    Myplot_OE(modelName);
    
    fprintf('### 所有任务已自动完成 ###\n');
end