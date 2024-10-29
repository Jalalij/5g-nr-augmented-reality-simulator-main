function h = getGNBHeight(simParameters)
    % paramters set according to 3GPP TR 38.901 
    switch simParameters.Scenario
        case 'UMa'
            h = 25;
        case 'UMi'
            h = 10;
        case 'RMa'
            h = 35;
        otherwise
            error('Scenario unknown.')
    end
end