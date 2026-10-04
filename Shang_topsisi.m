%% 第二步：使用 熵权-Topsis方法决策

%%  1-构建原始评价矩阵
X=[-costs(1,:);-costs(2,:);costs(3,:)]';
[n,m] = size(X);
disp(['共有' num2str(n) '个评价对象, ' num2str(m) '个评价指标']) ;

%% 2-构建标准化决策矩阵
Judge1 = input('是否有逆向指标，有请输入1 ，无请输入0：');
if Judge1 == 1
    Position1 = input('逆向指标所在的列，例如[2,3,6]： ');   % 磨损量 
    Type1 = ones(size(Position1));
    for i = 1 : size(Position1,2) 
        X(:,Position1(i)) = Positivization(X(:,Position1(i)),Type1(i));
    end
end

Judge2 = input('是否有正向指标，有请输入1 ，无请输入0：');
if Judge2 == 1   
    Position2 = input('正向指标所在的列，例如[2,3,6]： '); % 抗折及抗压强度
    Type2 = 2*ones(size(Position2));
    for i = 1 : size(Position2,2) 
        X(:,Position2(i)) = Positivization(X(:,Position2(i)),Type2(i));
    end
end
%归一化
Z = X ./ max(X)-min(X);
disp('归一化矩阵 Z = ')
disp(Z)
%% 3-确定评价指标熵权
for i = 1:n
    for j = 1:m
        p(i,j) = (1+Z(i,j))/sum(1+Z(:,j));
    end
end

for j = 1:m
    s = 0;
    for i = 1:n
        if p(i,j)~= 0
            s = s + p(i,j)*log(p(i,j)); % 防止分母为0
        end
    end
    e(j) = -1/log(n)*s;  %信息熵
end

weigh = (1-e)/sum(1-e); % 熵权

%% 456-计算与最大值的距离和最小值的距离
D_P = sum(((Z - repmat(max(Z),n,1)) .^ 2 ) .* repmat(weigh,n,1) ,2) .^ 0.5;   % D+ 与最大值的距离向量
D_N = sum(((Z - repmat(min(Z),n,1)) .^ 2 ) .* repmat(weigh,n,1) ,2) .^ 0.5;   % D- 与最小值的距离向量

%% 7-相对贴近度
Oi = D_N ./ (D_P+D_N); 
[maxValue, maxIndex] = max(Oi);

%% 画图
figure(3)
plot(Oi, 'b-o', 'MarkerFaceColor', 'm', 'MarkerSize', 5);
grid on;
xlabel('program');ylabel('Oi');
title('各方案相对贴近度'); 

disp(['——————>信息熵为[' num2str(e) ']<——————']) ;
disp(['——————>熵权为[' num2str(weigh) ']<——————']) ;
disp(['Pareto中方案' num2str(maxIndex) '最优']) ;