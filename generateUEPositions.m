function [uePositions,d2D_in, ueRelPosition] = generateUEPositions(simParameters)
% Return the position of UEs in each cell and their distance from the outer
% wall if the UE is indoors

uePositions = cell(simParameters.NumCells, 1);
ueRelPosition = cell(simParameters.NumCells, 1);
d2D_in = cell(simParameters.NumCells, 1);
for cellIdx=1:simParameters.NumCells
    gnbXCo = simParameters.GNBPosition(cellIdx, 1); % gNB X-coordinate
    gnbYCo = simParameters.GNBPosition(cellIdx, 2); % gNB Y-coordinate
    gnbZCo = simParameters.GNBPosition(cellIdx, 3); % gNB Y-coordinate
    if strcmp(simParameters.CellType,'omnidirectional')
        theta = rand(simParameters.NumUEs, 1)*(2*pi);
        % Expression to calculate position of UEs with in the cell. By default,
        % it will place the UEs randomly with in the cell
        r = sqrt(rand(simParameters.NumUEs, 1))*simParameters.CellRadius;
        x = round(gnbXCo + r.*cos(theta));
        y = round(gnbYCo + r.*sin(theta));
    else % sectorized cell with 120 degree sectors
        azimuthRange = simParameters.SectorAzimuthAngle(cellIdx,:);

        a = sqrt(simParameters.ISD^2/3); % length of hexagon edge
        % sector is a parallelogram - draw distance from paralleleogram edge randomly
        a1 = rand(simParameters.NumUEs, 1)*a;
        a2 = rand(simParameters.NumUEs, 1)*a;

        if all(azimuthRange == [-60 60])
            x_rel = cos(60/360*2*pi)*a1 + cos(60/360*2*pi)*a2;
            y_rel = - sin(60/360*2*pi)*a1 + sin(60/360*2*pi)*a2;
        elseif all(azimuthRange == [-180 -60])
            x_rel = sin(30/360*2*pi)*a1 - a2;
            y_rel = cos(30/360*2*pi)*a1;
        elseif all(azimuthRange == [60 180])
            x_rel = sin(30/360*2*pi)*a1 - a2;
            y_rel = -cos(30/360*2*pi)*a1;
        else
            error('uncaptured azimuth range for sectorized cell')
        end

        x = round(gnbXCo+ x_rel);
        y = round(gnbYCo + y_rel);
    end

    switch simParameters.Scenario % Number of floors is random
        case {'UMa','UMi'}
            ueIndoorFlag = rand(simParameters.NumUEs,1) < 0.8; % 80 percent indoor
        case 'RMa'
            ueIndoorFlag = rand(simParameters.NumUEs,1) < 0.5; % 50 percent indoor
    end

    n_fl = zeros(simParameters.NumUEs,1);
    for i =1:simParameters.NumUEs
        if ueIndoorFlag(i) == 1
            switch simParameters.Scenario % Number of floors is random
                case {'UMa','UMi'}
                    N_fl = rand()*4+4; % from range [4,8]
                    n_fl(i) = rand()*(N_fl-1)+1; %from range [1,N_fl]
                case 'RMa'
                    n_fl(i) = 1;
            end
        else
            n_fl(i) = 1;
        end
    end

    z = 3*(n_fl-1) + ones(simParameters.NumUEs, 1)*1.5;
    uePositions{cellIdx} = [x y z];

    % distance from wall for indoor UEs
    d2D_in{cellIdx} = zeros(simParameters.NumUEs, 1);
    for i =1:simParameters.NumUEs
        if ueIndoorFlag(i)
            switch simParameters.Scenario
                case {'UMa','UMi'}
                    if simParameters.DLCarrierFreq <= 6 && simParameters.ULCarierFreq <= 6
                        d2D_in{cellIdx}(i) = rand(1,1)*25; % special option for backwards compatibility with TR 36.873
                    else
                        d2D_in{cellIdx}(i) = min(rand(2,1)*25);
                    end
                case 'RMa'
                    d2D_in{cellIdx}(i) = min(rand(2,1)*10);
                otherwise
                    error('Scenario unknown.')
            end
        end
    end

    % UE position in spherical coordinates (r,azimuth,elevation)
    xRel = x-gnbXCo;
    yRel = y-gnbYCo;
    zRel = z-gnbZCo;

    d = sqrt((xRel).^2+(yRel).^2+(zRel).^2);
    el = asin(zRel./d)/(2*pi)*360;
    az = zeros(simParameters.NumUEs,1);
    for i =1:simParameters.NumUEs
        if xRel(i) > 0
            az(i) = atan(yRel(i)/xRel(i))/(2*pi)*360;
        else
            if yRel<0
                az(i) = 180-atan(yRel(i)/xRel(i))/(2*pi)*360;
            else
                az(i) = -180-atan(yRel(i)/xRel(i))/(2*pi)*360;
            end
        end
    end
    ueRelPosition{cellIdx,1} = [d az el];
end

end