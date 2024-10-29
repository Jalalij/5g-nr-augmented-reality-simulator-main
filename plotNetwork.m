function plotNetwork(simParameters)
if strcmp(simParameters.CellType, 'sectorized')
    return
end
% Create the figure
figure('Name', 'Network Topology Visualization', 'units', 'normalized', 'outerposition', [0 0 1 1], 'Visible', "on");
title('Network Topology Visualization');
hold on;

for cellIdx = 1:simParameters.NumCells
    
    % Plot the circle
    th = 0:pi/60:2*pi;
    xunit = simParameters.CellRadius * cos(th) + simParameters.GNBPosition(cellIdx, 1);
    yunit = simParameters.CellRadius * sin(th) + simParameters.GNBPosition(cellIdx, 2);
    if simParameters.CellOfInterest == simParameters.NCellIDList(cellIdx)
        h1 =  plot(xunit, yunit, 'Color', 'green'); % Cell of interest
    else
        h2 =  plot(xunit, yunit, 'Color', 'red');
    end
    xlabel('X-Position (meters)')
    ylabel('Y-Position (meters)')
    % Add tool tip data for gNBs
    s1 = scatter(simParameters.GNBPosition(cellIdx, 1), simParameters.GNBPosition(cellIdx, 2), '^','MarkerEdgeColor', 'magenta');
    cellIdRow = dataTipTextRow('Cell - ',{num2str(simParameters.NCellIDList(cellIdx))});
    s1.DataTipTemplate.DataTipRows(1) = cellIdRow;
    posRow = dataTipTextRow('Position[X, Y]: ',{['[' num2str(simParameters.GNBPosition(cellIdx, :)) ']']});
    s1.DataTipTemplate.DataTipRows(2) = posRow;
    
    % Add tool tip data for UEs
    uePosition = simParameters.UEPosition{cellIdx};
    ueIndoor = simParameters.UEIndoorDistance{cellIdx}>0;
    for ueIdx = 1:size(uePosition, 1)
        if ueIndoor(ueIdx)
            s3 = scatter(uePosition(ueIdx, 1), uePosition(ueIdx, 2), 's','MarkerEdgeColor', 'blue');
            ueIdRow = dataTipTextRow('UE - ',{num2str(ueIdx)});
            s3.DataTipTemplate.DataTipRows(1) = ueIdRow;
            posRow = dataTipTextRow('Position[X, Y]: ',{['[' num2str(uePosition(ueIdx, :)) ']']});
            s3.DataTipTemplate.DataTipRows(2) = posRow;
        else
            s2 = scatter(uePosition(ueIdx, 1), uePosition(ueIdx, 2), '.','MarkerEdgeColor', 'blue');
            ueIdRow = dataTipTextRow('UE - ',{num2str(ueIdx)});
            s2.DataTipTemplate.DataTipRows(1) = ueIdRow;
            posRow = dataTipTextRow('Position[X, Y]: ',{['[' num2str(uePosition(ueIdx, :)) ']']});
            s2.DataTipTemplate.DataTipRows(2) = posRow;
        end
    end
end
% Create the legend
if simParameters.NumCells > 1
    legend([h1 h2 s1 s2 s3], 'Cell of interest', 'Interfering cells', 'gNodeB', 'outdoor UE', 'indoor UE', 'Location', 'northeastoutside')
elseif all(ueIndoor)
    legend([h1 s1 s3], 'Cell of interest', 'gNodeB', 'indoor UE', 'Location', 'northeastoutside')
else
    legend([h1 s1 s2 s3], 'Cell of interest', 'gNodeB', 'outdoor UE', 'indoor UE', 'Location', 'northeastoutside')
end
axis auto
hold off;
daspect([1000,1000,1]); % Set data aspect ratio
end