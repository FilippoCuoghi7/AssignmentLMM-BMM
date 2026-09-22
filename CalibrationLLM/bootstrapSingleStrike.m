function volsStrike = bootstrapSingleStrike(j, strikes, flatVols, ...
    numMaturities, all_T1s, all_df1s, all_df2s, all_deltaTs, matIdx, options)
%BOOTSTRAPSINGLESTRIKE Performs the LMM calibration cascade for one strike.
%
%   INPUTS:
%       j             : Integer index of the current strike being calibrated.
%       strikes       : Array of all market strikes (in decimal).
%       flatVols      : Matrix of market flat volatilities (in decimal).
%       numMaturities : Total number of maturity pillars (scalar).
%       all_T1s       : Vector of fixing times (T1) for all future caplets.
%       all_df1s      : Vector of discount factors P(0, T1) for all caplets.
%       all_df2s      : Vector of discount factors P(0, T2) for all caplets.
%       all_deltaTs   : Vector of accrual fractions (delta) for all caplets.
%       options       : Optimization settings for the fzero solver.
%
%   OUTPUTS:
%       spotPillarVols  : A [numMaturities x 1] column vector containing the
%                       calibrated LMM spot volatilities for this specific strike.

strike_val = strikes(j);
flatVols_j = flatVols(:, j);

% Compute Market Target Caps for this Strike
marketCapPrices = zeros(numMaturities, 1);
for k = 1:numMaturities
    idx_target = 1:matIdx(k); % Exact integer slicing for all caplets up to T

    caplet_prices = computePriceCapletLMM(all_df1s(idx_target), all_df2s(idx_target), ...
        all_deltaTs(idx_target), all_T1s(idx_target), strike_val, flatVols_j(k));

    marketCapPrices(k) = sum(caplet_prices(:));
end

% Initialize outputs and the full caplet volatility tracker
spotPillarVols = zeros(numMaturities, 1);  % Tracks the 13 anchors
nCaplets = length(all_T1s);
volsStrike = zeros(nCaplets, 1);           % Tracks all 80 caplets

% Bucket 1 (Year 1): Constant Volatility
spotPillarVols(1) = flatVols_j(1);
volsStrike(1:matIdx(1)) = spotPillarVols(1); % Save flat vol for bucket 1

% Bootstrapping Bucket 2 to 20
for k = 2:numMaturities

    % Exact integer indices for past and present caplets
    idxOld = 1:matIdx(k-1);
    idxNew = (matIdx(k-1) + 1) : matIdx(k);

    targetDeltaC = marketCapPrices(k) - marketCapPrices(k-1);

    % Exact interpolation
    sigma1 = spotPillarVols(k-1);
    t1 = all_T1s(idxOld(end)); % Reset time of last caplet in previous bucket
    t3 = all_T1s(idxNew(end)); % Reset time of last caplet in current bucket

    w = (all_T1s(idxNew) - t1) ./ (t3 - t1);

    % Objective: oldPrice + newPrice - targetPrice
    objFun = @(sigma2) sum(computePriceCapletLMM(all_df1s(idxNew), all_df2s(idxNew), ...
        all_deltaTs(idxNew), all_T1s(idxNew), strike_val, ...
        sigma1 + w .* (sigma2 - sigma1))) - targetDeltaC;

    % Solve for the pillar spot volatility
    initial_guess = flatVols_j(k);
    spotPillarVols(k) = fzero(objFun, initial_guess, options);

    % Save the interpolated caplet volatilities so they can become "oldPrice" in the next loop
    volsStrike(idxNew) = sigma1 + w .* (spotPillarVols(k) - sigma1);
end
end