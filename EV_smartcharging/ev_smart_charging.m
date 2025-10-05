%% Smart EV Charging - Step 1: Initialization

clear; clc; close all;

% Simulation parameters
dt = 60;              % time step [s] (1 min)
T_sim = 4*3600;       % total time [s] (4 hours)
time = 0:dt:T_sim;    % time vector

% Grid constraint
Grid_limit = 20;      % kW (maximum total charging power available)

% Define EVs
nEV = 3;              % number of EVs
Battery_capacity = [40, 60, 80];   % kWh
SOC_init = [20, 40, 60];           % initial SOC (%)
SOC_target = [90, 90, 90];         % target SOC (%)

% Each EV max charging power (kW)
Pmax_EV = [7, 11, 22];  

% Initialize SOC array
SOC = zeros(nEV, length(time));
SOC(:,1) = SOC_init;

% Energy stored [kWh]
Energy_stored = (SOC_init./100).*Battery_capacity;


%% Step 2: Uncontrolled Charging (All EVs charge simultaneously)

SOC_uncontrolled = SOC;
Energy_stored_uncontrolled = Energy_stored;
Power_EV_uncontrolled = zeros(nEV, length(time));

for t = 2:length(time)
    for i = 1:nEV
        if SOC_uncontrolled(i,t-1) < SOC_target(i)
            % Charging at max power
            Power_EV_uncontrolled(i,t) = Pmax_EV(i);
            dE = Pmax_EV(i)*dt/3600; % kWh added in this step
            Energy_stored_uncontrolled(i) = Energy_stored_uncontrolled(i) + dE;
            SOC_uncontrolled(i,t) = (Energy_stored_uncontrolled(i)/Battery_capacity(i))*100;
        else
            Power_EV_uncontrolled(i,t) = 0;
            SOC_uncontrolled(i,t) = SOC_uncontrolled(i,t-1);
        end
    end
end

% Total grid power
Total_power_uncontrolled = sum(Power_EV_uncontrolled,1);


%% Step 3: Smart Charging Algorithm

SOC_smart = SOC;
Energy_stored_smart = Energy_stored;
Power_EV_smart = zeros(nEV, length(time));

for t = 2:length(time)
    % Find EVs that still need charging
    activeEVs = find(SOC_smart(:,t-1) < SOC_target');
    
    if isempty(activeEVs)
        SOC_smart(:,t) = SOC_smart(:,t-1);
        continue;
    end

    % Priority based on lower SOC
    [~, order] = sort(SOC_smart(activeEVs,t-1), 'ascend');
    activeEVs = activeEVs(order);
    
    Remaining_power = Grid_limit;
    
    for i = activeEVs'
        if Remaining_power <= 0
            Power_EV_smart(i,t) = 0;
            SOC_smart(i,t) = SOC_smart(i,t-1);
            continue;
        end
        
        % Allocate power (limited by Pmax and remaining grid)
        P_alloc = min(Pmax_EV(i), Remaining_power);
        Power_EV_smart(i,t) = P_alloc;
        Remaining_power = Remaining_power - P_alloc;

        % Update SOC
        dE = P_alloc*dt/3600; % kWh added in this step
        Energy_stored_smart(i) = Energy_stored_smart(i) + dE;
        SOC_smart(i,t) = (Energy_stored_smart(i)/Battery_capacity(i))*100;
    end
end

% Total grid power
Total_power_smart = sum(Power_EV_smart,1);

%% Step 4: Visualization - Comparing Uncontrolled vs Smart Charging

figure('Name','EV Smart Charging Dashboard','NumberTitle','off','Position',[100 100 1200 800]);

% 1. Grid power profile
subplot(3,1,1);
plot(time/3600, Total_power_uncontrolled,'r--','LineWidth',1.8); hold on;
plot(time/3600, Total_power_smart,'b','LineWidth',2);
grid on;
xlabel('Time (hours)');
ylabel('Grid Power (kW)');
title('Grid Power Demand Comparison');
legend('Uncontrolled','Smart Charging');

% 2. SOC of EVs
subplot(3,1,2);
plot(time/3600, SOC_uncontrolled(1,:), 'r--');
hold on;
plot(time/3600, SOC_smart(1,:), 'b');
plot(time/3600, SOC_uncontrolled(2,:), 'm--');
plot(time/3600, SOC_smart(2,:), 'c');
plot(time/3600, SOC_uncontrolled(3,:), 'g--');
plot(time/3600, SOC_smart(3,:), 'k');
grid on;
xlabel('Time (hours)');
ylabel('SOC (%)');
title('SOC of EVs (Uncontrolled vs Smart)');
legend('EV1-Unctrl','EV1-Smart','EV2-Unctrl','EV2-Smart','EV3-Unctrl','EV3-Smart');

% 3. Power allocation per EV (Smart case)
subplot(3,1,3);
plot(time/3600, Power_EV_smart(1,:), 'b','LineWidth',1.5); hold on;
plot(time/3600, Power_EV_smart(2,:), 'r','LineWidth',1.5);
plot(time/3600, Power_EV_smart(3,:), 'g','LineWidth',1.5);
grid on;
xlabel('Time (hours)');
ylabel('Power (kW)');
title('Power Allocation per EV (Smart Charging)');
legend('EV1','EV2','EV3');

% Save figure
if ~exist('Plots_and_Results','dir')
    mkdir('Plots_and_Results');
end
saveas(gcf,'Plots_and_Results/EV_SmartCharging_Dashboard.png');
