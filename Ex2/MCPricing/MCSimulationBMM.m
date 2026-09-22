function simulated_Libors = MCSimulationBMM(N_paths, dt, all_T1s, all_deltaTs, ...
    v_ATM, L_chol, Rho, B_init)
% MCSIMULATIONBMM Simulates the forward Libor rates under the Bond Market
% Model (spot/rolling measure), utilizing fully vectorized path-wise
% matrix operations.
%
%   INPUTS:
%       N_paths     : Number of Monte Carlo paths to simulate.
%       dt          : Euler time step (in years), e.g. 1/12 for monthly.
%       all_T1s     : [numRates x 1] Fixing times (Act/365) of each
%                     forward Libor period.
%       all_deltaTs : [numRates x 1] Accrual fractions (Act/365) of each
%                     forward Libor period.
%       v_ATM       : [numRates x 1] ATM spot volatility of each B_i(t),
%                     interpolated on the BMM calibrated surface.
%       L_chol      : Lower-triangular Cholesky factor of Rho, used to
%                     correlate the independent Brownian shocks.
%       Rho         : [numRates x numRates] Correlation matrix between
%                     the forward Libor periods.
%       B_init      : [numRates x 1] Initial bond price ratios
%                     B(0;T_i,T_i+1) = P(0,T_i+1)/P(0,T_i).
%
%   OUTPUT:
%       simulated_Libors : [N_paths x numRates] Simulated forward Libor
%                     rate at each path, fixed at its own reset date.

numRates = length(v_ATM);
time_steps = 0:dt:all_T1s(end);

% Expand the initial 16x1 bond vector into a 15x10000 matrix
% (Row = Rate, Column = Path)
B_current = repmat(B_init, 1, N_paths);

% Volatility state (16x1)
v_current = v_ATM;

% Any rate whose fixing time is at/before simulation start is already
% known today with certainty -> Zero its volatility immediately.
v_current(all_T1s <= time_steps(1)) = 0;

% Storage for finalized rates
simulated_Libors = zeros(numRates, N_paths);


for step = 1:(length(time_steps) - 1)

    t_current = time_steps(step);
    t_next    = time_steps(step + 1);

    % randn generates a matrix of independent shocks.
    Z_indep = randn(numRates, N_paths);
    Z_corr  = L_chol * Z_indep; 

    % BMM Drift Calculation
    drift = -v_current .* (tril(Rho, -1) * v_current);

    log_update = (drift - 0.5 * v_current.^2) * dt - (v_current * sqrt(dt)) .* Z_corr;
    B_current  = B_current .* exp(log_update);

    % The Fixing Mechanism (Check if we passed a fixing date)
    for i = 1:numRates
        if t_current <= all_T1s(i) && t_next > all_T1s(i)

            simulated_Libors(i, :) = (1 ./ B_current(i, :) - 1) / all_deltaTs(i);

            % Kill the volatility for this rate (fixing mechanism)
            v_current(i) = 0;
        end
    end

end

% Transpose the output to match the standard quantitative format
simulated_Libors = simulated_Libors';

end