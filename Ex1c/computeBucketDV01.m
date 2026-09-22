function dv01 = computeBucketDV01(datesSet, ratesBase, market, contract, volsLMM, UpfrontPct, bump)
% COMPUTEBUCKETDV01 Calculates the Delta bucket sensitivities (DV01) for the structured swap.
%
%   This function isolates the constant parameters of the structured swap (dates,
%   term sheet rules, and LMM spot volatilities). It then systematically bumps each
%   underlying calibration instrument (depos, futures, swaps) by the bump,
%   re-bootstraps the curve, and computes the change in the Mark-to-Market (MtM)
%   value of the swap holding the base upfront constant.
%
%   INPUTS:
%       datesSet   : Struct containing the dates for calibration instruments
%                    (settlement, depos, futures, swaps).
%       ratesBase  : Struct containing the original, unbumped market rates
%                    for the calibration instruments.
%       market     : Struct containing the base bootstrapped market data.
%                    Required field:
%                    - .strikes (market strike grid used for LMM calibration)
%       contract   : Struct containing the bond's term sheet parameters.
%                    Required fields:
%                    - .startDate, .endDate
%                    - .numPaymentsYear
%                    - .rules
%                    - .notional
%       volsLMM    : [N x M] matrix of calibrated LMM spot volatilities.
%       UpfrontPct : The fair upfront payment calculated on the base curve
%                    at inception (as a decimal percentage, uncorrected).
%       bump       : The absolute shift to be applied to the instruments before
%                    re-bootstrapping.
%
%   OUTPUT:
%       dv01       : A column vector containing the sensitivity (in Euros) of
%                    the swap's Mark-to-Market value, scaled to represent exactly 
%                    a 1 basis point (0.0001) shift in each respective bucket.

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

% Ensure strikes are in decimals
strikesGrid = market.strikes;
if strikesGrid(1) >= 1.0
    strikesGrid = strikesGrid / 100;
end

for i = 2:numPeriods
    rowLMM = i - 1; % Matches the corresponding forward rate reset period
    sigmaLMM(i) = interp1(strikesGrid, volsLMM(rowLMM, :), K(i), 'spline', 'extrap');
end

% Initialize loop variables
nDepos   = 3;
nFutures = 7;
nSwaps   = size(ratesBase.swaps, 1);

numBuckets = nDepos + nFutures + (nSwaps - 1); % Swaps start at index 2
dv01 = zeros(numBuckets, 1);
bucketIdx = 1;

% --- Loop 1: Deposits ---
for i = 1:nDepos
    ratesBumpedUp = ratesBase;
    ratesBumpedUp.depos(i, :) = ratesBumpedUp.depos(i, :) + bump;
    ratesBumpedDown = ratesBase;
    ratesBumpedDown.depos(i,:) = ratesBumpedDown.depos(i, :) - bump;
    
    rawMtMUp = computeMkmBumpedPrice(datesSet, ratesBumpedUp, contract, UpfrontPct, ...
        paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigmaLMM);
    rawMtMDown = computeMkmBumpedPrice(datesSet, ratesBumpedDown, contract, UpfrontPct, ...
        paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigmaLMM);

    rawMtM = rawMtMUp - rawMtMDown;
    dv01(bucketIdx) = rawMtM * (0.0001 / (2*bump));
    
    bucketIdx = bucketIdx + 1;
end

% --- Loop 2: Futures ---
for i = 1:nFutures
    ratesBumpedUp = ratesBase;
    ratesBumpedUp.futures(i, :) = ratesBumpedUp.futures(i, :) + bump;
    ratesBumpedDown = ratesBase;
    ratesBumpedDown.futures(i, :) = ratesBumpedDown.futures(i, :) - bump;
    
    rawMtMUp = computeMkmBumpedPrice(datesSet, ratesBumpedUp, contract, UpfrontPct, ...
        paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigmaLMM);
    rawMtMDown = computeMkmBumpedPrice(datesSet, ratesBumpedDown, contract, UpfrontPct, ...
        paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigmaLMM);

    rawMtM = rawMtMUp - rawMtMDown;
    dv01(bucketIdx) = rawMtM * (0.0001 / (2*bump));
        
    bucketIdx = bucketIdx + 1;
end

% --- Loop 3: Swaps ---
for i = 2:nSwaps
    ratesBumpedUp = ratesBase;
    ratesBumpedUp.swaps(i, :) = ratesBumpedUp.swaps(i, :) + bump;
    ratesBumpedDown = ratesBase;
    ratesBumpedDown.swaps(i, :) = ratesBumpedDown.swaps(i, :) - bump;
    
    rawMtMUp = computeMkmBumpedPrice(datesSet, ratesBumpedUp, contract, UpfrontPct, ...
        paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigmaLMM);
    rawMtMDown = computeMkmBumpedPrice(datesSet, ratesBumpedDown, contract, UpfrontPct, ...
        paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigmaLMM);

    rawMtM = rawMtMUp - rawMtMDown;
    dv01(bucketIdx) = rawMtM * (0.0001 / (2*bump));
        
    bucketIdx = bucketIdx + 1;
end

end