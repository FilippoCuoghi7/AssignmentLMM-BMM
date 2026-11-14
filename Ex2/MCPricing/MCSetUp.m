function [v_ATM, L_chol, B_init, all_T1s, all_deltaTs, all_df1s, all_df2s, Rho] = MCSetUp(market, fullCapletVolsBMM)
%MCSETUP Prepares the arrays, vectors, and matrices required to run the
% Bond Market Model Monte Carlo simulation.
%
%   This function rebuilds the quarterly caplet schedule used in the BMM
%   calibration, computes the initial forward Libor rates of the first
%   numRates = 16 periods (4-year exotic cap), interpolates their BMM spot
%   volatilities at the ATM strike K_i = L(0;T_i,T_i+1), and builds the
%   correlation matrix rho_ij = exp(-lambda*|T_i - T_j|) (lambda = 0.1,
%   Act/365) together with its Cholesky factor.
%
%   INPUTS:
%       market            : A structure containing the market data with the following fields:
%                           - dates      : Array of dates for the discount curve (first element is RefDate).
%                           - discounts  : Array of discount factors corresponding to market.dates.
%                           - maturities : Column vector of cap maturities in years.
%                           - strikes    : Column vector of cap strikes in percentage.
%       fullCapletVolsBMM : [nCaplets x numStrikes] The calibrated BMM spot volatilities
%                           (output of runCalibrationBMM). Rows correspond to forward
%                           rate reset periods, excluding the caplet fixing at t=0;
%                           columns correspond to market.strikes.
%
%   OUTPUTS:
%       v_ATM       : [numRates x 1] ATM spot volatility of each B_i(t),
%                     interpolated on the BMM calibrated surface.
%       L_chol      : Lower-triangular Cholesky factor of Rho, used to
%                     correlate the independent Brownian shocks.
%       B_init      : [numRates x 1] Initial bond price ratios
%                     B(0;T_i,T_i+1) = P(0,T_i+1)/P(0,T_i).
%       all_T1s     : Vector of fixing times (Act/365) for all caplets of the
%                     schedule, including the period fixing at t=0 (the first
%                     numRates entries are the simulated rates).
%       all_deltaTs : Vector of accrual fractions (delta, Act/360) for all caplets.
%       all_df1s    : Vector of discount factors P(0, T1) for all caplets.
%       all_df2s    : Vector of discount factors P(0, T2) for all caplets.
%       Rho         : [numRates x numRates] Correlation matrix between
%                     the forward Libor periods.

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
all_deltaTs = yearfrac(fixing_dates_T1, payment_dates_T2, 2); % Act/360 for Euribor

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
rowIdx = max(idx - 1, 1);
v_ATM = arrayfun(@(i) spline(strikes, fullCapletVolsBMM(rowIdx(i), :), L_initial_vec(i)), idx)';


T1_vec = all_T1s(idx);
% Implicit expansion creates the full 16x16 distance matrix instantly
time_diff_matrix = abs(T1_vec - T1_vec');
Rho = exp(-lambda * time_diff_matrix);

% Cholesky Decomposition
L_chol = chol(Rho, 'lower');

% Initialize: B(0; T_i, T_i+1) = B(0, T_i+1) / B(0, T_i)
B_init = all_df2s(idx) ./ all_df1s(idx);

end