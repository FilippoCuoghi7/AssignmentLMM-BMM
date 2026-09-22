function [priceErrors, marketCapPrices, modelCapPrices] = ComparePricesBMM(flatVols, numStrikes, numMaturities, all_T1s, all_df1s, all_df2s, all_deltaTs, matIdx, strikes, spotVols)
%COMPAREPRICESBMM Computes and compares Cap prices using market flat volatilities
% vs. BMM calibrated model spot volatilities.
%
%   INPUTS:
%       flatVols      : [numMaturities x numStrikes] Market flat vols.
%       numStrikes    : Number of strikes (scalar).
%       numMaturities : Number of maturity pillars (scalar).
%       all_T1s       : Vector of fixing times for all caplets.
%       all_df1s      : Vector of P(0, T1) discount factors.
%       all_df2s      : Vector of P(0, T2) discount factors.
%       all_deltaTs   : Vector of accrual fractions.
%       matIdx        : Array of exact integer boundary indices for maturities.
%       strikes       : Array of market strikes.
%       spotVols      : [nCaplets x numStrikes] The calibrated LMM spot volatilities
%                       (e.g., the 80x13 output from your calibration).
%
%   OUTPUTS:
%       priceError      : [numMaturities x numStrikes] The pricing error
%                         (Market Price - Model Price).
%       marketCapPrices : [numMaturities x numStrikes] Target prices using flat vols.
%       modelCapPrices  : [numMaturities x numStrikes] Re-priced caps using spot vols.

% Pre-allocate the full 13x13 matrices
marketCapPrices = zeros(numMaturities, numStrikes);
modelCapPrices  = zeros(numMaturities, numStrikes);

% Loop over Strikes (cols) and Maturities (rows)
for j = 1:numStrikes
    strike_val = strikes(j);
    flatVols_j = flatVols(:, j);
    spotVols_j = spotVols(:, j); % The 80x1 vector of caplet spot vols for this strike

    for k = 1:numMaturities
        idx_target = 1:matIdx(k); % Indices for all caplets up to T

        % Market Price (Uses a const flat vol for all caplets)
        caplet_pricesMkt = computePriceCapletLMM(all_df1s(idx_target), all_df2s(idx_target), ...
            all_deltaTs(idx_target), all_T1s(idx_target), strike_val, flatVols_j(k));

        marketCapPrices(k, j) = sum(caplet_pricesMkt(:));

        % Model Price (Uses the varying spot vol for each caplet)
        caplet_pricesModel = computePriceCapletBMM(all_df1s(idx_target), all_df2s(idx_target), ...
            all_deltaTs(idx_target), all_T1s(idx_target), strike_val, spotVols_j(idx_target));

        modelCapPrices(k, j) = sum(caplet_pricesModel(:));
    end
end

% Error Computation
priceErrors = abs(marketCapPrices - modelCapPrices);

end