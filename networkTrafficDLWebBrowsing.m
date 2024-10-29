classdef networkTrafficDLWebBrowsing < comm_sysmod.internal.ConfigBaseHandle
    %this function generates IP packets of HTTP traffic according to 3GPP
    %R1-070674 und IEEE 802.11-14/0571r12

    properties
        %PacketSize Length of the packet to be generated in bytes
        %   Specify the packet size value as a positive scalar. If
        %   packet size is larger than the data generated in On time, the
        %   data is accumulated across multiple 'On' times to generate a
        %   packet. The default value is 1500.
        MaxPacketSize = 1500

        %ProtocolOverhead Adds protocol overheads to the traffic in bytes
        %   Specify ProtocolOverheads as an integer in the range [0, 60]. To
        %   accommodate layer 3, layer 4, and application protocol overheads in
        %   the network traffic, set this property. The default value is 40.
        ProtocolOverhead = 40;

        %GeneratePacket Flag to indicate whether to generate video packet with
        %payload
        %   Specify GeneratePacket value as true or false. To generate a video
        %   packet with payload, set this property to true. If you set this
        %   property to false, the generate object function generates no
        %   application data packet. The default value is false.
        GeneratePacket (1, 1) logical = false;

        %ApplicationData Application data to be filled in the packet
        %   Specify ApplicationData as a column vector of integers in the range
        %   [0, 255]. This property is applicable when the <a href="matlab:help('networkTrafficVideoConference.GeneratePacket')">GeneratePacket</a> value
        %   is set to true. If the size of the application data is greater than
        %   the packet size, the object truncates the application data. If the
        %   size of the application data is smaller than the packet size, the
        %   object appends zeros. The default value is a 1500-by-1 vector of
        %   ones.
        ApplicationData = ones(1500, 1);
    end

    properties (Access = private)
        %pNextInvokeTime Time in milliseconds after which the generate method
        % should be invoked again
        pNextInvokeTime = 0;

        %pCurrentTime Time in milliseconds since traffic was first
        %generated
        pCurrentTime = 0;

        %pJitters Latency values of all the segements to be sent
        %   latency is the transmission time of segments of payload
        %   in milliseconds
        pLatencies = 0;

        %pJitters Jitter values of all the segements to be sent
        %   Jitter is the time gap between two consecutive segments of payload
        %   in milliseconds
        pJitters = 0;

        %pAppData Application data to be filled in the packet as a column vector
        % of integers in the range [0, 255]
        %   If size of the input application data is greater than the packet
        %   size, the object truncates the input application data. If size of
        %   the application data is smaller than the packet size, the object
        %   appends zeros.
        pAppData = ones(1500, 1);

        %pAppDataUpdated Flag to indicate whether the application data is
        %updated
        pAppDataUpdated = false;

        %pMainObjectSize Remaining size of the website main object yet to be packetized
        %   Remaining amount of website main object in bytes which is not yet packetized by
        %   the generate object function.
        pMainObjectSize = 0;

        %pEmbeddedObjectSize Remaining size of the website embedded object yet to be packetized
        %   Remaining amount of website embedded object in bytes which is not yet packetized by
        %   the generate object function.
        pEmbeddedObjectSize = 0;

        pMainWebsiteObjectCountdown = 0;

        pEmbeddedObjectsCountdown = 0;

        %pDataType Type of payload the jitter and latency values are associated with
        % 1: main object
        % 2: embedded object
        pDataType  = 0;

        pMeanParsingTime = 0.13;

        pMeanReadingTime = 30;

        pMeanMainObjectSize = 8.37;

        pMeanEmbeddedObjectSize = 6.17;

        pStandardDeviationMainObjectSize = 1.37;

        pStandardDeviationEmbeddedObjectSize = 2.36;

        pShapeParameterNumberOfEmbeddedObjects = 1.1;

        pScaleParameterNumberOfEmbeddedObjects = 2;

        pLowerBoundMainObjectSize = 100; % [Bytes]

        pUpperBoundMainObjectSize = 2e6; % [Bytes]

        pLowerBoundEmbeddedObjectSize = 50; % [Bytes]

        pUpperBoundEmbeddedObjectSize = 2e6; % [Bytes]

        %pMaxPayloadSize Maximum payload size in bytes excluding protocol overhead
        pMaxPayloadSize = 1460;
    end

    methods (Access = protected)
        function flag = isInactiveProperty(obj, prop)
            flag = false;
            if strcmp(prop, 'ApplicationData')
                flag = ~(obj.GeneratePacket);
            end
        end
    end

    methods
        function obj = networkTrafficDLWebBrowsing(varargin)
            obj@comm_sysmod.internal.ConfigBaseHandle(varargin{:});

            obj.pMainWebsiteObjectCountdown = rand(1,1)*generateRandomReadingTime(obj); % random number to simulate how much time has already passed before simulation start
            obj.pEmbeddedObjectsCountdown = obj.pMainWebsiteObjectCountdown + generateRandomParsingTime(obj);
        end

        function set.ProtocolOverhead(obj, value)
            % Validate protocol overheads value
            validateattributes(value, {'numeric'}, {'real', 'integer', 'scalar', ...
                '>=', 0, '<=', 60}, '', 'ProtocolOverhead');
            obj.ProtocolOverhead = value;
            obj.pMaxPayloadSize = obj.MaxPacketSize - obj.ProtocolOverhead;

            % Application data has changed, update the application data to be
            % added in the packet as per given application data
            updateAppData(obj);
        end

        function set.MaxPacketSize(obj, value)
            % Validate protocol overheads value
            obj.MaxPacketSize = value;
            obj.pMaxPayloadSize = obj.MaxPacketSize - obj.ProtocolOverhead;
                        
            % Application data has changed, update the application data to be
            % added in the packet as per given application data
            updateAppData(obj);
        end

        function set.ApplicationData(obj, data)
            % Validate application data
            validateattributes(data, {'numeric'}, {'real', 'integer', 'column', ...
                '>=', 0, '<=', 255}, '', 'ApplicationData');
            obj.ApplicationData = data;

            obj.pAppDataUpdated = true; %#ok<*MCSUP>
            % Application data has changed, update the application data to be
            % added in the packet as per given application data
            updateAppData(obj);
        end

        function [dt, packetSize, varargout] = generate(obj, varargin)
            %generate Generate next DL AR traffic packet
            %
            narginchk(1, 2);

            if isempty(varargin)
                obj.pNextInvokeTime = 0;
            else
                % Validate elapsed time value
                validateattributes(varargin{1}, {'numeric'}, {'real', 'scalar', ...
                    'finite', '>=', 0}, '', 'ElapsedTime');
                % Calculate time remaining before generating next packet
                obj.pNextInvokeTime = obj.pNextInvokeTime - varargin{1};
                obj.pCurrentTime = obj.pCurrentTime + varargin{1};
            end
            varargout{1} = zeros(0, 1); % Application packet

            if obj.pNextInvokeTime <= 0
                % New data is generated only if the old data is completely
                % sent and the time for generating new data is reached
                if ~obj.pMainObjectSize && ~obj.pEmbeddedObjectSize && obj.pMainWebsiteObjectCountdown<=0
                    obj.generateNewPayload(1);
                    % to include modeling of jitter for first packet of video
                    % frames, return a packet of size 0 and set next invoke time
                    % to first jitter value
                    obj.pMainWebsiteObjectCountdown =  generateRandomReadingTime(obj);
                end
                if ~obj.pEmbeddedObjectSize && obj.pEmbeddedObjectsCountdown<=0
                    obj.generateNewPayload(2);
                    obj.pEmbeddedObjectsCountdown = obj.pMainWebsiteObjectCountdown + generateRandomParsingTime(obj);
                end

                % output a segment
                switch obj.pDataType(1)
                    case 0 % payload type 0 means no packet to output
                        packetSize = 0;
                        dt = getNextInvokeTime(obj);
                        varargout{2} = 0;
                    case 1
                        [dt, packetSize, obj.pMainObjectSize] = obj.transmitSegment(obj.pMainObjectSize);
                        varargout{2} = 1;
                    case 2
                        [dt, packetSize, obj.pEmbeddedObjectSize] = obj.transmitSegment(obj.pEmbeddedObjectSize);
                        varargout{2} = 2;
                end

                dt = round(dt*1e6)/1e6; % Limiting dt to nanoseconds accuracy
                obj.pNextInvokeTime = dt;

                obj.pMainWebsiteObjectCountdown = obj.pMainWebsiteObjectCountdown - dt;
                obj.pMainWebsiteObjectCountdown = round(obj.pMainWebsiteObjectCountdown*1e6)/1e6; % Limiting dt to nanoseconds accuracy
                obj.pEmbeddedObjectsCountdown = obj.pEmbeddedObjectsCountdown - dt;
                obj.pEmbeddedObjectsCountdown = round(obj.pEmbeddedObjectsCountdown*1e6)/1e6; % Limiting dt to nanoseconds accuracy

                % If the flag to generate a packet is true, generate the packet
                if packetSize >0
                    if obj.GeneratePacket
                        varargout{1} = [obj.pAppData(1:packetSize, 1); ones(obj.ProtocolOverhead,1)];
                    end
                    packetSize = packetSize + obj.ProtocolOverhead;
                end
            else % Time is still remaining to generate the next frame
                dt = obj.pNextInvokeTime;
                packetSize = 0;
            end
        end
    end

    methods(Access = private)
        function updateAppData(obj)
            %updateAppData Set the application data based on the given packet
            %size and application data. This function is called whenever the
            %user sets either packet size or application data.

            % Update application data to be added in the packet
            if ~obj.pAppDataUpdated % Use default data as application data
                % Default data is not enough for application data, update the
                % application data as per the given packet size
                obj.pAppData = ones(obj.pMaxPayloadSize, 1);
            else  % Use given application data
                % Size of the given application data
                length = numel(obj.ApplicationData);
                obj.pAppData = zeros(obj.pMaxPayloadSize, 1);
                obj.pAppData(1 : min(length, obj.pMaxPayloadSize)) = obj.ApplicationData(1 : min(length, obj.pMaxPayloadSize));
            end
        end

        function generateNewPayload(obj, dataToGenerate)

            if dataToGenerate == 1
                % Generate new main object size
                pd = makedist('Lognormal','mu',obj.pMeanMainObjectSize,'sigma',obj.pStandardDeviationMainObjectSize);
                tpd = truncate(pd,obj.pLowerBoundMainObjectSize, obj.pUpperBoundMainObjectSize);
                newPayloadSize = round(random(tpd,1,1));
                obj.pMainObjectSize = newPayloadSize;
            else
                % Generate new embedded object size
                pd = makedist('Lognormal','mu',obj.pMeanEmbeddedObjectSize,'sigma',obj.pStandardDeviationEmbeddedObjectSize);
                tpd = truncate(pd,obj.pLowerBoundEmbeddedObjectSize, obj.pUpperBoundEmbeddedObjectSize);

                numEmbeddedObjects = round(generateNumberEmbeddedObjects(obj));
                newPayloadSize = sum(round(random(tpd,numEmbeddedObjects,1)));

                obj.pEmbeddedObjectSize = newPayloadSize;
            end

            % Calculate number of segments for new payload
            segmentsCount = ceil(newPayloadSize/obj.pMaxPayloadSize);

            obj.pLatencies = [obj.pLatencies; zeros(segmentsCount,1)];
            obj.pDataType = [obj.pDataType; ones(segmentsCount,1)*dataToGenerate];

            for i = numel(obj.pLatencies)-segmentsCount+1:numel(obj.pLatencies)
                obj.pLatencies(i) = obj.pCurrentTime;
            end

            [obj.pLatencies, sortingIndex] = sort(obj.pLatencies);
            obj.pDataType = obj.pDataType(sortingIndex);

            % Calculate jitter values for all the segments in the
            % video frame
            obj.pJitters = zeros(numel(obj.pLatencies),1);
            obj.pJitters(1) = obj.pLatencies(1) - obj.pCurrentTime;
            for i = 2 : numel(obj.pJitters)
                obj.pJitters(i) = obj.pLatencies(i) - obj.pLatencies(i-1);
            end
        end

        function nextTime = generateRandomParsingTime(obj)
            pd = makedist('Exponential','mu',obj.pMeanParsingTime);
            nextTime = random(pd,1,1);
        end

        function nextTime = generateRandomReadingTime(obj)
            pd = makedist('Exponential','mu',obj.pMeanReadingTime);
            nextTime = random(pd,1,1);
        end

        function Nd = generateNumberEmbeddedObjects(obj)
            paretoRandomValue = inf;
            while paretoRandomValue > 55
                uniformRandomValue = rand(1,1); % create pareto distribution via inverse transform sampling https://en.wikipedia.org/wiki/Pareto_distribution
                paretoRandomValue = (-(uniformRandomValue-1)/obj.pScaleParameterNumberOfEmbeddedObjects^obj.pShapeParameterNumberOfEmbeddedObjects)^(-1/obj.pShapeParameterNumberOfEmbeddedObjects); % letting H in https://en.wikipedia.org/wiki/Pareto_distribution go to infinity yields this formula
            end
            Nd = paretoRandomValue - obj.pScaleParameterNumberOfEmbeddedObjects;
        end

        function [dt, packetSize, payloadSize] = transmitSegment(obj, payloadSize)
            if payloadSize > obj.pMaxPayloadSize
                % Current packet size
                packetSize = obj.pMaxPayloadSize;
                dt = getNextInvokeTime(obj);
                % Update the remaining video frame size
                payloadSize = payloadSize - obj.pMaxPayloadSize;
            else % Last segment of the video frame
                % Current packet size
                packetSize = payloadSize;

                dt = getNextInvokeTime(obj);
                payloadSize = 0;
            end
        end

        function dt = getNextInvokeTime(obj)
            if numel(obj.pJitters) == 1
                obj.pJitters(end+1) = min(obj.pMainWebsiteObjectCountdown, obj.pEmbeddedObjectsCountdown);
                obj.pLatencies(end+1) = obj.pLatencies(end)+min(obj.pMainWebsiteObjectCountdown, obj.pEmbeddedObjectsCountdown);
                obj.pDataType(end+1) = 0;
            end

            % remove current values
            obj.pLatencies = obj.pLatencies(2:end);
            obj.pJitters = obj.pJitters(2:end);
            obj.pDataType = obj.pDataType(2:end);

            % get delta to next invoke time
            dt = obj.pJitters(1);
        end
    end
end
