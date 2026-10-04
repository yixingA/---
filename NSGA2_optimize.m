clc
clear
close all
%% 定义自变量范围
nvar = 3;     %约束变量个数
nobj = 3;     %目标函数个数
npop = 100;    %初始种群
maxit = 400;  %迭代次数
pc = 0.9;     %交叉概率
nc = round(pc * npop / 2) * 2;
mu = 0.1;     %变异概率

 %计算年化投资系数
    n_devices = length(C_device);
    annual_factor = zeros(n_devices, 1);
    for i = 1:n_devices
        annual_factor(i) = r / (1 - (1 + r)^(-life(i)));
    end
    
    % 年总成本计算
    S_CCHP = sum(C_device .* P_device .* annual_factor) + sum(daily_cost_CCHP) * N_days;
    S_SH = sum(C_device .* P_device .* annual_factor) + sum(daily_cost_SH) * N_days;
    
    % 年总成本节约率
    cost_saving = (S_CCHP - S_SH) / S_CCHP; % 最大化节约率
    E_CCHP = sum(gas_CCHP) * eta_ng + sum(elec_CCHP) * eta_elec / eff_grid;
    
    % SH-CCHP一次能源消耗
    E_SH = sum(gas_SH) * eta_ng + sum(elec_SH) * eta_elec / eff_grid;
    
    % 一次能源节约率
    energy_saving = (E_CCHP - E_SH) / E_CCHP; % 最大化节约率
        CO2_CCHP = sum(gas_CCHP) * co2_ng + sum(elec_CCHP) * co2_elec;
    
    % SH-CCHP碳排放
    CO2_SH = sum(gas_SH) * co2_ng + sum(elec_SH) * co2_elec;
    
    % 年总碳减排率
    emission_reduction = (CO2_CCHP - CO2_SH) / CO2_CCHP; % 最大化减排率

varmin = [0.5,0.5,34];
varmax = [1.5,1.5,38];
var = [varmin;varmax];

empty.position = [];
empty.cost = [];
empty.rank = [];
empty.domination = [];
empty.dominated = 0;
empty.crowdingdistance = [];
pop = repmat(empty, npop, 1);
%% 初始化种群
for i = 1 : npop
    pop(i).position = create_x(var);
    pop(i).cost = costfunction(pop(i).position);
end

%% 非支配排序
[pop,F] = nondominatedsort(pop);

%% 拥挤度计算
pop = calcrowdingdistance(pop,F);
%% 主程序
for it = 1 : maxit
    
    popc = repmat(empty, nc/2,2);
    % 选择，交叉算子
    for j = 1 : nc / 2
       p1 = tournamentsel(pop);
       p2 = tournamentsel(pop);
       [popc(j, 1).position, popc(j, 2).position] = crossover(p1.position, p2.position);
    end
    
    popc = popc(:);
    % 变异算子
    for k = 1 : nc
        popc(k).position = mutate(popc(k).position, mu, var);
        popc(k).cost = costfunction(popc(k).position);
    end
   
    newpop = [pop; popc];
    
    [pop,F] = nondominatedsort(newpop);

    pop = calcrowdingdistance(pop,F);
    
    % 排序
    pop = Sortpop(pop);
    
    % 淘汰
    pop = pop(1: npop);

    [pop,F] = nondominatedsort(pop);

    pop = calcrowdingdistance(pop,F);
    
    pop = Sortpop(pop);
    
    % 更新第1等级
    F1 = pop(F{1});

    % 保存倒数第30次的迭代结果
    if it==maxit-30
        endsecond=pop;
    end

    % 显示迭代信息
    disp(['Iteration ' num2str(it) ': Number of F1 Members = ' num2str(numel(F1))]);
    
    % 绘pareto图
    figure(1);
    plotcosts(F1);
    pause(0.01);
end 
costs=[F1.cost];    
%% 随机实验证明 pareto优解
    rp=500;%随机实验次数
    for i = 1 : rp
    pop(i).position = create_x(var);
    pop(i).cost = costfunction(pop(i).position);
    end
    rand_exper=[pop.cost];
    figure(11)
    plot3(-rand_exper(1, :), -rand_exper(2, :),rand_exper(3, :), 'k*', 'MarkerSize', 6);
    hold on
    scatter3(-costs(1, :), -costs(2, :),costs(3, :), 'r', 'filled' );
     hold off
    xlabel('Y1');
    ylabel('Y2');
    zlabel('Y3');
    title('非支配优解');
    legend(['随机实验次数',num2str(rp)],['pareto解']);
    grid on;
    