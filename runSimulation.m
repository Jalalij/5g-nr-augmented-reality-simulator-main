function runSimulation(numUEs, numCells, numFramesSim, enableMIMO, schedulingStrategy, schedulingWeightParameter, trafficConfiguration, worker)

clear hNRIPLogger % this has to be there due to IP logger implementation
clear hNRPDCPEntity % this has to be there due to IP logger implementation

[numUEs, numCells, numFramesSim, enableMIMO, schedulingWeightParameter, worker] = convertInput(numUEs, numCells, numFramesSim, enableMIMO, schedulingWeightParameter, worker);

%% Simulator Configuration
rng(worker);
simParameters = []; % Clear the simParameters variable
simParameters.NumFramesSim = numFramesSim; % Simulation time in terms of number of 10 ms frames
simParameters.SchedulingType = 0; % Set the value to 0 (slot based scheduling) or 1 (symbol based scheduling)
simParameters.NumCells = numCells; % Number of cells
simParameters.NCellIDList = 0:simParameters.NumCells-1; % List of physical cell IDs
% Validate the number of cells
validateattributes(simParameters.NumCells, {'numeric'}, {'nonempty', 'integer', 'scalar', '>', 0, '<=', 1008}, 'simParameters.NumCells', 'NumCells');
simParameters.NumUEs = numUEs; % number of UEs per cell (per sector if cellType is sectorized)
validateattributes(simParameters.NumUEs, {'numeric'}, {'nonempty', 'integer', 'scalar','>', 0, '<=', 65519}, 'simParameters.NumUEs', 'NumUEs');
simParameters.MaxReceivers = simParameters.NumCells * (simParameters.NumUEs + 1); % Number of nodes

simParameters.LOSChannelModel = "CDL-D";
simParameters.NLOSChannelModel = "CDL-C";
pathlossconf = nrPathLossConfig; % values according to TR 38.901 Section 7.4.1
pathlossconf.Scenario = "UMa";

simParameters.ISD = 200; % inter-site-distance (in meters)
simParameters.CellType = "sectorized"; % sectorized or omnidirectional (if sectorized is chosen only one sector is simulated otherwise the whole cell)
if strcmp(simParameters.CellType, "sectorized")
    simParameters.SectorAzimuthAngle = [-60 60; 60 180; -180 -60]; % azimuth angle of each sector
else
    simParameters.CellRadius = 100; % Radius of each cell (in meters)
    % Validate the cell radius
    validateattributes(simParameters.CellRadius, {'numeric'}, {'nonempty', 'real', 'scalar', '>', 0, 'finite'}, 'simParameters.CellRadius', 'CellRadius');
end

simParameters.Scenario = pathlossconf.Scenario;

simParameters.NumRBs = 273;
simParameters.SCS = 30; % kHz
simParameters.DLCarrierFreq = 4e9; % Hz
simParameters.ULCarrierFreq = 4e9; % Hz
% The UL and DL carriers are assumed to have symmetric channel
% bandwidth
simParameters.DLBandwidth = 100e6; % Hz
simParameters.ULBandwidth = 100e6; % Hz

simParameters.UETxPower = 23; % Tx power for all the UEs in dBm
num20MHzChannels = simParameters.DLBandwidth/20e6;
simParameters.GNBAntennaGain = 8; %Antenna gain for gNB in dBi
simParameters.GNBTxPower = 10*log10(10^(44/10)*num20MHzChannels) + simParameters.GNBAntennaGain; % 44 dBm / 20 MHz
simParameters.GNBRxGain = simParameters.GNBAntennaGain; % Rx gain for gNB in dBi

% gnb position
simParameters.GNBPosition = generateGNBPositions(simParameters);
validateattributes(simParameters.GNBPosition, {'numeric'}, {'nonempty', 'real', 'nrows', simParameters.NumCells, 'ncols', 3, 'finite'}, 'simParameters.GNBPosition', 'GNBPosition');

% For each cell, create the set of UE nodes and place them randomly within the cell radius
[simParameters.UEPosition, simParameters.UEIndoorDistance, ueRelPosition] = generateUEPositions(simParameters);

simParameters.DuplexMode = 1; % FDD (0) or TDD (1)
simParameters.DLULPeriodicity = 2.5; % Duration of the DL-UL pattern in ms
simParameters.NumDLSlots = 3; % Number of consecutive full DL slots at the beginning of each DL-UL pattern
simParameters.NumDLSyms = 10; % Number of consecutive DL symbols in the beginning of the slot following the last full DL slot
simParameters.NumULSyms = 2; % Number of consecutive UL symbols in the end of the slot preceding the first full UL slot
simParameters.NumULSlots = 1; % Number of consecutive full UL slots at the end of each DL-UL pattern

simParameters.SchedulerStrategy = schedulingStrategy; % Supported scheduling strategies: 'PF', 'RR', 'BestCQI' and 'DA'
simParameters.RBAllocationLimitUL = 273; % For PUSCH
simParameters.RBAllocationLimitDL = 273; % For PDSCH
if simParameters.SchedulingType == 1
    simParameters.TTIGranularity = 7; % length of smallest scheduling entity in OFDM Symbols
end
simParameters.BSRPeriodicity = 1; % Buffer status report transmission periodicity (in ms)
simParameters.PUSCHPrepTime = 200; % In microseconds
simParameters.RVSequence = [0 3];

if ~isfield(simParameters, 'SchedulingType') || simParameters.SchedulingType == 0 % If no scheduling type is specified or slot based scheduling is specified
    tickGranularity = 14;
    simParameters.PUSCHMappingType = 'B'; % for switching slot in DDDSU configuration
    simParameters.PDSCHMappingType = 'A';
else % Symbol based scheduling
    tickGranularity = 1;
    simParameters.PUSCHMappingType = 'B';
    simParameters.PDSCHMappingType = 'B';
end

if enableMIMO
    gNBTxArraySize = [2 4 2];
    gNBRxArraySize = [2 4 2];
    simParameters.GNBTxAnts = prod(gNBTxArraySize);
    simParameters.GNBRxAnts = prod(gNBRxArraySize);

    ueTxArraySize = repmat([1 2 2],simParameters.NumUEs,1);
    ueRxArraySize = repmat([1 2 2],simParameters.NumUEs,1);
    simParameters.UETxAnts = prod(ueTxArraySize,2);
    simParameters.UERxAnts = prod(ueRxArraySize,2);

    % Validate the number of transmitter and receiver antennas at UE
    validateattributes(simParameters.UETxAnts, {'numeric'}, {'nonempty', 'integer', 'nrows', simParameters.NumUEs, 'ncols', 1, 'finite'}, 'simParameters.UETxAnts', 'UETxAnts')
    validateattributes(simParameters.UERxAnts, {'numeric'}, {'nonempty', 'integer', 'nrows', simParameters.NumUEs, 'ncols', 1, 'finite'}, 'simParameters.UERxAnts', 'UERxAnts')

    simParameters.DownlinkSINR90pc = [-3.4600 1.5400 6.5400 11.0500 13.5400 16.0400 17.5400 20.0400 22.0400 24.4300 26.9300 27.4300 29.4300 32.4300 35.4300];
    simParameters.UplinkSINR90pc = [-5.4600 -0.4600 4.5400 9.0500 11.5400 14.0400 15.5400 18.0400 20.0400 22.4300 24.9300 25.4300 27.4300 30.4300 33.4300];
    %simParameters.SINR90pc = [-0.4600 4.5400 9.5400 14.0500 16.5400 19.0400 20.5400 23.0400 25.0400 27.4300 29.9300 30.4300 32.4300 35.4300 38.4300];
    %simParameters.DownlinkSINR90pc = [-0.4600 4.5400 9.5400 14.0500 16.5400 19.0400 20.5400 23.0400 25.0400 27.4300 29.9300 30.4300 32.4300 35.4300 38.4300];
    %simParameters.UplinkSINR90pc = [-5.4600 -0.4600 4.5400 9.0500 11.5400 14.0400 15.5400 18.0400 20.0400 22.4300 24.9300 25.4300 27.4300 30.4300 33.4300];

    simParameters.SRSSubbandSize = 32;
    srsConfig = cell(simParameters.NumCells, simParameters.NumUEs);
    combNumber = 4; % SRS comb number
    for cellIdx = 1:simParameters.NumCells
        for ueIdx = 1:simParameters.NumUEs
            % Ensure non-overlapping SRS resources when there are more than 4 UEs by giving different offset
            srsPeriod = [10 3+floor((ueIdx-1)/4)];
            srsBandwidthMapping = nrSRSConfig.BandwidthConfigurationTable{:,2};
            csrs = find(srsBandwidthMapping <= simParameters.NumRBs, 1, 'last') - 1;
            % Set full bandwidth SRS
            srsConfig{cellIdx,ueIdx} = nrSRSConfig('NumSRSPorts', 4, 'SymbolStart', 13, 'SRSPeriod', srsPeriod, 'KTC', combNumber, 'KBarTC',  mod(ueIdx-1, combNumber), 'BSRS', 0, 'CSRS', csrs);
        end
    end

    csirsConfig = cell(1, simParameters.NumCells);
    for cellIdx = 1:simParameters.NumCells
        csirsConfig{cellIdx} = nrCSIRSConfig('NID', simParameters.NCellIDList(cellIdx), 'NumRB', simParameters.NumRBs, 'RowNumber', 11, 'SubcarrierLocations', [1 3 5 7], 'SymbolLocations', 0, 'CSIRSPeriod', [10 0+cellIdx]);
    end

    % Specify the CSI report configuration.
    csiReportConfig.PanelDimensions = [8 1]; % [N1 N2] as per 3GPP TS 38.214 Table 5.2.2.2.1-2
    csiReportConfig.CQIMode = 'Subband'; % 'Wideband' or 'Subband'
    csiReportConfig.PMIMode = 'Subband'; % 'Wideband' or 'Subband'
    csiReportConfig.SubbandSize = 32; % Refer TS 38.214 Table 5.2.1.4-2 for valid subband sizes
    % Set codebook mode as 1 or 2. It is applicable only when the number of transmission layers is 1 or 2 and
    % number of CSI-RS ports is greater than 2
    csiReportConfig.CodebookMode = 1;
    csiReportConfig.CQITable = 'table1';
    simParameters.CSIReportConfig = {csiReportConfig};

    % Simulator does not support UL rank estimation - UL rank has to be fixed
    simParameters.ULRankIndicator = 1*ones(1, simParameters.NumUEs); % The example does not support UL rank estimation. Set the rank statically.

else
    gNBTxArraySize = [1 1 1];
    gNBRxArraySize = [2 4 2];
    simParameters.GNBTxAnts = prod(gNBTxArraySize);
    simParameters.GNBRxAnts = prod(gNBRxArraySize);

    ueTxArraySize = repmat([1 1 1],simParameters.NumUEs,1);
    ueRxArraySize = repmat([1 2 2],simParameters.NumUEs,1);
    simParameters.UETxAnts = prod(ueTxArraySize,2);
    simParameters.UERxAnts = prod(ueRxArraySize,2);

    % Validate the number of transmitter and receiver antennas at UE
    validateattributes(simParameters.UETxAnts, {'numeric'}, {'nonempty', 'integer', 'nrows', simParameters.NumUEs, 'ncols', 1, 'finite'}, 'simParameters.UETxAnts', 'UETxAnts')
    validateattributes(simParameters.UERxAnts, {'numeric'}, {'nonempty', 'integer', 'nrows', simParameters.NumUEs, 'ncols', 1, 'finite'}, 'simParameters.UERxAnts', 'UERxAnts')

    simParameters.SINR90pc = [-5.46 -0.46 4.54 9.05 11.54 14.04 15.54 18.04 20.04 22.43 24.93 25.43 27.43 30.43 33.43];
    %simParameters.DownlinkSINR90pc = [-0.4600 4.5400 9.5400 14.0500 16.5400 19.0400 20.5400 23.0400 25.0400 27.4300 29.9300 30.4300 32.4300 35.4300 38.4300];
    %simParameters.UplinkSINR90pc = [-5.4600 -0.4600 4.5400 9.0500 11.5400 14.0400 15.5400 18.0400 20.0400 22.4300 24.9300 25.4300 27.4300 30.4300 33.4300];

    srsConfig = cell(simParameters.NumCells, simParameters.NumUEs);
    combNumber = 4; % SRS comb number
    for cellIdx = 1:simParameters.NumCells
        for ueIdx = 1:simParameters.NumUEs
            % Ensure non-overlapping SRS resources when there are more than 4 UEs by giving different offset
            srsPeriod = [10 3+floor((ueIdx-1)/4)];
            srsBandwidthMapping = nrSRSConfig.BandwidthConfigurationTable{:,2};
            csrs = find(srsBandwidthMapping <= simParameters.NumRBs, 1, 'last') - 1;
            % Set full bandwidth SRS
            srsConfig{cellIdx,ueIdx} = nrSRSConfig('NumSRSPorts', 1, 'SymbolStart', 13, 'SRSPeriod', srsPeriod, 'KTC', combNumber, 'KBarTC',  mod(ueIdx-1, combNumber), 'BSRS', 0, 'CSRS', csrs);
        end
    end

    csirsConfig = cell(1, simParameters.NumCells);
    for cellIdx = 1:simParameters.NumCells
        csirsConfig{cellIdx} = nrCSIRSConfig('NID', simParameters.NCellIDList(cellIdx), 'NumRB', simParameters.NumRBs, 'RowNumber', 2, 'SubcarrierLocations', 1, 'SymbolLocations', 0);
    end

    csiReportConfig = struct('SubbandSize', 32, 'CQIMode', 'Subband', 'CQITable', 'table1');
    simParameters.CSIReportConfig = {csiReportConfig};
end

%% Logging and Visualization Configuration
simParameters.CellOfInterest = 0; % Set a value from 0 to NumCells-1
cellOfInterestIdx = find(simParameters.CellOfInterest == simParameters.NCellIDList);
% Validate Cell of interest
validateattributes(simParameters.CellOfInterest, {'numeric'}, {'nonempty', 'integer', 'scalar', '>=', 0, '<',simParameters.NumCells}, 'simParameters.CellOfInterest', 'CellOfInterest');

simParameters.CQIVisualization = false;
simParameters.RBVisualization = false;

enablePlotting = true;
enableLogging = true;

parametersLogFile = strcat('SimulationParameters_numUEs', num2str(numUEs),'_numCells',num2str(numCells),'_MIMO',num2str(enableMIMO),'_TrafficModel',trafficConfiguration,'_Scheduler',num2str(schedulingStrategy),'_SchedulerWeight',num2str(schedulingWeightParameter),'_',num2str(worker)); % For logging the simulation parameters
simulationMetricsFile = 'simulationMetrics'; % For logging the simulation metrics
simulationLogFile = strcat('SimulationLog_numUEs', num2str(numUEs),'_numCells',num2str(numCells),'_MIMO',num2str(enableMIMO),'_TrafficModel',trafficConfiguration,'_Scheduler',num2str(schedulingStrategy),'_SchedulerWeight',num2str(schedulingWeightParameter),'_',num2str(worker)); % For logging the simulation traces
simulationIPLogFile = strcat('IPSimulationLog_numUEs',  num2str(numUEs),'_numCells',num2str(numCells),'_MIMO',num2str(enableMIMO),'_TrafficModel',trafficConfiguration,'_Scheduler',num2str(schedulingStrategy),'_SchedulerWeight',num2str(schedulingWeightParameter),'_',num2str(worker)); % For logging the simulation traces

slotDuration = 1/(simParameters.SCS/15); % In ms
numSlotsFrame = 10/slotDuration; % Number of slots in a 10 ms frame
numSlotsSim = simParameters.NumFramesSim * numSlotsFrame; % Number of slots in the simulation

simParameters.NumMetricsSteps = 20; % update intervall for metrics plot
simParameters.MetricsStepSize = ceil(numSlotsSim / simParameters.NumMetricsSteps);
if mod(numSlotsSim, simParameters.NumMetricsSteps) ~= 0
    % Update the NumMetricsSteps parameter if NumSlotsSim is not
    % completely divisible by it
    simParameters.NumMetricsSteps = floor(numSlotsSim / simParameters.MetricsStepSize);
end

%% Wireless Channel Setup
simParameters.UELOSCondition = cell(simParameters.NumCells, 1);
simParameters.UEShadowFadingLoss = cell(simParameters.NumCells, 1);
for cellIdx = 1:simParameters.NumCells % For each cell
    simParameters.UELOSCondition{cellIdx} = zeros(simParameters.NumUEs,1);
    simParameters.UEShadowFadingLoss{cellIdx} = zeros(simParameters.NumUEs,1);
    for ueIdx = 1:simParameters.NumUEs % For each UE within the cell
        simParameters.UELOSCondition{cellIdx}(ueIdx) = getLOSCondition(pathlossconf, simParameters.GNBPosition(cellIdx, :).', simParameters.UEPosition{cellIdx}(ueIdx, :).', simParameters.UEIndoorDistance{cellIdx}(ueIdx)); % random LOS probability
        simParameters.UEShadowFadingLoss{cellIdx}(ueIdx) = getRandomShadowFadingLoss(pathlossconf,simParameters.DLCarrierFreq,simParameters.UELOSCondition{cellIdx}(ueIdx),simParameters.UEIndoorDistance{cellIdx}(ueIdx),simParameters.GNBPosition(cellIdx, :).',simParameters.UEPosition{cellIdx}(ueIdx, :).');
    end
end

% Configure the channel model
channelModelUL = cell(simParameters.NumCells, simParameters.NumUEs);
channelModelDL = cell(simParameters.NumCells, simParameters.NumUEs);
waveformInfo = nrOFDMInfo(simParameters.NumRBs, simParameters.SCS);
for cellIdx = 1:simParameters.NumCells % For each cell
    for ueIdx = 1:simParameters.NumUEs % For each UE within the cell
        if simParameters.UELOSCondition{cellIdx}(ueIdx)
            modelType = simParameters.LOSChannelModel;
        else
            modelType = simParameters.NLOSChannelModel;
        end

        % Configure the downlink channel model
        channel = nrCDLChannel;
        channel.DelayProfile = modelType;
        channel.MaximumDopplerShift = 3 / 3.6 * simParameters.DLCarrierFreq / physconst('lightspeed');
        channel.DelaySpread = 300e-9;
        channel.Seed = 73 + simParameters.NumUEs*(cellIdx-1) +(ueIdx - 1);
        channel.CarrierFrequency = simParameters.DLCarrierFreq;
        channel = hArrayGeometry(channel, simParameters.GNBTxAnts, simParameters.UERxAnts(ueIdx), 'downlink');
        channel.SampleRate = waveformInfo.SampleRate;
        channelModelDL{cellIdx,ueIdx} = channel;

        % Configure the uplink channel model
        channel = nrCDLChannel;
        channel.DelayProfile = modelType;
        channel.MaximumDopplerShift = 3 / 3.6 * simParameters.ULCarrierFreq / physconst('lightspeed');
        channel.DelaySpread = 300e-9;
        channel.Seed = 73 + simParameters.NumUEs*(cellIdx-1) +(ueIdx - 1);
        channel.CarrierFrequency = simParameters.ULCarrierFreq;
        channel = hArrayGeometry(channel, simParameters.UETxAnts(ueIdx), simParameters.GNBRxAnts, 'uplink');
        channel.SampleRate = waveformInfo.SampleRate;
        channelModelUL{cellIdx, ueIdx} = channel;
    end
end

%% gNB and UEs Setup
simParameters.configuration = trafficConfiguration;
% it is assumed that all cells are configured the same
if strcmp(simParameters.configuration, 'AR3GPP')
    [appTable, sdapTable, pdcpTable, rlcTable] = create3GPPARTrafficConfig(simParameters);
elseif strcmp(simParameters.configuration, 'AR3GPPWithIFrameRecovery')
    [appTable, sdapTable, pdcpTable, rlcTable] = create3GPPARTrafficConfigWithIFrameRecovery(simParameters);
elseif strcmp(simParameters.configuration, 'ARTUDNavigation')
    [appTable, sdapTable, pdcpTable, rlcTable] = createTUDARNavgiationTrafficConfig(simParameters);
elseif strcmp(simParameters.configuration, 'ARTUDWithIFrameRecoveryNavigation')
    [appTable, sdapTable, pdcpTable, rlcTable] = createTUDARNavigationTrafficConfigWithIFrameRecovery(simParameters);
elseif strcmp(simParameters.configuration, 'ARTUD3DCall')
    [appTable, sdapTable, pdcpTable, rlcTable] = createTUDAR3DCallTrafficConfig(simParameters);
elseif strcmp(simParameters.configuration, 'ARTUDWithIFrameRecovery3DCall')
    [appTable, sdapTable, pdcpTable, rlcTable] = createTUDAR3DCallTrafficConfigWithIFrameRecovery(simParameters);
else
    error("unknown traffic model")
end
simParameters.AppConfig = appTable;
simParameters.SDAPconfig = sdapTable;
simParameters.PDCPConfig = pdcpTable;
simParameters.RLCConfig = rlcTable;

lchInfo = cell(simParameters.NumCells,1);
for cellIdx = 1:simParameters.NumCells
    lchInfo{cellIdx} = repmat(struct('RNTI', [], 'LCID', [], 'EntityDir', []), [simParameters.NumUEs 1]);
    for ueIdx = 1:simParameters.NumUEs
        LCIDfull = [];
        EntityDirFull = [];
        for rlcIdx = 1:numel(simParameters.RLCConfig.RNTI)
            if simParameters.RLCConfig.RNTI(rlcIdx,:) == ueIdx
                LCIDfull = [LCIDfull; simParameters.RLCConfig.LogicalChannelID(rlcIdx,:)];
                EntityDirFull = [EntityDirFull; simParameters.RLCConfig.EntityType(rlcIdx,:)];
            end
        end
        lchInfo{cellIdx}(ueIdx).RNTI = ueIdx;
        lchInfo{cellIdx}(ueIdx).LCID = LCIDfull;
        lchInfo{cellIdx}(ueIdx).EntityDir = EntityDirFull;
    end
end

gNB = cell(simParameters.NumCells, 1);
UEs = cell(simParameters.NumCells, simParameters.NumUEs);

cellParam = simParameters; % Cell level parameters
cellParam.PLConfig = pathlossconf;

for cellIdx = 1:simParameters.NumCells % For each cell
    cellParam.NCellID = simParameters.NCellIDList(cellIdx); % Cell ID
    cellParam.Position = simParameters.GNBPosition(cellIdx, :); % gNB position in (x,y,z) coordinates
    cellParam.SRSConfig = srsConfig(cellIdx,:);
    cellParam.CSIRSConfig = csirsConfig(cellIdx);
    cellParam.CSIReportConfig = {csiReportConfig};
    cellParam.UERxAnts = simParameters.UERxAnts;
    cellParam.UETxAnts = simParameters.UETxAnts;
    gNB{cellIdx} = hNRGNB(cellParam); % Create gNB node
    % Create scheduler
    switch(simParameters.SchedulerStrategy)
        case 'RR' % Round-robin scheduler
            scheduler = hNRSchedulerRoundRobin(cellParam);
        case 'PF' % Proportional fair scheduler
            scheduler = hNRSchedulerProportionalFair(cellParam);
        case 'BestCQI' % Best CQI scheduler
            scheduler = hNRSchedulerBestCQI(cellParam);
        case 'DA' % Delay aware scheduler
            cellParam.DelayFactorWeight = schedulingWeightParameter;
            scheduler = hNRSchedulerDelayAware(cellParam);
        case 'DAFramePrio'
            scheduler = hNRSchedulerDelayAwareWithIFramePrio(cellParam);
        case 'PFFramePrio'
            cellParam.IFramePrioWeight = schedulingWeightParameter;
            scheduler = hNRSchedulerProportionalFairWithIFramePrio(cellParam);
        case 'FrameIntegretyProtection'
            scheduler = hNRSchedulerFrameIntegretyProtection(cellParam);
    end
    addScheduler(gNB{cellIdx}, scheduler); % Add scheduler to gNB
    cellParam.ChannelModel = channelModelUL(cellIdx,:);
    cellParam.ShadowFadingLoss = simParameters.UEShadowFadingLoss{cellIdx};
    cellParam.LOS = simParameters.UELOSCondition{cellIdx};
    cellParam.UEIndoorDistance = simParameters.UEIndoorDistance{cellIdx};
    cellParam.UEPosition = simParameters.UEPosition{cellIdx};
    if cellIdx == cellOfInterestIdx
        cellOfInterestParam = cellParam;
    end
    gNB{cellIdx}.PhyEntity = hNRGNBPhy(cellParam); % Create the PHY layer instance
    configurePhy(gNB{cellIdx}, cellParam); % Configure the PHY layer
    setPhyInterface(gNB{cellIdx}); % Set up the interface to PHY layer

    for ueIdx = 1:simParameters.NumUEs
        cellParam.Position = simParameters.UEPosition{cellIdx}(ueIdx, :); % Position of UE in (x,y,z) coordinates
        cellParam.SRSConfig = srsConfig{cellIdx,ueIdx};
        cellParam.CSIReportConfig = csiReportConfig;
        cellParam.ChannelModel = channelModelDL{cellIdx,ueIdx};
        cellParam.ShadowFadingLoss = simParameters.UEShadowFadingLoss{cellIdx}(ueIdx);
        cellParam.LOS = simParameters.UELOSCondition{cellIdx}(ueIdx);
        cellParam.UEIndoorDistance = simParameters.UEIndoorDistance{cellIdx}(ueIdx);
        cellParam.UERxAnts = simParameters.UERxAnts(ueIdx);
        cellParam.UETxAnts = simParameters.UETxAnts(ueIdx);
        UEs{cellIdx, ueIdx} = hNRUE(cellParam, ueIdx);
        UEs{cellIdx, ueIdx}.PhyEntity = hNRUEPhy(cellParam, ueIdx); % Create the PHY layer instance
        configurePhy(UEs{cellIdx, ueIdx}, cellParam); % Configure the PHY layer
        setPhyInterface(UEs{cellIdx, ueIdx}); % Set up the interface to PHY

        for sdapIdx = 1:numel(simParameters.SDAPconfig.RNTI)
            if simParameters.SDAPconfig.RNTI(sdapIdx) == ueIdx
                sdapChannelConfigStruct.RQI = simParameters.SDAPconfig.ReflectiveQoS(sdapIdx,:); % configure reflective QoS, 0: disabled, 1: enabled, no functionality is implemented behind this paramter besides the information being added to the header
                mappingRule = simParameters.SDAPconfig.MappingRule(sdapIdx,:);
                sdapChannelConfigStruct.MappingRule = mappingRule(mappingRule~=0);

                % Setup SDAP at gNB for the UE
                configurePDUSession(gNB{cellIdx}, ueIdx, sdapChannelConfigStruct);
                % Setup SDAP at UE
                configurePDUSession(UEs{cellIdx, ueIdx}, ueIdx, sdapChannelConfigStruct);
            end
        end

        for pdcpIdx = 1:numel(simParameters.PDCPConfig.RNTI)
            if simParameters.PDCPConfig.RNTI(pdcpIdx) == ueIdx
                pdcpChannelConfigStruct.RNTI = ueIdx;
                pdcpChannelConfigStruct.cellId = cellIdx;
                pdcpChannelConfigStruct.AppName = simParameters.AppConfig.ApplicationName(pdcpIdx);
                pdcpChannelConfigStruct.DataRadioBearerID = simParameters.PDCPConfig.DRBID(pdcpIdx);
                associatedLogicalChannels = simParameters.PDCPConfig.LCIDs(pdcpIdx,:);
                pdcpChannelConfigStruct.LogicalChannelIDs = associatedLogicalChannels(associatedLogicalChannels~=0);
                pdcpChannelConfigStruct.DataTimeToLive = simParameters.PDCPConfig.DataTimeToLive(pdcpIdx,:);
                pdcpChannelConfigStruct.EnableIntegrityProtection = simParameters.PDCPConfig.IntegrityProtection(pdcpIdx,:);
                pdcpChannelConfigStruct.EnablePacketDuplication = simParameters.PDCPConfig.PacketDuplication(pdcpIdx,:);
                pdcpChannelConfigStruct.EnableOutOfOrderDelivery = simParameters.PDCPConfig.OutOfOrderDelivery(pdcpIdx,:);
                pdcpChannelConfigStruct.ReorderingTimerStartingValue = simParameters.PDCPConfig.ReorderingTimer(pdcpIdx,:);
                pdcpChannelConfigStruct.ProtocolOverhead = simParameters.PDCPConfig.ProtocolOverhead(pdcpIdx,:);
                pdcpChannelConfigStruct.CompressedProtocolOverhead = simParameters.PDCPConfig.CompressedProtocolOverhead(pdcpIdx,:);

                % Setup PDCP at gNB for the UE
                configureDataRadioBearer(gNB{cellIdx}, ueIdx, pdcpChannelConfigStruct);
                % Setup PDCP at UE
                configureDataRadioBearer(UEs{cellIdx, ueIdx}, ueIdx, pdcpChannelConfigStruct);
            end
        end

        for rlcIdx = 1:numel(simParameters.RLCConfig.RNTI)
            if simParameters.RLCConfig.RNTI(rlcIdx) == ueIdx
                rlcChannelConfigStruct.LogicalChannelID = simParameters.RLCConfig.LogicalChannelID(rlcIdx,:);
                rlcChannelConfigStruct.LCGID = simParameters.RLCConfig.LCGID(rlcIdx,:);
                rlcChannelConfigStruct.SeqNumFieldLength = simParameters.RLCConfig.SeqNumFieldLength(rlcIdx,:);
                rlcChannelConfigStruct.MaxTxBufferSDUs = simParameters.RLCConfig.MaxTxBufferSDUs(rlcIdx,:);
                rlcChannelConfigStruct.ReassemblyTimer = simParameters.RLCConfig.ReassemblyTimer(rlcIdx,:);
                rlcChannelConfigStruct.EntityType = simParameters.RLCConfig.EntityType(rlcIdx,:);
                rlcChannelConfigStruct.Priority = simParameters.RLCConfig.Priority(rlcIdx,:);
                rlcChannelConfigStruct.PBR = simParameters.RLCConfig.PBR(rlcIdx,:);
                rlcChannelConfigStruct.BSD = simParameters.RLCConfig.BSD(rlcIdx,:);

                % Setup PDCP at gNB for the UE
                configureLogicalChannel(gNB{cellIdx}, ueIdx, rlcChannelConfigStruct);
                % Setup logical channel at UE
                configureLogicalChannel(UEs{cellIdx, ueIdx}, ueIdx, rlcChannelConfigStruct);
            end
        end

        % Add application data traffic pattern generators to gNB node and
        % UE node
        packetSize = 1500;
        for appIdx=1:numel(simParameters.AppConfig.RNTI)
            if simParameters.AppConfig.RNTI(appIdx) == ueIdx
                switch simParameters.AppConfig.ApplicationName(appIdx)
                    case "ARvideoTraffic"
                        app = networkTrafficARvideo('MaxPacketSize', packetSize, 'GeneratePacket', true, 'StreamingMethod', simParameters.AppConfig.AppParameter2(appIdx), 'NumFramesRecoveryStart', str2num(simParameters.AppConfig.AppParameter3(appIdx)), 'IFramePeriodicity', str2num(simParameters.AppConfig.AppParameter4(appIdx)));
                        app.setParameters3GPP(simParameters.AppConfig.AppParameter1(appIdx))
                    case "ARperiodicTraffic"
                        app = networkTrafficARperiodic('MaxPacketSize', packetSize, 'GeneratePacket', true);
                        app.setParameters3GPP(simParameters.AppConfig.AppParameter1(appIdx))
                    case "DLBufferedVideo"
                        app = networkTrafficDLBufferedVideo('MaxPacketSize', packetSize, 'GeneratePacket', true);
                    case "ULBufferedVideo"
                        app = networkTrafficULBufferedVideo('MaxPacketSize', packetSize, 'GeneratePacket', true);
                    case "DLWebBrowsing"
                        app = networkTrafficDLWebBrowsing('MaxPacketSize', packetSize, 'GeneratePacket', true);
                    case "ULWebBrowsing"
                        app = networkTrafficULWebBrowsing('MaxPacketSize', packetSize, 'GeneratePacket', true);
                    case "VoIP"
                        app = networkTrafficVoIP('MaxPacketSize', packetSize, 'GeneratePacket', true);
                    case "VideoConference"
                        app = networkTrafficVideoConference('GeneratePacket', true, 'HasJitter', str2num(simParameters.AppConfig.AppParameter1(appIdx)));
                    case "OnOff"
                        app = networkTrafficOnOff('GeneratePacket',true,'OnTime', simParameters.NumFramesSim*10e-3, 'OffTime', 0,'DataRate', 40e3);
                    case "ARTUD"
                        app = networkTrafficARTUD('GeneratePacket', true, 'UseCase', simParameters.AppConfig.AppParameter1(appIdx), 'Resolution', simParameters.AppConfig.AppParameter2(appIdx), 'NumFramesRecoveryStart', str2num(simParameters.AppConfig.AppParameter3(appIdx)), 'IFramePeriodicity', str2num(simParameters.AppConfig.AppParameter4(appIdx)));
                end
                app.ProtocolOverhead = simParameters.AppConfig.ProtocolOverhead(appIdx);
                if simParameters.AppConfig.HostDevice(appIdx) == 0
                    gNB{cellIdx}.addApplication(ueIdx, simParameters.AppConfig.AppID(appIdx), app);
                    if strcmp(simParameters.AppConfig.ApplicationName(appIdx), "ARTUD") || strcmp(simParameters.AppConfig.ApplicationName(appIdx), "ARvideoTraffic")
                        UEs{cellIdx,ueIdx}.registerCallbackToSourceApplication(ueIdx, simParameters.AppConfig.AppID(appIdx), app);
                    end
                else
                    UEs{cellIdx,ueIdx}.addApplication(ueIdx, simParameters.AppConfig.AppID(appIdx), app);
                end
            end
        end
    end
end

%% Simulation
nrNodes = [gNB(:); UEs(:)];
networkSimulator = hWirelessNetworkSimulator(nrNodes);

%%
% Create objects to log MAC and PHY traces.
if enableLogging

    % Create an object for IP Packet logging
    simIPLogger  = hNRIPLogger(simParameters, networkSimulator, gNB{1});
    simRLCLogger = cell(simParameters.NumCells, 1);
    simSchedulingLogger = cell(simParameters.NumCells, 1);
    simPhyLogger = cell(simParameters.NumCells, 1);

    for cellIdx = 1:simParameters.NumCells
        simParameters.NCellID = simParameters.NCellIDList(cellIdx);
        % Create an object for RLC traces logging
        simRLCLogger{cellIdx}  = hNRRLCLogger(simParameters, lchInfo{cellIdx}, networkSimulator, gNB{cellIdx}, UEs(cellIdx, :));
        % Create an object for MAC traces logging
        simSchedulingLogger{cellIdx}  = hNRSchedulingLogger(simParameters, networkSimulator, gNB{cellIdx}, UEs(cellIdx, :));
        % Create an object for PHY traces logging
        simPhyLogger{cellIdx}  = hNRPhyLogger(simParameters, networkSimulator, gNB{cellIdx}, UEs(cellIdx, :));
    end
    % Create an object for CQI and RB grid visualization
    if simParameters.CQIVisualization || simParameters.RBVisualization
        gridVisualizer = hNRGridVisualizer(simParameters, 'MACLogger', simSchedulingLogger);
    end
end

%%
if enablePlotting
    plotNetwork(simParameters);

    % Create an object for MAC and PHY metrics visualization
    metricsVisualizer = hNRMetricsVisualizer(simParameters, 'CellOfInterest', simParameters.CellOfInterest, 'EnableSchedulerMetricsPlots', true, 'EnablePhyMetricsPlots', true, ...
        'NetworkSimulator', networkSimulator, 'GNB', gNB{cellOfInterestIdx}, 'UEs', UEs(cellOfInterestIdx, :));
end

%% Run Simulation
simulationTime = simParameters.NumFramesSim * 1e-2;
% Run the simulation
run(networkSimulator, simulationTime);

if enablePlotting
    metrics = getMetrics(metricsVisualizer);
    save(simulationMetricsFile, 'metrics');
end

%%

if enablePlotting
    displayPerformanceIndicators(metricsVisualizer);
end

if enableLogging
    simulationLogs = cell(simParameters.NumCells,1);
    simulation_IPLogs = getIPLogs(simIPLogger);
    for cellIdx = 1:simParameters.NumCells
        if simParameters.DuplexMode == 0 % FDD
            logInfo = struct('DLTimeStepLogs', [], 'ULTimeStepLogs', [], 'SchedulingAssignmentLogs', [], 'BLERLogs', [], 'AvgBLERLogs', []);
            [logInfo.DLTimeStepLogs, logInfo.ULTimeStepLogs] = getSchedulingLogs(simSchedulingLogger{cellIdx});
        else % TDD
            logInfo = struct('TimeStepLogs', [], 'SchedulingAssignmentLogs', [], 'BLERLogs', [], 'AvgBLERLogs', []);
            logInfo.TimeStepLogs = getSchedulingLogs(simSchedulingLogger{cellIdx});
        end
        [logInfo.BLERLogs, logInfo.AvgBLERLogs] = getBLERLogs(simPhyLogger{cellIdx}); % BLER logs
        logInfo.SchedulingAssignmentLogs = getGrantLogs(simSchedulingLogger{cellIdx}); % Scheduling assignments log
        logInfo.RLCLogs = getRLCLogs(simRLCLogger{cellIdx});
        simulationLogs{cellIdx} = logInfo;
    end
    save(parametersLogFile, 'simParameters'); % Save simulation parameters in a MAT-file
    save(simulationLogFile, 'simulationLogs'); % Save simulation logs in a MAT-file
    save(simulationIPLogFile, 'simulation_IPLogs'); % Save IP logs in a MAT-file
end
end