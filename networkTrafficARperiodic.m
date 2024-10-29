classdef networkTrafficARperiodic < comm_sysmod.internal.ConfigBaseHandle
    %this function generates IP packets of cloud rendering augmented reality
    % DL data/audio traffic according to 3GPP TR 3.838 V17.0.0

    properties
        %PayloadSize Length of the data to be generated in bytes
        %   Specify the data size value as a positive scalar. 
        PayloadSize = 100;

        %PayloadPeriodicity Intervall of data generation in miliseconds
        %   Specifiy the time intervall between consecutive data generation
        %   in miliseconds
        PayloadPeriodicity = 4;

        %MaxPacketSize Length of the packet to be generated in bytes
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
        %pPayloadGenerationCountdown Latency values of all the segements to be sent
        %   latency is the transmission time of segments of payload
        %   in milliseconds
        pPayloadGenerationCountdown = 0;

        pRemainingPayloadSize = 0;

        %pJitters Latency values of all the segements to be sent
        %   latency is the transmission time of segments of payload
        %   in milliseconds
        pLatencies = 0;

        %pJitters Jitter values of all the segements to be sent
        %   Jitter is the time gap between two consecutive segments of payload
        %   in milliseconds
        pTimeDeltas = 0;

        %pNextInvokeTime Time in milliseconds after which the generate method
        % should be invoked again
        pNextInvokeTime = 0;

        %pOutputActive Type of payload the Jitter values are associated with 
        % 1: primary eye video frame
        % 2: secondary eye video frame
        pOutputActive  = 0;

        %pAppData Application data to be filled in the packet as a column vector
        % of integers in the range [0, 255]
        %   If size of the input application data is greater than the packet
        %   size, the object truncates the input application data. If size of
        %   the application data is smaller than the packet size, the object
        %   appends zeros.
        pAppData = ones(1500, 1);

        %pCurrSegmentNum Current segment number in the video frame
        pCurrSegmentNum = 1;

        %pAppDataUpdated Flag to indicate whether the application data is
        %updated
        pAppDataUpdated = false;

        %pMaxPayloadSize Maximum payload size in bytes excluding protocol overhead
        pMaxPayloadSize = 1460;

        %PrimaryTimeOffset determines the time offset for the data to start
        %   Specify DataTimeOffset value as time in miliseconds. 
        pDataTimeOffset = 0;
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
        function obj = networkTrafficARperiodic(varargin)
            obj@comm_sysmod.internal.ConfigBaseHandle(varargin{:});
            obj.pDataTimeOffset = rand() * obj.PayloadPeriodicity;  
        end

        function setParameters3GPP(obj, parameterSetName)
            validatestring(parameterSetName,{'audio/data_1', 'audio/data_2', 'pose/control'});
            switch parameterSetName
                case 'audio/data_1'
                    obj.PayloadPeriodicity = 10;
                    dataRate = 0.756;
                    obj.PayloadSize = dataRate*1e6*obj.PayloadPeriodicity/1e3/8;
                case 'audio/data_2'
                    obj.PayloadPeriodicity = 10;
                    dataRate = 1.12;
                    obj.PayloadSize = dataRate*1e6*obj.PayloadPeriodicity/1e3/8;
                case 'pose/control'
                    obj.PayloadPeriodicity = 4;
                    obj.PayloadSize = 100;
            end
            obj.pDataTimeOffset = rand() * obj.PayloadPeriodicity;
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

        function set.PayloadPeriodicity(obj, value)
            obj.PayloadPeriodicity = value;
            obj.pDataTimeOffset = rand() * obj.PayloadPeriodicity;  
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
            nargoutchk(2, 3);

            if isempty(varargin)
                obj.pNextInvokeTime = 0;
            else
                % Validate elapsed time value
                validateattributes(varargin{1}, {'numeric'}, {'real', 'scalar', ...
                    'finite', '>=', 0}, '', 'ElapsedTime');
                % Calculate time remaining before generating next packet
                obj.pNextInvokeTime = obj.pNextInvokeTime - varargin{1};
            end
            varargout{1} = zeros(0, 1); % Application packet
            if obj.pNextInvokeTime <= 0
                % New video frame is generated only if all the segments of the
                % last generated frame are sent
                if ~obj.pRemainingPayloadSize && obj.pPayloadGenerationCountdown<=0
                    obj.generateNewPayload();
                    % to include modeling of jitter for first packet of video
                    % frames, return a packet of size 0 and set next invoke time
                    % to first jitter value
                    obj.pPayloadGenerationCountdown = obj.PayloadPeriodicity;
                end

                % output a segment
                if obj.pOutputActive(1)
                    [dt, packetSize, obj.pRemainingPayloadSize] = obj.transmitSegment(obj.pRemainingPayloadSize);
                else
                    packetSize = 0;
                    dt = getNextInvokeTime(obj);
                end

                dt = round(dt*1e6)/1e6; % Limiting dt to nanoseconds accuracy
                obj.pNextInvokeTime = dt;

                obj.pPayloadGenerationCountdown = obj.pPayloadGenerationCountdown - dt;
                obj.pPayloadGenerationCountdown = round(obj.pPayloadGenerationCountdown*1e6)/1e6; % Limiting dt to nanoseconds accuracy

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


        function generateNewPayload(obj)
            newPayloadSize = obj.PayloadSize;

            obj.pRemainingPayloadSize = newPayloadSize;

            % Calculate number of segments for new payload
            segmentsCount = ceil(newPayloadSize/obj.pMaxPayloadSize);
            obj.pLatencies = [obj.pLatencies; ones(segmentsCount,1) * obj.pDataTimeOffset];
            obj.pOutputActive = [obj.pOutputActive; ones(segmentsCount,1)];

            [obj.pLatencies, sortingIndex] = sort(obj.pLatencies);
            obj.pOutputActive = obj.pOutputActive(sortingIndex);

            % Calculate jitter values for all the segments in the
            % video frame
            obj.pTimeDeltas = zeros(numel(obj.pLatencies),1);
            obj.pTimeDeltas(1) = obj.pLatencies(1);
            for i = 2 : numel(obj.pTimeDeltas)
                obj.pTimeDeltas(i) = obj.pLatencies(i) - obj.pLatencies(i-1);
            end
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

                if numel(obj.pTimeDeltas) == 1
                    obj.pTimeDeltas(end+1) = obj.pPayloadGenerationCountdown;
                    obj.pLatencies(end+1) = 0;
                    obj.pOutputActive(end+1) = 0;
                end

                dt = getNextInvokeTime(obj);
                payloadSize = 0;
            end
        end
        function dt = getNextInvokeTime(obj)
            obj.pLatencies = obj.pLatencies(2:end);
            obj.pTimeDeltas = obj.pTimeDeltas(2:end);
            obj.pOutputActive = obj.pOutputActive(2:end);
            dt = obj.pTimeDeltas(1); 
        end
    end
end
