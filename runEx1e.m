function [Notionals_Exact, Sigma_Swaps] = runEx1e(market, contract, curveDatesSet, curveRatesSet, fullCapletVolsLMM, upfrontPct)
% RUNEX1E_DELTAHEDGE Encapsulates the setup and execution of the coarse-grained Delta hedge.
%
%   This wrapper function prepares the required pricing arrays and market maturities,
%   builds the hedging swap instruments, loops through the three macro-buckets (2y, 6y, 10y)
%   to compute the DV01 sensitivities, and solves the lower-triangular hedging system.
%
%   INPUTS:
%       market            : Struct containing the base bootstrapped market curve
%                           (.dates, .discounts) and the strike grid (.strikes).
%       contract          : Struct containing the structured bond term sheet
%                           parameters.
%       curveDatesSet     : Struct containing the original dates for the calibration
%                           instruments.
%       curveRatesSet     : Struct containing the original, unbumped market quotes.
%       fullCapletVolsLMM : Matrix of calibrated LMM spot volatilities mapped to the grid.
%       upfrontPct        : The fair upfront payment (in decimal) calculated at inception.
%
%   OUTPUTS:
%       Notionals         : A 3x1 column vector containing the required Notional amounts
%                           (in EUR) to buy/sell for the 2y, 6y, and 10y swaps respectively
%                           to completely Delta-hedge the structured bond.
%       Sigma_Swaps       : A 3x3 lower-triangular matrix containing the DV01 sensitivities
%                           of the 3 hedging swaps to the 3 macro-buckets.

% Setup the pre-requisite arrays for the Bond Pricer
[paymentDates, ~] = computePaymentDates(contract.startDate, contract.endDate, contract.numPaymentsYear, 'modifiedfollowing');
datesT1 = [contract.startDate; paymentDates(1:end-1)];
datesT2 = paymentDates;
yearsT1 = yearfrac(contract.startDate, datesT1, 3);
deltaT  = yearfrac(datesT1, datesT2, 2);
[S, K, C] = computeParameters(contract.startDate, paymentDates, contract.rules, contract.numPaymentsYear);

% Setup Constant LMM Spot Volatilities
numPeriods = length(paymentDates);
sigmaLMM = zeros(numPeriods, 1);
strikesGrid = market.strikes;

if strikesGrid(1) >= 1.0
    strikesGrid = strikesGrid / 100;
end

for i = 2:numPeriods
    rowLMM = i - 1;
    sigmaLMM(i) = interp1(strikesGrid, fullCapletVolsLMM(rowLMM, :), K(i), 'spline', 'extrap');
end

% Calculate the exact market maturities
t_depos   = yearfrac(curveDatesSet.settlement, curveDatesSet.depos(1:3), 2);
t_futures = yearfrac(curveDatesSet.settlement, curveDatesSet.futures(1:7, 2), 2);
t_swaps   = yearfrac(curveDatesSet.settlement, curveDatesSet.swaps(2:end), 6);
marketMaturities = [t_depos; t_futures; t_swaps];

% Build the 3 Hedging Swaps on the Base Curve
swap2y  = buildStandardSwap(2,  curveDatesSet.settlement, market.dates, market.discounts);
swap6y  = buildStandardSwap(6,  curveDatesSet.settlement, market.dates, market.discounts);
swap10y = buildStandardSwap(10, curveDatesSet.settlement, market.dates, market.discounts);

% Run the Coarse-Grained Sensitivities Engine
macroNodes = [2, 6, 10];
bumpMacro = 1e-4; % 1 bp shift

Sigma_Swaps = zeros(3, 3);
Sigma_Bond  = zeros(3, 1);

fprintf('\nComputing Coarse-Grained Sensitivities...\n');
for b = 1:3
    [dv01Bond, dv01S2, dv01S6, dv01S10] = computeMacroBucketSensitivities( ...
        b, macroNodes, marketMaturities, curveDatesSet, curveRatesSet, bumpMacro, ...
        swap2y, swap6y, swap10y, ...
        contract, upfrontPct, paymentDates, datesT1, datesT2, yearsT1, deltaT, S, K, C, sigmaLMM);

    Sigma_Bond(b) = dv01Bond;
    Sigma_Swaps(b, 1) = dv01S2;
    Sigma_Swaps(b, 2) = dv01S6;
    Sigma_Swaps(b, 3) = dv01S10;
end

% Solve the Hedging Portfolio

% Method A: Exact Linear System (Includes computational noise/cross-sensitivities)
Notionals_Exact = -Sigma_Swaps \ Sigma_Bond;

% Method B: (Forced) Upper Triangular System
Sigma_Swaps_Clean = triu(Sigma_Swaps);
Notionals_Approx  = -Sigma_Swaps_Clean \ Sigma_Bond;

% Calculate the difference
Differences = Notionals_Exact - Notionals_Approx;

% ---------------------------------------------------------
% Display Results in a Professional Table
% ---------------------------------------------------------
fprintf('\n--- Delta Hedging Portfolio Comparison ---\n');
fprintf('This compares the exact linear solve vs. the theoretical "waterfall" substitution.\n\n');

fprintf('%-12s | %-18s | %-18s | %-15s\n', 'Instrument', 'Exact Solve (EUR)', 'Triangular (EUR)', 'Difference');
fprintf('---------------------------------------------------------------------------\n');
fprintf('%-12s | %18.2f | %18.2f | %15.2f\n', '2y Swap', Notionals_Exact(1), Notionals_Approx(1), Differences(1));
fprintf('%-12s | %18.2f | %18.2f | %15.2f\n', '6y Swap', Notionals_Exact(2), Notionals_Approx(2), Differences(2));
fprintf('%-12s | %18.2f | %18.2f | %15.2f\n', '10y Swap', Notionals_Exact(3), Notionals_Approx(3), Differences(3));

disp(' ');
disp('Original Swap Sensitivity Matrix (Notice the tiny non-zero elements below diagonal):');
disp(Sigma_Swaps);
Notionals = -Sigma_Swaps \ Sigma_Bond;

% Display Results
fprintf('\n--- Delta Hedging Portfolio ---\n');
fprintf('Notional 2y Swap  : %15.2f EUR\n', Notionals(1));
fprintf('Notional 6y Swap  : %15.2f EUR\n', Notionals(2));
fprintf('Notional 10y Swap : %15.2f EUR\n', Notionals(3));

disp(' ');
disp('Swap Sensitivity Matrix (Sigma_Swaps):');
disp(Sigma_Swaps);

end