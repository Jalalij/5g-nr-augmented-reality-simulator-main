function updatedBeamIndices = hPlotBeamformingPattern(configParam, gNB, beamIndices)
%hPlotBeamformingPattern Update the beam index and plot beamforming pattern 
%   hPlotBeamformingPattern(configParam, gNB) updates the beam index for
%   all UEs and plots the beamforming pattern by considering these inputs:
%
%   CONFIGPARAM is the simulation structure with these necessary fields:
%      NumUEs            -  Number of UEs in the cell
%      SSBIndex          -  Synchronization signal block (SSB) index
%                           corresponding to each UE
%      NumCSIRSBeams     -  Number of channel state information resource
%                           signal (CSI-RS) beams in one SSB beam sweep
%      TxAntPanel        -  Transmit antenna array panel
%      Position          -  Position of gNB in (x,y,z) coordinates
%      UEPosition        -  Position of UE in (x,y,z) coordinates
%      DLCarrierFreq     -  Downlink Carrier Frequency (Hz)
%      BeamWeightTable   -  Beamweights of CSI-RS transmit beams
%   GNB                -  gNB object
%   BEAMINDICES        -  CSI-RS transmit beam indices for all UEs in the
%                         previous iteration
%   UPDATEDBEAMINDICES -  CSI-RS transmit beam indices for all UEs in the 
%                         current iteration

%   Copyright 2021 The MathWorks, Inc.

% Initialize the beam indices for all UEs 
updatedBeamIndices = -1*ones(1, configParam.NumUEs);
linkDir = 0; % Downlink

% Get the updated beam indices for all UEs 
for ueIdx = 1:configParam.NumUEs
    csiMeasurement = gNB.MACEntity.getChannelQualityStatus(linkDir, ueIdx);
    if ~isempty(csiMeasurement.CSIResourceIndicator)
        updatedBeamIndices(ueIdx) = (configParam.SSBIndex(ueIdx)-1)*configParam.NumCSIRSBeams + csiMeasurement.CSIResourceIndicator;
    end
end

% Plot the beamforming pattern 
if beamIndices ~= updatedBeamIndices
    sceneParams = struct();
    sceneParams.TxArray = configParam.TxAntPanel;
    sceneParams.TxArrayPos = configParam.Position';
    sceneParams.UEPos = configParam.UEPosition';
    sceneParams.Lambda = physconst('LightSpeed')/configParam.DLCarrierFreq;
    sceneParams.ArrayScaling = 500;    % Scaling factor to visualize antenna array elements
    sceneParams.MaxTxBeamLength = 150; % Scaling factor to visualize the beam
    plotSpatialTxBeamforming(sceneParams, configParam.BeamWeightTable(:, unique(updatedBeamIndices)), unique(updatedBeamIndices));
end
end

function plotSpatialTxBeamforming(sceneParams, wT, beamIndices)
%plotSpatialTxBeamforming Plot spatial transmit beamforming scenario
%   plotSpatialTxBeamforming(SCENEPARAMS, WT) plots the spatial
%   transmit beamforming scenario by considering these inputs:
%
%   SCENEPARAMS is a structure with these fields:
%      TxArray         - Transmit antenna array System object
%      TxArrayPos      - Center of the transmitting antenna array,
%                        specified as a three-element vector in Cartesian
%                        form, [x;y;z], with respect to global coordinate
%                        system. Units are in meters
%      UEPos           - UE Positions as a 3-by-K matrix. K is the
%                        number of UEs and each column of UEPos is
%                        a different UE and has the Cartesian form
%                        [x;y;z] with respect to global coordinate system.
%                        Units are in meters
%      Lambda          - Carrier wavelength in meters
%      ArrayScaling    - Scaling factor to plot the transmit antenna panel
%                        array
%      MaxTxBeamLength - Maximum length of transmit beams in the plot
%
%    WT   - Steering weights for transmit beamforming. WT is
%          specified as a matrix, where each column represents
%          the weights corresponding to a separate direction
%
%    BEAMINDICES - Updated beam indices for all UEs

% Extract the inputs
txArray    = sceneParams.TxArray;
txArrayPos = sceneParams.TxArrayPos;
uePos      = sceneParams.UEPos;
lambda     = sceneParams.Lambda;
arrayScaling = sceneParams.ArrayScaling;
txBeamScaling = sceneParams.MaxTxBeamLength;
fc = physconst('LightSpeed')/lambda;

% Get the positions of transmit antenna elements (in meters)
txElemPos = getElementPosition(txArray);

% Scale the antenna elements positions and shift them to centers of
% antenna arrays
txarraypos_plot = txElemPos*arrayScaling + txArrayPos;

% Plot the transmit antenna array
figure;
h1 = plot3(txarraypos_plot(1,:), txarraypos_plot(2,:), ...
    txarraypos_plot(3,:), 'ro', 'MarkerSize', 2, 'MarkerFaceColor', 'r');
hold on;

% Get the transmit antenna size
txArraySize = txArray.Size;

% Plot the transmit antenna panel
txPanelCorners = txarraypos_plot(:, [1 txArraySize(1) prod(txArraySize) prod(txArraySize)-txArraySize(1)+1]);
txPanel = patch(txPanelCorners(1,:), txPanelCorners(2,:),...
    txPanelCorners(3,:), [0.5725 0.6588 0.8196], 'LineStyle', ':', 'FaceAlpha', 0.5);

numUEs = size(uePos,2);
UE = cell(1,numUEs); % Initialize UE labels cell array

for m = 1: numUEs
    UE{m} = strcat('UE-',num2str(m));  % UE labels
end

% Plot the UE Positions
h3 = plot3(uePos(1,:), uePos(2,:), uePos(3,:), 'ro', 'MarkerSize', 25);
text(uePos(1,:), uePos(2,:), uePos(3,:), UE, 'HorizontalAlignment','center')

h4 = zeros(1, numUEs); % Initialize line object array
% Plot the paths connecting txArrayPos and UEPos
for m = 1:numUEs
    h4(m) = plot3([txArrayPos(1) uePos(1,m)], [txArrayPos(2) uePos(2,m)],...
        [txArrayPos(3) uePos(3,m)],'b', 'LineWidth', 1.5);
end

% Plot the transmit beam patterns
numTxBeams = size(wT,2);
txBeamColorMap = rand(numTxBeams,3);
h5 = zeros(1, numTxBeams); % Initialize surface object array
txBeamLegend = cell(1,numTxBeams);
for txBeamIndex = 1:numTxBeams
    % Obtain the Spherical coordinate pattern
    [txPat,txAZRange,txELRange] = pattern(txArray, fc, 'Weights', wT(:,txBeamIndex));
    txbeam = db2mag(txPat);
    txbeam = (txbeam/max(txbeam(:)))*txBeamScaling;
    % Conversion to Cartesian coordinate system
    [x1,y1,z1] = sph2cart(deg2rad(txAZRange), deg2rad(txELRange'), txbeam);
    % Surface plot by shifting it to center of antenna array/gNB
    txhandle = surf(x1 + txArrayPos(1), y1 + txArrayPos(2), z1 + txArrayPos(3));
    txhandle.EdgeColor = 'none';
    txhandle.FaceColor = txBeamColorMap(txBeamIndex,:);
    txhandle.FaceAlpha = 0.9;
    h5(txBeamIndex) = txhandle;
    if numTxBeams == 1
        txBeamLegend = {'Transmit beam'};
    else
        txBeamLegend{txBeamIndex} = ['Transmit beam ' num2str(txBeamIndex)];
    end
end

xlabel('X axis (m)')
ylabel('Y axis (m)')
zlabel('Z axis (m)')

legend([h1 txPanel h3 h4(1) h5 ], ...
    [{'Transmit antenna elements','Transmit antenna panel','UE(s)', ...
    'LOS path(s)'} txBeamLegend ],'Location', ...
    'bestoutside');

hold off;
axis equal;
grid on;
end