function SFLoss = getRandomShadowFadingLoss(PLconf, freq, LOS, d2D_in, pos_GNB, pos_UE)

[~,SFstdDeviation]=nrPathLossWithIndoorPropagation(PLconf, freq, LOS, d2D_in, pos_GNB, pos_UE); % frequency does not matter for calculation of SF value

SFLoss = normrnd(0,SFstdDeviation);

end