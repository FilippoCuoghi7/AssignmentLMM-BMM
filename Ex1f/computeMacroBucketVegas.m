function [VegaBond, VegaCap6y, VegaCap10y] = computeMacroBucketVegas( ...
    bucketIndex, macroNodes, market, curveDates, curveDiscounts, bump, ...
    cap6yInfo, cap10yInfo, basePriceCap6y, basePriceCap10y, ...
    contract, UpfrontPct)
% COMPUTEMACROBUCKETVEGAS Computes the coarse-grained Vega sensitivities.
%
%   This function calculates the risk (Vega) of the portfolio to a specific
%   macro-bucket of the volatility surface. It applies triangle-weighted
%   shifts to the flat market volatilities, recalibrates the LMM spot vols,
%   and reprices the Structured Bond and hedging Caps.
%
%   INPUTS:
%       bucketIndex      : Integer (1 or 2) indicating the macro-bucket being shocked.
%       macroNodes       : Array of the macro bucket peaks.
%       market           : Struct containing the base bootstrapped market data.
%       curveDates       : Array of dates from the base yield curve.
%       curveDiscounts   : Array of discount factors from the base yield curve.
%       bump             : Scalar value representing the volatility shift size.
%       cap6yInfo        : Struct containing the 6y Cap characteristics.
%       cap10yInfo       : Struct containing the 10y Cap characteristics.
%       basePriceCap6y   : The exact MtM of the 6y Cap under unbumped volatilities.
%       basePriceCap10y  : The exact MtM of the 10y Cap under unbumped volatilities.
%       contract         : Struct containing the structured bond term sheet.
%       UpfrontPct       : The fair upfront payment calculated at inception.
%
%   OUTPUTS:
%       VegaBond         : The change in MtM of the Structured Bond for this bucket.
%       VegaCap6y        : The change in MtM of the 6y Hedging Cap for this bucket.
%       VegaCap10y       : The change in MtM of the 10y Hedging Cap for this bucket.

% Extract variables from the struct 'market'
marketMaturities = market.maturities;
marketStrikes = market.strikes;

% Get the Triangle Weights for the current bucket
weights = getMacroWeights(marketMaturities, macroNodes, bucketIndex);

% Create a safe, explicit copy of the base market
marketBumped = market;

% Apply the weighted shocks to the flat vols
marketBumped.vols = marketBumped.vols + (weights * bump) * 100;

% Recalibrate the LMM Spot Volatilities using the bumped market
[~, ~, ~, ~, BumpedSpotVolsLMM] = runCalibrationLMM(marketBumped);

% Price the instruments using the new Volatility Surface

% The Structured Bond (Base NPV = 0, so bumped MtM is the Vega)
VegaBond = computeMtMGivenVols(market, contract, UpfrontPct, BumpedSpotVolsLMM);

% The Hedging Caps (Must subtract Base Price to isolate the Vega)
bumpedCap6y  = computePriceCap(cap6yInfo, curveDates, curveDiscounts, marketStrikes, BumpedSpotVolsLMM);
bumpedCap10y = computePriceCap(cap10yInfo, curveDates, curveDiscounts, marketStrikes, BumpedSpotVolsLMM);

VegaCap6y  = bumpedCap6y - basePriceCap6y;
VegaCap10y = bumpedCap10y - basePriceCap10y;

end