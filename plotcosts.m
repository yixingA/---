function plotcosts(pop)

    costs = [pop.cost];
    
    scatter3(-costs(1, :), -costs(2, :),costs(3, :), 'r', 'filled' );
    xlabel('Y1');
    ylabel('Y2');
    zlabel('Y3');
    title('Pareto解集');
    grid on;

end
