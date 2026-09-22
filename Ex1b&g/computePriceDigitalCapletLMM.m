function P = computePriceDigitalCapletLMM(df1, df2, deltaT, T1, strike, sigma)
%COMPUTEPRICEDIGITALCAPLETLMM Computes the price of a Digital Caplet under LMM.
%   Pays exactly 'deltaT' at T2 if the fixing rate L(T1) > strike.
%
%   INPUTS:
%       df1    : Discount factor to the fixing date P(0, T1).
%       df2    : Discount factor to the payment date P(0, T2).
%       deltaT : The accrual fraction between T1 and T2.
%       T1     : Time to expiry in years.
%       strike : The strike rate (K).
%       sigma  : Black implied volatility.
%
%   OUTPUTS:
%       P      : Present value of the digital caplet(s).

% Calculate the Forward Libor Rate (L)
L = (df1 ./ df2 - 1) ./ deltaT;

% Scalar Expansion
N = max([length(L), length(T1), length(strike), length(sigma)]);
if isscalar(strike), strike = strike * ones(N, 1); end
if isscalar(sigma),  sigma  = sigma  * ones(N, 1); end
if isscalar(T1),     T1     = T1     * ones(N, 1); end
if isscalar(deltaT), deltaT = deltaT * ones(N, 1); end

P = zeros(N,1);

% Safety Check: Only price valid stochastic options
idxBlack = (T1 > 0) & (sigma > 0) & (L > 0) & (strike > 0);

% Compute Black's Digital formula ONLY on valid indices
if any(idxBlack)
    stdDev = sigma(idxBlack) .* sqrt(T1(idxBlack));
    d2 = (log(L(idxBlack) ./ strike(idxBlack)) - 0.5 .* stdDev.^2) ./ stdDev;

    % Digital payoff: deltaT * df2 * N(d2)
    P(idxBlack) = deltaT(idxBlack) .* df2(idxBlack) .* normcdf(d2);
end

% Intrinsic Value Fallback (Expired/Zero-vol options)
idxIntrinsic = ~idxBlack;
if any(idxIntrinsic)
    % If deterministic, it pays deltaT exactly if L > K
    is_triggered = (L(idxIntrinsic) > strike(idxIntrinsic));
    P(idxIntrinsic) = df2(idxIntrinsic) .* deltaT(idxIntrinsic) .* is_triggered;
end
end