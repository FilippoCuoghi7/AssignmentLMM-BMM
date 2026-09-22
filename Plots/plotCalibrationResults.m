function plotCalibrationResults(market, marketCapPrices, modelCapPrices, priceErrors, modelFlag)
%PLOTCALIBRATIONRESULTS Generates a 3-panel 3D surface plot comparing
% market cap prices, model cap prices, and the calibration error.
%
%   INPUTS:
%       market          : struct containing strikes (array of market strikes)
%                         and maturities (array of market maturities).
%       marketCapPrices : [numMaturities x numStrikes] matrix of market prices
%       modelCapPrices  : [numMaturities x numStrikes] matrix of model prices
%       priceErrors     : [numMaturities x numStrikes] matrix of pricing errors
%       modelFlag       : (Optional) 1 for LMM, 0 for BMM. Defaults to 1.

% Determine the model string based on the flag
if nargin < 5 || modelFlag == 1
    modelStr = 'LMM';
else
    modelStr = 'BMM';
end

strikes = market.strikes;
maturities = market.maturities;

% Prepare the X and Y grid for the 3D surface
[X, Y] = meshgrid(strikes, maturities);

% Hold the subplots side-by-side
figName = sprintf('%s Calibration Validation', modelStr);
figure('Name', figName, 'Position', [100, 200, 1400, 450], 'Color', 'w');

% --- PLOT 1: Market Prices ---
subplot(1, 3, 1);
surf(X, Y, marketCapPrices, 'FaceColor', '#0072BD', 'FaceAlpha', 0.8, 'EdgeColor', '#444444');
title('Market Cap Prices (Target)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Strike (%)', 'FontWeight', 'bold');
ylabel('Maturity (Years)', 'FontWeight', 'bold');
zlabel('Cap Price', 'FontWeight', 'bold');
grid on;
view(-45, 30);

% --- PLOT 2: Model Prices ---
subplot(1, 3, 2);
surf(X, Y, modelCapPrices, 'FaceColor', '#D95319', 'FaceAlpha', 0.8, 'EdgeColor', '#444444');
title(sprintf('%s Cap Prices (Calibrated)', modelStr), 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Strike (%)', 'FontWeight', 'bold');
ylabel('Maturity (Years)', 'FontWeight', 'bold');
zlabel('Cap Price', 'FontWeight', 'bold');
grid on;
view(-45, 30);

% --- PLOT 3: Calibration Error ---
subplot(1, 3, 3);
surf(X, Y, priceErrors);
zlim([-1e-8, 1e-8]);
title(sprintf('%s Calibration Error (Market - Model)', modelStr), 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Strike (%)', 'FontWeight', 'bold');
ylabel('Maturity (Years)', 'FontWeight', 'bold');
zlabel('Error', 'FontWeight', 'bold');
colormap(jet);
colorbar;
grid on;
view(-45, 30);

% Add a main title over all the subplots
sgtitle(sprintf('%s Calibration Results', modelStr), 'FontSize', 14, 'FontWeight', 'bold');

end