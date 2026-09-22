function capInfo = buildATMCap(maturityYears, startDate, baseDates, baseDiscounts, numPaymentsYear)
% BUILDATMCAP Creates a standard ATM Cap for Vega hedging purposes.
%
%   This function generates the exact schedule for an Interest Rate Cap and
%   calculates its At-The-Money (ATM) strike. By standard market convention,
%   the ATM strike of a Cap is a single fixed rate applied to all caplets,
%   equal to the forward swap rate corresponding to the Cap's payment frequency.
%
%   INPUTS:
%       maturityYears   : Scalar representing the maturity of the Cap in years.
%       startDate       : The valuation/start date of the Cap as a datetime object.
%       baseDates       : Array of dates from the bootstrapped base yield curve.
%       baseDiscounts   : Array of discount factors corresponding to baseDates.
%       numPaymentsYear : Integer indicating the number of payments per year.
%
%   OUTPUTS:
%       capInfo         : A struct containing the generated characteristics of the Cap:
%                         - .type          : String identifier ('Cap').
%                         - .maturityYears : The maturity in years.
%                         - .paymentDates  : Array of payment dates.
%                         - .datesT1       : Array of accrual start dates.
%                         - .datesT2       : Array of accrual end dates.
%                         - .yearsT1       : Option expiry times (Act/365) for LMM.
%                         - .deltaT        : Accrual fractions (Act/360) for Libor.
%                         - .strike        : The calculated ATM forward swap rate.

% Generate the payment schedule
convention = 'modifiedfollowing';
endDate = businessDateOffsetTarget(startDate, maturityYears, 0, 0, convention);
[paymentDates, ~] = computePaymentDates(startDate, endDate, numPaymentsYear, convention);
paymentDates = paymentDates(:);

% Setup Accrual Dates and Year Fractions
datesT1 = [startDate; paymentDates(1:end-1)];
datesT2 = paymentDates;
deltaT = yearfrac(datesT1, datesT2, 2);
yearsT1 = yearfrac(startDate, datesT1, 3);

% Interpolate the end-of-period Discount Factors
df2 = getDiscountFactorByZeroRatesLinearInterp(startDate, datesT2, baseDates, baseDiscounts);
df2 = df2(:);

% Calculate the ATM Strike (The Forward Swap Rate of the spot-starting Cap)
numerator = 1 - df2(end);
denominator = sum(deltaT .* df2);
strikeATM = numerator / denominator;

% Build the Output Struct
capInfo.type = 'Cap';
capInfo.maturityYears = maturityYears;
capInfo.paymentDates = paymentDates;
capInfo.datesT1 = datesT1;
capInfo.datesT2 = datesT2;
capInfo.yearsT1 = yearsT1;
capInfo.deltaT = deltaT;
capInfo.strike = strikeATM;

end