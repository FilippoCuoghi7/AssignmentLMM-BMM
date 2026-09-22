function [S, K, C] = computeParameters(startDate, paymentDates, rules, numPaymentsYear)
% COMPUTEPARAMETERS Assigns spread/strike/cap to each payment from the
% structured-rules matrix, by nominal rule-year of each payment.
%
%   INPUTS:
%       startDate       : Contract start date (unused now; kept for
%                         interface compatibility with existing callers).
%       paymentDates    : [N x 1] Array of Party B payment dates.
%       rules           : [K x 5] matrix of [StartYear, EndYear, Spread, Strike, Cap].
%       numPaymentsYear : Number of payments per year.
%
%   OUTPUTS:
%       S, K, C         : [N x 1] Arrays of Spread, Strike, and Cap/Fallback.

num_periods = length(paymentDates);

% Nominal rule-year of each payment, from its position in the schedule
periodIdx = (1:num_periods)';
ruleYear = ceil(periodIdx / numPaymentsYear);

S = zeros(num_periods, 1);
K = zeros(num_periods, 1);
C = zeros(num_periods, 1);

for i = 1:size(rules, 1)
    start_yr = rules(i, 1);
    end_yr   = rules(i, 2);
    spread   = rules(i, 3);
    strike   = rules(i, 4);
    cap      = rules(i, 5);

    idx = (ruleYear > start_yr) & (ruleYear <= end_yr);

    idx(1) = false; % Protect first fixed coupon

    S(idx) = spread;
    K(idx) = strike;
    C(idx) = cap;
end
end