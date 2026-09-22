function [Notionals_Exact, Sigma_Caps] = runEx1f(market, contract, fullCapletVolsLMM, upfrontPct)
% RUNEX1F Encapsulates the setup and execution of the coarse-grained Vega hedge.
%
%   This wrapper function prepares the required hedging Caps, calculates their
%   unbumped base prices, loops through the two macro-volatility buckets (6y, 10y)
%   to compute the Vega sensitivities, and solves the upper-triangular hedging system.
%
%   INPUTS:
%       market            : Struct containing the base bootstrapped market data.
%       contract          : Struct containing the structured bond term sheet parameters.
%       curveDates        : Array of dates from the base bootstrapped yield curve.
%       curveDiscounts    : Array of discount factors corresponding to curveDates.
%       fullCapletVolsLMM : Matrix of calibrated LMM spot volatilities mapped to
%                           the market grid.
%       upfrontPct        : The fair upfront payment (in decimal) calculated at inception.
%
%   OUTPUTS:
%       Notionals_Exact   : A 2x1 column vector containing the exact required Notional
%                           amounts (in EUR) to buy/sell for the 6y and 10y Caps
%                           respectively to completely Vega-hedge the structured bond.
%       Sigma_Caps        : A 2x2 matrix containing the uncleaned Vega sensitivities
%                           of the 2 hedging Caps to the 2 macro-buckets (6y and 10y).

% Extract Variables from Market struct
curveDates = market.dates;
curveDiscounts = market.discounts;

% Build the Hedging Caps
numPaymentsYear = contract.numPaymentsYear;
startDate = contract.startDate;

cap6yInfo  = buildATMCap(6,  startDate, curveDates, curveDiscounts, numPaymentsYear);
cap10yInfo = buildATMCap(10, startDate, curveDates, curveDiscounts, numPaymentsYear);

% Compute Base Prices for the Caps
marketStrikes = market.strikes;
basePriceCap6y  = computePriceCap(cap6yInfo,  curveDates, curveDiscounts, marketStrikes, fullCapletVolsLMM);
basePriceCap10y = computePriceCap(cap10yInfo, curveDates, curveDiscounts, marketStrikes, fullCapletVolsLMM);

% Run the Coarse-Grained Vega Sensitivities Engine
macroNodes = [6, 10];
bumpVega = 1e-4; % 1 bp volatility shift

Sigma_Caps = zeros(2, 2);
Sigma_Bond = zeros(2, 1);

fprintf('\nComputing Coarse-Grained Vega Sensitivities...\n');
for b = 1:2
    [vegaBond, vegaCap6, vegaCap10] = computeMacroBucketVegas( ...
        b, macroNodes, market, curveDates, curveDiscounts, bumpVega, ...
        cap6yInfo, cap10yInfo, basePriceCap6y, basePriceCap10y, ...
        contract, upfrontPct);

    Sigma_Bond(b) = vegaBond;
    Sigma_Caps(b, 1) = vegaCap6;
    Sigma_Caps(b, 2) = vegaCap10;
end

% Solve the Hedging Portfolio

% Method A: Exact Linear System (Includes computational noise)
Notionals_Exact = -Sigma_Caps \ Sigma_Bond;

% Method B: Forced Upper-Triangular (Approximation)
Sigma_Caps_Clean = triu(Sigma_Caps);
Notionals_Approx = -Sigma_Caps_Clean \ Sigma_Bond;

% Calculate the difference
Differences = Notionals_Exact - Notionals_Approx;

% ---------------------------------------------------------
% Display Results
% ---------------------------------------------------------
fprintf('\n--- Vega Hedging Portfolio Comparison ---\n');
fprintf('This compares the exact linear solve vs. the theoretical "waterfall" substitution.\n\n');

fprintf('%-12s | %-18s | %-18s | %-15s\n', 'Instrument', 'Exact Solve (EUR)', 'Triangular (EUR)', 'Difference');
fprintf('---------------------------------------------------------------------------\n');
fprintf('%-12s | %18.2f | %18.2f | %15.2f\n', '6y Cap', Notionals_Exact(1), Notionals_Approx(1), Differences(1));
fprintf('%-12s | %18.2f | %18.2f | %15.2f\n', '10y Cap', Notionals_Exact(2), Notionals_Approx(2), Differences(2));

disp(' ');
disp('Original Cap Sensitivity Matrix (Sigma_Caps):');
disp(Sigma_Caps);

end