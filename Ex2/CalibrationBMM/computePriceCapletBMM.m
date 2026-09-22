function P = computePriceCapletBMM(df1, df2, deltaT, T1, strike, nu)
%COMPUTEPRICECAPLETBMM Computes the price of a Caplet under the Bond Market Model (BMM).
%   Under BMM, a caplet is priced as a put option on a Zero Coupon Bond.
%
%   INPUTS:
%       df1    : Discount factor to the fixing date P(0, T1).
%       df2    : Discount factor to the payment date P(0, T2).
%       deltaT : The accrual fraction between T1 and T2.
%       T1     : Time to expiry in years.
%       strike : The strike rate (K). (scalar/vector)
%       nu     : BMM spot volatility. (scalar/vector)
%
%   OUTPUTS:
%       P      : Present value of the caplet(s) under BMM.

% Calculate the Forward Libor Rate (L)
L = (df1 ./ df2 - 1) ./ deltaT;

% Scalar Expansion
N = max([length(L), length(T1), length(strike), length(nu)]);
if isscalar(strike), strike = strike * ones(N, 1); end
if isscalar(nu),     nu     = nu     * ones(N, 1); end
if isscalar(T1),     T1     = T1     * ones(N, 1); end

P = zeros(N, 1);

% Safety Check: Only price valid options
idxBMM = (T1 > 0) & (nu > 0) & (L > 0) & (strike > 0);

% Compute BMM formula only on valid indices
if any(idxBMM)
    stdDev = nu(idxBMM) .* sqrt(T1(idxBMM));

    % BMM's d1 and d2
    numerator   = 1 + deltaT(idxBMM) .* L(idxBMM);
    denominator = 1 + deltaT(idxBMM) .* strike(idxBMM);

    d1 = (log(numerator ./ denominator) ./ stdDev) + 0.5 .* stdDev;
    d2 = d1 - stdDev;

    % ZCB put logic
    P(idxBMM) = df2(idxBMM) .* (numerator .* normcdf(d1) - denominator .* normcdf(d2));
end

% Intrinsic Value Fallback (Expired/Zero-vol options)
idxIntrinsic = ~idxBMM;
if any(idxIntrinsic)
    
    P(idxIntrinsic) = df2(idxIntrinsic) .* deltaT(idxIntrinsic) .* ...
        max(L(idxIntrinsic) - strike(idxIntrinsic), 0);
end
end