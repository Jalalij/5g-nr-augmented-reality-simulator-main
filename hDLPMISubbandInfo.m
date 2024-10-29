function info = hDLPMISubbandInfo(carrier,reportConfig)
% hDLPMISubbandInfo Downlink PMI subband information
%   INFO = hDLPMISubbandInfo(CARRIER,REPORTCONFIG) returns the PMI subband
%   information or the PRG information INFO considering the carrier
%   configuration CARRIER and CSI report configuration structure
%   REPORTCONFIG.

%   Copyright 2022 The MathWorks, Inc.

    nSizeBWP = reportConfig.NSizeBWP;
    if isempty(nSizeBWP)
        nSizeBWP = carrier.NSizeGrid;
    end
    nStartBWP = reportConfig.NStartBWP;
    if isempty(nStartBWP)
        nStartBWP = carrier.NStartGrid;
    end

    % If PRGSize is present, consider the subband size as PRG size
    if isfield(reportConfig,'PRGSize') && ~isempty(reportConfig.PRGSize)
        reportingMode = 'Subband';
        NSBPRB = reportConfig.PRGSize;
        ignoreBWPSize = true; 
    else
        reportingMode = reportConfig.PMIMode;
        NSBPRB = reportConfig.SubbandSize;
        ignoreBWPSize = false; 
    end

    % Get the subband information
    if strcmpi(reportingMode,'Wideband') || (~ignoreBWPSize && nSizeBWP < 24)
        % According to TS 38.214 Table 5.2.1.4-2, if the size of BWP is
        % less than 24 PRBs, the division of BWP into subbands is not
        % applicable. In this case, the number of subbands is considered as
        % 1 and the subband size is considered as the size of BWP
        numSubbands = 1;
        NSBPRB = nSizeBWP;
        subbandSizes = NSBPRB;
    else
        % Calculate the size of first subband
        firstSubbandSize = NSBPRB - mod(nStartBWP,NSBPRB);

        % Calculate the size of last subband
        if mod(nStartBWP + nSizeBWP,NSBPRB) ~= 0
            lastSubbandSize = mod(nStartBWP + nSizeBWP,NSBPRB);
        else
            lastSubbandSize = NSBPRB;
        end

        % Calculate the number of subbands
        numSubbands = (nSizeBWP - (firstSubbandSize + lastSubbandSize))/NSBPRB + 2;

        % Form a vector with each element representing the size of a subband
        subbandSizes = NSBPRB*ones(1,numSubbands);
        subbandSizes(1) = firstSubbandSize;
        subbandSizes(end) = lastSubbandSize;
    end

    % Place the number of subbands and subband sizes in the output
    % structure
    info.NumSubbands = numSubbands;
    info.SubbandSizes = subbandSizes;
    info.SubbandSet = quantiz(nStartBWP + (0:nSizeBWP-1),nStartBWP + [0 cumsum(subbandSizes)]-0.5);
end