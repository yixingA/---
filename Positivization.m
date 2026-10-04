function [posit_x] = Positivization(x,type)

    if type == 1      %极小
        posit_x = max(x)-x;  
    elseif type == 2  %极大       
        posit_x = x-min(x);       
    else
        disp('没有这种类型的指标，请检查Type向量中是否有除了1、2之外的其他值')
    end
end