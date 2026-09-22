function [finalPrice, confidenceInterval, standardError] = priceExoticOption(simLibors, all_deltaTs)
%PRICEEXOTICOPTION Calculates the Price of the exotic cap across all paths.
%
%   INPUTS:
%       simLibors : A matrix of simulated forward Libor rates.
%                   Dimensions: [N_paths x numRates].
%                   Each row represents a single Monte Carlo path, and each column
%                   represents a specific fixing date.
%
%       all_deltaTs : A vector containing the accrual factors for
%                     each corresponding Libor period.
%                     Dimensions: [numRates x 1] or [1 x numRates].
%
%   OUTPUTS:
%       finalPrice         : The Monte Carlo estimate of the exotic cap's present value.
%
%       confidenceInterval : A 1x2 vector containing the [lower_bound, upper_bound] of the
%                            95% confidence interval for the estimated price.
%
%       standardError      : The standard error of the Monte Carlo simulation.

% N_paths should be 10000, numRates should be 16
[N_paths, numRates] = size(simLibors);

% Array to hold the total Present Value for each path
total_PV_paths = zeros(N_paths, 1);

% The stochastic discount factor starts exactly at 1.0 (today)
stoch_DF = ones(N_paths, 1);

% Loop through all 16 quarters
for i = 1:numRates

    % Update the Stochastic Discount Factor
    % B_i = 1 / (1 + delta_i * L_i)
    B_i = 1 ./ (1 + all_deltaTs(i) * simLibors(:, i));
    stoch_DF = stoch_DF .* B_i;

    % Calculate the Exotic Payoff
    % We only calculate payouts for the 6-month mark and beyond (i >= 2)
    if i >= 2
        L_i = simLibors(:, i);
        L_prev = simLibors(:, i-1);

        % The payoff: delta * max(0, L_i - L_{i-1} - 5bps)
        payoff = all_deltaTs(i) * max(0, L_i - L_prev - 0.0005);

        % Discount the payoff to today and add to the running total
        total_PV_paths = total_PV_paths + (payoff .* stoch_DF);
    end
end

% The Monte Carlo price is the average of all 10,000 discounted paths
finalPrice = mean(total_PV_paths);

% Calculate the Standard Error
std_dev = std(total_PV_paths);
standardError = std_dev / sqrt(N_paths);

% Calculate the 95% Confidence Interval (z = 1.96)
z_score = 1.96;
confidenceInterval = [finalPrice - z_score * standardError, finalPrice + z_score * standardError];

end