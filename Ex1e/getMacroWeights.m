function weights = getMacroWeights(marketMaturities, macroNodes, bucketIndex)
% GETMACROWEIGHTS Calculates generalized Triangle Weights for Coarse-Grained DV01.
%
%   INPUTS:
%       marketMaturities : Vector of year fractions for all active instruments.
%       macroNodes       : Vector of the macro bucket peaks.
%       bucketIndex      : The index of the bucket being calculated.
%
%   OUTPUTS:
%       weights          : A vector of weights between 0 and 1.

% Ensure column vectors for proper matrix dimensions
t = marketMaturities(:);
weights = zeros(size(t));
numNodes = length(macroNodes);

if bucketIndex == 1
    % --- THE FIRST BUCKET ---
    t1 = macroNodes(1);
    t2 = macroNodes(2);

    weights(t <= t1) = 1.0;

    idx = (t > t1) & (t < t2);
    weights(idx) = (t2 - t(idx)) / (t2 - t1);

elseif bucketIndex == numNodes
    % --- THE LAST BUCKET ---
    t_prev = macroNodes(end-1);
    t_curr = macroNodes(end);

    idx = (t > t_prev) & (t < t_curr);
    weights(idx) = (t(idx) - t_prev) / (t_curr - t_prev);

    weights(t >= t_curr) = 1.0;

else
    % --- ANY MIDDLE BUCKET ---
    t_prev = macroNodes(bucketIndex - 1);
    t_curr = macroNodes(bucketIndex);
    t_next = macroNodes(bucketIndex + 1);

    % Ramp up
    idx_up = (t > t_prev) & (t <= t_curr);
    weights(idx_up) = (t(idx_up) - t_prev) / (t_curr - t_prev);

    % Ramp down
    idx_down = (t > t_curr) & (t < t_next);
    weights(idx_down) = (t_next - t(idx_down)) / (t_next - t_curr);
end
end