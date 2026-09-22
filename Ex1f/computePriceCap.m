function price = computePriceCap(capInfo, curveDates, curveDiscounts, marketStrikes, fullCapletVolsLMM)
% COMPUTEPRICECAP Prices an Interest Rate Cap given LMM spot volatilities.
%
%   This function calculates the present value of a standard Cap by evaluating
%   all of its constituent caplets and summing their prices. It automatically
%   handles the volatility smile interpolation for the Cap's constant ATM strike.
%
%   INPUTS:
%       capInfo           : Struct containing the Cap schedule and ATM strike.
%       curveDates        : Base yield curve dates for discounting.
%       curveDiscounts    : Base yield curve discounts for discounting.
%       marketStrikes     : The vector of market strikes.
%       fullCapletVolsLMM : Matrix of calibrated LMM caplet volatilities.
%
%   OUTPUTS:
%       price             : The Total Net Present Value (MtM) of the Cap.

% Extract the Valuation Date (Start Date)
valDate = capInfo.datesT1(1);

% Interpolate the Discount Factors for all periods
df1 = getDiscountFactorByZeroRatesLinearInterp(valDate, capInfo.datesT1, curveDates, curveDiscounts);
df2 = getDiscountFactorByZeroRatesLinearInterp(valDate, capInfo.datesT2, curveDates, curveDiscounts);

% Ensure column vectors
df1 = df1(:);
df2 = df2(:);

% Extract the ATM Strike
strikeATM = capInfo.strike;

% Ensure market strikes are in decimals for interpolation
if marketStrikes(1) >= 1.0
    marketStrikes = marketStrikes / 100;
end

% Map the Volatilities to the Caplets
numCaplets = length(capInfo.paymentDates);
sigmaLMM = zeros(numCaplets, 1);

% Note: We skip the first period (i=1).
for i = 2:numCaplets
    rowLMM = i - 1;
    sigmaLMM(i) = interp1(marketStrikes, fullCapletVolsLMM(rowLMM, :), strikeATM, 'spline', 'extrap');
end

% Price all Caplets simultaneously
capletPrices = computePriceCapletLMM(df1, df2, capInfo.deltaT, capInfo.yearsT1, strikeATM, sigmaLMM);

% The Cap price is the sum of the caplets (we computed already the prices
% at t0, so we already discounted)
price = sum(capletPrices);

end