function ssbIndex = computeSSBToUE(simParameters,ssbTxAngles,ssbSweepRange,ueRelPosition)
%   SSBINDEX = computeSSBtoUE(SIMPARAMETERS,SSBTXANGLES,SSBSWEEPRANGE,UERELPOSITION)
%   computes an SSB to UE based on SSBTXANGLES and SSBSWEEPRANGE. If a UE
%   falls within the sweep range of an SSB then the corresponding SSBINDEX
%   is assigned. If a UE does not fall under any of the SSBs then the 
%   function approximates UE to its nearest SSB.
ssbIndex = zeros(1,simParameters.NumUEs);
for i=1:simParameters.NumUEs
    if (ueRelPosition(i,2) > (ssbTxAngles(1) - ssbSweepRange/2)) && ...
            (ueRelPosition(i,2) <= (ssbTxAngles(1) + ssbSweepRange/2))
        ssbIndex(i) = 1;
    elseif (ueRelPosition(i,2) > (ssbTxAngles(2) - ssbSweepRange/2)) && ...
            (ueRelPosition(i,2) <= (ssbTxAngles(2) + ssbSweepRange/2))
        ssbIndex(i) = 2;
    elseif (ueRelPosition(i,2) > (ssbTxAngles(3) - ssbSweepRange/2)) && ...
            (ueRelPosition(i,2) <= (ssbTxAngles(3) + ssbSweepRange/2))
        ssbIndex(i) = 3;
    elseif (ueRelPosition(i,2) > (ssbTxAngles(4) - ssbSweepRange/2)) && ...
            (ueRelPosition(i,2) <= (ssbTxAngles(4) + ssbSweepRange/2))
        ssbIndex(i) = 4;
    else % Approximate UE to the nearest SSB
        % Initialize an array to store the difference between the UE azimuth and
        % SSB azimuth beam sweep angles
        angleDiff = zeros(1,length(ssbTxAngles));
        for angleIdx = 1: length(ssbTxAngles)
            angleDiff(angleIdx) = abs(ssbTxAngles(angleIdx) - ueRelPosition(i,2));
        end
        % Minimum azimuth angle difference
        [~,idx] = min(angleDiff);
        ssbIndex(i) = idx;
    end
end