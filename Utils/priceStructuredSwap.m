function MkM = priceStructuredSwap(curveDates, curveDiscounts, contract, UpfrontPct, ...
    paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigma)
% PRICESTRUCTUREDSWAP Core Mark-to-Market pricer for the structured swap,
% given an already-bootstrapped curve and a per-period volatility vector.
%
%   This is the single shared coupon-pricing routine used by both the
%   Delta (curve-bump) and Vega (vol-bump) sensitivity functions, and by
%   the base-case pricer, so the coupon formula lives in exactly one
%   place instead of being duplicated across all of them.
%
%   INPUTS:
%       curveDates, curveDiscounts : Bootstrapped discount curve.
%       contract        : Struct containing the bond's term sheet parameters
%                         (.startDate, .spreadA, .firstCouponB, .notional).
%       UpfrontPct      : The fair upfront payment calculated at inception
%                         (decimal percentage), held fixed.
%       paymentDates    : [N x 1] Array of Party B payment dates.
%       datesT1         : [N x 1] Array of accrual start dates.
%       datesT2         : [N x 1] Array of accrual end dates.
%       yearsT1         : [N x 1] Array of reset times (Act/365) for option pricing.
%       deltaT          : [N x 1] Array of accrual fractions (Act/360) for Libor.
%       S, K, C         : [N x 1] Arrays for Spread, Strike, and Cap/Fallback.
%       sigma           : [N x 1] Array of per-period volatilities to price
%                         the embedded options with.
%
%   OUTPUT:
%       MkM             : The Mark-to-Market value of the structured swap,
%                         in EUR.

% Party A leg (floating + protection payment) — unaffected by volatility
bpvA = computeBPVFloater(paymentDates, curveDates, curveDiscounts, contract.startDate);
dfEnd = getDiscountFactorByZeroRatesLinearInterp(curveDates(1), paymentDates(end), curveDates, curveDiscounts);
npvAPct = (1 - dfEnd) + (contract.spreadA * bpvA);

% Party B coupons
df1s = getDiscountFactorByZeroRatesLinearInterp(curveDates(1), datesT1, curveDates, curveDiscounts);
df2s = getDiscountFactorByZeroRatesLinearInterp(curveDates(1), datesT2, curveDates, curveDiscounts);

forwardLibor = (df1s ./ df2s - 1) ./ deltaT;
pvFloat = (forwardLibor + S) .* deltaT .* df2s;

pvCaplet = computePriceCapletLMM(df1s, df2s, deltaT, yearsT1, K, sigma);
pvDigital = computePriceDigitalCapletLMM(df1s, df2s, deltaT, yearsT1, K, sigma);

digitalAmount = (K + S) - C;
pvDigitalScaled = digitalAmount .* pvDigital;

pvCoupons = pvFloat - pvCaplet - pvDigitalScaled;

% Override the 1st period (deterministic coupon, no volatility risk)
pvCoupons(1) = contract.firstCouponB * deltaT(1) * df2s(1);

npvBCouponsPct = sum(pvCoupons);

% Mark-to-Market of the swap (base-case value is zero at inception by construction)
MkM = -(npvBCouponsPct + UpfrontPct - npvAPct) * contract.notional;

end
