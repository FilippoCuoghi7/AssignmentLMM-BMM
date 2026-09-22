function MtM = computeMtMGivenVols(market, contract, UpfrontPct, spotVolsLMM)
% COMPUTEMTMGIVENVOLS Auxiliary function to price the swap for a given Volatility Matrix.
%
%   This extracts the core Black-76 pricing logic so it can be called cleanly
%   by the Vega sensitivity function without code duplication.
%
%   INPUTS:
%       market      : Struct containing the base bootstrapped market data.
%                     Required fields:
%                     - .dates (discount factor dates)
%                     - .discounts (discount factors)
%                     - .strikes (market strike grid)
%       contract    : Struct containing the bond's term sheet parameters.
%                     Required fields:
%                     - .startDate, .endDate, .numPaymentsYear
%                     - .rules, .spreadA, .firstCouponB, .notional
%       UpfrontPct  : The fair upfront payment calculated at inception
%                     (as a decimal percentage, uncorrected).
%       spotVolsLMM : [N x M] matrix of LMM spot volatilities to be used
%                     for pricing this specific market scenario.
%
%   OUTPUT:
%       MtM         : The Mark-to-Market value of the swap (in Euros)
%                     evaluated under the provided volatility matrix.

% Setup Dates (Unchanged by volatility)
[paymentDates, ~] = computePaymentDates(contract.startDate, contract.endDate, ...
    contract.numPaymentsYear, 'modifiedfollowing');

% Setup Arrays for Party B
datesT1 = [contract.startDate; paymentDates(1:end-1)];
datesT2 = paymentDates;
yearsT1 = yearfrac(contract.startDate, datesT1, 3);
deltaT  = yearfrac(datesT1, datesT2, 2);

[S, K, C] = computeParameters(contract.startDate, paymentDates, contract.rules, contract.numPaymentsYear);

% Spline Interpolation for the specific Spot Volatilities
numPeriods = length(paymentDates);
sigma = zeros(numPeriods, 1);
strikesGrid = market.strikes;
if strikesGrid(1) >= 1.0
    strikesGrid = strikesGrid / 100;
end

for i = 2:numPeriods
    rowLMM = i - 1;
    sigma(i) = interp1(strikesGrid, spotVolsLMM(rowLMM, :), K(i), 'spline', 'extrap');
end

% Price the swap under the given volatility surface
MtM = priceStructuredSwap(market.dates, market.discounts, contract, UpfrontPct, ...
    paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigma);
end