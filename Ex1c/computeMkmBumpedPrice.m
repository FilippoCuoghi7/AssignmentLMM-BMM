function MkMBumped = computeMkmBumpedPrice(datesSet, ratesSetBumped, contract, UpfrontPct, ...
    paymentDates, datesT1, datesT2, yearsT1, deltaT, ...
    S, K, C, sigmaLMM)
% COMPUTEMKMBUMPEDPRICE Bootstraps a bumped yield curve and computes the new MtM.
%
%   This function is optimized for Delta sensitivity (DV01) calculations.
%   It computes the Mark-to-Market using the uncorrected (Standard Black-76)
%   digital option price, ignoring volatility skew.
%
%   INPUTS:
%       datesSet        : Struct containing calibration dates.
%       ratesSetBumped  : Struct containing the market rates with 1 instrument bumped.
%       contract        : Struct containing the bond's term sheet parameters.
%       UpfrontPct      : The base upfront payment calculated at inception.
%       paymentDates    : [N x 1] Array of Party B payment dates.
%       datesT1         : [N x 1] Array of accrual start dates.
%       datesT2         : [N x 1] Array of accrual end dates.
%       yearsT1         : [N x 1] Array of reset times (Act/365) for option pricing.
%       deltaT          : [N x 1] Array of accrual fractions (Act/360) for Libor.
%       S, K, C         : [N x 1] Arrays for Spread, Strike, and Cap/Fallback.
%       sigmaLMM        : [N x 1] Array of base LMM spot volatilities.
%
%   OUTPUT:
%       MkMBumped       : The Mark-to-Market value of the structured swap in Euros
%                         under the bumped yield curve (Uncorrected).

% Generate the new discount curve reflecting the bump
[bumpedDates, bumpedDiscounts, ~] = bootstrap(datesSet, ratesSetBumped);

% Price the swap off the bumped curve (sticky vols)
MkMBumped = priceStructuredSwap(bumpedDates, bumpedDiscounts, contract, UpfrontPct, ...
    paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigmaLMM);

end