%% 请先确保YALMIP工具箱和CPLEX正确安装,MATLAB导入对应文件，否则无法运行程序！！
%CPLEX免费试用版对求解规模有限制，如出现规模过大无法求解，请购买正式版或申请教育版！！！

%% 初始化
clc;
clear;
    
%-------------------------常量定义-----------------------%
%基础电负荷
Pfel=[500,520,493,490,502,598,650,973,1176,1371,1403,1457,1336,1240,1230,1270,1336,1650,1690,1406,1636,1567,996,632];
PFEL=[400,416,394,392,402,478,520,778,941,1097,1122,1166,1069,992,984,1016,909,1320,1352,1125,1309,1254,797,506];%固定电负荷
Pcool=[143,143,131,155,143,255,659,827,840,833,862,973,979,1042,970,917,878,832,617,644,430,506,155,131];%基础冷负荷
Pcccc=[129,129,118,139,129,230,593,744,756,750,775,876,881,938,873,825,790,749,555,580,387,455,140,118];%固定冷负荷
Qfhl=[1459,1580,1584,1486,1448,1352,1342,1320,1394,1329,1241,1223,1147,1021,1008,1060,1154,1124,1167,1370,1473,1496,1189,1135];%基础热负荷
Qfhl1=[1313,1422,1426,1337,1303,1217,1207,1188,1255,1196,1117,1100,1032,919,907,954,1039,1012,1050,1233,1326,1346,1070,1022];%固定热负荷
T_amb=[24.409,24.067,23.767,23.515,23.314,23.134,22.95,22.76,22.617,23.373,24.52,26.179,28.738,31.071,32.878,34.107,34.849,35.225,35.181,34.669,33.621,31.964,29.548,27.71];
%风电预测出力
Pwt=[203,277,264,331,137,81,72,141,43,12,20,12,5,48,86,346,287,530,491,448,603,601,403,380];
%光伏预测出力
Ppv=[0,0,0,0,0,0,97,220,336,410,486,444,453,445,442,325,202,140,29,0,0,0,0,0];
bb=[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]; %这个不用管
%与电网的交互成本交互成本 % 1-5，23-24 谷 % 6-12，19-22 峰 % 13-18 平 
price=[0.45,0.45,0.45,0.45,0.45,1.21,1.21,1.21,1.21,1.21,1.21,1.21,0.73,0.73,0.73,0.73,0.73,0.73,1.21,1.21,1.21,1.21,0.45,0.45];
psell=[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5];
%%   峰 平 谷 电价
buy=[0.45 0.73 1.21];%谷/峰 购电价
%% 各变量及常量定义
%------------------------变量定义-----------------------%
Psel=sdpvar(1,24,'full');%可平移电负荷
Qchl=sdpvar(1,24,'full');%可削减热负荷
cl=sdpvar(1,24,'full');%
P_MT=sdpvar(1,24,'full');%微燃机电功率出力
U_MT=binvar(1,24,'full');%微燃机开停机标记位
H_GB=sdpvar(1,24,'full');%燃气锅炉输出热功率
P_AC=sdpvar(1,24,'full');%电制冷机输入功率
H_AR=sdpvar(1,24,'full');%吸收式制冷机输入功率
Pbuy=sdpvar(1,24,'full');%从电网购电电量
Psell=sdpvar(1,24,'full');%向电网售电电量
Pnet=sdpvar(1,24,'full');%交换功率
Temp_net=binvar(1,24,'full'); % 购|售电标志
Pcharge=sdpvar(1,24,'full');UPcharge=binvar(1,24,'full');%  蓄电池充电  
Pdischarge=sdpvar(1,24,'full');UPdischarge=binvar(1,24,'full');%  蓄电池放电  
Peh=intvar(1,24,'full');%电转热
Hti=intvar(1,24,'full');UHti=binvar(1,24,'full');%蓄热槽充热
Hto=intvar(1,24,'full');UHto=binvar(1,24,'full');%蓄热槽放热
P_ashp=sdpvar(1,24,'full');%空气源热泵出力
mode_ashp = binvar(1,24,'full');%空气源热泵制热制冷模式
Q_ashp_cool = sdpvar(1,24,'full'); %空气源热泵冷出力
Q_ashp_heat = sdpvar(1,24,'full');%空气源热泵热出力
Psel1=zeros(1,24);%可平移电负荷
Qchl1=zeros(1,24);%可削减热负荷
cl1=zeros(1,24);

% Gini=sdpvar(1,1,'full');%天然气功率
% Fnet=sdpvar(1,24,'full');
 %%一天分为24小时，时间步长取1小时/60min
%%%% 1台MT机组,1台
COP_AR=1.2;%吸收式制冷机制冷系数
COP_AC=4;%电制冷机冷系数
e_Re=0.75;%余热回收效率
COP_cool = @(T_amb) 3.0 - 0.1*(T_amb - 25); 
COP_heat = @(T_amb) 3.5 - 0.15*(5 - T_amb);
%% chp热-电特性
a_MT=2.67;%成本系数
b_MT=66.2;%启动基本成本
c_MT=100;%启停成本
e_MT=0.35;%MT电效率
e_H=0.85;%MT热效率
for i=2:24%MT起停状态转换标记位
    I_MT(i)=abs(U_MT(i)-U_MT(i-1));
end
H_MT=P_MT*e_H*((1-e_MT)/e_MT);%燃气轮机热出力
F_MT=a_MT*P_MT+b_MT*U_MT+c_MT*I_MT;%燃气轮机燃料费用
 %%电转气设备
% e_p2g=1.3;
% sigama_g=0.02;
% g_p2g=Pp2g*e_p2g;
%热储能
H_storage_max=1500; h_n=0.98;h_charge=0.98;h_discharge=1;%热储能容量/自损/充热/放热；
% %%电转热
Peh_max=500;n_Peh=0.93;%转换设备/转换率
%% 燃气锅炉
e_GB=0.9;%燃气锅炉效率
F_GB=H_GB/e_GB;%燃气锅炉输入天然气量
%%
%电储能
% E_storage_max=2000; e_n=1;e_charge=1;e_discharge=1;%电储能容量/自损/充电/放电;
% 
% bggin=1000;%%电储能
% for i=1:24
%     B(1,i)=bggin+Pcharge(1,i)*e_charge-Pdischarge(1,i); % 0.98为转换率
%     bggin=B(1,i);
% end
% 
% %%约束条件
Constraints =[];
% 
%  %%电储能容量约束、充电约束、放电约束、状态约束、SOC约束
%  for i=1:24  %容量约束
%      Constraints=[Constraints,0<=Pcharge(1,i)<=350*UPcharge(1,i)];
%      Constraints=[Constraints,0<=Pdischarge(1,i)<=350*UPdischarge(1,i)];
%  end
% 
%  for i=1:24%充电约束、放电约束、
% if  i>0&&i<24
%      Constraints=[Constraints,-200<=Pcharge(1,i+1)-Pdischarge(1,i+1)-(Pcharge(1,i)-Pdischarge(1,i))<=200];
% elseif i==24
%          Constraints=[Constraints,-200<=Pcharge(1,1)-Pdischarge(1,1)-(Pcharge(1,i)-Pdischarge(1,i))<=200];
% end
% end
% 
%  for i=1:24 %状态约束
%      Constraints=[Constraints,UPcharge(1,i)+UPdischarge(1,i)<=1];    %不能同时充放电
%  end
% 
%  Constraints=[Constraints,sum(UPcharge(1,1:24)+UPdischarge(1,1:24))<=10];%考虑寿命
%  Constraints=[Constraints,B(1,24)==1000];
% 
%  for i=1:24 %SOC约束
%      Constraints=[Constraints,400<=B(1,i)<=1600];
%  end
       
 begin=1000;%%热储能
for i=1:24
    L(1,i)=begin*h_n+h_charge*Hti(1,i)-Hto(1,i);%%%热储能容量
    begin=L(1,i);
end
        
 %%热储能容量约束、充热约束、放热约束、状态约束
for i=1:24
Constraints=[Constraints,200<=L(1,i)<=H_storage_max];
end
Constraints=[Constraints,L(1,24)>=800];
for i=1:24
    Constraints=[Constraints,0<=Hti(1,i)<=200*UHti(1,i)];
    Constraints=[Constraints,0<=Hto(1,i)<=150*UHto(1,i)];
end
for i=1:23
    Constraints=[Constraints,-300<=Hti(1,i+1)-Hto(1,i+1)-(Hti(1,i)-Hto(1,i))<=200];
end
for i=1:24
    Constraints=[Constraints,UHti(1,i)+UHto(1,i)<=1];
end
%  Constraints = [Constraints,g_p2g+Fnet==F_MT+F_GB];
%   Constraints=[Constraints,Fnet>=0];
for i=1:24   
    Constraints = [Constraints,0<=P_MT(i)<=700*U_MT(i)];%燃气轮机上下限约束
    Constraints = [Constraints,0<=H_GB(i)<=900];%锅炉上下限约束
        Constraints=[Constraints,0<=H_AR(i)<=500];%吸收式制冷机出力下限约束
    Constraints=[Constraints,0<=P_AC(i)<=140];%电制冷机出力下限约束

      Constraints = [Constraints, -500<=Pnet(i)<=500,0<=Pbuy(i)<=500, -500<=Psell(i)<=0]; %主网功率交换约束
   Constraints = [Constraints, implies(Temp_net(i),[Pnet(i)>=0,Pbuy(i)==Pnet(i),Psell(i)==0])]; %购电情况约束
  Constraints = [Constraints, implies(1-Temp_net(i),[Pnet(i)<=0,Psell(i)==Pnet(i),Pbuy(i)==0])]; %售电情况约束 
    Constraints = [Constraints,0<=Psel(i)<=220];%可平移电负荷上限    
     Constraints = [Constraints,0<=Qchl(i)<=160];%可平移电负荷上限  
        Constraints = [Constraints,0<=cl(i)<=150];%可平移电负荷上限  
end

  Constraints = [Constraints,sum(Psel(1:i))==0.2*sum(Pfel(1:i))];%可平移负荷总量不变约束
      Constraints = [Constraints,sum(Qchl(1:i))==0.1*sum(Qfhl(1:i))];%可削减热负荷总量约束   
        Constraints = [Constraints,sum(cl(1:i))==0.1*sum(Pcool(1:i))];%可削减热负荷总量约束  

%%%电热转换上下限
for i=1:24
    Constraints=[Constraints,0<=Peh(1,i)<=Peh_max];
end
      for i=1:23
    Constraints=[Constraints,-100<=Peh(1,i+1)-Peh(1,i)<=200];
      end
%%
% 空气源热泵上下限 
      for i = 1:24
    % 模式互斥与冷热输出
    Constraints = [Constraints, 
        Q_ashp_cool(i) <= COP_cool(T_amb(i)) * P_ashp(i) * (1 - mode_ashp(i)),
        Q_ashp_heat(i) <= COP_heat(T_amb(i)) * P_ashp(i) * mode_ashp(i),
        Q_ashp_cool(i) >= 0,
        Q_ashp_heat(i) >= 0
    ];
    
    % 电功率上下限（与现有约束合并）
    Constraints = [Constraints, 
        0 <= P_ashp(i) <= 300,
        implies(mode_ashp(i) == 0, P_ashp(i) >= 0),
        implies(mode_ashp(i) == 1, P_ashp(i) >= 0)
    ];
end

         for i=1:24       
Constraints = [Constraints,PFEL(i)+Psel(i)+2>=Pwt(i)+Ppv(i)+Pnet(i)+P_MT(i)-P_AC(i)-Peh(i)- P_ashp(i)>=PFEL(i)+Psel(i)]; %电平衡
Constraints = [Constraints,Qfhl1(i)+Qchl(i)+2>=H_MT(i)*e_Re+H_GB(i)-H_AR(i)+Peh(1,i)*n_Peh+(-Hti(1,i)+h_discharge*Hto(1,i))+Q_ashp_heat(i)>=Qfhl1(i)+Qchl(i)];%热平衡约束
    Constraints=[Constraints,Pcccc(1,i)+cl(i)+2>=COP_AR*H_AR(i)+COP_AC*P_AC(i)+ Q_ashp_cool(i)>=Pcccc(1,i)+cl(i)];%冷平衡约束
  Constraints = [Constraints, -300<=sum(Pdischarge(1:i)+Pcharge(1:i))<=1000] ;%SOC约束，电池容量1000kwh，初始S0C为0.4，0.3<=SOC<=0.9
         end
%分时气价        
 for i=1:24                   
    if i>=7&&i<=12
        Cgas(i)=1.57;
    elseif  i>=19&&i<=22
        Cgas(i)=1.57;
    elseif i>=13&&i<=18
        Cgas(i)=2.05;
    else
        Cgas(i)=2.05;
    end
end        
         
 %% 燃料成本
% R_Ng=3.24;%天然气价格
C_Ng=0;
for i=1:24
H_Ng=9.78;%天然气热值
C_Ng=C_Ng+Cgas(i)*(F_MT(i)+F_GB(i))/H_Ng;%IES购天然气成本 
end
C_co2=0;
C_grid=0;
C_Rm=0;
 %% IES运行成本
K_MT=0.1685;%燃气轮机运行维护费用
K_GB=0.0018;%燃气锅炉运行维护费用
K_HE=0.0065;%余热锅炉运行维护费用
K_AR=0.0156;%吸附式制冷机运行维护费用
K_AC=0.0104;%电制冷机运行维护费用
K_PV=0.01329;%光伏电池运行维护费用
K_PW=0.0126;%风机运行维护费用
e_HE=0.9;%余热锅炉效率
K_EB=0.0125;%电锅炉运行维护费用
K_ASHP = 0.008;

for i=1:24
C_Rm=C_Rm+P_MT(i)*K_MT+H_GB(i)*K_GB+K_HE*Qfhl(i)/e_HE+H_AR(i)*K_AR+P_AC(i)*K_AC+Ppv(i)*K_PV+Pwt(i)*K_PW+K_EB*Peh(i)+ K_ASHP * P_ashp(i);%IES维护成本        
C_co2=C_co2+0.320*(0.065-0.102)*(H_GB(i)+6*P_MT(i)+H_MT(i)+H_AR(i)+P_AC(i)+Peh(i));%CCHP机组碳交易成本     
C_grid=C_grid+0.268*(1.08-0.728)*Pbuy(i);%与电网交互的碳交易成本
end

         %% 目标函数
%------------------运行成本+碳交易成本最小--------------------%
for k=1:24 %与电网的交互成本交互成本 % 1-5，23-24 谷 % 6-12，19-22 峰 % 13-18 平 
    if k>=1&&k<7
        Cgrid(1,k)=Pbuy(1,k).*buy(3);
    elseif k>=7&&k<13
        Cgrid(1,k)=Pbuy(1,k).*buy(1);
    elseif k>=13&&k<19
        Cgrid(1,k)=Pbuy(1,k).*buy(2);
    elseif k>=19&&k<23
        Cgrid(1,k)=Pbuy(1,k).*buy(1);
    else
        Cgrid(1,k)=Pbuy(1,k).*buy(3);
    end
end
%卖电收益
C_sell=0;
for i=1:24
    C_sell=C_sell+Psell(i)*psell(i);
end
%买电成本
C_buy=0;
for i=1:24
C_buy=C_buy+Cgrid(i);
end

%目标函数

   F=C_Rm+C_Ng+C_sell+C_buy+C_grid+C_co2;

ops = sdpsettings('solver','cplex', 'verbose', 2);%通过将verbose设置为0，解决者将以最小的显示运行。通过增加值，显示级别被控制（通常1提供了适度的显示级别，而2提供了大量的信息）。
optimize(Constraints,F,ops)
value(F)%费用
Psel1=value(Psel);
Qchl1=value(Qchl);
cl1=value(cl);
C_co2=value(C_co2);
C_grid=value(C_grid);
% for k=1:24   %算出蓄电池SOC曲线的作用
% s(k)=value(sum(Pcharge(1:k)-Pdischarge(1:k)))/1000+0.4;
% soc(k+1)=s(k);
% end
soc(1)=0.4;

% for i=1:24
%      F_2=F_2+1.08*Pbuy(i);%购电碳排放量
%       F_1=F_1+0.065*(H_GB+6*P_MT+H_MT+H_AR+P_AC);%CCHP碳排放量
% end

%% 画图
x=1:24
figure
stairs(x,price,'-r')
hold on
stairs(x,Cgas,'--b')
hold on
stairs(x,psell,'-g')
legend('分时电价','分时气价','上网电价');



x=1:24;
figure
stairs(x,Ppv,'-r')
hold on
stairs(x,Pwt,'--b')
legend('光伏预测曲线','风机预测曲线');


figure
plot(x,PFEL+Psel1,'-*',x,Pfel,'-+');
xlabel('时间/h');
ylabel('电负荷/kW');
set(get(gca,'XLabel'),'Fontsize',14) 
set(get(gca,'YLabel'),'Fontsize',14)
title('需求响应前后电负荷曲线');
legend('优化后电负荷','优化前电负荷');
set(gca,'XLim',[1 24]);%X轴的数据显示范围
set(gca,'YLim',[0 2000]);
box off

figure
plot(x,Qfhl1+Qchl1,'-*',x,Qfhl,'-+');
xlabel('时间/h');
ylabel('热负荷/kW');
set(get(gca,'XLabel'),'Fontsize',14) 
set(get(gca,'YLabel'),'Fontsize',14)
title('需求响应前后热负荷曲线');
legend('优化后热负荷','优化前热负荷');
set(gca,'XLim',[1 24]);%X轴的数据显示范围
set(gca,'YLim',[0 1700]);
box off

figure
plot(x,Pcccc+cl1,'-*',x,Pcool,'-+');
xlabel('时间/h');
ylabel('冷负荷/kW');
set(get(gca,'XLabel'),'Fontsize',14) 
set(get(gca,'YLabel'),'Fontsize',14)
title('需求响应前后冷负荷曲线');
legend('优化后冷负荷','优化前冷负荷');
set(gca,'XLim',[1 24]);%X轴的数据显示范围
set(gca,'YLim',[0 1200]);
box off


figure
plot(x,Pfel,'-*',x,Qfhl,'-+',x,Pcool,'--');
xlabel('时间/h');
ylabel('用户负荷曲线/kW');
set(get(gca,'XLabel'),'Fontsize',14) 
set(get(gca,'YLabel'),'Fontsize',14)
title('典型用户的负荷预测曲线');
legend('电负荷曲线','热负荷曲线','冷负荷曲线');
set(gca,'XLim',[1 24]);%X轴的数据显示范围
set(gca,'YLim',[0 2000]);
box off

%电平衡
x=1:24;
PP=[Pbuy;P_MT;Pwt;Ppv;bb;bb];
PP1=[Psell;bb;bb;bb;-P_AC;-Peh;-P_ashp];
figure
bar(PP','stack');
h=legend('交换功率','燃气轮机出力','风电出力出力','光伏出力','电制冷机耗电','电锅炉耗电','电转气设备出力','空气源热泵耗电','Location','NorthWest');
set(h,'Orientation','horizon')
hold on
bar(PP1','stack');
plot(x,value(PFEL+Psel),'r','linewidth',2);
xlabel('时段');ylabel('功率/kW');
hold off

%热平衡
x=1:24;
QQ=[H_GB;H_MT*e_Re;Q_ashp_heat;bb;Hto;Peh*n_Peh];
QQ1=[bb;bb;-H_AR;-Hti;bb];
figure
bar(QQ','stack');
h=legend('燃气锅炉出力','余热锅炉出力','空气源热泵制热','吸收式制冷机出力','蓄热槽出力','电锅炉出力','Location','NorthWest');
set(h,'Orientation','horizon')
hold on
bar(QQ1','stack');
plot(x,value(Qfhl1+Qchl),'r','linewidth',2);
xlabel('时段');ylabel('功率/kW');
hold off

%冷平衡
x=1:24;
LL=[COP_AR*H_AR;COP_AC*P_AC; Q_ashp_cool];
figure
bar(LL','stack');
h=legend('吸收式制冷机','电制冷机','空气源热泵制冷','Location','NorthWest');
set(h,'Orientation','horizon')
hold on
plot(x,value(Pcccc+cl),'r','linewidth',2);
xlabel('时段');ylabel('功率/kW');
hold off
% %蓄电池荷电状态
% xx=0:24;
% figure
% plot(xx,soc,'r');
% xlabel('时段');ylabel('SOC值');
% title('蓄电池SOC状态');
%计算碳排放量
 P_co2=0;
 P_grid=0;
for i=1:24
    P_co2=P_co2+0.065*(H_GB(i)+6*P_MT(i)+H_MT(i)+H_AR(i)+P_AC(i)+Peh(i)+P_ashp);
P_grid=P_grid+1.08*Pbuy(i);%与电网交互的碳交易成本

end
