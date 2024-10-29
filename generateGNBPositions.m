function [gnbPosition] = generateGNBPositions(simParameters)
% Return the position of GNBs for sectorized cells given 

gnbHeight = getGNBHeight(simParameters);
positionOfFirstCell = [1700 600 gnbHeight]; % [x y z]

if strcmp(simParameters.CellType,'sectorized')
    a = sqrt(simParameters.ISD^2/3); % length of hexagon edge
    ri = sqrt(a^2 - (a/2)^2); % radius of the inner circle of the hexagon

    gnbPosition = zeros(simParameters.NumCells, 3);
    if simParameters.NumCells == 1
        gnbPosition(1,:) = positionOfFirstCell;
    elseif simParameters.NumCells == 3
        gnbPosition(1,:) = positionOfFirstCell;
        gnbPosition(2,:) = positionOfFirstCell + [3/2*a ri 0];
        gnbPosition(3,:) = positionOfFirstCell + [3/2*a -ri 0];
    else
        error('a number of cells other than 1 or 3 needs to be done manually')
    end
else % omnidirectional
    gnbPosition = zeros(simParameters.NumCells, 3);
    if simParameters.NumCells == 1
        gnbPosition(1,:) = positionOfFirstCell;
    elseif simParameters.NumCells == 3
        gnbPosition(1,:) = positionOfFirstCell;
        gnbPosition(2,:) = positionOfFirstCell + [simParameters.ISD/2 sqrt(3/4*simParameters.ISD^2) 0];
        gnbPosition(3,:) = positionOfFirstCell + [-simParameters.ISD/2 sqrt(3/4*simParameters.ISD^2) 0];
    else
        error('a number of cells other than 1 or 3 needs to be done manually')
    end
end
end