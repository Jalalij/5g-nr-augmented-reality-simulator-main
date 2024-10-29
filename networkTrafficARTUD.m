classdef networkTrafficARTUD < comm_sysmod.internal.ConfigBaseHandle
    %this function generates IP packets according to [1]
    % [1] P. Schulz et.al., "Analysis and Modeling of Downlink Traffic in Cloud-Rendering Architectures for Augmented Reality"

    properties 
        Resolution = '8K'; % has to be either '8K' or '1080p'
        UseCase = 'Navigation'; % has to be either 'Navigation' or '3DVolumetricCall'

        %NumFramesRecoveryStart Number of frames before stream recovery
        %   Specify duration (as intager number of frames) until an I-frame
        %   is sent to recover the stream
        NumFramesRecoveryStart = inf;

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

        %IFramePeriodicity determines how often periodic I-frames are generated
        IFramePeriodicity = 8;

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

        %pLatencies Latency values of all the segements to be sent
        %   latency is the transmission time of segments of payload
        %   in milliseconds
        pLatencies = 0;

        %pJitters Jitter values of all the segments in the video frame
        %   Jitter is the time gap between two consecutive segments of a frame
        %   in milliseconds
        pJitters = zeros(1, 10);

        %pAppDataUpdated Flag to indicate whether the application data is
        %updated
        pAppDataUpdated = false;

        %pMaxPayloadSize Maximum payload size in bytes excluding protocol overhead
        pMaxPayloadSize = 1460;

        %pTimeOffset determines the time offset for the video
        %stream to start.
        %   Specify PrimaryExeTimeOffset value as time in miliseconds. If
        %   StreamingMethod is set to 'SingleEyeBuffer' this value
        %   determines the time offset for frames of both eyes
        %
        pTimeOffset = 0;

        % pIframeSizes is a temporary storages for I frames to be generated
        pIframeSizes = [];
        % pIframeSizes is a temporary storages for P frames to be generated
        pPframeSizes = [];

        % pFrameCount is a counter for the frames to be generated
        pFrameCount = 0;

        %Frame Array is an array in the format [Frame_Type Frame_Count Total_Segments Current_Segment]
        % Frame_Type: if 1 -> P-frame; if 2 -> I-frame
        % Frame_Count: counter for the current frame
        % Total_Segments: number of segments the frame is divided into
        % Current_Segment: current number of the transmitted segment
        pFrame_Array = []; 

        % pTxFrameSizes stores the frame size of transmitted frames
        pTxFrameSizes = zeros(256,1);

        % pRxFrameSizes stores the frame size of successfully received frames
        pRxFrameSizes = zeros(256,1);

        % pLostFramesCount stores the number of lost frames
        pLostFramesCount = 0;

        % pTxDataRate stores the number of transmitted bytes
        pTxFrameBytes = 0;

        %pFramesSinceLastIFrame Number of frames since the last I-frame was
        % sent.
        pFramesSinceLastIFrame = 0;

        pRecoveryInprogress = 0;
    end

    properties (Constant)
        FrameInterval = 1000/60; % [ms]
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
        function obj = networkTrafficARTUD(varargin)
            obj@comm_sysmod.internal.ConfigBaseHandle(varargin{:});
            obj.pTimeOffset = rand()*obj.FrameInterval; % traffic model is fixed to 60 FPS
        end

        function set.UseCase(obj, value)
            obj.UseCase = value;
            updateAppData(obj);
            generateTraffic(obj);
        end

        function set.Resolution(obj, value)
            obj.Resolution = value;
            updateAppData(obj);
            generateTraffic(obj);
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

        function set.IFramePeriodicity(obj, value)
            obj.IFramePeriodicity = value;

            % random time since last I-frame such that individual
            % users do not have guaranteed I-frames at the same time
            obj.pFramesSinceLastIFrame = min(floor(rand(1,1)*obj.IFramePeriodicity));
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
                    frameNumberAsByte = bit2int(int2bit(obj.pFrameCount+1,8),8); % 1 Byte frame number
                    [segmentsCount, I_P_FrameIndicator] = obj.generateNewPayload(obj.pFrameCount+1);
                    obj.pFrame_Array = [obj.pFrame_Array; I_P_FrameIndicator obj.pFrameCount segmentsCount 0];
                    obj.pRxFrameSizes(frameNumberAsByte+1) = 0;
                    obj.pTxFrameSizes(frameNumberAsByte+1) = 0;
                end

                % output a segment
                switch obj.pDataType(1)
                    case 0 % payload type 0 means no packet to output
                        packetSize = 0;
                        dt = getNextInvokeTime(obj);
                        varargout{2} = {0};
                    otherwise
                        transmittedFrameNumber = obj.pDataType(1);
                        [dt, packetSize, obj.pVideoFrameSize(transmittedFrameNumber+1)] = obj.transmitSegment(obj.pVideoFrameSize(transmittedFrameNumber+1));
                        [result,loc] = ismember(obj.pFrameCount,obj.pFrame_Array(:,2),'rows');
                        if result==1
                            obj.pFrame_Array(loc,4) = obj.pFrame_Array(loc,4) + 1;
                            varargout{2} = {obj.pFrame_Array(loc,:)};
                        end

                        % we use the preamble to transmit the frame number
                        % since knowledge over the frame number is needed
                        % for the recovery strategy
                        frameNumberAsByte = bit2int(int2bit(transmittedFrameNumber,8),8); % 1 Byte frame number
                        header = [zeros(1,obj.ProtocolOverhead) frameNumberAsByte];
                        header = header(end-obj.ProtocolOverhead+1:end).';

                        % use the last byte for indexing the stored tx size
                        obj.pTxFrameSizes(frameNumberAsByte+1) = obj.pTxFrameSizes(frameNumberAsByte+1) + packetSize + obj.ProtocolOverhead;
                end

                dt = round(dt*1e6)/1e6; % Limiting dt to nanoseconds accuracy
                obj.pNextInvokeTime = dt;

                % If the flag to generate a packet is true, generate the packet
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

        function stats = getStatistics(obj)
            simulationTime = obj.pFrameCount * obj.FrameInterval / 1000; % [s]
            LFPS = obj.pLostFramesCount / simulationTime;
            DR = obj.pTxFrameBytes / simulationTime * 8 / 1e6; % [Mbit/s]
            stats = [LFPS, DR];
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

        function generateTraffic(obj)
            randomTrafficModelStart = 10000+randi(10000); % start of the traffic model seems to perform differently compared to the rest
            N=10000+randomTrafficModelStart;
            switch obj.Resolution
                case '1080p'
                    switch obj.UseCase
                        case 'Navigation'
                            IFrameTrafficModel = NavigationTrafficModel_IFramesOnly_1080p(obj);
                            PFrameTrafficModel = NavigationTrafficModel_PFramesOnly_1080p(obj);
                        case '3DVolumetricCall'
                            IFrameTrafficModel = VolumetricCallTrafficModel_IFramesOnly_1080p(obj);
                            PFrameTrafficModel = VolumetricCallTrafficModel_PFramesOnly_1080p(obj);
                    end
                case '8K'
                    switch obj.UseCase
                        case 'Navigation'
                            IFrameTrafficModel = NavigationTrafficModel_IFramesOnly_8K(obj);
                            PFrameTrafficModel = NavigationTrafficModel_PFramesOnly_8K(obj);
                        case '3DVolumetricCall'
                            IFrameTrafficModel = VolumetricCallTrafficModel_IFramesOnly_8K(obj);
                            PFrameTrafficModel = VolumetricCallTrafficModel_PFramesOnly_8K(obj);
                    end
            end

            [~, obj.pIframeSizes] = traffic_simulation(obj, N+2, IFrameTrafficModel); % generate one frame extra because sometimes there will be a NaN on last value
            obj.pIframeSizes= obj.pIframeSizes(randomTrafficModelStart:end-1); % account for bug in original traffic model
            while any(obj.pIframeSizes>10^7)
                [~, obj.pIframeSizes] = traffic_simulation(obj, N+2, IFrameTrafficModel); % generate one frame extra because sometimes there will be a NaN on last value
                obj.pIframeSizes = obj.pIframeSizes(randomTrafficModelStart:end-1); % account for bug in original traffic model
            end
            obj.pIframeSizes = round(obj.pIframeSizes); % rount to integer bytes

            [~, obj.pPframeSizes] = traffic_simulation(obj, N+2, PFrameTrafficModel); % generate one frame extra because sometimes there will be a NaN on last value
            obj.pPframeSizes = obj.pPframeSizes(randomTrafficModelStart:end-1); % account for bug in original traffic model
            while any(obj.pPframeSizes>10^7)
                [~, obj.pPframeSizes] = traffic_simulation(obj, N+2, PFrameTrafficModel); % generate one frame extra because sometimes there will be a NaN on last value
                obj.pPframeSizes = obj.pPframeSizes(randomTrafficModelStart:end-1); % account for bug in original traffic model
            end
            obj.pPframeSizes = round(obj.pPframeSizes); % round to integer bytes

        end

        function [segmentsCount, I_P_FrameIndicator] = generateNewPayload(obj,frameNumberToGenerate)

            if frameNumberToGenerate > numel(obj.pIframeSizes)
                error("Current implementation does not support such a long simulation time")
            end


            transmittedFrameNumber = bit2int(int2bit(frameNumberToGenerate,8),8);
            % check if previous frame is at the other end of the array
            % since the index is only 1 Byte
            if ~isinf(obj.NumFramesRecoveryStart)
                if transmittedFrameNumber - obj.NumFramesRecoveryStart < 0
                    previousTransmittedFrameNumber = 256 + (transmittedFrameNumber - obj.NumFramesRecoveryStart);
                else
                    previousTransmittedFrameNumber = transmittedFrameNumber - obj.NumFramesRecoveryStart;
                end
            end

            % if recovery is already in process send P-frames
            if frameNumberToGenerate == 1 || isinf(obj.NumFramesRecoveryStart)
                lastFrameSuccessfull = true;
            elseif obj.pRxFrameSizes(previousTransmittedFrameNumber+1) < obj.pTxFrameSizes(previousTransmittedFrameNumber+1)
                lastFrameSuccessfull = false;
                obj.pLostFramesCount = obj.pLostFramesCount + 1;
            else
                lastFrameSuccessfull = true;
            end

            if obj.pRecoveryInprogress > 0 
                obj.pRecoveryInprogress = obj.pRecoveryInprogress - 1;
            end

            if obj.pFramesSinceLastIFrame >= obj.IFramePeriodicity-1 || (~lastFrameSuccessfull && obj.pRecoveryInprogress==0) % generate I-frame
                newPayloadSize = obj.pIframeSizes(frameNumberToGenerate);
                obj.pFramesSinceLastIFrame = 0;
                I_P_FrameIndicator = 2; % indicates I-frame

                obj.pRecoveryInprogress = obj.NumFramesRecoveryStart;
            else
                newPayloadSize = obj.pPframeSizes(frameNumberToGenerate);
                obj.pFramesSinceLastIFrame = obj.pFramesSinceLastIFrame + 1;
                I_P_FrameIndicator = 1;
            end

            obj.pTxFrameBytes = obj.pTxFrameBytes + newPayloadSize;

            % Generate new video frame size using truncated Gaussian distribution
            obj.pVideoFrameSize(end+1) = newPayloadSize;

            % Calculate number of segments for new payload
            segmentsCount = ceil(newPayloadSize/obj.pMaxPayloadSize);
            obj.pLatencies = [obj.pLatencies; zeros(segmentsCount,1)];
            obj.pDataType = [obj.pDataType; ones(segmentsCount,1)*frameNumberToGenerate];

            % Calculate latency for each packet in milliseconds
            % using truncated Gaussian distribution
            for i = numel(obj.pLatencies)-segmentsCount+1:numel(obj.pLatencies)
                obj.pLatencies(i) = obj.pTimeOffset+obj.pFrameCount*obj.FrameInterval;
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

        function Dist = DiscreteDist(obj, Probabilities, Values)
            % Returns a (dummy) Distribution for a discrete Random Variable
            % (only the random function is implemented so far)
            %
            % Input:
            %     Probabilities ... Column Vector of probabilities
            %     Values        ... Column Vecotr of associated Values

            assert(all(size(Probabilities) == size(Values) ));

            Dist = struct();
            Dist.DistributionName = 'Discrete';
            Dist.Probabilities = Probabilities;
            Dist.Values =  Values;
            Dist.random = @(varargin) discrete_random(obj, [Probabilities, Values], varargin{:} ) ;

            Dist.mean = sum(Probabilities .* Values);

            tmp  = Values - Dist.mean;
            Dist.var = sum(Probabilities .* tmp.^2);

        end

        function y = delayedsum(obj, coeff, x)
            % calulates the sum_i=1^p coeff_i x_(N-i)
            % with p = length(coeff)
            %      N = length(X)
            %
            % if p > N only the first N coeffs are considered
            %

            coeff = ensure_col(obj, coeff);
            x     = ensure_col(obj, x);

            p = length(coeff);
            N = length(x);

            if p > N
                ptilde = N;
            else
                ptilde = p;
            end

            y = sum(  coeff(1:ptilde) .* x(end:-1:end-ptilde+1) );
        end

        function y = bounded_ARIMA(obj, N, model, y0)
            % Implements a bounded ARIMA process
            %
            % INPUT:
            %   N ....... number of values to simulate
            %   model ... struct containing all model parameters
            %             See an example in DefaultTrafficModel.m (PFrameModel)
            %     .bounds ... 1x2 lower and upper bound (can be inf)
            %     .AR ... coefficients of the auto-regressive part (alphas)
            %     .MA ... coefficients of the moving-average part (betas)
            %     .D .... Integration order (0 or 1)
            %     .Constant ... Constant drift
            %     .EpsilonDistribution ... Distribution of the Random Variable in each
            %                              time step
            %   y0 ...... Initial Value (Default 0)
            %
            % OUTPUT:
            %   y ....... Nx1 vector containing the simulated values


            if nargin < 3
                y0 = 0;
            end

            if ~isfield(model, 'bounds') || isempty(model.bounds)
                model.bounds = [-inf, inf];
            end

            lb = model.bounds(1);
            ub = model.bounds(2);

            assert(lb < ub);

            % P = model.P;
            % Q = model.Q;
            D = model.D;

            assert(D <= 1);

            alphas = model.AR;
            betas  = model.MA;
            delta  = model.Constant;

            if iscell(alphas)
                alphas = cell2mat(alphas);
            end
            if iscell(betas)
                betas = cell2mat(betas);
            end

            eps_dist = model.EpsilonDistribution;

            y = nan(N, 1);
            yd = nan(N, 1);
            % epsilons = nan(N,1);
            epsilons = eps_dist.random(N,1); % faster approach: pre-sample + apply bounds only when necessary.

            lenalp = length(alphas);
            lenbet = length(betas);

            lasty = y0;
            for fi = 1:N
                if fi > 2
                    yd(fi-2) = y(fi-1) - y(fi-2);
                end
                if D==0
                    %         yt = y(1:fi-1);
                    Z = delta + delayedsum(obj, alphas, y(max(1, fi-lenalp):fi-1)) + delayedsum(obj, betas, epsilons(max(1, fi-lenbet):fi-1));
                elseif D==1
                    %         yt = diff(y(1:fi-1), D);
                    Z = delta + delayedsum(obj, alphas, yd(max(1, fi-lenalp-1):fi-2)) + delayedsum(obj, betas, epsilons(max(1, fi-lenbet):fi-1));
                else
                    %yt = diff(y(1:fi-1), D);
                    Z = nan;
                    warning('D > 1 not yet implemented');
                end
                %     epst = epsilons(1:fi-1);

                %     Z = delta + delayedsum(obj, alphas, yt) + delayedsum(obj, betas, epst);
                % Z = delta + delayedsum(obj, alphas, yt) + delayedsum(obj, betas, epsilons(1:fi-1));

                eps_bounds = [lb, ub] - Z;
                if D==1
                    eps_bounds = eps_bounds -lasty;
                end

                if epsilons(fi) < eps_bounds(1) || epsilons(fi) > eps_bounds(2)
                    % resample:
                    if diff(eps_dist.cdf(eps_bounds)) <= 0
                        % truncation not possible (probability < 0)
                        if epsilons(fi) > eps_bounds(2)
                            % enforce negative epsilon
                            eps_bounds = [-inf, 0];
                        else
                            % enforce positive epsilon
                            eps_bounds = [0, inf];
                        end
                    end
                    trunc_dist = truncate(eps_dist, eps_bounds(1), eps_bounds(2));
                    epsilons(fi) = trunc_dist.random(1);
                end

                switch D
                    case 0
                        y(fi) = Z + epsilons(fi);
                    case 1
                        y(fi) = lasty + Z + epsilons(fi);
                    otherwise
                        warning('D > 1 not yet implemented');
                end

                %
                lasty = y(fi);
            end
        end

        function A = ensure_col(obj, A)

            A = reshape(A, numel(A), 1);

        end

        function samples = discrete_random(obj, pmf_table, varargin)
            % samples random values according to a given pmf_table
            %
            % pmf_table(:,1) ... probabilities
            % pmf_table(:,2) ... values
            %
            % varargin ... desired dimensions (same as the builtin random(...))

            r = rand(varargin{:});

            samples = nan(size(r));

            cdf = cumsum(pmf_table(:,1));
            cdf = cdf / cdf(end); % normalize to 1, if necessary.

            for si = 1:numel(samples)
                ind = find( r(si) < cdf, 1, 'first');
                samples(si) = pmf_table(ind,2);
            end
        end

        function TrafficModel = VolumetricCallTrafficModel_IFramesOnly_8K(obj)
            % This Function contains (and explains) the default parameters (as obtained from the video
            % data) of the Traffic Model.
            %
            % One Convenient way could be to load this model and modify it where
            % necessary.

            TrafficModel = struct();

            %% General:
            % TrafficModel.General.fps = 60;
            % Distribution for frame inter arrival times (fixed to 1 / 60fps ):
            TrafficModel.InterArrivalTimeDist = DiscreteDist(obj, 1, 1/60);

            %% P Frames:
            % This model is used (in the log domain!) for the P-Frames in the independent mode:
            TrafficModel.PFrameModel.LogFrameSizeDist = makedist('Normal', 'mu', 10.3375, 'sigma', 0.514037);
            % This model is used (in the log domain!) for the first P-Frame of a busy period (only for ARIMA)
            TrafficModel.PFrameModel.LogInitFrameSizeDist = TrafficModel.PFrameModel.LogFrameSizeDist;% makedist('Normal', 'mu', 7.42196, 'sigma', 1.48805);
            % ... but with a certain probability the size of the last P-Frame of the previous period will be used
            %     (set to 0 to turn off)
            TrafficModel.PFrameModel.ContinueProbability = 0.5;
            % TrafficModel.PFrameModel.Type = 'independent';
            TrafficModel.PFrameModel.Type = 'ARIMA';
            % ARIMA Parameters:
            % Overall Model Coefficients
            TrafficModel.PFrameModel.D       = [1];
            TrafficModel.PFrameModel.AR       = [-0.994937	-0.990372	];
            TrafficModel.PFrameModel.MA       = [0.472854	0.457152	-0.471012	];
            TrafficModel.PFrameModel.Constant =  0.000591068	;
            TrafficModel.PFrameModel.Var      =  0.0413492	;
            TrafficModel.PFrameModel.EpsilonDistribution = makedist('Normal', 'mu', 0, 'sigma', TrafficModel.PFrameModel.Var);
            % Bounds of the ARIMA process (in the log domain):
            TrafficModel.PFrameModel.bounds  = [4.36945 12.1046];
            % Distribution of P-Frames when the process is idle:
            TrafficModel.PFrameModel.IdleLogDistribution = makedist('Normal', 'mu', 5.15142, 'sigma', 0.949468);
            %% Key Frames:
            % Interval of Key Frames (counted in frames):
            TrafficModel.KeyFrameModel.IntervalDistribution   = DiscreteDist(obj, 1, 1); % fixed to 250
            % Bound the Key Frames:
            TrafficModel.KeyFrameModel.Bounds                 = [0 exp(13.5243)];
            % Correlate (in the log domain) the busy Key-Frames with the P-Frames (works best with both being log-normally distributed)
            TrafficModel.KeyFrameModel.BusyPFrameCorrelation        = 0.741337;
            % Distribution of the busy Key Frames:
            TrafficModel.KeyFrameModel.BusyLogDistribution = makedist('Normal', 'mu', 12.3887, 'sigma', 0.248395);
            % Distribution of the idle Key Frames:
            TrafficModel.KeyFrameModel.IdleLogDistribution = DiscreteDist(obj, [1], [11.8292]);
            %% Busy / Idle:
            % Distributions of the busy and idle period lengths (counted in frames, will be rounded later:
            % TrafficModel.StateModel.BusyFramesModel = makedist('Exponential', 'mu', 972.609);
            % TrafficModel.StateModel.IdleFramesModel = makedist('Exponential', 'mu', 42.6667);
            TrafficModel.StateModel.BusyFramesModel = DiscreteDist(obj, 1, inf);
            TrafficModel.StateModel.IdleFramesModel = DiscreteDist(obj, 1, 0);

        end

        function TrafficModel = VolumetricCallTrafficModel_PFramesOnly_1080p()
            % This Function contains (and explains) the default parameters (as obtained from the video
            % data) of the Traffic Model. for 1080p resolution, no key frames.
            %

            TrafficModel = struct();

            %% General:
            % TrafficModel.General.fps = 60;
            % Distribution for frame inter arrival times (fixed to 1 / 60fps ):
            TrafficModel.InterArrivalTimeDist = DiscreteDist(obj, 1, 1/60);

            %% P Frames:
            % This model is used (in the log domain!) for the P-Frames in the independent mode:
            TrafficModel.PFrameModel.LogFrameSizeDist = makedist('Normal', 'mu', 8.30783, 'sigma', 0.436414);
            % This model is used (in the log domain!) for the first P-Frame of a busy period (only for ARIMA)
            TrafficModel.PFrameModel.LogInitFrameSizeDist = makedist('Normal', 'mu', 6.71973, 'sigma', 0.682123);
            % ... but with a certain probability the size of the last P-Frame of the previous period will be used
            %     (set to 0 to turn off)
            TrafficModel.PFrameModel.ContinueProbability = 0.2;
            % TrafficModel.PFrameModel.Type = 'independent';
            TrafficModel.PFrameModel.Type = 'ARIMA';
            % ARIMA Parameters:
            % Overall Model Coefficients
            TrafficModel.PFrameModel.D       = [1];
            TrafficModel.PFrameModel.AR       = [-0.992072	-0.985663	];
            TrafficModel.PFrameModel.MA       = [0.347367	0.336548	-0.597504	];
            TrafficModel.PFrameModel.Constant =  0.00211516	;
            TrafficModel.PFrameModel.Var      =  0.0318153	;
            TrafficModel.PFrameModel.EpsilonDistribution = makedist('Normal', 'mu', 0, 'sigma', TrafficModel.PFrameModel.Var);
            % Bounds of the ARIMA process (in the log domain):
            TrafficModel.PFrameModel.bounds  = [4.85203 10.1155];
            % Distribution of P-Frames when the process is idle:
            TrafficModel.PFrameModel.IdleLogDistribution = makedist('Normal', 'mu', 4.89659, 'sigma', 0.123582);
            %% Key Frames:
            % Interval of Key Frames (counted in frames):
            % TrafficModel.KeyFrameModel.IntervalDistribution   = DiscreteDist(1, 250); % fixed to 250
            % set Key frame intervals to infinity (first frame will still be a key frame)
            TrafficModel.KeyFrameModel.IntervalDistribution = DiscreteDist(obj, 1, inf);
            % Bound the Key Frames:
            TrafficModel.KeyFrameModel.Bounds                 = [0 exp(9.51281)];
            % Correlate (in the log domain) the busy Key-Frames with the P-Frames (works best with both being log-normally distributed)
            TrafficModel.KeyFrameModel.BusyPFrameCorrelation        = -0.0240897;
            % Distribution of the busy Key Frames:
            TrafficModel.KeyFrameModel.BusyLogDistribution = makedist('Normal', 'mu', 9.10303, 'sigma', 0.24324);
            % Distribution of the idle Key Frames:
            TrafficModel.KeyFrameModel.IdleLogDistribution = DiscreteDist(obj, [1], [8.47595]);
            %% Busy / Idle:
            % Distributions of the busy and idle period lengths (counted in frames, will be rounded later:
            TrafficModel.StateModel.BusyFramesModel = makedist('Exponential', 'mu', 1265.74);
            TrafficModel.StateModel.IdleFramesModel = makedist('Exponential', 'mu', 58.7273);
        end

        function TrafficModel = VolumetricCallTrafficModel_PFramesOnly_8K(obj)
            % This Function contains (and explains) the default parameters (as obtained from the video
            % data) of the Traffic Model.
            %
            % One Convenient way could be to load this model and modify it where
            % necessary.

            TrafficModel = struct();

            %% General:
            % TrafficModel.General.fps = 60;
            % Distribution for frame inter arrival times (fixed to 1 / 60fps ):
            TrafficModel.InterArrivalTimeDist = DiscreteDist(obj, 1, 1/60);

            %% P Frames:
            % This model is used (in the log domain!) for the P-Frames in the independent mode:
            TrafficModel.PFrameModel.LogFrameSizeDist = makedist('Normal', 'mu', 10.3375, 'sigma', 0.514037);
            % This model is used (in the log domain!) for the first P-Frame of a busy period (only for ARIMA)
            TrafficModel.PFrameModel.LogInitFrameSizeDist = TrafficModel.PFrameModel.LogFrameSizeDist;% makedist('Normal', 'mu', 7.42196, 'sigma', 1.48805);
            % ... but with a certain probability the size of the last P-Frame of the previous period will be used
            %     (set to 0 to turn off)
            TrafficModel.PFrameModel.ContinueProbability = 0.5;
            % TrafficModel.PFrameModel.Type = 'independent';
            TrafficModel.PFrameModel.Type = 'ARIMA';
            % ARIMA Parameters:
            % Overall Model Coefficients
            TrafficModel.PFrameModel.D       = [1];
            TrafficModel.PFrameModel.AR       = [-0.994937	-0.990372	];
            TrafficModel.PFrameModel.MA       = [0.472854	0.457152	-0.471012	];
            TrafficModel.PFrameModel.Constant =  0.000591068	;
            TrafficModel.PFrameModel.Var      =  0.0413492	;
            TrafficModel.PFrameModel.EpsilonDistribution = makedist('Normal', 'mu', 0, 'sigma', TrafficModel.PFrameModel.Var);
            % Bounds of the ARIMA process (in the log domain):
            TrafficModel.PFrameModel.bounds  = [4.36945 12.1046];
            % Distribution of P-Frames when the process is idle:
            TrafficModel.PFrameModel.IdleLogDistribution = makedist('Normal', 'mu', 5.15142, 'sigma', 0.949468);
            %% Key Frames:
            % Interval of Key Frames (counted in frames):
            TrafficModel.KeyFrameModel.IntervalDistribution   = DiscreteDist(obj, 1, inf); % fixed to 250
            % Bound the Key Frames:
            TrafficModel.KeyFrameModel.Bounds                 = [0 exp(13.5243)];
            % Correlate (in the log domain) the busy Key-Frames with the P-Frames (works best with both being log-normally distributed)
            TrafficModel.KeyFrameModel.BusyPFrameCorrelation        = 0.741337;
            % Distribution of the busy Key Frames:
            TrafficModel.KeyFrameModel.BusyLogDistribution = makedist('Normal', 'mu', 12.3887, 'sigma', 0.248395);
            % Distribution of the idle Key Frames:
            TrafficModel.KeyFrameModel.IdleLogDistribution = DiscreteDist(obj, [1], [11.8292]);
            %% Busy / Idle:
            % Distributions of the busy and idle period lengths (counted in frames, will be rounded later:
            % TrafficModel.StateModel.BusyFramesModel = makedist('Exponential', 'mu', 972.609);
            % TrafficModel.StateModel.IdleFramesModel = makedist('Exponential', 'mu', 42.6667);
            TrafficModel.StateModel.BusyFramesModel = DiscreteDist(obj, 1, inf);
            TrafficModel.StateModel.IdleFramesModel = DiscreteDist(obj, 1, 0);
        end

        function TrafficModel = VolumetricCallTrafficModel_IFramesOnly_1080p(obj)
            % This Function contains (and explains) the default parameters (as obtained from the video
            % data) of the Traffic Model. for 1080p resolution, no key frames.
            %

            TrafficModel = struct();

            %% General:
            % TrafficModel.General.fps = 60;
            % Distribution for frame inter arrival times (fixed to 1 / 60fps ):
            TrafficModel.InterArrivalTimeDist = DiscreteDist(1, 1/60);

            %% P Frames:
            % This model is used (in the log domain!) for the P-Frames in the independent mode:
            TrafficModel.PFrameModel.LogFrameSizeDist = makedist('Normal', 'mu', 8.30783, 'sigma', 0.436414);
            % This model is used (in the log domain!) for the first P-Frame of a busy period (only for ARIMA)
            TrafficModel.PFrameModel.LogInitFrameSizeDist = makedist('Normal', 'mu', 6.71973, 'sigma', 0.682123);
            % ... but with a certain probability the size of the last P-Frame of the previous period will be used
            %     (set to 0 to turn off)
            TrafficModel.PFrameModel.ContinueProbability = 0.2;
            % TrafficModel.PFrameModel.Type = 'independent';
            TrafficModel.PFrameModel.Type = 'ARIMA';
            % ARIMA Parameters:
            % Overall Model Coefficients
            TrafficModel.PFrameModel.D       = [1];
            TrafficModel.PFrameModel.AR       = [-0.992072	-0.985663	];
            TrafficModel.PFrameModel.MA       = [0.347367	0.336548	-0.597504	];
            TrafficModel.PFrameModel.Constant =  0.00211516	;
            TrafficModel.PFrameModel.Var      =  0.0318153	;
            TrafficModel.PFrameModel.EpsilonDistribution = makedist('Normal', 'mu', 0, 'sigma', TrafficModel.PFrameModel.Var);
            % Bounds of the ARIMA process (in the log domain):
            TrafficModel.PFrameModel.bounds  = [4.85203 10.1155];
            % Distribution of P-Frames when the process is idle:
            TrafficModel.PFrameModel.IdleLogDistribution = makedist('Normal', 'mu', 4.89659, 'sigma', 0.123582);
            %% Key Frames:
            % Interval of Key Frames (counted in frames):
            % TrafficModel.KeyFrameModel.IntervalDistribution   = DiscreteDist(1, 250); % fixed to 250
            % set Key frame intervals to infinity (first frame will still be a key frame)
            TrafficModel.KeyFrameModel.IntervalDistribution = DiscreteDist(1, 1);
            % Bound the Key Frames:
            TrafficModel.KeyFrameModel.Bounds                 = [0 exp(9.51281)];
            % Correlate (in the log domain) the busy Key-Frames with the P-Frames (works best with both being log-normally distributed)
            TrafficModel.KeyFrameModel.BusyPFrameCorrelation        = -0.0240897;
            % Distribution of the busy Key Frames:
            TrafficModel.KeyFrameModel.BusyLogDistribution = makedist('Normal', 'mu', 9.10303, 'sigma', 0.24324);
            % Distribution of the idle Key Frames:
            TrafficModel.KeyFrameModel.IdleLogDistribution = DiscreteDist(obj, [1], [8.47595]);
            %% Busy / Idle:
            % Distributions of the busy and idle period lengths (counted in frames, will be rounded later:
            TrafficModel.StateModel.BusyFramesModel = makedist('Exponential', 'mu', 1265.74);
            TrafficModel.StateModel.IdleFramesModel = makedist('Exponential', 'mu', 58.7273);
        end

        function TrafficModel = NavigationTrafficModel_IFramesOnly_8K(obj)
            % This Function contains (and explains) the default parameters (as obtained from the video
            % data) of the Traffic Model.
            %
            % One Convenient way could be to load this model and modify it where
            % necessary.


            TrafficModel = struct();

            %% General:
            % TrafficModel.General.fps = 60;
            % Distribution for frame inter arrival times (fixed to 1 / 60fps ):
            TrafficModel.InterArrivalTimeDist = DiscreteDist(obj, 1, 1/60);

            %% P Frames:
            % This model is used (in the log domain!) for the P-Frames in the independent mode:
            TrafficModel.PFrameModel.LogFrameSizeDist = makedist('Normal', 'mu', 9.5286, 'sigma', 0.784133);

            % This model is used (in the log domain!) for the first P-Frame of a busy period (only for ARIMA)
            TrafficModel.PFrameModel.LogInitFrameSizeDist = makedist('Normal', 'mu', 7.93411, 'sigma', 1.5759);
            % ... but with a certain probability the size of the last P-Frame of the previous period will be used
            %     (set to 0 to turn off)
            TrafficModel.PFrameModel.ContinueProbability = 0.8;
            % TrafficModel.PFrameModel.ContinueProbability = 0.0;

            % TrafficModel.PFrameModel.Type = 'independent';
            TrafficModel.PFrameModel.Type = 'ARIMA';

            % ARIMA Parameters:
            TrafficModel.PFrameModel.D        = 1;
            % TrafficModel.PFrameModel.AR       = [-0.104166	0.574846	0.209096	0.0901297	0.0442575	];
            % TrafficModel.PFrameModel.MA       = [-0.372604	-0.665013	0.0837112	];
            % TrafficModel.PFrameModel.Constant =  1.15354e-05	;
            % TrafficModel.PFrameModel.Var      =  0.0633286	;
            TrafficModel.PFrameModel.AR       = [-0.642442	-0.340076	-0.161739	-0.116258	-0.0742357	-0.0627455	-0.0362322	-0.0593347	];
            TrafficModel.PFrameModel.MA       = [0.172323	];
            TrafficModel.PFrameModel.Constant =  8.81407e-05	;
            TrafficModel.PFrameModel.Var      =  0.0635221	;
            TrafficModel.PFrameModel.EpsilonDistribution = makedist('Normal', 'mu', 0, 'sigma', sqrt(TrafficModel.PFrameModel.Var ));

            % Bounds of the ARIMA process (in the log domain):
            TrafficModel.PFrameModel.bounds  = log( [500 1e5] );

            % Distribution of P-Frames when the process is idle:
            TrafficModel.PFrameModel.IdleLogDistribution = DiscreteDist(obj, 1, log(70));

            %% Key Frames:
            % Interval of Key Frames (counted in frames)
            TrafficModel.KeyFrameModel.IntervalDistribution   = DiscreteDist(obj, 1, 1); % fixed to 250
            % Bound the Key Frames:
            TrafficModel.KeyFrameModel.Bounds                 = [0 exp(12.58)];
            % Correlate (in the log domain) the busy Key-Frames with the P-Frames (works best with both being log-normally distributed)
            TrafficModel.KeyFrameModel.BusyPFrameCorrelation        = 0.63;

            % Distribution of the busy Key Frames:
            busy_mu    = 12.0508;
            busy_sigma = 0.162503;
            TrafficModel.KeyFrameModel.BusyLogDistribution = makedist('Normal', 'mu', busy_mu, 'sigma', busy_sigma);

            % Distribution of the idle Key Frames:
            TrafficModel.KeyFrameModel.IdleLogDistribution = makedist('Normal', 'mu', 11.84, 'sigma', 0.05);
            % TrafficModel.KeyFrameModel.IdleLogDistribution = DiscreteDist(obj, 1, round(11.84));

            % obsolete
            % TrafficModel.KeyFrameModel.BusyDistribution    = makedist('LogNormal', 'mu', busy_mu, 'sigma',busy_sigma);
            % TrafficModel.KeyFrameModel.IdleDistribution    = makedist('LogNormal', 'mu', 11.84, 'sigma', 0.05);


            %% Busy / Idle:
            % Distributions of the busy and idle period lengths (counted in frames, will be rounded later):
            TrafficModel.StateModel.BusyFramesModel = makedist('Exponential', 'mu', 412.536);
            TrafficModel.StateModel.IdleFramesModel = makedist('Exponential', 'mu', 139.189);

        end

        function TrafficModel = NavigationTrafficModel_IFramesOnly_1080p(obj)
            % This Function contains (and explains) the parameters (as obtained from the video
            % data) of the Traffic Model for the navigation use case in 1080p
            % resolution. (with keyframes only at the start)
            %
            TrafficModel = struct();

            %% General:
            % TrafficModel.General.fps = 60;
            % Distribution for frame inter arrival times (fixed to 1 / 60fps ):
            TrafficModel.InterArrivalTimeDist = DiscreteDist(obj, 1, 1/60);

            %% P Frames:
            % This model is used (in the log domain!) for the P-Frames in the independent mode:
            TrafficModel.PFrameModel.LogFrameSizeDist = makedist('Normal', 'mu', 8.12579, 'sigma', 0.454317);
            % This model is used (in the log domain!) for the first P-Frame of a busy period (only for ARIMA)
            TrafficModel.PFrameModel.LogInitFrameSizeDist = makedist('Normal', 'mu', 7.03877, 'sigma', 0.880261);
            % ... but with a certain probability the size of the last P-Frame of the previous period will be used
            %     (set to 0 to turn off)
            TrafficModel.PFrameModel.ContinueProbability = 0.4;
            % TrafficModel.PFrameModel.Type = 'independent';
            TrafficModel.PFrameModel.Type = 'ARIMA';
            % ARIMA Parameters:
            % Overall Model Coefficients
            TrafficModel.PFrameModel.D       = [1];
            TrafficModel.PFrameModel.AR       = [0.865553	0.0212779	0.0721626	];
            TrafficModel.PFrameModel.MA       = [-1.31911	0.326399	];
            TrafficModel.PFrameModel.Constant =  2.40275e-05	;
            TrafficModel.PFrameModel.Var      =  0.0324771	;
            TrafficModel.PFrameModel.EpsilonDistribution = makedist('Normal', 'mu', 0, 'sigma', TrafficModel.PFrameModel.Var);
            % Bounds of the ARIMA process (in the log domain):
            TrafficModel.PFrameModel.bounds  = [5.02388 9.32367];
            % Distribution of P-Frames when the process is idle:
            TrafficModel.PFrameModel.IdleLogDistribution = makedist('Normal', 'mu', 4.8993, 'sigma', 0.107087);
            %% Key Frames:
            % Interval of Key Frames (counted in frames):
            % TrafficModel.KeyFrameModel.IntervalDistribution   = DiscreteDist(obj, 1, 250); % fixed to 250
            % set Key frame intervals to infinity (first frame will still be a key frame)
            TrafficModel.KeyFrameModel.IntervalDistribution = DiscreteDist(obj, 1, 1);
            % Bound the Key Frames:
            TrafficModel.KeyFrameModel.Bounds                 = [0 exp(9.10209)];
            % Correlate (in the log domain) the busy Key-Frames with the P-Frames (works best with both being log-normally distributed)
            TrafficModel.KeyFrameModel.BusyPFrameCorrelation  = 0.662501;
            % Distribution of the busy Key Frames:
            TrafficModel.KeyFrameModel.BusyLogDistribution = makedist('Normal', 'mu', 8.7598, 'sigma', 0.207139);
            % Distribution of the idle Key Frames:
            TrafficModel.KeyFrameModel.IdleLogDistribution = DiscreteDist(obj, [1], [8.47408]);
            %% Busy / Idle:
            % Distributions of the busy and idle period lengths (counted in frames, will be rounded later:
            TrafficModel.StateModel.BusyFramesModel = makedist('Exponential', 'mu', 335.515);
            TrafficModel.StateModel.IdleFramesModel = makedist('Exponential', 'mu', 141.01);
            %% END GENERATED CODE FOR TRAFFIC MODEL CONFIGURATION
        end

        function TrafficModel = NavigationTrafficModel_PFramesOnly_8K(obj)
            % This Function contains (and explains) the default parameters (as obtained from the video
            % data) of the Traffic Model.
            %
            % One Convenient way could be to load this model and modify it where
            % necessary.


            TrafficModel = struct();

            %% General:
            % TrafficModel.General.fps = 60;
            % Distribution for frame inter arrival times (fixed to 1 / 60fps ):
            TrafficModel.InterArrivalTimeDist = DiscreteDist(obj, 1, 1/60);

            %% P Frames:
            % This model is used (in the log domain!) for the P-Frames in the independent mode:
            TrafficModel.PFrameModel.LogFrameSizeDist = makedist('Normal', 'mu', 9.5286, 'sigma', 0.784133);

            % This model is used (in the log domain!) for the first P-Frame of a busy period (only for ARIMA)
            TrafficModel.PFrameModel.LogInitFrameSizeDist = makedist('Normal', 'mu', 7.93411, 'sigma', 1.5759);
            % ... but with a certain probability the size of the last P-Frame of the previous period will be used
            %     (set to 0 to turn off)
            TrafficModel.PFrameModel.ContinueProbability = 0.8;
            % TrafficModel.PFrameModel.ContinueProbability = 0.0;

            % TrafficModel.PFrameModel.Type = 'independent';
            TrafficModel.PFrameModel.Type = 'ARIMA';

            % ARIMA Parameters:
            TrafficModel.PFrameModel.D        = 1;
            % TrafficModel.PFrameModel.AR       = [-0.104166	0.574846	0.209096	0.0901297	0.0442575	];
            % TrafficModel.PFrameModel.MA       = [-0.372604	-0.665013	0.0837112	];
            % TrafficModel.PFrameModel.Constant =  1.15354e-05	;
            % TrafficModel.PFrameModel.Var      =  0.0633286	;
            TrafficModel.PFrameModel.AR       = [-0.642442	-0.340076	-0.161739	-0.116258	-0.0742357	-0.0627455	-0.0362322	-0.0593347	];
            TrafficModel.PFrameModel.MA       = [0.172323	];
            TrafficModel.PFrameModel.Constant =  8.81407e-05	;
            TrafficModel.PFrameModel.Var      =  0.0635221	;
            TrafficModel.PFrameModel.EpsilonDistribution = makedist('Normal', 'mu', 0, 'sigma', sqrt(TrafficModel.PFrameModel.Var ));

            % Bounds of the ARIMA process (in the log domain):
            TrafficModel.PFrameModel.bounds  = log( [500 1e5] );

            % Distribution of P-Frames when the process is idle:
            TrafficModel.PFrameModel.IdleLogDistribution = DiscreteDist(obj, 1, log(70));

            %% Key Frames:
            % Interval of Key Frames (counted in frames)
            TrafficModel.KeyFrameModel.IntervalDistribution   = DiscreteDist(obj, 1, inf); % fixed to 250
            % Bound the Key Frames:
            TrafficModel.KeyFrameModel.Bounds                 = [0 exp(12.58)];
            % Correlate (in the log domain) the busy Key-Frames with the P-Frames (works best with both being log-normally distributed)
            TrafficModel.KeyFrameModel.BusyPFrameCorrelation        = 0.63;

            % Distribution of the busy Key Frames:
            busy_mu    = 12.0508;
            busy_sigma = 0.162503;
            TrafficModel.KeyFrameModel.BusyLogDistribution = makedist('Normal', 'mu', busy_mu, 'sigma', busy_sigma);

            % Distribution of the idle Key Frames:
            TrafficModel.KeyFrameModel.IdleLogDistribution = makedist('Normal', 'mu', 11.84, 'sigma', 0.05);
            % TrafficModel.KeyFrameModel.IdleLogDistribution = DiscreteDist(obj, 1, round(11.84));

            % obsolete
            % TrafficModel.KeyFrameModel.BusyDistribution    = makedist('LogNormal', 'mu', busy_mu, 'sigma',busy_sigma);
            % TrafficModel.KeyFrameModel.IdleDistribution    = makedist('LogNormal', 'mu', 11.84, 'sigma', 0.05);


            %% Busy / Idle:
            % Distributions of the busy and idle period lengths (counted in frames, will be rounded later):
            TrafficModel.StateModel.BusyFramesModel = makedist('Exponential', 'mu', 412.536);
            TrafficModel.StateModel.IdleFramesModel = makedist('Exponential', 'mu', 139.189);

        end

        function TrafficModel = NavigationTrafficModel_PFramesOnly_1080p(obj)
            % This Function contains (and explains) the parameters (as obtained from the video
            % data) of the Traffic Model for the navigation use case in 1080p
            % resolution. (with keyframes only at the start)
            %

            TrafficModel = struct();

            %% General:
            % TrafficModel.General.fps = 60;
            % Distribution for frame inter arrival times (fixed to 1 / 60fps ):
            TrafficModel.InterArrivalTimeDist = DiscreteDist(obj, 1, 1/60);


            %% BEGIN GENERATED CODE FOR TRAFFIC MODEL CONFIGURATION
            %% P Frames:
            % This model is used (in the log domain!) for the P-Frames in the independent mode:
            TrafficModel.PFrameModel.LogFrameSizeDist = makedist('Normal', 'mu', 8.12579, 'sigma', 0.454317);
            % This model is used (in the log domain!) for the first P-Frame of a busy period (only for ARIMA)
            TrafficModel.PFrameModel.LogInitFrameSizeDist = makedist('Normal', 'mu', 7.03877, 'sigma', 0.880261);
            % ... but with a certain probability the size of the last P-Frame of the previous period will be used
            %     (set to 0 to turn off)
            TrafficModel.PFrameModel.ContinueProbability = 0.4;
            % TrafficModel.PFrameModel.Type = 'independent';
            TrafficModel.PFrameModel.Type = 'ARIMA';
            % ARIMA Parameters:
            % Overall Model Coefficients
            TrafficModel.PFrameModel.D       = [1];
            TrafficModel.PFrameModel.AR       = [0.865553	0.0212779	0.0721626	];
            TrafficModel.PFrameModel.MA       = [-1.31911	0.326399	];
            TrafficModel.PFrameModel.Constant =  2.40275e-05	;
            TrafficModel.PFrameModel.Var      =  0.0324771	;
            TrafficModel.PFrameModel.EpsilonDistribution = makedist('Normal', 'mu', 0, 'sigma', TrafficModel.PFrameModel.Var);
            % Bounds of the ARIMA process (in the log domain):
            TrafficModel.PFrameModel.bounds  = [5.02388 9.32367];
            % Distribution of P-Frames when the process is idle:
            TrafficModel.PFrameModel.IdleLogDistribution = makedist('Normal', 'mu', 4.8993, 'sigma', 0.107087);
            %% Key Frames:
            % Interval of Key Frames (counted in frames):
            % TrafficModel.KeyFrameModel.IntervalDistribution   = DiscreteDist(obj, 1, 250); % fixed to 250
            % set Key frame intervals to infinity (first frame will still be a key frame)
            TrafficModel.KeyFrameModel.IntervalDistribution = DiscreteDist(obj, 1, inf);
            % Bound the Key Frames:
            TrafficModel.KeyFrameModel.Bounds                 = [0 exp(9.10209)];
            % Correlate (in the log domain) the busy Key-Frames with the P-Frames (works best with both being log-normally distributed)
            TrafficModel.KeyFrameModel.BusyPFrameCorrelation  = 0.662501;
            % Distribution of the busy Key Frames:
            TrafficModel.KeyFrameModel.BusyLogDistribution = makedist('Normal', 'mu', 8.7598, 'sigma', 0.207139);
            % Distribution of the idle Key Frames:
            TrafficModel.KeyFrameModel.IdleLogDistribution = DiscreteDist(obj, [1], [8.47408]);
            %% Busy / Idle:
            % Distributions of the busy and idle period lengths (counted in frames, will be rounded later:
            TrafficModel.StateModel.BusyFramesModel = makedist('Exponential', 'mu', 335.515);
            TrafficModel.StateModel.IdleFramesModel = makedist('Exponential', 'mu', 141.01);
            %% END GENERATED CODE FOR TRAFFIC MODEL CONFIGURATION
        end

        function [times, framesizes, states, key_indices] = traffic_simulation(obj, N, TrafficModel)
            % Simulates Video Traffic
            %
            % INPUT:
            %   N .............. Number of frames
            %   TrafficModel ... Struct that contains all Traffic Parameters
            %                    (see DefaultTrafficModel.m for details)
            %
            % OUTPUT:
            %   times .......... (Nx1) time instances (seconds)
            %   framesizes ..... (Nx1) frame sizes at each time instance (in byte)
            %   states ......... (Nx1) states at each time instance busy (true) idle (false)
            %   key_indices .... vector containing the indices of the key frames


            %% default parameters
            if nargin < 2 || isempty(TrafficModel)
                TrafficModel = DefaultTrafficModel();
            end
            if nargin < 3
                do_plot = false;
            end

            %% setup
            % times = (0 : N-1)' / TrafficModel.General.fps;
            times      = cumsum([0; TrafficModel.InterArrivalTimeDist.random(N-1,1)]);
            states     = false(N,1);
            framesizes = nan(N,1);

            %% generate idle / busy periods
            % pbusystart = TrafficModel.StateModel.BusyFramesMean / (TrafficModel.StateModel.BusyFramesMean + TrafficModel.StateModel.IdleFramesMean);
            pbusystart = TrafficModel.StateModel.BusyFramesModel.mean / (TrafficModel.StateModel.BusyFramesModel.mean + TrafficModel.StateModel.IdleFramesModel.mean);
            busyperiod0 = rand() < pbusystart;

            busyperiod = busyperiod0;
            tn = 1;
            period_ends = [];
            period_lengths = [];
            while tn < N

                if busyperiod
                    frames = round( TrafficModel.StateModel.BusyFramesModel.random() );
                else
                    frames = round( TrafficModel.StateModel.IdleFramesModel.random() );
                end
                % no "empty phases":
                frames = max(1, frames);
                % limit it to N
                if tn + frames - 1 > N
                    frames = N-tn+1;
                end

                states( tn : min(tn+frames-1, N) ) = busyperiod;

                tn = tn + frames;
                period_lengths(end+1) = frames;
                period_ends(end+1)    = tn-1;
                busyperiod = ~busyperiod;
            end

            period_states = false(size(period_ends));
            period_states(end-1:-2:1) =  busyperiod;
            period_states(end  :-2:1) = ~busyperiod;

            nperiods = length(period_ends);

            %% P-Frames:

            f0 = 1;
            for pi = 1:nperiods
                len  = period_lengths(pi);
                f1   = f0 + len -1;
                %     fprintf('Generate frames %d ... %d (length %d)\n', f0, f1, len);

                if period_states(pi)
                    % busy
                    switch TrafficModel.PFrameModel.Type
                        case 'ARIMA'
                            if pi < 3 || rand() >  TrafficModel.PFrameModel.ContinueProbability
                                y0 = TrafficModel.PFrameModel.LogInitFrameSizeDist.random();
                            else % continue with the old value:
                                y0 = ye;
                            end
                            framesizes(f0:f1) = bounded_ARIMA(obj,len, TrafficModel.PFrameModel, y0);
                            ye = framesizes(f1);
                        otherwise
                            % independent frames:
                            framesizes(f0:f1) = TrafficModel.PFrameModel.LogFrameSizeDist.random(len, 1);
                    end
                else
                    % idle
                    framesizes(f0:f1) = TrafficModel.PFrameModel.IdleLogDistribution.random(len,1);
                end

                f0 = f1+1;
            end

            %% Key Frames:

            % positions:
            % key_indices = 1 : TrafficModel.KeyFrameModel.Interval : N;
            key_indices = 1;
            new_index = key_indices(end) + TrafficModel.KeyFrameModel.IntervalDistribution.random();
            while new_index <= N
                key_indices(end+1) = new_index;
                new_index = key_indices(end) + TrafficModel.KeyFrameModel.IntervalDistribution.random();
            end


            % n_key_frames = length(key_indices);
            busy_key_indices = key_indices( states(key_indices) );
            idle_key_indices = key_indices( ~states(key_indices) );
            n_busy_key_frames = length(busy_key_indices);
            n_idle_key_frames = length(idle_key_indices);

            % Idle Key Frames
            idle_key_frames = TrafficModel.KeyFrameModel.IdleLogDistribution.random( n_idle_key_frames, 1 );
            idle_key_frames = exp(idle_key_frames);

            % Busy Key Frames (correlate with P-Frames if desired)
            rho = TrafficModel.KeyFrameModel.BusyPFrameCorrelation;
            if rho == 0
                % No Correlation:
                %     busy_key_frames = TrafficModel.KeyFrameModel.BusyDistribution.random( n_busy_key_frames, 1 );
                busy_key_frames = TrafficModel.KeyFrameModel.BusyLogDistribution.random( n_busy_key_frames, 1 );
                busy_key_frames = exp( busy_key_frames );
            else
                % Correlation coefficient rho
                muz    = TrafficModel.KeyFrameModel.BusyLogDistribution.mean;
                mux    = TrafficModel.PFrameModel.LogFrameSizeDist.mean;
                sigmaz = sqrt( TrafficModel.KeyFrameModel.BusyLogDistribution.var );
                sigmax = sqrt( TrafficModel.PFrameModel.LogFrameSizeDist.var );
                alpha  = rho * sigmaz / sigmax;
                % aux var:
                muy = muz - alpha * mux;
                sigmay = sqrt( sigmaz^2 - alpha^2 * sigmax^2 );
                %
                Ydist = makedist('Normal', 'mu', muy, 'sigma', sigmay);
                Y     = Ydist.random(  n_busy_key_frames, 1 );
                X     = framesizes(busy_key_indices);
                busy_log_key_frames = alpha * X + Y;
                busy_key_frames = exp(busy_log_key_frames);
            end

            % bounds:
            busy_key_frames = max(busy_key_frames, TrafficModel.KeyFrameModel.Bounds(1));
            busy_key_frames = min(busy_key_frames, TrafficModel.KeyFrameModel.Bounds(2));

            idle_key_frames = max(idle_key_frames, TrafficModel.KeyFrameModel.Bounds(1));
            idle_key_frames = min(idle_key_frames, TrafficModel.KeyFrameModel.Bounds(2));

            %%
            % transform to linear domain:
            framesizes = exp(framesizes);

            %% Add Key Frames to the P-Frames:

            % corr(busy_key_frames, framesizes(busy_key_indices))
            framesizes(busy_key_indices) = framesizes(busy_key_indices) + busy_key_frames;
            framesizes(idle_key_indices) = framesizes(idle_key_indices) + idle_key_frames;

        end
    end
end
