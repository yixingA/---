% 清空环境
clear; close all; clc;

%% 1. 定义空气源热泵参数
P_max = 10; % 最大电功率 (kW)
COP_cool = @(T_amb) 3.0 - 0.1*(T_amb - 25); % 制冷COP与环境温度的关系
COP_heat = @(T_amb) 3.5 - 0.15*(5 - T_amb); % 制热COP与环境温度的关系

%% 2. 输入数据
T_amb = [30, 28, 25, 22, 20, 18, 15, 12, 10, 8, 5, 3, 30, 28, 25, 22, 20, 18, 15, 12, 10, 8, 5, 3]; % 24小时环境温度（示例数据）
Q_cool_demand = [50, 48, 45, 40, 35, 30, 25, 20,50, 48, 45, 40, 35, 30, 25, 20,50, 48, 45, 40, 35, 30, 25, 20];       % 制冷需求 (kW)
Q_heat_demand = [0, 0, 0, 5, 10, 15, 20, 25,50, 48, 45, 40, 35, 30, 25, 20,50, 48, 45, 40, 35, 30, 25, 20 ];           % 制热需求 (kW)
n = 24; % 时间步长（24小时）

%% 3. 定义优化变量（YALMIP）
% 连续变量：制冷功率、制热功率
P_cool = sdpvar(n, 1); % 制冷模式电功率 (kW)
P_heat = sdpvar(n, 1); % 制热模式电功率 (kW)

% 二进制变量：运行模式（0=制冷，1=制热）
mode_flag = binvar(n, 1); 

%% 4. 定义目标函数（总电耗最小）
objective = sum(P_cool + P_heat); 

%% 5. 定义约束条件
constraints = [];
M = P_max; % Big-M法中的大常数

for t = 1:n
    % 制冷/热性能计算
    Q_cool_t = COP_cool(T_amb(t)) * P_cool(t); % 制冷量 = COP * 电功率
    Q_heat_t = COP_heat(T_amb(t)) * P_heat(t); % 制热量 = COP * 电功率
    
    % 冷热负荷需求约束
    constraints = [constraints;
        Q_cool_t >= Q_cool_demand(t); % 制冷量 >= 需求
        Q_heat_t >= Q_heat_demand(t); % 制热量 >= 需求
    ];
    
    % 模式互斥约束（同一时间只能选择一种模式）
    constraints = [constraints;
        P_cool(t) <= M*(1 - mode_flag(t)); % 若mode_flag=1，P_cool=0
        P_heat(t) <= M*mode_flag(t);        % 若mode_flag=0，P_heat=0
    ];
    
    % 功率上下限约束
    constraints = [constraints;
        0 <= P_cool(t) <= 100;
        0 <= P_heat(t) <= 100;
    ];
end

%% 6. 求解优化问题
% 配置CPLEX求解器
options = sdpsettings('solver', 'cplex', 'verbose', 1);

% 求解
sol = optimize(constraints, objective, options);

% 检查求解状态
if sol.problem == 0
    disp('优化成功！');
else
    error('求解失败：%s', sol.info);
end

%% 7. 提取结果
P_cool_opt = value(P_cool); % 最优制冷功率
P_heat_opt = value(P_heat); % 最优制热功率
mode_opt = value(mode_flag); % 最优运行模式

%% 8. 可视化结果
figure;
subplot(3,1,1);
plot(1:n, P_cool_opt, 'b', 'LineWidth', 1.5);
ylabel('制冷功率 (kW)');
grid on;

subplot(3,1,2);
plot(1:n, P_heat_opt, 'r', 'LineWidth', 1.5);
ylabel('制热功率 (kW)');
grid on;

subplot(3,1,3);
stem(1:n, mode_opt, 'g', 'LineWidth', 1.5);
ylabel('运行模式 (0=冷,1=热)');
xlabel('时间 (小时)');
ylim([-0.1 1.1]);
grid on;
