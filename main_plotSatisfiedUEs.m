simulationFolder = 'SimulationResults_21_07/';
numUEsToPlot = 1:10;
numCellsToPlot = 3;
MIMOToPlot = 1;
SchedulingStrategyToPlot = 'PF';
schedulingWeightToPlot = 0;
TrafficModelToPlot = 'AR3GPP';

FrameDB = 10; %[ms]
PoseControlDB = 10; %[ms]
AudioDataDB = 10; %[ms]

maximumFrameLossRate = 0.01;
maximumULPacketLossRate = 1;
maximumDLPacketLossRate = 0.01; 

includeUEsWithBadCoverage = true;

fileListIPLogs = dir(strcat(simulationFolder,'IPSimulationLog*.mat'));
fileListBaseLogs = dir(strcat(simulationFolder,'SimulationLog*.mat'));

%% load files
packetLossRateDLPERUEFull = cell(numel(numUEsToPlot),1);
packetLossRateULPERUEFull = cell(numel(numUEsToPlot),1);
frameLossRatePerUEFull = cell(numel(numUEsToPlot),1);

for i=1:numel(numUEsToPlot)
    for f=1:numel(fileListIPLogs)
        filenameIPLogs = fileListIPLogs(f).name;
        filenameBaseLogs = replace(filenameIPLogs,"IPSimulationLog", "SimulationLog");

        numUEs = str2num(cell2mat(extractBetween(filenameIPLogs,'numUEs','_')));
        if numUEs ~= numUEsToPlot(i)
            continue
        end

        numCells = str2num(cell2mat(extractBetween(filenameIPLogs,'numCells','_')));
        if numCells ~= numCellsToPlot
            continue
        end

        schedulingWeight = str2num(cell2mat(extractBetween(filenameIPLogs,'SchedulerWeight','_')));
        if schedulingWeight ~= schedulingWeightToPlot
            continue
        end

        MIMO = str2num(cell2mat(extractBetween(filenameIPLogs,'MIMO','_')));
        if MIMO ~= MIMOToPlot
            continue
        end

        extractionResults = extractBetween(filenameIPLogs,'Scheduler','_');
        SchedulingStrategy = cell2mat(extractionResults(1));
        if ~strcmp(SchedulingStrategyToPlot, SchedulingStrategy)
            continue
        end

        if ~strcmp(TrafficModelToPlot, cell2mat(extractBetween(filenameIPLogs,'TrafficModel','_')))
            continue
        end

        load(strcat(simulationFolder,filenameIPLogs));
        if ~includeUEsWithBadCoverage
            load(strcat(simulationFolder,filenameBaseLogs));
        end

        % DL IP packets for data/audio
        numEntriesDL = numel(simulation_IPLogs{end-1,4}(:,1));
        for t = 2:numEntriesDL
            if ~includeUEsWithBadCoverage
                cellID = simulation_IPLogs{end-1,4}{t,2};
                RNTI = simulation_IPLogs{end-1,4}{t, 3};
                if any(find(simulationLogs{cellID,1}.AvgBLERLogs(:,1)>0.1)==RNTI) || any(find(simulationLogs{cellID,1}.AvgBLERLogs(:,2)>0.1)==RNTI) || any(find(simulationLogs{cellID,1}.AvgBLERLogs(:,2)>0.1)==RNTI)
                    continue
                end
            end
            if strcmp(simulation_IPLogs{end-1,4}{t,1},'ARperiodicTraffic')
                targetRxPackets = simulation_IPLogs{end-1,4}{t,6} + simulation_IPLogs{end-1,4}{t,8};
                packetsLost = simulation_IPLogs{end-1,4}{t,8};
                packetsExceedingDelayBudget = numel(find(simulation_IPLogs{end-1,4}{t,13}>AudioDataDB));
                packetLossRateDLPERUEFull{i} = [packetLossRateDLPERUEFull{i} (packetsLost+packetsExceedingDelayBudget)/targetRxPackets];
            end
        end

        % UL IP packets
        numEntiresUL = numel(simulation_IPLogs{end-1,5}(:,1));
        for t = 2:numEntiresUL
            if ~includeUEsWithBadCoverage
                cellID = simulation_IPLogs{end-1,5}{t,2};
                RNTI = simulation_IPLogs{end-1,5}{t, 3};
                if any(find(simulationLogs{cellID,1}.AvgBLERLogs(:,1)>0.1)==RNTI) || any(find(simulationLogs{cellID,1}.AvgBLERLogs(:,2)>0.1)==RNTI)
                    continue
                end
            end
            if strcmp(simulation_IPLogs{end-1,5}{t,1},'ARperiodicTraffic')
                targetRxPackets = simulation_IPLogs{end-1,5}{t,6} + simulation_IPLogs{end-1,5}{t,8};
                packetsLost = simulation_IPLogs{end-1,5}{t,8};
                packetsExceedingDelayBudget = numel(find(simulation_IPLogs{end-1,5}{t,13}>PoseControlDB));
                packetLossRateULPERUEFull{i} = [packetLossRateULPERUEFull{i} (packetsLost+packetsExceedingDelayBudget)/targetRxPackets];
            end
        end

        % DL Frames
        numEntriesDL = numel(simulation_IPLogs{end,4}(:,1));
        for t = 2:numEntriesDL
            if strcmp(simulation_IPLogs{end,4}{t,1},'ARvideoTraffic') || strcmp(simulation_IPLogs{end,4}{t,1},'ARTUD')
                targetRxFrames = simulation_IPLogs{end,4}{t,6} + simulation_IPLogs{end,4}{t,7}  + simulation_IPLogs{end,4}{t,8}  + simulation_IPLogs{end,4}{t,9};
                if ~includeUEsWithBadCoverage
                    cellID = simulation_IPLogs{end,4}{t,2};
                    RNTI = simulation_IPLogs{end,4}{t, 3};
                    if any(find(simulationLogs{cellID,1}.AvgBLERLogs(:,1)>0.1)==RNTI) || any(find(simulationLogs{cellID,1}.AvgBLERLogs(:,2)>0.1)==RNTI)
                        continue
                    end
                end
                
                framesLost = simulation_IPLogs{end,4}{t,8}  + simulation_IPLogs{end,4}{t,9};
                framesExceedingDelayBudget = numel(find(simulation_IPLogs{end,4}{t,13}>FrameDB));
                frameLossRatePerUEFull{i} = [frameLossRatePerUEFull{i} (framesLost+framesExceedingDelayBudget)/targetRxFrames];
            end
        end
    end
end

%% satisfied UE 
satisifiedUEs = zeros(numel(numUEsToPlot),1);
totalNumberOfUEs = zeros(numel(numUEsToPlot),1);
for i=1:numel(numUEsToPlot)
    for j=1:numel(frameLossRatePerUEFull{i})
        totalNumberOfUEs(i) = totalNumberOfUEs(i) + 1;
        if isempty(packetLossRateDLPERUEFull{i})
            if frameLossRatePerUEFull{i}(j) <= maximumFrameLossRate
                satisifiedUEs(i) = satisifiedUEs(i) + 1;
            end
        else
            if packetLossRateDLPERUEFull{i}(j) <= maximumDLPacketLossRate && packetLossRateULPERUEFull{i}(j) <= maximumULPacketLossRate && frameLossRatePerUEFull{i}(j) <= maximumFrameLossRate
                satisifiedUEs(i) = satisifiedUEs(i) + 1;
            end
        end

    end
end

%% Gooddput plot
figure
set(gcf,'Color','white')
set(gcf, 'Position',  [100, 100, 300, 200])
plot(numUEsToPlot(totalNumberOfUEs~=0),satisifiedUEs(totalNumberOfUEs~=0)./totalNumberOfUEs(totalNumberOfUEs~=0)*100);
hold on
plot([0 max(totalNumberOfUEs)],[1 1]*90);
xlabel('Number of UEs per Cell', 'Interpreter', 'latex')
ylabel('Satisfied UEs [\%]', 'Interpreter', 'latex')
grid on
ylim([0 100]);
xlim([0 20]);
