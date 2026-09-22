function [dv01Bond, dv01S2, dv01S6, dv01S10] = computeMacroBucketSensitivities( ...
    bucketIndex, macroNodes, marketMaturities, datesSet, ratesSet, bump, ...
    swap2y, swap6y, swap10y, ...
    contract, UpfrontPct, paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigmaLMM)
% COMPUTEMACROBUCKETSENSITIVITIES Orchestrates the single-bootstrap coarse-grained DV01 engine.
%
%   This function represents the core of the risk engine. For a given macro-bucket,
%   it applies the exact triangle-weighted shifts to the market instruments,
%   performs a SINGLE curve bootstrap, and then evaluates the new Mark-to-Market
%   prices for both the Structured Bond and the three hedging swaps simultaneously.
%   Because the base instruments (par swaps and fair-value bond) start with an NPV
%   of exactly 0, the bumped price represents the exact DV01.
%
%   INPUTS:
%       bucketIndex             : Integer indicating which macro-bucket is being shocked.
%       macroNodes              : Array of the macro bucket peaks.
%       marketMaturities        : Array of year fractions for all active market calibration instruments.
%       bump                    : Scalar value representing the shift size.
%       datesSet                : Struct containing the original dates for calibration instruments.
%       ratesSet                : Struct containing the original, unbumped market quotes.
%       swap2y, swap6y, swap10y : Structs containing the fixed characteristics of the
%                                 hedging swaps (generated via buildStandardSwap).
%       contract                : Struct containing the bond's term sheet parameters.
%       UpfrontPct              : The fair upfront payment calculated at inception (as a decimal).
%       paymentDates            : Array of Party B payment dates (datetime).
%       datesT1, datesT2        : Arrays of accrual start and end dates for the floating legs.
%       yearsT1                 : Array of reset times (Act/365) used for option pricing.
%       deltaT                  : Array of accrual fractions (Act/360) for Libor rates.
%       S                       : Array of Spread values for each period.
%       K                       : Array of Strike values for each period.
%       C                       : Array of Cap/Fallback values for each period.
%       sigmaLMM                : Array of base LMM spot volatilities mapped to each period.
%
%   OUTPUTS:
%       dv01Bond                : The DV01 of the Structured Bond for this bucket.
%       dv01S2                  : The DV01 of the 2y Hedging Swap for this bucket.
%       dv01S6                  : The DV01 of the 6y Hedging Swap for this bucket.
%       dv01S10                 : The DV01 of the 10y Hedging Swap for this bucket.

% Get the Triangle Weights for the current bucket
weights = getMacroWeights(marketMaturities, macroNodes, bucketIndex);

% Apply the weighted shocks to create ONE bumped rate set
ratesBumped = ratesSet;

idx = 1;
ratesBumped.depos(1:3, :) = ratesBumped.depos(1:3, :) + weights(idx:idx+2) * bump;
idx = idx + 3;
ratesBumped.futures(1:7, :) = ratesBumped.futures(1:7, :) + weights(idx:idx+6) * bump;
idx = idx + 7;
ratesBumped.swaps(2:end, :) = ratesBumped.swaps(2:end, :) + weights(idx:end) * bump;

% Bootstrap again
[bumpedDates, bumpedDiscounts, ~] = bootstrap(datesSet, ratesBumped);

% Price using this one new curve
% (Since Base NPV = 0, the Bumped NPV is exactly the DV01)

% The Structured Bond DV01
dv01Bond = computeMkmGivenCurve(bumpedDates, bumpedDiscounts, contract, UpfrontPct, ...
    paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigmaLMM);

% The 3 Hedging Swaps DV01s
dv01S2  = priceBumpedSwap(swap2y, datesSet.settlement, bumpedDates, bumpedDiscounts);
dv01S6  = priceBumpedSwap(swap6y, datesSet.settlement, bumpedDates, bumpedDiscounts);
dv01S10 = priceBumpedSwap(swap10y, datesSet.settlement, bumpedDates, bumpedDiscounts);

end