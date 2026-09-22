function [correction, sigma, vega] = computeDigitalSmileCorrection(df1, df2, ...
    deltaT, T1, K, marketStrikes, volSurfaceRow)
% COMPUTEDIGITALSMILECORRECTION Aggregates the Vega and Volatility Skew to
% compute the price correction for a digital option.
%
% INPUTS:
%   df1, df2, deltaT, T1, K : Standard caplet parameters.
%   marketStrikes           : The market strike grid (row vector).
%   volSurfaceRow           : The calibrated LMM spot vols for this specific period.
%
% OUTPUTS:
%   correction : The price adjustment to subtract from the standard digital price.
%   sigma      : The interpolated spot volatility at strike K.
%   vega       : The analytical Black Vega of the caplet.

% Get the volatility and the slope (skew) at strike K
[sigma, skew] = computeVolSlopeLMM(marketStrikes, volSurfaceRow, K);

% Calculate the caplet Vega
vega = computeCapletVega(df1, df2, deltaT, T1, K, sigma);

% Compute the correction term (Vega * dSigma/dK)
correction = vega .* skew;

end