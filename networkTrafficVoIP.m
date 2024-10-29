classdef networkTrafficVoIP < comm_sysmod.internal.ConfigBaseHandle
%networkTrafficVoIP Model VoIP application traffic pattern
%   VOIPOBJ = networkTrafficVoIP creates an object to generate VoIP
%   application traffic pattern using default values. This object specifies
%   the configuration parameters to generate the VoIP application traffic
%   pattern based on IEEE 802.11ax Evaluation Methodology.
%
%   VOIPOBJ = networkTrafficVoIP(Name,Value) creates an object, VOIPOBJ,
%   with the specified property Name set to the specified Value. You can
%   specify additional name-value pair arguments in any order as
%   (Name1,Value1,...,NameN,ValueN).
%
%   networkTrafficVoIP properties:
%
%   ExponentialMean      - Mean value for exponential distribution to
%                          calculate active or silent state duration in
%                          milliseconds
%   HasJitter            - Flag to indicate whether to model jitter
%   LaplaceScale         - Scale parameter for Laplace distribution to
%                          calculate packet arrival delay jitter in
%                          milliseconds
%   LaplaceMu            - Location parameter for Laplace distribution to
%                          calculate packet arrival delay jitter in
%                          milliseconds
%   GeneratePacket       - Flag to indicate whether to generate a VoIP
%                          packet with payload
%   ApplicationData      - Application data to be added in the VoIP packet
%
%   networkTrafficVoIP methods:
%
%   generate - Generate next VoIP application traffic packet
%
%   % Example 1:
%   %   Generate VoIP application traffic pattern
%
%   voipObj = networkTrafficVoIP; % Create object
%   [dt, packetSize] = generate(voipObj); % Generate pattern
%
%   % Example 2:
%   %   Generate VoIP application traffic pattern with a mean value of
%   %   exponential distribution as 5
%
%   voipObj = networkTrafficVoIP('ExponentialMean',5); % Create object
%   [dt, packetSize] = generate(voipObj); % Generate pattern
%
%   % Example 3:
%   %   Generate VoIP application traffic pattern and the data packet
%
%   voipObj = networkTrafficVoIP('GeneratePacket',true); % Create object
%   [dt, packetSize, packet] = generate(voipObj); % Generate packet
%
%   % Example 4:
%   %   Generate VoIP application traffic pattern and visualize packet
%   %   sizes and packet intervals
%
%   voipObj = networkTrafficVoIP; % Create object
%   % Call traffic generator function in a loop to generate 200 packets
%   for i = 1:200
%       [dt(i), packetSize(i)] = generate(voipObj);
%   end
%   stem(dt); % Stem graph to see VoIP traffic pattern
%   title('dt vs Packet number');
%   xlabel('Packet number');
%   ylabel('dt in milliseconds');
%   figure;
%   stem(packetSize); % Stem graph to see different packet sizes
%   title('Packet size vs Packet number');
%   xlabel('Packet number');
%   ylabel('Packet size in bytes');
%
%   See also generate, networkTrafficOnOff, networkTrafficFTP,
%   networkTrafficVideoConference.

%   Copyright 2020-2021 The MathWorks, Inc.

%#codegen

properties
    %ExponentialMean Mean value for exponential distribution to calculate
    % active or silent state duration in milliseconds
    %   Specify the exponential mean value as a nonnegative integer scalar.
    %   The object uses this property to calculate the exponentially
    %   distributed active or silent state duration in the VoIP traffic.
    %   The default value is 1250.
    ExponentialMean = 1250;

    %HasJitter Flag to indicate whether to model jitter
    %   Specify HasJitter as true or false. If the HasJitter flag is true,
    %   the object models jitter using Laplace distribution. The default
    %   value is true.
    HasJitter (1, 1) logical = true;

    %LaplaceScale Scale parameter for Laplace distribution to calculate
    % packet arrival delay jitter in milliseconds
    %   Specify the laplace scale value as a positive scalar in the
    %   range [1,100]. This property is applicable when the value of <a href="matlab:help('networkTrafficVoIP.HasJitter')">HasJitter</a>
    %   is set to true. The default value is 5.11.
    LaplaceScale = 5.11;

    %LaplaceMu Location parameter for Laplace distribution to calculate
    % packet arrival delay jitter in milliseconds
    %   Specify the laplace mu value as a positive scalar in the
    %   range [0, 100]. This property is applicable when the value of <a href="matlab:help('networkTrafficVoIP.HasJitter')">HasJitter</a>
    %   is set to true. The default value is 0.
    LaplaceMu = 0;

    %ProtocolOverhead Adds protocol overheads to the traffic in bytes
    %   Specify ProtocolOverheads as an integer in the range [0, 60]. To
    %   accommodate layer 3, layer 4, and application protocol overheads in
    %   the network traffic, set this property. The default value is 40.
    ProtocolOverhead = 40;

    %GeneratePacket Flag to indicate whether to generate a VoIP packet with
    %payload
    %   Specify generate packet value as true or false. To generate a VoIP
    %   packet with payload, set this property to true. If you set this
    %   property to false, the generate object function generates no
    %   application data packet. The default value is false.
    GeneratePacket (1, 1) logical = false;

    %ApplicationData Application data to be added in the packet
    %   Specify application data as a column vector of integer values in
    %   the range [0, 255]. This property is applicable when the
    %   value of <a href="matlab:help('networkTrafficVoIP.GeneratePacket')">GeneratePacket</a> is set to true.
    %   If the size of the application data is greater than the packet
    %   size, the object truncates the application data. If the size of the
    %   application data is smaller than the packet size, the object
    %   appends zeros. The default value is a 36-by-1 vector of ones
    %   (Packet size in active state).
    ApplicationData = ones(36, 1);
end

properties (Access = private)
    %CurrentState Current state of the Markov model
    % 1 - Active
    % 2 - silent
    CurrentState

    %PktsInState Number of packets to be generated in a current state
    PktsInState = 0;

    %TransitionMatrix Initialize transition matrix of the Markov model, as
    % specified in IEEE 11ax Evaluation Methodology
    TransitionMatrix = [0.984 0.016;0.016 0.984];

    %UpdatedTransitionMatrix Updated transition matrix of the Markov model
    % Transition matrix is updated after every packet generation
    UpdatedTransitionMatrix = [0.984 0.016;0.016 0.984];

    %NextInvokeTime Time after which the generate method
    % should be invoked again
    NextInvokeTime = 0;

    %StateDuration Duration of a current state in milliseconds
    % State duration is calculated using exponential distribution
    StateDuration = 0;

    %AppData Application data to be added in the packet as a column vector
    % of integer values in the range [0, 255]
    AppData = ones(36,1);

end

methods (Access = protected)
    function flag = isInactiveProperty(obj, prop)
        flag = false;
        if strcmp(prop,'ApplicationData')
            flag = ~(obj.GeneratePacket);
        end
        if strcmp(prop,'LaplaceMu')
            flag = ~(obj.HasJitter);
        end
        if strcmp(prop,'LaplaceScale')
            flag = ~(obj.HasJitter);
        end
    end
end

methods
    function obj = networkTrafficVoIP(varargin)
        obj@comm_sysmod.internal.ConfigBaseHandle(varargin{:});
        obj.CurrentState = randi(2); % Initial state is selected randomly
        if obj.CurrentState == 1
            obj.NextInvokeTime = rand() * 20;
        else
            obj.NextInvokeTime = rand() * 160;
        end
    end

    function set.ExponentialMean(obj, value)
        % Validate exponential mean value
        validateattributes(value, {'numeric'}, {'real', 'scalar', 'finite',  ...
            'integer', '>=', 0}, '', 'ExponentialMean');
        obj.ExponentialMean = value;
    end

    function set.LaplaceScale(obj, value)
        % Validate laplace scale value
        validateattributes(value, {'numeric'}, {'real', 'scalar', 'finite', ...
            '>', 0, '<=', 100}, '', 'LaplaceScale');
        obj.LaplaceScale = value;
    end

    function set.LaplaceMu(obj, value)
        % Validate laplace mu value
        validateattributes(value, {'numeric'}, {'real', 'scalar', 'finite', ...
            '>=', 0, '<=', 100}, '', 'LaplaceMu');
        obj.LaplaceMu = value;
    end

    function set.ProtocolOverhead(obj, value)
        % Validate protocol overheads value
        validateattributes(value, {'numeric'}, {'real', 'integer', 'scalar', ...
            '>=', 0, '<=', 60}, '', 'ProtocolOverhead');
        obj.ProtocolOverhead = value;
    end

    function set.ApplicationData(obj, data)
        % Validate application data
        validateattributes(data, {'double'}, {'real', 'integer', 'column', ...
            '>=', 0, '<=', 255}, '', 'ApplicationData');
        % Size of the given application data
        appDataSize = min(numel(data), 36);
        obj.AppData = zeros(36, 1); %#ok<MCSUP>
        obj.AppData(1 : appDataSize) = data(1 : appDataSize); %#ok<MCSUP>
        obj.ApplicationData = data;
    end

    function [dt, packetSize, varargout] = generate(obj, varargin)
            %generate Generate next VoIP application traffic packet
            %
            %   [DT, PACKETSIZE] = generate(OBJ) returns DT and PACKETSIZE,
            %   where DT is the time remaining to generate next packet in
            %   milliseconds and PACKETSIZE is the size of the current
            %   packet in bytes.
            %
            %   [DT, PACKETSIZE] = generate(OBJ, ELAPSEDTIME) specifies
            %   elapsed time, ELAPSEDTIME in milliseconds, and returns DT
            %   and PACKETSIZE, where DT is the time remaining to generate
            %   next packet in milliseconds and PACKETSIZE is the size of
            %   the current packet in bytes.
            %
            %   [..., PACKET] = generate(...) also returns the application
            %   packet, PACKET, that contains a column vector of integer
            %   values in the range [0, 255]. The function returns PACKET
            %   only when the <a href="matlab:help('networkTrafficVoIP.GeneratePacket')">GeneratePacket</a> property is set to true.
            %   PACKET contains the application data specified by the
            %   <a href="matlab:help('networkTrafficVoIP.ApplicationData')">ApplicationData</a> property. If ApplicationData property is
            %   not specified, PACKET is a column vector of ones.
            %
            %   % Example 1:
            %   %   Generate VoIP application traffic pattern
            %
            %   voipObj = networkTrafficVoIP; % Create object
            %   [dt, packetSize] = generate(voipObj); % Generate pattern
            %
            %   See also networkTrafficVoIP.

            narginchk(1, 2);
            nargoutchk(2, 3);

            if isempty(varargin)
                obj.NextInvokeTime = 0;
            else
                % Validate elapsed time value
                validateattributes(varargin{1}, {'numeric'}, {'real', ...
                    'scalar', 'finite', '>=', 0}, '', 'ElapsedTime');
                % Calculate time remaining before generating next packet
                obj.NextInvokeTime = obj.NextInvokeTime - varargin{1};
            end

            if obj.NextInvokeTime <= 0
                % Check the current state
                if obj.CurrentState == 1 % Active state
                    % Frame duration for active talking state in
                    % milliseconds, as specified in IEEE 11ax Evaluation
                    % Methodology
                    frameDuration = 20;
                    % Packet size in active state, as specified in IEEE
                    % 11ax Evaluation Methodology
                    packetSize = 33 + obj.ProtocolOverhead; % Add protocol headers
                    % Update transition matrix after every packet generation
                    obj.UpdatedTransitionMatrix = obj.UpdatedTransitionMatrix * obj.TransitionMatrix;
                else % silent state
                    % Frame duration for silent state in milliseconds, as
                    % specified in IEEE 11ax Evaluation Methodology
                    frameDuration = 160;
                    % Packet size in silent state, as specified in IEEE
                    % 11ax Evaluation Methodology
                    packetSize = 7 + obj.ProtocolOverhead; % Add protocol headers
                    % Update transition matrix for every 20 milliseconds i.e
                    % 8 times in silent state
                    obj.UpdatedTransitionMatrix = obj.UpdatedTransitionMatrix * (obj.TransitionMatrix^7);
                end
                if obj.HasJitter % Model jitter
                    while true
                        % Generate laplace random number
                        jitter = obj.laplaceRandomNumber();
                        % If the abs(jitter) value is greater than the
                        % frame duration, discard the jitter value and
                        % generate a new value for jitter
                        if abs(jitter) <= frameDuration
                            dt = round(frameDuration + jitter);
                            break;
                        end
                    end
                else % No jitter
                    dt = frameDuration;
                end
                if ~obj.PktsInState
                    % Calculate state duration of current state
                    obj.StateDuration = obj.ExponentialMean * -log(rand);
                    % Calculate total packets to be generated in current state
                    obj.PktsInState = floor(obj.StateDuration/frameDuration);
                    % Compute the next state
                    nextState = obj.markovModel(obj.CurrentState, obj.TransitionMatrix);
                    % Update current state for the next iteration
                    obj.CurrentState = nextState;
                end
                % Update next invoke time with dt
                obj.NextInvokeTime = dt;
                % Update remaining packets to be generated in the
                % current state
                obj.PktsInState = obj.PktsInState - 1;

                % If the flag to generate next packet is true, generate the packet
                if obj.GeneratePacket
                    varargout{1} = [obj.AppData(1:packetSize-obj.ProtocolOverhead, 1); ones(obj.ProtocolOverhead,1)];
                else % Generate packet flag is set to false
                    varargout{1} = [];
                end
            else % Next packet generation time has not come yet
                % Return dt and packet size
                dt = obj.NextInvokeTime;
                packetSize = 0;
                varargout{1} = [];
            end
    end
end

methods(Access = private)
    function lrand = laplaceRandomNumber(obj)
        %laplaceRandomNumber Generate a random number using
        % Laplace distribution
        %
        % LRAND = laplaceRandomNumber(OBJ) Return a positive
        % random delay jitter
        %
        % LRAND is the jitter value of current packet

        % Generate a random jitter value according to Laplace distribution
        u = rand();
        lrand = obj.LaplaceMu - obj.LaplaceScale * sign(u - 0.5) * log(1 - exp(-80/obj.LaplaceScale) - 2*abs(u-0.5));
    end

    function nextState = markovModel(~, CurrentState, TransitionMatrix)
        %markovModel Return the next state based on current state
        %
        % NEXTSTATE = markovModel(CURRENTSTATE, TRANSITIONMATRIX) generates
        % the next state
        %
        % NEXTSTATE is the next state of the VoIP session
        %
        % CURRENTSTATE is the current state of the VoIP session
        %
        % TRANSITIONMATRIX is the current Markov transition matrix

        % Get a random number to select the next state
        r = randi(1000);

        % Check if the random number is within the range of current state
        if r <= (TransitionMatrix(CurrentState, 1)*1000)
            % Update the next state as active state
            nextState = 1;
        else
            % Update the next state as silent state
            nextState = 2;
        end
    end
end
end