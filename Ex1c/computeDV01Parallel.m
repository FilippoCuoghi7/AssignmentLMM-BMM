function dv01Parallel = computeDV01Parallel(datesSet, ratesBase, market, contract, ...
    volsLMM, UpfrontPct, bump)
% COMPUTEDV01PARALLEL Calculates the parallel Delta sensitivity (DV01) for
% the structured swap, bumping every calibration instrument (depos,
% futures, swaps) simultaneously by the same amount.
%
%   This is an independent cross-check against sum(computeBucketDV01(...)):
%   the two should reconcile closely, since a full-curve 1bp shift is, to
%   first order, equivalent to shifting every bucket by 1bp one at a time
%   and summing the effects. A mismatch would signal an overlap or a gap
%   in the bucket decomposition.
%
%   INPUTS: same as computeBucketDV01.
%       datesSet   : Struct containing the dates for calibration instruments.
%       ratesBase  : Struct containing the original, unbumped market rates.
%       market     : Struct containing the base bootstrapped market data.
%       contract   : Struct containing the bond's term sheet parameters.
%       volsLMM    : [N x M] matrix of calibrated LMM spot volatilities.
%       UpfrontPct : The fair upfront payment calculated on the base curve.
%       bump       : The absolute shift applied to the instruments.
%
%   OUTPUT:
%       dv01Parallel : The sensitivity (in Euros) of the swap's
%                      Mark-to-Market value to a uniform 1bp (0.0001)
%                      parallel shift of the entire calibration curve.

% Generate Schedule
[paymentDates, ~] = computePaymentDates(contract.startDate, contract.endDate, ...
    contract.numPaymentsYear, 'modifiedfollowing');

% Setup Time Arrays
datesT1 = [contract.startDate; paymentDates(1:end-1)];
datesT2 = paymentDates;
yearsT1 = yearfrac(contract.startDate, datesT1, 3);
deltaT  = yearfrac(datesT1, datesT2, 2);

% Setup Term Sheet Arrays
[S, K, C] = computeParameters(contract.startDate, paymentDates, contract.rules, contract.numPaymentsYear);

% Setup Constant LMM Spot Volatilities
numPeriods = length(paymentDates);
sigmaLMM = zeros(numPeriods, 1);

strikesGrid = market.strikes;
if strikesGrid(1) >= 1.0
    strikesGrid = strikesGrid / 100;
end

for i = 2:numPeriods
    rowLMM = i - 1; % Matches the corresponding forward rate reset period
    sigmaLMM(i) = interp1(strikesGrid, volsLMM(rowLMM, :), K(i), 'spline', 'extrap');
end

% Bump every calibration instrument simultaneously (parallel shift)
ratesBumpedUp = ratesBase;
ratesBumpedUp.depos   = ratesBumpedUp.depos + bump;
ratesBumpedUp.futures = ratesBumpedUp.futures + bump;
ratesBumpedUp.swaps   = ratesBumpedUp.swaps + bump;

ratesBumpedDown = ratesBase;
ratesBumpedDown.depos   = ratesBumpedDown.depos - bump;
ratesBumpedDown.futures = ratesBumpedDown.futures - bump;
ratesBumpedDown.swaps   = ratesBumpedDown.swaps - bump;

rawMtMUp = computeMkmBumpedPrice(datesSet, ratesBumpedUp, contract, UpfrontPct, ...
    paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigmaLMM);
rawMtMDown = computeMkmBumpedPrice(datesSet, ratesBumpedDown, contract, UpfrontPct, ...
    paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigmaLMM);

rawMtM = rawMtMUp - rawMtMDown;
dv01Parallel = rawMtM * (0.0001 / (2*bump));

end
