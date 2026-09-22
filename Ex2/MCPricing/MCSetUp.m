function [v_ATM, L_chol, B_init, all_T1s, all_deltaTs, all_df1s, all_df2s, Rho] = MCSetUp(market, fullCapletVolsBMM)
%MCSETUP Prepares the arrays, vectors, and matrices required to run the
% Bond Market Model Monte Carlo simulation.

% Start Date is the RefDate of the bootstrap
startDate = market.dates(1);

% Extract and format market data (convert % to decimals)
capMaturities = market.maturities(:);
strikes       = market.strikes(:) / 100;
dates         = market.dates;
discounts     = market.discounts;

% Build the Global 20-Year Schedule
endDate = startDate + calyears(max(capMaturities));

% Generate Payment Dates (T2) using Modified Following
[payment_dates_T2, ~] = computePaymentDates(startDate, endDate, 4, 'modifiedfollowing');

% Generate Fixing Dates (T1)
fixing_dates_T1 = [startDate; payment_dates_T2(1:end-1)];

% Calculate Time Fractions
all_T1s     = yearfrac(startDate, fixing_dates_T1, 3);        % Act/365 for Vol
all_deltaTs = yearfrac(fixing_dates_T1, payment_dates_T2, 3); % Act/365 for Euribor

% Pre-calculate all discount factors for the entire schedule
all_df1s = getDiscountFactorByZeroRatesLinearInterp(startDate, fixing_dates_T1, dates, discounts);
all_df2s = getDiscountFactorByZeroRatesLinearInterp(startDate, payment_dates_T2, dates, discounts);

% Define specific parameters for the 4-year exotic cap
lambda = 0.1;
numRates = 16;
idx = 1:numRates; % Index vector for the first 16 caplets

% Compute all 16 initial forward rates at once
L_initial_vec = (all_df1s(idx) ./ all_df2s(idx) - 1) ./ all_deltaTs(idx);

% Apply spline row-by-row to extract the ATM volatilities
v_ATM = arrayfun(@(i) spline(strikes, fullCapletVolsBMM(i, :), L_initial_vec(i)), idx)';

T1_vec = all_T1s(idx);
% Implicit expansion creates the full 16x16 distance matrix instantly
time_diff_matrix = abs(T1_vec - T1_vec');
Rho = exp(-lambda * time_diff_matrix);

% Cholesky Decomposition
L_chol = chol(Rho, 'lower');

% Initialize: B(0; T_i, T_i+1) = B(0, T_i+1) / B(0, T_i)
B_init = all_df2s(idx) ./ all_df1s(idx);

end