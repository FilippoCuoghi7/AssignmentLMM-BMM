function volsStrike = bootstrapSingleStrikeBMM(j, strikes, flatVols, ...
    numMaturities, all_T1s, all_df1s, all_df2s, all_deltaTs, matIdx, options)
%BOOTSTRAPSINGLESTRIKEBMM Performs the BMM calibration cascade for one strike.
%   This function targets the exact market cap prices (computed using the
%   LMM Black-76 formula) and extracts the specific BMM spot volatilities
%   that replicate those prices.
%
%   INPUTS:
%       j             : Integer index of the current strike being calibrated.
%       strikes       : Array of all market strikes (in decimal).
%       flatVols      : Matrix of market flat volatilities (in decimal).
%       numMaturities : Total number of maturity pillars (scalar).
%       all_T1s       : Vector of fixing times (T1) for all caplets.
%       all_df1s      : Vector of discount factors P(0, T1) for all caplets.
%       all_df2s      : Vector of discount factors P(0, T2) for all caplets.
%       all_deltaTs   : Vector of accrual fractions (delta) for all caplets.
%       matIdx        : Array of exact integer boundary indices for maturities.
%       options       : Optimization settings passed from the main script.
%                       (Note: This function internally tightens the TolX to
%                       accommodate the microscopic scale of BMM volatilities).
%
%   OUTPUTS:
%       volsStrike    : A [nCaplets x 1] column vector containing the fully
%                       interpolated BMM spot volatilities for every single
%                       caplet up to the maximum maturity.

strike_val = strikes(j);
flatVols_j = flatVols(:, j);

% Compute Market Target Caps using the standard LMM (Black-76) formula
marketCapPrices = zeros(numMaturities, 1);
for k = 1:numMaturities
    idx_target = 1:matIdx(k); % Exact integer slicing for all caplets up to T
    caplet_prices = computePriceCapletLMM(all_df1s(idx_target), all_df2s(idx_target), ...
        all_deltaTs(idx_target), all_T1s(idx_target), strike_val, flatVols_j(k));
    marketCapPrices(k) = sum(caplet_prices(:));
end

% Initialize outputs and the full caplet volatility tracker
spotPillarVols = zeros(numMaturities, 1);
nCaplets = length(all_T1s);
volsStrike = zeros(nCaplets, 1);

% Bootstrapping Bucket 1 to 20
for k = 1:numMaturities

    % Identify the specific caplets in the current bucket
    if k == 1
        idxOld = []; % No old caplets for Bucket 1
        idxNew = 1:matIdx(1);
    else
        idxOld = 1:matIdx(k-1);
        idxNew = (matIdx(k-1) + 1) : matIdx(k);
    end

    % Extract the exact delta and calculate the exact Forward Rate for the first new caplet
    exact_delta = all_deltaTs(idxNew(1));
    exact_L     = (all_df1s(idxNew(1)) ./ all_df2s(idxNew(1)) - 1) ./ exact_delta;

    % Precise scaling factor:
    % v = sigma * (delta * L) / (1 + delta * L)
    rigorous_scale = (exact_delta * exact_L) / (1 + exact_delta * exact_L);
    initial_guess  = flatVols_j(k) * rigorous_scale;

    if k == 1
        % --- BUCKET 1 (Year 1) ---
        % No interpolation needed. We must solve for Bucket 1 because
        % BMM pricing is fundamentally different from LMM pricing.
        targetCap = marketCapPrices(1);

        objFun = @(nu) sum(computePriceCapletBMM(all_df1s(idxNew), all_df2s(idxNew), ...
            all_deltaTs(idxNew), all_T1s(idxNew), strike_val, nu)) - targetCap;

        spotPillarVols(1) = fzero(objFun, initial_guess, options);
        volsStrike(idxNew) = spotPillarVols(1);

    else
        % --- BUCKET 2 to 20 ---
        targetDeltaC = marketCapPrices(k) - marketCapPrices(k-1);

        % Exact interpolation anchors
        nu1 = spotPillarVols(k-1);
        t1  = all_T1s(idxOld(end));
        t3  = all_T1s(idxNew(end));
        w   = (all_T1s(idxNew) - t1) ./ (t3 - t1);

        objFun = @(nu2) sum(computePriceCapletBMM(all_df1s(idxNew), all_df2s(idxNew), ...
            all_deltaTs(idxNew), all_T1s(idxNew), strike_val, ...
            nu1 + w .* (nu2 - nu1))) - targetDeltaC;

        spotPillarVols(k) = fzero(objFun, initial_guess, options);

        % Save the interpolated caplet volatilities
        volsStrike(idxNew) = nu1 + w .* (spotPillarVols(k) - nu1);
    end
end
end