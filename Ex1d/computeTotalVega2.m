function TotalVega = computeTotalVega2(market, contract, fullCapletVolsLMM, UpfrontPct, bump)
% COMPUTETOTALVEGA2 Calculates the Model Vega using Central Finite Difference.
%
%   This function computes the Total Vega (also known as Parallel Vega) of the
%   structured swap. It applies a symmetric parallel bump (+/- bump) to the
%   entire Spot LMM volatility surface simultaneously, recalculates the
%   Mark-to-Market value of the swap for both scenarios, and takes a central
%   difference -- matching the precision of computeTotalVega's Market Vega --
%   while holding the discount curve and the initial upfront payment constant.
%
%   INPUTS:
%       market            : Struct containing the base bootstrapped market data.
%                           Required fields:
%                           - .dates (discount factor dates)
%                           - .discounts (discount factors)
%                           - .strikes (market strike grid)
%       contract          : Struct containing the bond's term sheet parameters.
%                           Required fields:
%                           - .startDate, .endDate, .numPaymentsYear
%                           - .rules, .spreadA, .firstCouponB, .notional
%       fullCapletVolsLMM : [N x M] matrix of base calibrated LMM spot volatilities.
%       UpfrontPct        : The fair upfront payment calculated at inception
%                           (as a decimal percentage, uncorrected).
%       bump              : The magnitude of the parallel shift to apply to the
%                           volatility surface.
%
%   OUTPUT:
%       TotalVega         : The change in the Mark-to-Market value of the swap
%                           (in Euros), scaled to represent a 1% 
%                           parallel shift in the spot volatility surface.

% Generate Payment Schedule
[paymentDates, ~] = computePaymentDates(contract.startDate, contract.endDate, ...
    contract.numPaymentsYear, 'modifiedfollowing');

% Setup Arrays for Party B
datesT1 = [contract.startDate; paymentDates(1:end-1)];
datesT2 = paymentDates;
yearsT1 = yearfrac(contract.startDate, datesT1, 3); % Act/365 for Volatility
deltaT  = yearfrac(datesT1, datesT2, 2);            % Act/360 for Euribor accrual

% Extract Dynamic Parameters (Spread, Strike, Cap)
[S, K, C] = computeParameters(contract.startDate, paymentDates, contract.rules, contract.numPaymentsYear);

% Bump the entire implied volatility matrix up and down symmetrically
fullCapletVolsUp   = fullCapletVolsLMM + bump;
fullCapletVolsDown = fullCapletVolsLMM - bump;

numPeriods = length(paymentDates);
sigmaUp   = zeros(numPeriods, 1);
sigmaDown = zeros(numPeriods, 1);

% Ensure strikes are in decimals for interpolation
strikesGrid = market.strikes;
if strikesGrid(1) >= 1.0
    strikesGrid = strikesGrid / 100;
end

% Interpolate the new spot volatilities using each bumped matrix
for i = 2:numPeriods
    rowLMM = i - 1; % Matches the corresponding forward rate reset period
    sigmaUp(i)   = interp1(strikesGrid, fullCapletVolsUp(rowLMM, :),   K(i), 'spline', 'extrap');
    sigmaDown(i) = interp1(strikesGrid, fullCapletVolsDown(rowLMM, :), K(i), 'spline', 'extrap');
end

% Price the swap under both bumped volatility surfaces
MkMUp = priceStructuredSwap(market.dates, market.discounts, contract, UpfrontPct, ...
    paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigmaUp);
MkMDown = priceStructuredSwap(market.dates, market.discounts, contract, UpfrontPct, ...
    paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigmaDown);

% Central Difference Vega (Normalized to a 1% Volatility Shift)
TotalVega = (MkMUp - MkMDown) / (2 * bump) * 0.01;

end