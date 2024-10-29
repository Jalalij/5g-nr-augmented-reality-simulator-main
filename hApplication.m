classdef hApplication < handle
%hApplication Implement application layer functionality
%   APP = hApplication creates an object for application layer. It is a
%   container of different application traffic generators and application
%   receiver to terminate the packets. It is responsible for invoking
%   different traffic model objects for generating packets. It also
%   maintains the application level statistics.
%
%   APP = hApplication(Name, Value) creates an object for application layer
%   with the specified property Name set to the specified Value. You can
%   specify additional name-value pair arguments in any order as (Name1,
%   Value1, ..., NameN, ValueN).
%
%   hApplication properties:
%
%   ID               - Node identifier
%   MaxApplications  - Maximum number of applications that can be
%                      added
%
%   hApplication methods:
%
%   run            - Run application layer to generate packets
%   addApplication - Add application traffic model to application layer
%   receivePacket  - Receive and terminate packet

%   Copyright 2020-2022 The MathWorks, Inc.

%#codegen

properties
    %ID Node identifier
    ID {mustBeInteger, mustBeGreaterThan(ID, 0)}= 1;

    %MaxApplications Maximum number of applications that can be added
    MaxApplications {mustBeInteger, mustBeGreaterThanOrEqual(MaxApplications, 0)} = 16;
end

properties(SetAccess = private, Hidden)
    %Applications Context of the applications added to the application
    % layer. This is a cell array of size N-by-1 where N is the maximum
    % number of applications that can be added to the application layer.
    % Each cell in the cell array is a structure with these fields:
    %   App            - Handle object for application traffic pattern
    %                    such as networkTrafficOnOff, networkTrafficFTP,
    %                    networkTrafficVoIP, networkTrafficVideoConference.
    %   TimeLeft       - Time left for the generation of next packet from 
    %                    the associated traffic pattern object.
    %   DestinationID  - Destination node identifier of the application.
    %   AppID          - Traffic identifier.
    Applications
    
    %ApplicationsCount Count of applications that has been added
    ApplicationsCount = 0;

    %LastRunTime Time (in nanoseconds) at which the application layer was invoked last time
    LastRunTime = 0;

    % NextInvokeTime Next invoke time
    %   Next invoke time for application packet generation
    %NextInvokeTime = 0;

    % Tx_ApplicationsCallback is a matrix of call backs per AppID and RNTI for informing
    % the source application out of band e.g. on packet success
    Tx_ApplicationsCallback={};
end

properties(Constant)
    %ApplicationPacket Format of the packet that will be sent to lower layer
    ApplicationPacket = struct('PacketLength', 0, ...
        'DestinationID', 0, ... % Immediate destination node ID
        'Timestamp', 0, ... % Packet generation time stamp at origin
        'PacketID', 0, ... % Packet identifier assigned at origin
        'AppID', 0, ... % App identifier assigned at origin
        'Frame', zeros(1,4), ... %Frame Type & Number for AR Video Frame Logging
        'Data', zeros(2304, 1, 'uint8'));
end

methods
    function obj = hApplication(varargin)
        % Name-value pairs
        for idx = 1:2:nargin
            obj.(varargin{idx}) = varargin{idx+1};
        end
        
        obj.Applications = cell(obj.MaxApplications, 1);
    end
    
    function nextInvokeTime = run(obj, currentTime, txPacketFcn)
        %run Run application layer to generate packets
        %
        % NEXTINVOKETIME = run(OBJ, CURRENTTIME, TXPACKETFCN) runs the
        % configured traffic models in the application layer to generate
        % packet, if the current time reaches the next packet generation
        % time. Otherwise, returns next packet generation time (in
        % nanoseconds).
        %
        % NEXTINVOKETIME indicates the time (in nanoseconds) at which the
        % next packet generation takes place.
        %
        % CURRENTTIME indicates the current time (in nanoseconds).
        %
        % TXPACKETFCN is a function handle for sending data to the lower
        % layer.
        
        % Find the elapsed time since the last run of application layer
        elapsedTime = currentTime - obj.LastRunTime;
        nextInvokeTime = inf;
        runAppsFlag = true;
        
        while runAppsFlag
            % Time to generate the next packet
            for idx=1:obj.ApplicationsCount
                obj.Applications{idx}.TimeLeft = obj.Applications{idx}.TimeLeft - elapsedTime;
                if obj.Applications{idx}.TimeLeft <= 0
                    if isa(obj.Applications{idx}.App,'networkTrafficARvideo') || isa(obj.Applications{idx}.App,'networkTrafficARTUD')
                        % Generate data from the application traffic pattern
                        [packetInterval, packetSize, packetData, frame_data] = obj.Applications{idx}.App.generate();   
                        frameInformation = cell2mat(frame_data);
                    else
                        % Generate data from the application traffic pattern
                        [packetInterval, packetSize, packetData] = obj.Applications{idx}.App.generate();
                    end
                    % Put data and its associated context in the packet
                    % structure
                    packet = obj.ApplicationPacket;
                    packet.AppID = obj.Applications{idx}.AppID;
                    packet.Data = packetData;
                    packet.PacketLength = packetSize;
                    packet.DestinationID = obj.Applications{idx}.DestinationID;
                    if isa(obj.Applications{idx}.App,'networkTrafficARvideo') || isa(obj.Applications{idx}.App,'networkTrafficARTUD')
                        packet.Frame = frameInformation;
                    end
                    obj.Applications{idx}.TimeLeft = round(packetInterval * 1e6); % In nanoseconds (rounded to full nanoseconds)
    
                    % Send packet to lower layer
                    txPacketFcn(packet, obj.Applications{idx}.TimeLeft);
                end

                % Find the minimum of next invoke times
                if obj.Applications{idx}.TimeLeft < nextInvokeTime
                    nextInvokeTime = obj.Applications{idx}.TimeLeft;
                end
            end
            % If the next invoke time is not 0, stop running the
            % application traffic generators
            if nextInvokeTime > 0
                runAppsFlag = false;
            else
                nextInvokeTime = Inf;
                elapsedTime = 0;
            end
        end
        nextInvokeTime = currentTime + nextInvokeTime;
        % Update the last run time of application layer
        
        obj.LastRunTime = currentTime;
    end
   
    function addApplication(obj, app, metaData)
        %addApplication Add application traffic model to application layer
        %
        % addApplication(OBJ, APP, METADATA) adds the application traffic
        % model to application layer.
        %
        % APP is a handle object that generates the application traffic. It
        % should be one of networkTrafficOnOff, networkTrafficVoIP,
        % networkTrafficFTP, or networkTrafficVideoConference.
        %
        % METADATA is a structure and contains following fields.
        %   DestinationNode - Destination node id.
        %   AppID           - App identifier to differentiate
        %                     priorities of different traffic at lower
        %                     layers.
        
        if obj.ApplicationsCount == obj.MaxApplications
            error('hApplication:MaxAppLimit', ...
                'Number of applications that can be configured has reached the limit %d', ...
                obj.MaxApplications);
        end
        
        obj.ApplicationsCount = obj.ApplicationsCount + 1;
        appIdx = obj.ApplicationsCount;
        % Fill the application context
        obj.Applications{appIdx}.App = app;
        obj.Applications{appIdx}.TimeLeft = 0;
        obj.Applications{appIdx}.DestinationID = metaData.DestinationNode;
        obj.Applications{appIdx}.AppID = metaData.AppID;
    end

    function registerCallback(obj, callbackFcn, RNTI, appID)
        %registerCallback Register a callback to the source application
        obj.Tx_ApplicationsCallback{appID, RNTI} = callbackFcn;
    end
    
    function receivePacket(obj, packet, appID, RNTI)
        %receivePacket Receive and terminate packet
        if size(obj.Tx_ApplicationsCallback,1) >=appID && size(obj.Tx_ApplicationsCallback,2) >= RNTI
            if ~isempty(obj.Tx_ApplicationsCallback{appID,RNTI})
                txFwdFcn = obj.Tx_ApplicationsCallback{appID,RNTI};
                txFwdFcn(packet);
            end
        end
    end
end
end