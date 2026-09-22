function MkM = computeMkmGivenCurve(curveDates, curveDiscounts, contract, UpfrontPct, ...
    paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigmaLMM)
% COMPUTEMKMGIVENCURVE Calculates the MtM of the structured swap given a pre-bootstrapped curve.
%
%   Unlike computeMkmBumpedPrice, this function does NOT perform a bootstrap.
%   It is highly optimized to receive an already-bootstrapped curve (dates and discounts)
%   and compute the exact Mark-to-Market value using the standard Black-76 digital
%   option price, ignoring volatility skew.
%
%   INPUTS:
%       curveDates      : Array of dates from a bootstrapped yield curve.
%       curveDiscounts  : Array of discount factors corresponding to curveDates.
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
%       MkM             : The Mark-to-Market value of the structured swap in Euros.

MkM = priceStructuredSwap(curveDates, curveDiscounts, contract, UpfrontPct, ...
    paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigmaLMM);

end