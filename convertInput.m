function [numUEs, numCells, numFramesSim, enableMIMO, schedulingWeightParameter, worker] = convertInput(numUEs, numCells, numFramesSim, enableMIMO, schedulingWeightParameter, worker)

if ischar(numUEs) || isstring(numUEs)
    numUEs = str2num(numUEs);
end

if ischar(numFramesSim) || isstring(numFramesSim)
    numFramesSim = str2num(numFramesSim);
end

if ischar(worker) || isstring(worker)
    worker = str2num(worker);
end

if ischar(numCells) || isstring(numCells)
    numCells = str2num(numCells);
end

if ischar(enableMIMO) || isstring(enableMIMO)
    enableMIMO = str2num(enableMIMO);
end

if ischar(schedulingWeightParameter) || isstring(schedulingWeightParameter)
    schedulingWeightParameter = str2num(schedulingWeightParameter);
end

end