function vega = computeCapletVega(df1, df2, deltaT, T1, strike, sigma)
% COMPUTECAPLETVEGA Computes the analytical Black Vega of a caplet.
%
%   The function calculates the sensitivity of the caplet price with respect
%   to the implied volatility (Vega) using the Black-76 model.
%
%   Formula:
%   Vega = B(0, T2) * deltaT * L * sqrt(T1) * phi(d1), phi = pdf of a N(0,1).
%
%   INPUTS:
%       df1    : Discount factor to the fixing date B(0, T1).
%       df2    : Discount factor to the payment date B(0, T2).
%       deltaT : The accrual fraction between T1 and T2.
%       T1     : Time to expiry in years.
%       strike : The strike rate (K) of the caplet.
%       sigma  : Black implied volatility (spot volatility).
%
%   OUTPUTS:
%       vega   : The analytical Vega of the caplet, representing the change
%                in price for a 100% change in volatility (1 unit of sigma).

% Calculate the Forward Libor Rate (L) using no-arbitrage ratio
L = (df1 ./ df2 - 1) ./ deltaT;

% Initialize output vector
vega = zeros(size(L));

% Safety Check: Only compute for options with valid numerical inputs
idx = (T1 > 0) & (sigma > 0) & (L > 0) & (strike > 0);

if any(idx)
    % Calculate d1 parameter for the Black formula
    stdDev = sigma(idx) .* sqrt(T1(idx));
    d1 = (log(L(idx) ./ strike(idx)) + 0.5 .* stdDev.^2) ./ stdDev;

    % Calculate Vega:
    % normpdf(d1) provides the standard normal probability density n(d1)
    vega(idx) = df2(idx) .* deltaT(idx) .* L(idx) .* sqrt(T1(idx)) .* normpdf(d1);
end
end