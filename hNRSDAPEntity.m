classdef hNRSDAPEntity < handle
%hNRSDAPEntity Implements SDAP functionality
% this class is a non-exhaustive implementation for primary
% functionalities of the 5G NR SDAP layer

    properties (Access = public)
        % RQI Reflective QoS Indication. No
        % functionality is implemented behind this paramter
        RQI = 0;
        % MappingRule Rule to map AppIDs to data radio bearers. Index
        % indicates AppID, content at the respective index indicates DRBID
        % which the application is mapped to
        MappingRule = [1];
        % DefaultDRB Default DRB which the Application is mapped to when no
        % mapping rule is defined.
        DefaultDRB = 1;
        %PDCPChannelConfig A cell array of PDCP channel configuration structure
        PDCPChannelsConfig
        %TxForwardFcn A cell array of functions to send data to PDCP layer
        TxForwardFcn
        % RxForwardFcn Function handle to forward the processed SDAP SDUs to
        % the application layer
        RxForwardFcn
    end

    methods(Access = public)
        function obj = hNRSDAPEntity(config)
            if isfield(config, 'RQI')
                obj.RQI = config.RQI;
            end
            if isfield(config, 'MappingRule')
                obj.MappingRule = config.MappingRule;
            end
            if isfield(config, 'DefaultDRB')
                obj.DefaultDRB = config.DefaultDRB;
            end            
        end

        function registerAppReceiverFcn(obj, rxForwardFcn)
            %registerAppReceiverFcn Register application layer receiver
            % callback to forward the received SDAP SDUs
            %   registerAppReceiverFcn(obj, RXFORWARDFCN) registers the
            %   application layer receiver callback RXFORWARDFCN to forward
            %   the received SDAP SDU.
            %
            %   RXFORWARDFCN Function handle to forward the received SDAP
            %   SDUs to the application layer.

            obj.RxForwardFcn = rxForwardFcn;
        end

        function registerPDCPTransmitterFcn(obj, txForwardFcn, pdcpChannelConfig)
            %registerPDCPTransmitterFcn Register PDCP layer transmitter
            % callback to forward the received SDAP SDUs
            %   registerPDCPTransmitterFcn(obj, TXFORWARDFCN) registers the
            %   pdcp layer transmitter function TXFORWARDFCN per PDCP layer to forward
            %   the SDAP SDU to be transmitted.

            obj.TxForwardFcn{pdcpChannelConfig.DataRadioBearerID} = txForwardFcn;

            % Store the logical channel information
            obj.PDCPChannelsConfig{pdcpChannelConfig.DataRadioBearerID} = pdcpChannelConfig;
        end

        function transmitSDU(obj, sdapSDU, appID, frameInformation)
            %transmitSDU Transmit an SDAP SDU. This function adds the SDAP
            % header and selects a PDCP entity based on the specified
            % mapping rule
            %  frameInformation is structured as follows:
            %  [I_P_FrameIndicator frameCount totalNumberOfSegmentsForFrame segementCount]
            if isempty(sdapSDU)
                return
            end

            % implement the header according to TS37.324
            sdapHeader = [1; obj.RQI; int2bit(appID,6)]; % [bit]
            sdapHeader = bit2int(sdapHeader,8); % [byte]

            pdcpSDU = [sdapHeader; sdapSDU];

            % choose suitable SDAP entity based on mapping rule
            if numel(obj.MappingRule)<appID
                drbID = obj.DefaultDRB;
            else
                drbID = obj.MappingRule(appID);
            end

            txFunction = [];
            for i=1:numel(obj.PDCPChannelsConfig)
                if obj.PDCPChannelsConfig{i}.DataRadioBearerID == drbID
                    txFunction = obj.TxForwardFcn{i}; 
                    break
                end
            end

            % Forward the received SDU to PDCP layer if any callback
            % is registered
            if ~isempty(txFunction) && ~isempty(pdcpSDU)
                txFunction(pdcpSDU, frameInformation);
            end
        end

        function receiveSDU(obj, pdcpSDU, RNTI)
            %receiveSDU Receive a PDCP SDU. This functions removes the SDAP
            % header. This implementation is minimal and does
            % not implement reflective QoS mapping - mapping rule is set
            % during entity construction
            
            % Forward the received SDU to application layer if any callback
            % is registered
            if ~isempty(obj.RxForwardFcn) && ~isempty(pdcpSDU)
                sdapHeader = pdcpSDU(1:1);
                sdapHeader = int2bit(sdapHeader,8);
                appID = bit2int(sdapHeader(3:end),6);

                sdapSDU = pdcpSDU(2:end); % discard the header (1 Byte)
                obj.RxForwardFcn(sdapSDU, appID, RNTI);
            end
        end
    end
end
