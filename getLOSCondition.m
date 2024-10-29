function LOS = getLOSCondition(config,posBS,posUE, d2D_in)

% Expansion of BS and UE positions for matrix operations
bs = permute(repmat(posBS,1,1,1),[2 3 1]);
ue = permute(repmat(posUE,1,1,1),[3 2 1]);
hBS = bs(:,:,3);
hUT = ue(:,:,3);

% 3D distance between BS and UE
d3D  = sqrt((ue(:,:,1)-bs(:,:,1)).^2 + ...
    (ue(:,:,2)-bs(:,:,2)).^2 + ...
    (ue(:,:,3)-bs(:,:,3)).^2);
d2D = sqrt(d3D.^2-(hBS-hUT).^2);

d2D_out = d2D - d2D_in;

scenario = config.Scenario;

switch scenario
    case 'UMa'
        if d2D_out<=18
            LOSprobability = 1;
        else
            if hUT <=13
                C = 0;
            else
                C=((hUT-13)/10)^1.5;
            end
            LOSprobability = (18/d2D_out+exp(-d2D_out/36)*(1-18/d2D_out))*(1+C*5/4*(d2D_out/100)^3*exp(-d2D_out/150));
        end
    case 'UMi'
        if d2D_out<=18
            LOSprobability = 1;
        else
            LOSprobability = 18/d2D_out + exp(-d2D_out/36)*(1-18/d2D_out);
        end        
    case 'RMa'
        if d2D_out<=10
            LOSprobability = 1;
        else
            LOSprobability = exp(-(d2D-10)/1000);
        end
    otherwise
        error('Scenario unknown.')
end

LOS = rand()<LOSprobability;
end