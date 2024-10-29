classdef networkTrafficARvideo < comm_sysmod.internal.ConfigBaseHandle
    %this function generates IP packets of cloud rendering augmented reality
    % DL video traffic according to 3GPP TR 3.838 V17.0.0

    properties
        %NumFramesRecoveryStart Number of frames before stream recovery
        %   Specify duration (as intager number of frames) until an I-frame
        %   is sent to recover the stream
        NumFramesRecoveryStart = inf;

        %FrameInterval Average time intervall between consecutive video
        % frames in miliseconds
        %   Specifiy the time intervall between consecutive frame generation
        %   in miliseconds
        FrameInterval = 1000/60;

        %JitterStdDeviation is the standard deviation of the truncated Gaussian
        % video frame generation jitter in miliseconds
        JitterStdDeviation = 2;

        %Jitter limits are the lower und upper limits of the truncated Gaussian
        % video frame generation jitter in miliseconds
        JitterLimits = [-4 4];

        %Data rate determines the average data rate of the stream in Megabit
        % per second
        DataRate = 30;

        %PacketSize Length of the packet to be generated in bytes
        %   Specify the packet size value as a positive scalar. If
        %   packet size is larger than the data generated in On time, the
        %   data is accumulated across multiple 'On' times to generate a
        %   packet. The default value is 1500.
        MaxPacketSize = 1500

        %StreamingMethod determines the steraming method as either
        % 'SingleEyeBuffer' or 'DualEyeBuffer'
        StreamingMethod {mustBeMember(StreamingMethod,{'SingleEyeBuffer','DualEyeBuffer'})} = 'SingleEyeBuffer';

        %VideoEncodingMethod determines the video encoding method as either
        % 'SingleStream', 'SliceBased' or 'GOPBased'
        %   'SingleStream': I and P-frames are not modelled according to
        %   the specified single stream model
        %   'SliceBased': a single video frame is dvided into N slices, 1
        %   I-slice and IFramePeriodicity-1 P-Slices
        %   'GOPBased': a video frame is either I- or P-frame, one I-frame
        %   every IFramePeriodicity frames
        VideoEncodingMethod {mustBeMember(VideoEncodingMethod,{'SingleStream','SliceBased', 'GOPBased'})} = 'SingleStream';

        %IFramePeriodicity determines the number of slices in a frame
        % when VideoEncodingMethod is set to 'SliceBased' and determines
        % how often I-frames are generated when VideoEncodingMethod is set
        % to 'GOPBased'
        IFramePeriodicity = 8;

        %SizeRatio describes the average size ratio between one I-frame/
        % I-Slice and one P-frame/P-slice
        SizeRatio = 2;

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
        %pTruncatedGaussianMean is the derrived mean of the truncated gaussian
        % packet size distribution in byte, if VideoEncodingMethod is not
        % SingleStream the mean corresponds to the P-frame mean
        pTruncatedGaussianMean =  62500;

        %pTruncatedGaussianSTD is the derrived standard deviation of the
        % truncated gaussian packet size distribution in byte
        pTruncatedGaussianSTD = 6562.5;

        %pIFrameTruncatedGaussianMean is the derrived mean of the
        % truncated gaussian I frame packet size distribution in byte,
        % only used when VideoEncodingMethod is not 'SingleStream'
        pIFrameTruncatedGaussianMean =  62500;

        %pTruncatedGaussianSTD is the derrived standard deviation of the
        % truncated gaussian I frame packet size distribution in byte,
        % only used when VideoEncodingMethod is not 'SingleStream'
        pIFrameTruncatedGaussianSTD = 6562.5;

        %pTruncatedGaussianSTD is the limit of the truncated gaussian packet
        % size distribution in byte
        pPacketSizeLimits = [31250 93750];

        %pIFramePacketSizeLimits is the limit of the truncated gaussian packet
        % size distribution in byte
        pIFramePacketSizeLimits = [31250 93750];

        %pPrimaryVideoFrameSize Remaining size of the video frame yet to be packetized
        %   Remaining amount of frame in bytes which is not yet packetized by
        %   the generate object function.
        pPrimaryVideoFrameSize = 0;

        pPrimaryFrameGenerationCountdown = 0;

        pPrimaryRecoveryInprogress = 0;

        %pPrimaryVideoFrameSize Remaining size of the video frame yet to be packetized
        %   Remaining amount of the second eye frame in bytes which is not yet
        %   packetized by the generate object function. Only required if
        %   StreamingMethod is set to 'DualEyeBuffer'
        pSecondaryVideoFrameSize = 0;

        pSecondaryFrameGenerationCountdown = 0;

        pSecondaryRecoveryInprogress = 0;

        %pNextInvokeTime Time in milliseconds after which the generate method
        % should be invoked again
        pNextInvokeTime = 0;

        %pCurrentTime Time in milliseconds since traffic was first
        %generated
        pCurrentTime = 0;

        pPrimaryFrameCount = 0;
        pSecondaryFrameCount = 0;

        %pAppData Application data to be filled in the packet as a column vector
        % of integers in the range [0, 255]
        %   If size of the input application data is greater than the packet
        %   size, the object truncates the input application data. If size of
        %   the application data is smaller than the packet size, the object
        %   appends zeros.
        pAppData = ones(1500, 1);

        %pCurrSegmentNum Current segment number in the video frame
        pCurrSegmentNum = 1;

        %Frame Array
        pFrame_Array = []; %[Frame_Type Frame_Count Total_Segments Current_Segment]

        %pJitters Latency values of all the segements to be sent
        %   latency is the transmission time of segments of payload
        %   in milliseconds
        pLatencies = 0;

        %pJitters Jitter values of all the segements to be sent
        %   Jitter is the time gap between two consecutive segments of payload
        %   in milliseconds
        pJitters = 0;

        %pEyeFrameType Type of payload the Jitter values are associated with
        % 1: primary eye video frame
        % 2: secondary eye video frame
        pEyeFrameType  = 0;

        %pFramesSinceLastIFrame Number of frames since the last I-frame was
        % sent. Only active if VideoEncodingMethod is set to 'GOPBased'
        pFramesSinceLastIFrame = 0;

        %pSecondaryFramesSinceLastIFrame Number of frames since the last I-frame was
        % sent for secondary eye. Only active if VideoEncodingMethod is
        % set to 'GOPBased' and streaming method is set to 'DualEyeBuffer'
        pSecondaryFramesSinceLastIFrame = 0;

        % pTxFrameSizes stores the frame size of transmitted frames
        pTxFrameSizes = zeros(256,1);

        % pRxFrameSizes stores the frame size of successfully received frames
        pRxFrameSizes = zeros(256,1);

        %pAppDataUpdated Flag to indicate whether the application data is
        %updated
        pAppDataUpdated = false;

        %pMaxPayloadSize Maximum payload size in bytes excluding protocol overhead
        pMaxPayloadSize = 1460;

        %PrimaryTimeOffset determines the time offset for the video
        %stream of the the first eye to start.
        %   Specify PrimaryExeTimeOffset value as time in miliseconds. If
        %   StreamingMethod is set to 'SingleEyeBuffer' this value
        %   determines the time offset for frames of both eyes
        %
        pPrimaryTimeOffset = 0;

        %SecondaryTimeOffset determines the time for the video stream
        % of the second eye to start.
        %   Specify SecondaryExeTimeOffset value as time in miliseconds.
        %   Only applies if StreamingMethod is set to 'DualEyeBuffer.
        pSecondaryTimeOffset = 8;
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
        function obj = networkTrafficARvideo(varargin)
            obj@comm_sysmod.internal.ConfigBaseHandle(varargin{:});
            obj.pSecondaryTimeOffset = rand()*obj.FrameInterval;
            obj.pPrimaryTimeOffset = rand()*obj.FrameInterval;
        end

        function setParameters3GPP(obj, parameterSetName)
            validatestring(parameterSetName,{'singleStreamDL_1', 'singleStreamDL_2', 'multiStreamSliceDL_1', 'multiStreamSliceDL_2', 'multiStreamSliceDL_3', 'multiStreamSliceDL_4', 'multiStreamGOPDL_1', 'multiStreamGOPDL_2', 'multiStreamGOPDL_3', 'multiStreamGOPDL_4', 'singleStreamUL_1', 'singleStreamUL_2'});
            switch parameterSetName
                case 'singleStreamDL_1'
                    obj.DataRate = 30;
                    obj.FrameInterval = 1000/60;
                case 'singleStreamDL_2'
                    obj.DataRate = 45;
                    obj.FrameInterval = 1000/60;
                case 'multiStreamSliceDL_1'
                    obj.DataRate = 30;
                    obj.SizeRatio = 2;
                    obj.FrameInterval = 1000/60;
                    obj.VideoEncodingMethod = 'SliceBased';
                case 'multiStreamSliceDL_2'
                    obj.DataRate = 45;
                    obj.SizeRatio = 2;
                    obj.FrameInterval = 1000/60;
                    obj.VideoEncodingMethod = 'SliceBased';
                case 'multiStreamSliceDL_3'
                    obj.DataRate = 30;
                    obj.SizeRatio = 1.5;
                    obj.FrameInterval = 1000/60;
                    obj.VideoEncodingMethod = 'SliceBased';
                case 'multiStreamSliceDL_4'
                    obj.DataRate = 45;
                    obj.SizeRatio = 1.5;
                    obj.FrameInterval = 1000/60;
                    obj.VideoEncodingMethod = 'SliceBased';
                case 'multiStreamGOPDL_1'
                    obj.DataRate = 30;
                    obj.SizeRatio = 2;
                    obj.FrameInterval = 1000/60;
                    obj.VideoEncodingMethod = 'GOPBased';
                case 'multiStreamGOPDL_2'
                    obj.DataRate = 45;
                    obj.SizeRatio = 2;
                    obj.FrameInterval = 1000/60;
                    obj.VideoEncodingMethod = 'GOPBased';
                case 'multiStreamGOPDL_3'
                    obj.DataRate = 30;
                    obj.SizeRatio = 1.5;
                    obj.FrameInterval = 1000/60;
                    obj.VideoEncodingMethod = 'GOPBased';
                case 'multiStreamGOPDL_4'
                    obj.DataRate = 45;
                    obj.SizeRatio = 1.5;
                    obj.FrameInterval = 1000/60;
                    obj.VideoEncodingMethod = 'GOPBased';
                case 'singleStreamUL_1'
                    obj.DataRate = 30;
                    obj.FrameInterval = 1000/60;
                case 'singleStreamUL_2'
                    obj.DataRate = 45;
                    obj.FrameInterval = 1000/60;
            end
            obj.updateParameters();
        end

        function set.FrameInterval(obj, value)
            % Validate FrameInterval value
            validateattributes(value, {'numeric'}, {'real', 'scalar', 'finite', ...
                '>', 0}, '', 'FrameInterval');
            obj.FrameInterval = value;

            obj.updateParameters();
        end

        function set.JitterStdDeviation(obj, value)
            % Validate JitterStdDeviation value
            validateattributes(value, {'numeric'}, {'real', 'scalar', 'finite', ...
                'nonnegative'}, '', 'JitterStdDeviation');
            obj.JitterStdDeviation = value;
        end

        function set.JitterLimits(obj, value)
            % Validate JitterLimits value
            validateattributes(value, {'numeric'}, {'2d', 'real', 'scalar', ...
                'nonnegative', 'finite'}, '', 'JitterLimits');
            obj.JitterLimits = value;
        end

        function set.DataRate(obj, value)
            % Validate DataRate value
            validateattributes(value, {'numeric'}, {'real', 'scalar', 'finite', ...
                'nonnegative'}, '', 'DataRate');
            obj.DataRate = value;

            obj.updateParameters();
        end

        function set.MaxPacketSize(obj, value)
            % Validate packet size value
            validateattributes(value, {'numeric'}, {'real', 'scalar', ...
                'finite', 'integer', '>', 0}, '', 'MaxPacketSize')
            obj.MaxPacketSize = value;
            obj.pMaxPayloadSize = obj.MaxPacketSize - obj.ProtocolOverhead;
            % Packet size has changed, update the application data to be added
            % in the packet as per given packet size
            updateAppData(obj);
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

        function set.StreamingMethod(obj, value)
            obj.StreamingMethod = value;
            obj.updateParameters();
        end

        function set.VideoEncodingMethod(obj, value)
            obj.VideoEncodingMethod = value;
            obj.updateParameters();
        end

        function set.IFramePeriodicity(obj, value)
            % Validate DataRate value
            validateattributes(value, {'numeric'}, {'real', 'scalar', 'finite', ...
                'nonnegative'}, '', 'IFramePeriodicity');
            obj.IFramePeriodicity = value;

            obj.updateParameters();
        end

        function set.SizeRatio(obj, value)
            % Validate DataRate value
            validateattributes(value, {'numeric'}, {'real', 'scalar', 'finite', ...
                'nonnegative'}, '', 'SizeRatio');
            obj.SizeRatio = value;

            obj.updateParameters();
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
            nargoutchk(2, 4, 4);

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

                if ~obj.pPrimaryVideoFrameSize && obj.pPrimaryFrameGenerationCountdown<=0
                    frameNumberAsBitSequence = [0; int2bit(obj.pPrimaryFrameCount+1,7)];
                    frameNumberAsByte = bit2int(frameNumberAsBitSequence,8); % 1 Byte frame number
                    [segmentsCount, I_P_FrameIndicator] = obj.generateNewPayload(1,obj.pPrimaryFrameCount+1);
                    obj.pPrimaryFrameCount = obj.pPrimaryFrameCount + 1;
                    obj.pFrame_Array = [obj.pFrame_Array; I_P_FrameIndicator obj.pPrimaryFrameCount segmentsCount 0];
                    % to include modeling of jitter for first packet of video
                    % frames, return a packet of size 0 and set next invoke time
                    % to first jitter value
                    obj.pPrimaryFrameGenerationCountdown = obj.FrameInterval;
                    obj.pRxFrameSizes(frameNumberAsByte+1) = 0;
                    obj.pTxFrameSizes(frameNumberAsByte+1) = 0;
                end
                if ~obj.pSecondaryVideoFrameSize && strcmp(obj.StreamingMethod, 'DualEyeBuffer') && obj.pSecondaryFrameGenerationCountdown<=0
                    frameNumberAsBitSequence = [1; int2bit(obj.pSecondaryFrameCount+1,7)];
                    frameNumberAsByte = bit2int(frameNumberAsBitSequence,8); % 1 Byte frame number
                    [segmentsCount, I_P_FrameIndicator] = obj.generateNewPayload(2,obj.pSecondaryFrameCount+1);
                    obj.pSecondaryFrameCount = obj.pSecondaryFrameCount + 1;
                    obj.pFrame_Array = [obj.pFrame_Array; I_P_FrameIndicator obj.pSecondaryFrameCount segmentsCount 0];
                    % to include modeling of jitter for first packet of video
                    % frames, return a packet of size 0 and set next invoke time
                    % to first jitter value
                    obj.pSecondaryFrameGenerationCountdown = obj.FrameInterval;
                    obj.pRxFrameSizes(frameNumberAsByte+1) = 0;
                    obj.pTxFrameSizes(frameNumberAsByte+1) = 0;
                end

                % output a segment
                switch obj.pEyeFrameType(1)
                    case 0 % payload type 0 means no packet to output
                        packetSize = 0;
                        dt = getNextInvokeTime(obj);
                        varargout{2} = {0};
                    case 1
                        [dt, packetSize, obj.pPrimaryVideoFrameSize] = obj.transmitSegment(obj.pPrimaryVideoFrameSize);
                        [result,loc] = ismember(obj.pPrimaryFrameCount,obj.pFrame_Array(:,2),'rows');
                        if result==1
                            obj.pFrame_Array(loc,4) = obj.pFrame_Array(loc,4) + 1;
                            varargout{2} = {obj.pFrame_Array(loc,:)};
                        end
                        % we use the preamble to transmit the frame number
                        % since knowledge over the frame number is needed
                        % for the recovery strategy
                        frameNumberAsByte = bit2int([0;int2bit(obj.pPrimaryFrameCount,7)],8); % 1 Byte frame number
                        header = [zeros(1,obj.ProtocolOverhead) frameNumberAsByte];
                        header = header(end-obj.ProtocolOverhead+1:end).';

                        % use the last byte for indexing the stored tx size
                        obj.pTxFrameSizes(frameNumberAsByte+1) = obj.pTxFrameSizes(frameNumberAsByte+1) + packetSize + obj.ProtocolOverhead;
                    case 2
                        [dt, packetSize, obj.pSecondaryVideoFrameSize] = obj.transmitSegment(obj.pSecondaryVideoFrameSize);
                        [result,loc] = ismember(obj.pSecondaryFrameCount,obj.pFrame_Array(:,2),'rows');
                        if result==1
                            obj.pFrame_Array(loc,4) = obj.pFrame_Array(loc,4) + 1;
                            varargout{2} = {obj.pFrame_Array(loc,:)};
                        end
                        % we use the preamble to transmit the frame number
                        % since knowledge over the frame number is needed
                        % for the recovery strategy
                        frameNumberAsByte = bit2int([1;int2bit(obj.pSecondaryFrameCount,7)],8); % 1 Byte frame number
                        header = [zeros(1,obj.ProtocolOverhead) frameNumberAsByte];
                        header = header(end-obj.ProtocolOverhead+1:end).';
                        % use the last byte for indexing the stored tx size
                        obj.pTxFrameSizes(frameNumberAsByte+1) = obj.pTxFrameSizes(frameNumberAsByte+1) + packetSize + obj.ProtocolOverhead;
                end

                dt = round(dt*1e6)/1e6; % Limiting dt to nanoseconds accuracy
                obj.pNextInvokeTime = dt;

                obj.pSecondaryFrameGenerationCountdown = obj.pSecondaryFrameGenerationCountdown - dt;
                obj.pSecondaryFrameGenerationCountdown = round(obj.pSecondaryFrameGenerationCountdown*1e6)/1e6; % Limiting dt to nanoseconds accuracy
                obj.pPrimaryFrameGenerationCountdown = obj.pPrimaryFrameGenerationCountdown - dt;
                obj.pPrimaryFrameGenerationCountdown = round(obj.pPrimaryFrameGenerationCountdown*1e6)/1e6; % Limiting dt to nanoseconds accuracy

                % If the flag to generate a packet is true, generate the packet
                if packetSize >0
                    if obj.GeneratePacket
                        varargout{1} = [header; obj.pAppData(1:packetSize, 1)];
                    end
                    packetSize = packetSize + obj.ProtocolOverhead;
                end
            else % Time is still remaining to generate the next frame
                dt = obj.pNextInvokeTime;
                packetSize = 0;
            end
        end
        function receiveFeedbackFromRx(obj,packet)
            header = packet(1:obj.ProtocolOverhead);
            frameNumber = header(end);
            obj.pRxFrameSizes(frameNumber+1) = obj.pRxFrameSizes(frameNumber+1) + numel(packet);
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

        function jitter = truncatedGaussianJitter(obj)
            % Generate random number using truncatedGaussianDistribution
            if obj.JitterLimits(1)<0
                pd = makedist('Normal','mu',-obj.JitterLimits(1),'sigma',obj.JitterStdDeviation);
                tpd = truncate(pd,0,-obj.JitterLimits(1)+obj.JitterLimits(2));
            else
                pd = makedist('Normal','mu',0,'sigma',obj.JitterStdDeviation);
                tpd = truncate(pd,obj.JitterLimits(1),obj.JitterLimits(2));
            end

            jitter = random(tpd,1,1);
        end

        function updateParameters(obj)
            if strcmp(obj.StreamingMethod, 'SingleEyeBuffer')
                effectiveDataRate = obj.DataRate;
            else
                effectiveDataRate = obj.DataRate/2;
            end

            if strcmp(obj.VideoEncodingMethod, 'SingleStream')
                obj.pTruncatedGaussianMean = effectiveDataRate*1e6/(1000/obj.FrameInterval)/8;
            elseif strcmp(obj.VideoEncodingMethod, 'SliceBased')
                obj.pTruncatedGaussianMean = (effectiveDataRate * 1/(obj.IFramePeriodicity-1+obj.SizeRatio))*1e6/(1000/obj.FrameInterval)/8;
                obj.pIFrameTruncatedGaussianMean = (effectiveDataRate * obj.SizeRatio/(obj.IFramePeriodicity-1+obj.SizeRatio))*1e6/(1000/obj.FrameInterval)/8;
            elseif strcmp(obj.VideoEncodingMethod, 'GOPBased')
                obj.pTruncatedGaussianMean = (effectiveDataRate * obj.IFramePeriodicity * 1/(obj.IFramePeriodicity-1+obj.SizeRatio))*1e6/(1000/obj.FrameInterval)/8;
                obj.pIFrameTruncatedGaussianMean = (effectiveDataRate * obj.IFramePeriodicity * obj.SizeRatio/(obj.IFramePeriodicity-1+obj.SizeRatio))*1e6/(1000/obj.FrameInterval)/8;

                % random time since last I-frame such that individual
                % users do not have guaranteed I-frames at the same time
                obj.pFramesSinceLastIFrame = min(floor(rand(1,1)*obj.IFramePeriodicity));
                obj.pSecondaryFramesSinceLastIFrame = min(floor(rand(1,1)*obj.IFramePeriodicity));
            end

            if strcmp(obj.VideoEncodingMethod, 'SliceBased') || strcmp(obj.VideoEncodingMethod, 'GOPBased')
                obj.pIFrameTruncatedGaussianSTD = 0.105*obj.pIFrameTruncatedGaussianMean;
                obj.pIFramePacketSizeLimits = [0.5*obj.pIFrameTruncatedGaussianMean 1.5*obj.pIFrameTruncatedGaussianMean];
            end

            obj.pTruncatedGaussianSTD = 0.105*obj.pTruncatedGaussianMean;
            obj.pPacketSizeLimits = [0.5*obj.pTruncatedGaussianMean 1.5*obj.pTruncatedGaussianMean];

            obj.pSecondaryTimeOffset = rand()*obj.FrameInterval;
            obj.pPrimaryTimeOffset = rand()*obj.FrameInterval;
        end


        function [segmentsCount, I_P_FrameIndicator] = generateNewPayload(obj, eyeFrameTypeToGenerate, frameNumberToGenerate)
            if strcmp(obj.VideoEncodingMethod,'SingleStream')
                pd = makedist('Normal','mu',obj.pTruncatedGaussianMean,'sigma',obj.pTruncatedGaussianSTD);
                tpd = truncate(pd,obj.pPacketSizeLimits(1),obj.pPacketSizeLimits(2));
                newPayloadSize = round(random(tpd,1,1));
                I_P_FrameIndicator = 0; % neither I-frame, nor P-frame
            elseif strcmp(obj.VideoEncodingMethod,'SliceBased')
                % generate P-Slice distribution
                pdPFrame = makedist('Normal','mu',obj.pTruncatedGaussianMean,'sigma',obj.pTruncatedGaussianSTD);
                tpdPFrame = truncate(pdPFrame,obj.pPacketSizeLimits(1),obj.pPacketSizeLimits(2));

                % generate I-Slice distribution
                pdIFrame = makedist('Normal','mu',obj.pIFrameTruncatedGaussianMean,'sigma',obj.pTruncatedGaussianSTD);
                tpdIFrame = truncate(pdIFrame,obj.pIFramePacketSizeLimits(1),obj.pIFramePacketSizeLimits(2));

                newPayloadSize = round(random(tpdIFrame,1,1)) + round(random(tpdPFrame,1,1));
                I_P_FrameIndicator = 0; % neither I-frame, nor P-frame
            elseif strcmp(obj.VideoEncodingMethod,'GOPBased')
                if eyeFrameTypeToGenerate == 1
                    timeSinceLastIFrame = obj.pFramesSinceLastIFrame;
                else
                    timeSinceLastIFrame = obj.pSecondaryFramesSinceLastIFrame;
                end

                transmittedFrameNumber = bit2int([int2bit(frameNumberToGenerate,7)],7);
                % check if previous frame is at the other end of the array
                % since the index is only 7 bit

                if ~isinf(obj.NumFramesRecoveryStart)
                    if transmittedFrameNumber - obj.NumFramesRecoveryStart <0
                        previousTransmittedFrameNumber = 128 + (transmittedFrameNumber - obj.NumFramesRecoveryStart);
                    else
                        previousTransmittedFrameNumber = transmittedFrameNumber - obj.NumFramesRecoveryStart;
                    end

                    transmittedFrameNumber = bit2int([eyeFrameTypeToGenerate-1; int2bit(transmittedFrameNumber,7)],8);
                    previousTransmittedFrameNumber = bit2int([eyeFrameTypeToGenerate-1; int2bit(previousTransmittedFrameNumber,7)],8);
                end

                % if recovery is already in process send P-frames
                if frameNumberToGenerate == 1 || isinf(obj.NumFramesRecoveryStart)
                    lastFrameSuccessfull = true;
                % if previous frame has not arrived yet (transmission error or latency too high)
                elseif obj.pRxFrameSizes(previousTransmittedFrameNumber+1) < obj.pTxFrameSizes(previousTransmittedFrameNumber+1)
                    lastFrameSuccessfull = false;
                else
                    lastFrameSuccessfull = true;
                end

                % recoveryInProgress counter used to only transmit P-frames
                % after an I-frame when its reception is not yet clear
                if eyeFrameTypeToGenerate == 1
                    if obj.pPrimaryRecoveryInprogress > 0
                        obj.pPrimaryRecoveryInprogress = obj.pPrimaryRecoveryInprogress - 1;
                    end
                    recoveryInProgress = obj.pPrimaryRecoveryInprogress;
                else
                    if obj.pSecondaryRecoveryInprogress > 0
                        obj.pSecondaryRecoveryInprogress = obj.pSecondaryRecoveryInprogress - 1;
                    end
                    recoveryInProgress = obj.pSecondaryRecoveryInprogress;
                end

                if timeSinceLastIFrame >= obj.IFramePeriodicity-1 || (~lastFrameSuccessfull && recoveryInProgress==0) % generate I-frame
                    pdIFrame = makedist('Normal','mu',obj.pIFrameTruncatedGaussianMean,'sigma',obj.pTruncatedGaussianSTD);
                    tpdIFrame = truncate(pdIFrame,obj.pIFramePacketSizeLimits(1),obj.pIFramePacketSizeLimits(2));
                    newPayloadSize = round(random(tpdIFrame,1,1));

                    timeSinceLastIFrame = 0;

                    I_P_FrameIndicator = 2; % indicates I-frame

                    if eyeFrameTypeToGenerate == 1
                        obj.pPrimaryRecoveryInprogress = obj.NumFramesRecoveryStart;
                    else
                        obj.pSecondaryRecoveryInprogress = obj.NumFramesRecoveryStart;
                    end

                else % generate P-frame
                    pd = makedist('Normal','mu',obj.pTruncatedGaussianMean,'sigma',obj.pTruncatedGaussianSTD);
                    tpd = truncate(pd,obj.pPacketSizeLimits(1),obj.pPacketSizeLimits(2));
                    newPayloadSize = round(random(tpd,1,1));

                    timeSinceLastIFrame = timeSinceLastIFrame+1;

                    I_P_FrameIndicator = 1; % indicates P-frame
                end

                if eyeFrameTypeToGenerate == 1
                    obj.pFramesSinceLastIFrame = timeSinceLastIFrame;
                else
                    obj.pSecondaryFramesSinceLastIFrame = timeSinceLastIFrame;
                end
            end

            if eyeFrameTypeToGenerate == 1
                % Generate new video frame size using truncated Gaussian distribution
                obj.pPrimaryVideoFrameSize = newPayloadSize;
            else
                % Generate new video frame size using truncated Gaussian distribution
                obj.pSecondaryVideoFrameSize = newPayloadSize;
            end

            % Calculate number of segments for new payload
            segmentsCount = ceil(newPayloadSize/obj.pMaxPayloadSize);
            obj.pLatencies = [obj.pLatencies; zeros(segmentsCount,1)];
            obj.pEyeFrameType = [obj.pEyeFrameType; ones(segmentsCount,1)*eyeFrameTypeToGenerate];
            if eyeFrameTypeToGenerate == 1
                % Calculate latency for each packet in milliseconds
                % using truncated Gaussian distribution
                currentJitter = obj.truncatedGaussianJitter();
                for i = numel(obj.pLatencies)-segmentsCount+1:numel(obj.pLatencies)
                    obj.pLatencies(i) = currentJitter+obj.pPrimaryTimeOffset+obj.pPrimaryFrameCount*obj.FrameInterval;
                end
            elseif eyeFrameTypeToGenerate == 2
                currentJitter = obj.truncatedGaussianJitter();
                for i = numel(obj.pLatencies)-segmentsCount+1:numel(obj.pLatencies)
                    obj.pLatencies(i) = currentJitter+obj.pSecondaryTimeOffset+obj.pSecondaryFrameCount*obj.FrameInterval;
                end
            end
            [obj.pLatencies, sortingIndex] = sort(obj.pLatencies);
            obj.pEyeFrameType = obj.pEyeFrameType(sortingIndex);

            % Calculate jitter values for all the segments in the
            % video frame
            obj.pJitters = zeros(numel(obj.pLatencies),1);
            obj.pJitters(1) = obj.pLatencies(1) - obj.pCurrentTime;
            for i = 2 : numel(obj.pJitters)
                obj.pJitters(i) = obj.pLatencies(i) - obj.pLatencies(i-1);
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

                if numel(obj.pJitters) == 1
                    if strcmp(obj.StreamingMethod,'DualEyeBuffer')
                        obj.pJitters(end+1) = min(obj.pPrimaryFrameGenerationCountdown, obj.pSecondaryFrameGenerationCountdown);
                        obj.pLatencies(end+1) = min(obj.pPrimaryFrameCount*obj.FrameInterval,obj.pPrimaryFrameCount*obj.FrameInterval);
                    else
                        obj.pJitters(end+1) = obj.pPrimaryFrameGenerationCountdown;
                        obj.pLatencies(end+1) = obj.pPrimaryFrameCount*obj.FrameInterval;
                    end

                    obj.pEyeFrameType(end+1) = 0;
                end

                dt = getNextInvokeTime(obj);
                payloadSize = 0;
            end
        end
        function dt = getNextInvokeTime(obj)
            obj.pLatencies = obj.pLatencies(2:end);
            obj.pJitters = obj.pJitters(2:end);
            obj.pEyeFrameType = obj.pEyeFrameType(2:end);
            dt = obj.pJitters(1); % Add jitter
        end
    end
end
