% RunAssignment05
% AY2025-2026

clc; clear; close all
format long

projectRoot = fileparts(which('runAssignment05.m'));
addpath(genpath(projectRoot));

%% Bootstrap 
[curveDatesSet, curveRatesSet] = readExcelData('MktData_CurveBootstrap.xls', 'dd-mmm-yy');
[curveDates, curveDiscounts, curveZeroRates] = bootstrap(curveDatesSet, curveRatesSet);

% Market inputs
market = struct;
market.dates = curveDates;
market.discounts = curveDiscounts;
market.zeroRates = curveZeroRates;

%% Exercise 1

% a) Calibration of LLM spot vols 
market.vols = [14.0, 13.0, 12.9, 12.1, 13.3, 13.8, 14.4, 15.0, 17.2, 19.1, 20.2, 21.6, 23.9;
    22.4, 19.7, 17.5, 18.0, 19.2, 20.4, 21.0, 21.4, 22.3, 23.6, 24.9, 26.1, 28.1;
    23.8, 21.7, 20.0, 19.8, 20.3, 20.5, 20.8, 21.4, 22.9, 24.3, 25.6, 26.7, 28.2;
    24.2, 22.4, 20.9, 20.4, 20.4, 20.2, 20.2, 20.5, 21.7, 22.9, 24.0, 25.0, 26.6;
    24.3, 22.6, 21.2, 20.6, 20.4, 19.8, 19.5, 19.6, 20.5, 21.5, 22.6, 23.5, 25.0;
    24.3, 22.7, 21.4, 20.7, 20.2, 19.4, 18.9, 18.8, 19.3, 20.2, 21.2, 22.0, 23.5;
    24.1, 22.6, 21.4, 20.7, 20.1, 19.1, 18.4, 18.1, 18.4, 19.1, 20.0, 20.8, 22.2;
    23.9, 22.5, 21.4, 20.6, 20.0, 18.8, 18.0, 17.6, 17.6, 18.2, 19.0, 19.8, 21.1;
    23.7, 22.4, 21.3, 20.5, 19.8, 18.5, 17.6, 17.1, 17.0, 17.6, 18.3, 19.0, 20.3;
    23.5, 22.2, 21.2, 20.4, 19.6, 18.3, 17.3, 16.8, 16.5, 16.9, 17.6, 18.3, 19.5;
    23.0, 21.7, 20.8, 20.0, 19.3, 17.9, 16.9, 16.2, 15.8, 16.0, 16.5, 17.1, 18.1;
    22.3, 21.2, 20.3, 19.5, 18.7, 17.3, 16.3, 15.5, 15.0, 15.1, 15.5, 16.0, 16.9;
    21.6, 20.4, 19.5, 18.8, 18.0, 16.6, 15.5, 14.7, 14.1, 14.1, 14.5, 15.0, 15.9];
market.strikes = [1.5, 1.75, 2.00, 2.25, 2.5, 3.00, 3.50, 4.00, 5.00, 6.00, 7.00, 8.00, 10.00];
market.maturities = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20];

[priceErrorsLMM, marketCapPrices, modelCapPricesLMM, spotVolGridLMM, fullCapletVolsLMM] = runCalibrationLMM(market);

% Plot of the comparison between market prices and LMM calibrated model prices
plotCalibrationResults(market, marketCapPrices, modelCapPricesLMM, priceErrorsLMM, 1);

%%
% b) and g) Upfront of the Contract with Black Digital and Corrected Digital

% Contract inputs 
contract = struct();
contract.notional = 5e7;
contract.spreadA = 0.02;
contract.startDate = market.dates(1);
contract.endDate = contract.startDate + calyears(10);
contract.numPaymentsYear = 4;

contract.firstCouponB = 0.04; % 4.00% fixed for the first quarter
% Define the structured rules matrix for Party B
% Format: [Start_Year, End_Year, Spread, Strike, Cap]
contract.rules = [
    0.0,  3.0,  0.010,  0.042,  0.045;  % Up to Year 3
    3.0,  6.0,  0.012,  0.047,  0.049;  % Year 3 to Year 6
    6.0, 10.0,  0.013,  0.054,  0.056   % Year 6 to Year 10
];

[upfrontPct, upfrontEuro, upfrontCorrPct, upfrontCorrEuro] = runEx1bANDg(market, ...
    contract, fullCapletVolsLMM);

%% 
% c) Bucket DV01 
bumpDv01 = 1e-4; % +1 bp
dv01vec = computeBucketDV01(curveDatesSet, curveRatesSet, market, contract, ...
    fullCapletVolsLMM, upfrontPct, bumpDv01);

dv01 = sum(dv01vec);

% Cross-check: sum of bucket DV01s vs. a single full-curve parallel bump.
dv01Parallel = computeDV01Parallel(curveDatesSet, curveRatesSet, market, contract, ...
    fullCapletVolsLMM, upfrontPct, bumpDv01);

fprintf('\n--- DV01 Reconciliation: Bucket Sum vs. Parallel ---\n');
fprintf('Sum of Bucket DV01s : EUR %.4f\n', dv01);
fprintf('Parallel DV01       : EUR %.4f\n', dv01Parallel);
fprintf('Difference          : EUR %.4f (%.4f%% of parallel)\n', ...
    dv01 - dv01Parallel, 100 * (dv01 - dv01Parallel) / dv01Parallel);

% Plot the bucket sensitivities
figure;
bar(dv01vec);
title('Bucket DV01 Sensitivities');
xlabel('Market Instrument Bucket (Depos -> Futures -> Swaps)');
ylabel('Sensitivity (EUR per 1 bp shift)');
grid on;

%% 
% d) Total (Parallel) Vega
bumpVega = 1e-4; % +1 bp

% Compute Model Vega (bumping calibrated spot vols directly)
totalModelVegaEUR = computeTotalVega2(market, contract, fullCapletVolsLMM, ...
    upfrontPct, bumpVega);
fprintf('Total Model Vega (Scaled to 1%% shift)  : %.2f EUR\n', totalModelVegaEUR);

% Compute Market Vega (bumping flat vols & recalibrating)
totalMarketVegaEUR = computeTotalVega(market, contract, upfrontPct, bumpVega);
fprintf('Total Market Vega (Scaled to 1%% shift) : %.2f EUR\n', totalMarketVegaEUR);

%% 
% e) Coarse-Grained buckets and Delta hedging

[NotionalsDeltaHedge, Sigma_Swaps_DeltaHedge] = runEx1e(market, contract, curveDatesSet, ...
    curveRatesSet, fullCapletVolsLMM, upfrontPct);

%% 
% f) Vega hedging

[NotionalsVegaHedge, Sigma_Swaps_VegaHedge] = runEx1f(market, contract, fullCapletVolsLMM, ...
    upfrontPct);

%% Exercise 2

% Calibration of BMM spot vols
[priceErrorsBMM, ~, modelCapPricesBMM, spotVolGridBMM, ...
    fullCapletVolsBMM] = runCalibrationBMM(market);

% Plot of the comparison between market prices and BMM calibrated model prices
plotCalibrationResults(market, marketCapPrices, modelCapPricesBMM, priceErrorsBMM, 0);

% Pricing 
[v_ATM, L_chol, B_init, all_T1s, all_deltaTs, all_df1s, all_df2s, Rho] = MCSetUp(market, ...
    fullCapletVolsBMM);

rng(123);
N_paths = 10000;
dt = 1/12;
simLibors = MCSimulationBMM(N_paths, dt, all_T1s, all_deltaTs, v_ATM, L_chol, ...
    Rho, B_init); % simulation, spot/rolling measure

[percentagePrice, CI, stdErr] = priceExoticOption(simLibors, all_deltaTs);

fprintf('\n============================================================\n');
fprintf(' Exercise 2b - Exotic Cap under BMM (Spot Measure MC)\n');
fprintf('============================================================\n');
fprintf('N_paths                : %d\n', N_paths);
fprintf('Price                   : %.6f%%\n', percentagePrice*100);
fprintf('Standard Error          : %.6f%%\n', stdErr*100);
fprintf('95%% Confidence Interval : [%.6f%%, %.6f%%]\n', CI(1)*100, CI(2)*100);
fprintf('============================================================\n');



