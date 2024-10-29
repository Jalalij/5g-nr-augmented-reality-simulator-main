classdef networkTrafficDLBufferedVideo < comm_sysmod.internal.ConfigBaseHandle
    %this function generates IP packets of cloud rendering augmented reality
    % DL video traffic according to 3GPP TR 3.838 V17.0.0

    properties
        %FrameInterval Average time intervall between consecutive video
        % frames in miliseconds
        %   Specifiy the time intervall between consecutive frame generation
        %   in miliseconds
        FrameInterval = 1000/30;

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
        %pPrimaryVideoFrameSize Remaining size of the video frame yet to be packetized
        %   Remaining amount of frame in bytes which is not yet packetized by
        %   the generate object function.
        pVideoFrameSize = 0;

        %pNextInvokeTime Time in milliseconds after which the generate method
        % should be invoked again
        pNextInvokeTime = 0;

        %pCurrentTime Time in milliseconds since traffic was first
        %generated
        pCurrentTime = 0;

        %pDataType Type of payload the jitter and latency values are associated with
        % 0: no output (required to rund generater function)
        % 1: video object
        pDataType  = 0;

        %pAppData Application data to be filled in the packet as a column vector
        % of integers in the range [0, 255]
        %   If size of the input application data is greater than the packet
        %   size, the object truncates the input application data. If size of
        %   the application data is smaller than the packet size, the object
        %   appends zeros.
        pAppData = ones(1500, 1);

        %pJitters Latency values of all the segements to be sent
        %   latency is the transmission time of segments of payload
        %   in milliseconds
        pLatencies = 0;

        %pJitters Jitter values of all the segements to be sent
        %   Jitter is the time gap between two consecutive segments of payload
        %   in milliseconds
        pJitters = 0;

        %pAppDataUpdated Flag to indicate whether the application data is
        %updated
        pAppDataUpdated = false;

        pFrameCount = 0;

        pLambda = 20850;

        pK = 0.8099;

        %pMaxPayloadSize Maximum payload size in bytes excluding protocol overhead
        pMaxPayloadSize = 1460;      

        %PrimaryTimeOffset determines the time offset for the video
        %stream of the the first eye to start.
        %   Specify PrimaryExeTimeOffset value as time in miliseconds. If
        %   StreamingMethod is set to 'SingleEyeBuffer' this value
        %   determines the time offset for frames of both eyes
        %
        pTimeOffset = 0;
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
        function obj = networkTrafficDLBufferedVideo(varargin)
            obj@comm_sysmod.internal.ConfigBaseHandle(varargin{:});
            obj.pTimeOffset = rand()*obj.FrameInterval;
        end

        function setModelClass(obj, parameterSetName)
            validatestring(parameterSetName,{'BV1', 'BV2', 'BV3', 'BV4', 'BV5', 'BV6'});
            switch parameterSetName
                case 'BV1'
                    obj.pLambda = 6950;
                    obj.pK = 0.8099;
                case 'BV2'
                    obj.pLambda = 13900;
                    obj.pK = 0.8099;
                case 'BV3'
                    obj.pLambda = 20850;
                    obj.pK = 0.8099;
                case 'BV4'
                    obj.pLambda = 27800;
                    obj.pK = 0.8099;
                case 'BV5'
                    obj.pLambda = 34750;
                    obj.pK = 0.8099;
                case 'BV6'
                    obj.pLambda = 54210;
                    obj.pK = 0.8099;
            end
        end

        function set.FrameInterval(obj, value)
            % Validate FrameInterval value
            validateattributes(value, {'numeric'}, {'real', 'scalar', 'finite', ...
                '>', 0}, '', 'FrameInterval');
            obj.FrameInterval = value;
            obj.pTimeOffset = rand()*obj.FrameInterval;
        end

        function set.ProtocolOverhead(obj, value)
            % Validate protocol overheads value
            validateattributes(value, {'numeric'}, {'real', 'integer', 'scalar', ...
                '>=', 0, '<=', 60}, '', 'ProtocolOverhead');
            obj.ProtocolOverhead = value;
            obj.pMaxPayloadSize = obj.MaxPacketSize - obj.ProtocolOverhead;
            % Packet size has changed, update the application data to be added
            % in the packet as per given packet size
            updateAppData(obj);
        end

        function set.MaxPacketSize(obj, value)
            % Validate protocol overheads value
            obj.MaxPacketSize = value;
            obj.pMaxPayloadSize = obj.MaxPacketSize - obj.ProtocolOverhead;
            % Packet size has changed, update the application data to be added
            % in the packet as per given packet size
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
            %generate Generate next DL buffered video traffic packet

            narginchk(1, 2);
            nargoutchk(2, 3, 4);

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
                % New video frame is generated only if all the segments of the
                % last generated frame are sent
                if obj.pDataType(1) == 0
                    obj.generateNewPayload(obj.pFrameCount+1);
                end

                % output a segment
                switch obj.pDataType(1)
                    case 0 % payload type 0 means no packet to output
                        packetSize = 0;
                        dt = getNextInvokeTime(obj);
                        varargout{2} = 0;
                    otherwise
                        transmittedFrameNumber = obj.pDataType(1);
                        [dt, packetSize, obj.pVideoFrameSize(transmittedFrameNumber+1)] = obj.transmitSegment(obj.pVideoFrameSize(transmittedFrameNumber+1));
                        varargout{2} = transmittedFrameNumber;
                end

                dt = round(dt*1e6)/1e6; % Limiting dt to nanoseconds accuracy
                obj.pNextInvokeTime = dt;

                % If the flag to generate a packet is true, generate the packet
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

        function jitter = generateJitter(obj)
            % Generate random number using Gamma distribution
            pd = makedist('Gamma','a',0.2463,'b',60.227);
            jitter = random(pd,1,1);
        end

        function generateNewPayload(obj,frameNumberToGenerate)
            pd = makedist('Weibull','a',obj.pLambda,'b',obj.pK);
            newPayloadSize = round(random(pd,1,1));

            % Generate new video frame size using truncated Gaussian distribution
            obj.pVideoFrameSize(end+1) = newPayloadSize;

            % Calculate number of segments for new payload
            segmentsCount = ceil(newPayloadSize/obj.pMaxPayloadSize);
            obj.pLatencies = [obj.pLatencies; zeros(segmentsCount,1)];
            obj.pDataType = [obj.pDataType; ones(segmentsCount,1)*frameNumberToGenerate];

            % Calculate latency for each packet in milliseconds
            % using truncated Gaussian distribution
            for i = numel(obj.pLatencies)-segmentsCount+1:numel(obj.pLatencies)
                obj.pLatencies(i) = obj.generateJitter()+obj.pTimeOffset+obj.pFrameCount*obj.FrameInterval;
            end

            % add another invoke time at time of next frame generation
            obj.pDataType = [obj.pDataType; 0];
            obj.pLatencies = [obj.pLatencies; obj.pTimeOffset+(obj.pFrameCount+1)*obj.FrameInterval];

            [obj.pLatencies, sortingIndex] = sort(obj.pLatencies);
            obj.pDataType = obj.pDataType(sortingIndex);

            % Calculate jitter values for all the segments in the
            % video frame
            obj.pJitters = zeros(numel(obj.pLatencies),1);
            obj.pJitters(1) = obj.pLatencies(1) - obj.pCurrentTime;
            for i = 2 : numel(obj.pJitters)
                obj.pJitters(i) = obj.pLatencies(i) - obj.pLatencies(i-1);
            end

            obj.pFrameCount = obj.pFrameCount + 1;
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
                obj.pJitters(end+1) = obj.pFrameCount*obj.FrameInterval-obj.pCurrentTime;
                obj.pLatencies(end+1) = obj.pFrameCount*obj.FrameInterval;
                obj.pDataType(end+1) = 0;
            end

            obj.pLatencies = obj.pLatencies(2:end);
            obj.pJitters = obj.pJitters(2:end);
            obj.pDataType = obj.pDataType(2:end);
            dt = obj.pJitters(1); % Add jitter
        end
    end
end
