function [volAtK, slope] = computeVolSlopeLMM(marketStrikes, volSurfaceRow, K)
% COMPUTEVOLSLOPELMM Calculates the volatility and its numerical derivative (skew)
% with respect to the strike price for a specific LMM caplet.
%
% INPUTS:
%   marketStrikes : Row vector of market strike grid.
%   volSurfaceRow : Row vector of calibrated LMM spot vols for the specific caplet.
%   K             : The evaluation strike where we want the volatility and slope.
%
% OUTPUTS:
%   volAtK        : The interpolated spot volatility exactly at K.
%   slope         : The numerical derivative (dSigma/dK) evaluated at K.

% Define a tiny shift (1 bp) for the numerical derivative
epsilon = 0.0001;

% Interpolate the volatility exactly at K, slightly above, and slightly below
% We use 'spline' as requested by the assignment hint
volAtK  = spline(marketStrikes, volSurfaceRow, K);
volUp   = spline(marketStrikes, volSurfaceRow, K + epsilon);
volDown = spline(marketStrikes, volSurfaceRow, K - epsilon);

% Compute the precise central difference derivative
slope = (volUp - volDown) / (2 * epsilon);

end