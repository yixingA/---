function x = create_x(var)

    n = size(var, 2);
    x = zeros(1, n);
    for i = 1 : n
        x(i) = var(1, i) + rand() * (var(2, i)-var(1, i));
    end
    
end