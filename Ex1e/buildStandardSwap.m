function swapInfo = buildStandardSwap(maturityYears, refDate, baseDates, baseDiscounts)
% BUILDSTANDARDSWAP Creates a standard par swap for hedging purposes.
%
%   INPUTS:
%       maturityYears : The maturity of the swap.
%       refDate       : The valuation date (t0) as a datetime object.
%       baseDates     : The dates array from your original bootstrap.
%       baseDiscounts : The discounts array from your original bootstrap.
%
%   OUTPUTS:
%       swapInfo      : A struct containing the swap's fixed characteristics
%                       (schedule, day-counts, and the locked-in par rate).

% Create the annual payment schedule for the Fixed Leg
% Convention for EUR Swap Fixed Leg is 1 payment a year
convention = 'modifiedfollowing';
refDate = datetime(refDate, 'ConvertFrom', 'datenum');
endDate = businessDateOffsetTarget(refDate, maturityYears, 0, 0, convention);
[paymentDates, ~] = computePaymentDates(refDate, endDate, 1, convention);

% Ensure paymentDates is a column vector
paymentDates = paymentDates(:);

% Calculate the year fractions (tau)
% Convention for EUR Swap Fixed Leg is 30/360 European
schedule = [refDate; paymentDates];
tau = yearfrac(schedule(1:end-1), schedule(2:end), 6);

% Interpolate the base discount factors for these payment dates
dfs = getDiscountFactorByZeroRatesLinearInterp(refDate, paymentDates, baseDates, baseDiscounts);

% Ensure dfs is a column vector
dfs = dfs(:);

% Calculate the base BPV (Basis Point Value) of the fixed leg
BPV = sum(tau .* dfs);

% Calculate the base Floating Leg NPV
floatNPV = 1 - dfs(end);

% Lock in the Par Swap Rate so initial NPV = 0
parRate = floatNPV / BPV;

% Build the swap struct
swapInfo.type = 'Swap';
swapInfo.maturityYears = maturityYears;
swapInfo.paymentDates = paymentDates;
swapInfo.tau = tau;
swapInfo.parRate = parRate;

end