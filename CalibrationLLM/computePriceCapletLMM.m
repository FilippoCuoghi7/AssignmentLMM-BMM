function P = computePriceCapletLMM(df1, df2, deltaT, T1, strike, sigma)
%COMPUTEPRICECAPLETLMM Computes the price of a Caplet using Black-76 formula under LMM.
%
%   INPUTS:
%       df1    : Discount factor to the fixing date P(0, T1).
%       df2    : Discount factor to the payment date P(0, T2).
%       deltaT : The accrual fraction between T1 and T2.
%       T1     : Time to expiry in years.
%       strike : The strike rate (K). (scalar/vector)
%       sigma  : Black implied volatility. (scalar/vector)
%
%   OUTPUTS:
%       P      : Present value of the caplet(s).

% Calculate the Forward Libor Rate (L)
L = (df1 ./ df2 - 1) ./ deltaT;

% Scalar Expansion (allows vectorized strikes/vols)
N = max([length(L), length(T1), length(strike), length(sigma)]);

% Expand scalars to vectors of length N
if isscalar(strike), strike = strike * ones(N, 1); end
if isscalar(sigma),  sigma  = sigma  * ones(N, 1); end
if isscalar(T1),     T1     = T1     * ones(N, 1); end

P = zeros(N,1);

% Safety Check: Only price valid options
idxBlack = (T1 > 0) & (sigma > 0) & (L > 0) & (strike > 0);

% Compute Black's formula ONLY on valid indices
if any(idxBlack)
    stdDev = sigma(idxBlack) .* sqrt(T1(idxBlack)); 

    d1 = (log(L(idxBlack) ./ strike(idxBlack)) + 0.5 .* stdDev.^2) ./ stdDev; 
    d2 = d1 - stdDev;

    % Final price computation for the active subset
    P(idxBlack) = deltaT(idxBlack) .* df2(idxBlack) .* ...
        (L(idxBlack) .* normcdf(d1) - strike(idxBlack) .* normcdf(d2));
end

% Intrinsic Value Fallback (Expired/Zero-vol options)
idxIntrinsic = ~idxBlack;
if any(idxIntrinsic)
    P(idxIntrinsic) = df2(idxIntrinsic) .* deltaT(idxIntrinsic) .* ...
                      max(L(idxIntrinsic) - strike(idxIntrinsic), 0);
end
end