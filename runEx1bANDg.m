function [upfrontPct, upfrontEuro, upfrontCorrectedPct, upfrontCorrectedEuro] = runEx1bANDg(market, contract, fullCapletVolsLMM)
% RUNEX1BANDG Prices the structured bond and computes the required upfront payment.
%
%   This function calculates the present value of both legs of the structured
%   swap and solves for the fair upfront payment required by Party B to make
%   the initial mark-to-market zero. It computes two distinct pricing scenarios:
%   the pure theoretical Black-76 price, and the price adjusted for the
%   Volatility Smile (Digital Risk).
%
%   INPUTS:
%       market            : A struct containing general market data.
%                           Required fields:
%                           - .dates (discount factor dates)
%                           - .discounts (discount factors)
%                           - .strikes (market strike grid in percentage, e.g., 2.00)
%       contract          : A struct containing the bond's term sheet parameters.
%                           Required fields:
%                           - .startDate, .endDate
%                           - .numPaymentsYear (e.g., 4 for quarterly)
%                           - .spreadA (Party A floating spread)
%                           - .rules (payoff rules for computeParameters)
%                           - .firstCouponB (deterministic first period coupon)
%                           - .notional (the principal amount in Euros)
%       fullCapletVolsLMM : [N x M] matrix of discrete calibrated LMM spot
%                           volatilities. Rows correspond to forward rate
%                           reset periods, columns correspond to market.strikes.
%
%   OUTPUTS:
%       upfrontPct           : The fair upfront payment as a decimal percentage
%                              of the notional (Pure theoretical / Uncorrected).
%       upfrontEuro          : The fair upfront payment in currency/Euros
%                              (Pure theoretical / Uncorrected).
%       upfrontCorrectedPct  : The fair upfront payment as a decimal percentage,
%                              accounting for the Volatility Smile correction
%                              on the embedded digital options.
%       upfrontCorrectedEuro : The fair upfront payment in currency/Euros,
%                              accounting for the Volatility Smile correction.

% Generate Payment Schedule
[paymentDates, ~] = computePaymentDates(contract.startDate, contract.endDate, ...
    contract.numPaymentsYear, 'modifiedfollowing');

% Calculate Party A NPV
bpvA = computeBPVFloater(paymentDates, market.dates, market.discounts, contract.startDate);
dfEnd = getDiscountFactorByZeroRatesLinearInterp(market.dates(1), paymentDates(end), market.dates, market.discounts);
npvAPct = (1 - dfEnd) + (contract.spreadA * bpvA);

% Setup Arrays for Party B
datesT1 = [contract.startDate; paymentDates(1:end-1)];
datesT2 = paymentDates;

yearsT1 = yearfrac(contract.startDate, datesT1, 3); % Act/365 for Volatility
deltaT  = yearfrac(datesT1, datesT2, 2);            % Act/360 for Euribor accrual

df1s = getDiscountFactorByZeroRatesLinearInterp(market.dates(1), datesT1, market.dates, market.discounts);
df2s = getDiscountFactorByZeroRatesLinearInterp(market.dates(1), datesT2, market.dates, market.discounts);

% Extract Dynamic Parameters (Spread, Strike, Cap)
[S, K, C] = computeParameters(contract.startDate, paymentDates, contract.rules, contract.numPaymentsYear);

numPeriods = length(paymentDates);
sigmaLMM = zeros(numPeriods, 1);
smileCorrection = zeros(numPeriods, 1);

% Interpolate LMM Volatilities & Smile Correction
idx = 2:numPeriods;
rowIndices = (idx - 1)';

% Use arrayfun to pass each row index and each strike (K) into your custom function
[smileCorrection(idx), sigmaLMM(idx), ~] = arrayfun(...
    @(r, k) computeDigitalSmileCorrection(df1s(r+1), df2s(r+1), deltaT(r+1), yearsT1(r+1), k, ...
    market.strikes/100, fullCapletVolsLMM(r, :)), ...
    rowIndices, K(idx));

% Price Party B's Structured Coupons
forwardLibor = (df1s ./ df2s - 1) ./ deltaT;
pvFloat = (forwardLibor + S) .* deltaT .* df2s;

% Compute the embedded options
pvCaplet = computePriceCapletLMM(df1s, df2s, deltaT, yearsT1, K, sigmaLMM);
digitalAmount = (K + S) - C;

% Calculate both Digital variations
pvDigital = computePriceDigitalCapletLMM(df1s, df2s, deltaT, yearsT1, K, sigmaLMM);
pvDigitalCorrected = pvDigital - smileCorrection;

% Scale the digital prices
pvDigitalScaled = digitalAmount .* pvDigital;
pvDigitalScaledCorrected = digitalAmount .* pvDigitalCorrected;

% Combine the components for both legs
pvCoupons = pvFloat - pvCaplet - pvDigitalScaled;
pvCouponsCorrected = pvFloat - pvCaplet - pvDigitalScaledCorrected;

% Override the 1st period (coupon rate at 4%)
pvCoupons(1) = contract.firstCouponB * deltaT(1) * df2s(1);
pvCouponsCorrected(1) = contract.firstCouponB * deltaT(1) * df2s(1);

% Total NPV of Party B's coupons
npvBCouponsPct = sum(pvCoupons);
npvBCouponsCorrectedPct = sum(pvCouponsCorrected);

% Solve for Upfronts
upfrontPct = npvAPct - npvBCouponsPct;
upfrontEuro = upfrontPct * contract.notional;

upfrontCorrectedPct = npvAPct - npvBCouponsCorrectedPct;
upfrontCorrectedEuro = upfrontCorrectedPct * contract.notional;

% =========================================================================
% GENERATE CONSOLE REPORT
% =========================================================================

% Calculate differences for the report
diffPct = (upfrontCorrectedPct - upfrontPct) * 100;
diffEuro = upfrontCorrectedEuro - upfrontEuro;

fprintf('\n');
fprintf('============================================================\n');
fprintf(' Exercise 1b & 1g - Fair Upfront & Digital Smile Risk\n');
fprintf('============================================================\n');
fprintf('Contract Notional      : %.2f EUR\n', contract.notional);
fprintf('NPV Party A            : %.6f EUR\n', npvAPct * contract.notional);
fprintf('------------------------------------------------------------\n');
fprintf(' [Theoretical / Uncorrected Black-76]\n');
fprintf('NPV Party B (Coupons)  : %.6f EUR\n', npvBCouponsPct * contract.notional);
fprintf('Fair Upfront Uncorr.   : %.6f%%\n', upfrontPct * 100);
fprintf('Upfront Amount Uncorr. : %.2f EUR\n', upfrontEuro);
fprintf('------------------------------------------------------------\n');
fprintf(' [Smile Corrected / Digital Risk Included]\n');
fprintf('NPV Party B (Coupons)  : %.6f EUR\n', npvBCouponsCorrectedPct * contract.notional);
fprintf('Fair Upfront Corr.     : %.6f%%\n', upfrontCorrectedPct * 100);
fprintf('Upfront Amount Corr.   : %.2f EUR\n', upfrontCorrectedEuro);
fprintf('------------------------------------------------------------\n');
fprintf(' [Impact of Volatility Skew]\n');
fprintf('Difference in Upfront  : %+.6f%% (%+.2f bps)\n', diffPct, diffPct * 100);
fprintf('Difference in Amount   : %+.2f EUR\n', diffEuro);
fprintf('============================================================\n\n');

end