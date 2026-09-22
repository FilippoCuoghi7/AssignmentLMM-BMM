function TotalVega = computeTotalVega(market, contract, UpfrontPct, bump)
% COMPUTETOTALVEGA Calculates the Market Vega using Central Finite Difference.
%
%   This function computes the sensitivity to a parallel shift in the raw market
%   implied volatilities. It shifts the quoted volatilities up and down by 'bump',
%   recalibrates the LMM spot volatilities for both scenarios, and re-prices the
%   swap to find the Mark-to-Market impact.
%
%   INPUTS:
%       market     : Struct containing the base bootstrapped market data.
%       contract   : Struct containing the bond's term sheet parameters.
%       UpfrontPct : The fair upfront payment calculated at inception.
%       bump       : The absolute parallel shift applied to the flat
%                    volatilities.
%   OUTPUT:
%       TotalVega  : The change in the swap's MtM (in Euros), scaled to 
%                    represent a 1% (100 bps) parallel shift in volatility.

marketUp = market;
marketUp.vols = market.vols + bump*100; % flat vols are in percentage.

marketDown = market;
marketDown.vols = market.vols - bump*100; % flat vols are in percentage.


% Recalibrate the spot volatilities
[~, ~, ~, ~, spotVols_up] = runCalibrationLMM(marketUp);
[~, ~, ~, ~, spotVols_down] = runCalibrationLMM(marketDown);


% Reprice
mtm_up   = computeMtMGivenVols(market, contract, UpfrontPct, spotVols_up);
mtm_down = computeMtMGivenVols(market, contract, UpfrontPct, spotVols_down);

% Compute Central Difference Vega (Normalized to a 1% Volatility Shift).
TotalVega = (mtm_up - mtm_down) / (2 * bump) * 0.01;

end