function [priceErrorsBMM, marketCapPrices, modelCapPricesBMM, spotVolGrid, fullCapletVols] = runCalibrationBMM(market)
%RUNCALIBRATIONBMM Calibrates BMM spot volatilities to market flat caps.
%   Uses a piecewise-constant volatility assumption and linear interpolation
%   between cap maturity pillars to bootstrap a spot volatility grid.
%
%   INPUT:
%       market : A structure containing the market data with the following fields:
%                - dates      : Array of dates for the discount curve (first element is RefDate).
%                - discounts  : Array of discount factors corresponding to market.dates.
%                - maturities : Column vector of cap maturities in years.
%                - strikes    : Column vector of cap strikes in percentage.
%                - vols       : Matrix of market flat volatilities in percentage.
%                               Rows = maturities, Columns = strikes.
%
%   OUTPUTS:
%       priceErrors       : [numMaturities x numStrikes] matrix of pricing errors
%                         (Market Price - Model Price).
%       marketCapPrices   : [numMaturities x numStrikes] matrix of target Cap prices
%                         computed using the market flat volatilities.
%       modelCapPricesBMM : [numMaturities x numStrikes] matrix of Cap prices
%                         computed using the newly calibrated BMM spot volatilities.
%       spotVolGrid       : [numMaturities x numStrikes] matrix containing the
%                         calibrated spot volatilities at the exact maturity pillars.

% Start Date is the RefDate of the bootstrap
startDate = market.dates(1);

% Extract and format market data (convert % to decimals)
capMaturities = market.maturities(:);
strikes       = market.strikes(:) / 100;
flatVols      = market.vols / 100;
dates         = market.dates;
discounts     = market.discounts;

numMaturities = length(capMaturities);
numStrikes    = length(strikes);

% Build the Global 20-Year Schedule
% (the max maturity is the last element in capMaturities (20 years))
endDate = startDate + calyears(max(capMaturities));

% Generate Payment Dates (T2) using Modified Following
[payment_dates_T2, ~] = computePaymentDates(startDate, endDate, 4, 'modifiedfollowing');

% Generate Fixing Dates (T1)
fixing_dates_T1 = [startDate; payment_dates_T2(1:end-1)];

% Calculate Time Fractions
all_T1s     = yearfrac(startDate, fixing_dates_T1, 3);      % Act/365 for Vol
all_deltaTs = yearfrac(fixing_dates_T1, payment_dates_T2, 2); % Act/360 for Euribor

% Pre-calculate all discount factors for the entire schedule
all_df1s = getDiscountFactorByZeroRatesLinearInterp(startDate, fixing_dates_T1, dates, discounts);
all_df2s = getDiscountFactorByZeroRatesLinearInterp(startDate, payment_dates_T2, dates, discounts);

% Exclude the T=0 caplet
futureIdx = all_T1s > 0;
all_T1s = all_T1s(futureIdx);
all_deltaTs = all_deltaTs(futureIdx);
all_df1s = all_df1s(futureIdx);
all_df2s = all_df2s(futureIdx);

matIdx = zeros(numMaturities, 1);
for k = 1:numMaturities
    % A Cap of T years includes caplets fixing strictly before T years.
    matIdx(k) = find(all_T1s < capMaturities(k), 1, 'last');
end

% BMM needs microscopic precision.
options = optimset('Display', 'off', 'TolX', 1e-12, 'TolFun', 1e-12);

% Use arrayfun to bootstrap each strike column independently
volCells = arrayfun(@(j) bootstrapSingleStrikeBMM(j, strikes, flatVols, ...
    numMaturities, all_T1s, all_df1s, all_df2s, all_deltaTs, matIdx, options), ...
    1:numStrikes, 'UniformOutput', false);

% volCells is a cell array of column vectors. We concatenate them horizontally
% to rebuild the 80x13 output matrix.
fullCapletVols = horzcat(volCells{:});

[priceErrorsBMM, marketCapPrices, modelCapPricesBMM] = ComparePricesBMM(flatVols, numStrikes, ...
    numMaturities, all_T1s, all_df1s, ...
    all_df2s, all_deltaTs, matIdx, strikes, fullCapletVols);

% Extract ONLY the 13x13 maturity pillars --> same grid of Flat Vols.
spotVolGrid = fullCapletVols(matIdx, :);

end