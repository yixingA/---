function fitness = fitnessfun(x, p_train, t_train)

%%  获取优化参数
gam = x(1);
sig = x(2);

%%  参数设置
type       = 'f';                % 模型类型f回归，c分类
kernel     = 'RBF_kernel';       % RBF 核函数  
%             poly_kernel        % 多项式核函数 
%             MLP_kernel         % 多层感知机核函数
%             lin_kernel         % 线性核函数
proprecess = 'preprocess';       % 是否归一化

%%  数据的参数
num_size = length(t_train);

%%  交叉验证程序
indices = crossvalind('Kfold', num_size, 5);

for i = 1 : 5
    
    % 获取第i份数据的索引逻辑值
    valid_data = (indices == i);
    
    % 取反，获取第i份训练数据的索引逻辑值
    train_data = ~valid_data;
    
    % 1份测试，4份训练
    pv_train = p_train(train_data, :);
    tv_train = t_train(train_data, :);
    
    pv_valid = p_train(valid_data, :);
    tv_valid = t_train(valid_data, :);
    
    % 建立模型
    model = initlssvm(pv_train, tv_train, type, gam, sig, kernel, proprecess);

    % 模型训练
    model = trainlssvm(model);

    % 仿真预测
    t_sim = simlssvm(model, pv_valid);

    % 适应度值
    error(i) = mean(sqrt(sum((t_sim - tv_valid) .^ 2, 2) ./ size(pv_valid, 1)));

end

%%  获取适应度
fitness = mean(error);

end