%% 第三步：绘制决策方案最优解

Opti_case=[-7.166476452214681;-34.436206494760200;1.724416954032261];% 最优方案解

% 绘图
figure(4)
scatter3(-costs(1, :), -costs(2, :),costs(3, :), 'r', 'filled' );
hold on
plot3(-Opti_case(1), -Opti_case(2), Opti_case(3),'kp', 'MarkerSize', 10, 'MarkerFaceColor', 'k');
xlabel('Y1');
ylabel('Y2');
zlabel('Y3');
legend('pareto解','决策方案');
grid on;