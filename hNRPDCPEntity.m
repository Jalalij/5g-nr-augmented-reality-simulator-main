classdef hNRPDCPEntity < handle
    %hNRSDAPEntity Implement PDCP functionality
    % this class is a non-exhaustive implementation for primary
    % functionalities and is not implemented according close to the 3GPP documents

    properties (Access = public)
        %DataRadioBearerID ID for this PDCP entity 
        DataRadioBearerID
        
        %RLCChannelConfig A cell array of RLC channel configuration structure
        RLCChannelsConfig

        %TxForwardFcn A cell array of functions to send data to RLC layer
        TxForwardFcn

        %RemoveSDUFcn A cell array of functions to remove a certain PDCP
        %SDU due to timeout
        RemoveSDUFcn

        %RxForwardFcn Function handle to forward the processed PDCP SDUs to
        % the SDAP layer
        RxForwardFcn

        %LogicalChannelIDs Logical channel IDs which are associated with this PDCP entity
        LogicalChannelIDs

        %DataTimeToLive Time for data being valid. If data is not
        % scheduled until a timer expires it is discarded.
        DataTimeToLive

        %ReorderingTimerStartingValue Time for data being reorderd before packet loss is
        % assumed in [ms]. 
        ReorderingTimerStartingValue = 50;

        %EnableIntegrityProtection Specifies if integrity protection shall
        %be modelled
        EnableIntegrityProtection = false;

        %EnableIntegrityProtection Specifies if PDCP packet duplication is
        %enabled for this entity
        EnablePacketDuplication = false;

        %EnableOutOfOrderDelivery Enable that received packets are
        %transmitted out of order
        EnableOutOfOrderDelivery = true;

        %ProtocolOverhead Protocol overhead of higher layers before ROHC
        ProtocolOverhead = 40;

        %CompressedProtocolOverhead Protocol overhead of higher layers after ROHC
        CompressedProtocolOverhead = 3;

        %SNSize Sequence number size. Either 12 or 18 bits.
        SNSize = 18;

        %Packet Timer. Upward Counter used for Logging Latency
        IP_Packet_Timer = -1;

        %LastRunTime Time (in nanoseconds) at which the application layer was invoked last time
        LastRunTime = 0;

        %Containers for IP Packet Logging
        Tx_Packet_Identifier = containers.Map('KeyType','char','ValueType','any');
        Rx_Packet_Identifier = containers.Map('KeyType','char','ValueType','any');

        App_Name_Identifier = containers.Map('KeyType','char','ValueType','any');

    end

    properties (Access = private)
        %pTx_DiscardTimers Timer for every SDU to count the time until SDU is discarded 
        pTx_DiscardTimers = []; %[ms]

        %pRx_ReorderingTimer Reordering timer according to TS 38.331
        pRx_ReorderingTimer = 50; %[ms]

        %pRx_ReorderingTimerActive Flag to indicate if reordering timer is active
        pRx_ReorderingTimerActive = false; %[ms]

        %pTx_SNs Sequence number for every TXed SDU
        pTx_SNs = [];
        
        %pRx_buffer Buffer for received SDUs
        pRx_buffer = {};

        %pRx_Counts_buffer Count values of SDUs in Rx_buffer
        pRx_Counts_buffer = [];

        %pRx_Counts Count values of every SDU ever received by this entity
        pRx_Counts = [];

        %pRx_Deliv Count value of the first PDCP SDU not deliverd to upper
        % layers
        pRx_Deliv = 0;
        
        %pRx_Reord Count value of the PDU which triggered reordering.
        pRx_Reord = 0;

        %pTx_next Counter to identify next SDU to be transmitted
        pTx_next = 0;

        %pRx_next Counter to identify next SDU to be received
        pRx_next = 0;


        Tx_pkt_ID;
        Rx_pkt_ID;


    end

    methods(Access = public)
        function obj = hNRPDCPEntity(config,entity_type)
            if isfield(config, 'DataRadioBearerID') 
                obj.DataRadioBearerID = config.DataRadioBearerID; 
            end 
            if isfield(config, 'LogicalChannelIDs')
                obj.LogicalChannelIDs = config.LogicalChannelIDs;
            end
            if isfield(config, 'DataTimeToLive')
                obj.DataTimeToLive = config.DataTimeToLive;
            end
            if isfield(config, 'EnableIntegrityProtection')
                obj.EnableIntegrityProtection = config.EnableIntegrityProtection;
            end
            if isfield(config, 'EnablePacketDuplication')
                obj.EnablePacketDuplication = config.EnablePacketDuplication;
            end
            if isfield(config, 'EnableOutOfOrderDelivery')
                obj.EnableOutOfOrderDelivery = config.EnableOutOfOrderDelivery;
            end
            if isfield(config,'ReorderingTimerStartingValue')
                obj.ReorderingTimerStartingValue = config.ReorderingTimerStartingValue;
                obj.pRx_ReorderingTimer = config.ReorderingTimerStartingValue;
            end
            %Packet Source and Destination
            if entity_type % Packet Source = UE
                %obj.Tx_pkt_ID = strcat("SRC: UE ",int2str(config.RNTI),"_ DEST: GNB ",int2str(config.cellId));
                %obj.Rx_pkt_ID = strcat("SRC: GNB ",int2str(config.cellId),"_ DEST: UE ",int2str(config.RNTI));         
                obj.Tx_pkt_ID = strcat("1,",int2str(config.cellId),",",int2str(config.RNTI),",",int2str(config.DataRadioBearerID));
                obj.Rx_pkt_ID = strcat("0,",int2str(config.cellId),",",int2str(config.RNTI),",",int2str(config.DataRadioBearerID));
                
                obj.App_Name_Identifier(strcat(int2str(config.RNTI),",",int2str(config.DataRadioBearerID))) = config.AppName;
            
            else % Packet Source = GNB
                %obj.Tx_pkt_ID = strcat("SRC: GNB ",int2str(config.cellId),"_ DEST: UE ",int2str(config.RNTI));
                %obj.Rx_pkt_ID = strcat("SRC: UE ",int2str(config.RNTI),"_ DEST: GNB ",int2str(config.cellId));
                obj.Tx_pkt_ID = strcat("0,",int2str(config.cellId),",",int2str(config.RNTI),",",int2str(config.DataRadioBearerID));
                obj.Rx_pkt_ID = strcat("1,",int2str(config.cellId),",",int2str(config.RNTI),",",int2str(config.DataRadioBearerID));
            end

        end
        
        function registerSDAPReceiverFcn(obj, rxForwardFcn)
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

        function registerRLCTransmitterFcn(obj, txForwardFcn, rlcChannelConfig)
            %registerPDCPTransmitterFcn Register PDCP layer transmitter
            % callback to forward the received SDAP SDUs
            %   registerPDCPTransmitterFcn(obj, TXFORWARDFCN) registers the
            %   pdcp layer transmitter function TXFORWARDFCN per PDCP layer to forward
            %   the SDAP SDU to be transmitted.

            obj.TxForwardFcn{end+1} = txForwardFcn;
            obj.RLCChannelsConfig{end+1} = rlcChannelConfig;
        end

        function registerRLCDequeFcn(obj, txDequeueFunction)
            %registerPDCPTransmitterFcn Register PDCP layer transmitter
            % callback to forward the received SDAP SDUs
            %   registerPDCPTransmitterFcn(obj, TXFORWARDFCN) registers the
            %   pdcp layer transmitter function TXFORWARDFCN per PDCP layer to forward
            %   the SDAP SDU to be transmitted.

            obj.RemoveSDUFcn{end+1} = txDequeueFunction;
        end

        function transmitSDU(obj, sdapSDU, frameInformation)
            %  frameInformation is structured as follows:
            %  [I_P_FrameIndicator frameCount totalNumberOfSegmentsForFrame segementCount]

            obj.pTx_DiscardTimers(end+1) = obj.DataTimeToLive;
            sequenceNumberToTransmit = mod(obj.pTx_next,2^obj.SNSize);
            obj.pTx_SNs(end+1) = sequenceNumberToTransmit;
           
            %For the IP Logger
            tx_hfn = (obj.pTx_next - sequenceNumberToTransmit)/(2^obj.SNSize);
            tx_count = encodeCountValue(obj,tx_hfn,sequenceNumberToTransmit);
            obj.Tx_Packet_Identifier(strcat(obj.Tx_pkt_ID,",",int2str(tx_count))) = [obj.IP_Packet_Timer numel(sdapSDU(2:end)) obj.DataTimeToLive frameInformation];           
   
            obj.pTx_next = obj.pTx_next + 1;
            % ROHC, keep SDAP header, but compress other headers by a fixed
            % number of bits
            compressedSDU = [sdapSDU(1);sdapSDU(2+obj.ProtocolOverhead-obj.CompressedProtocolOverhead:end)];

            pdcpHeader = generateHeader(obj,sequenceNumberToTransmit);

            % implement the footer according to TS38.323
            if obj.EnableIntegrityProtection
                pdcpFooter = zeros(32/8,1);
            else
                pdcpFooter = [];
            end

            pdcpSDU = [pdcpHeader; compressedSDU; pdcpFooter];
            frameTypeIndicator = frameInformation(1); % 0: no video frame, 1: P-frame, 2: I-frame
            portionOfFrameTransmitted = frameInformation(4)/frameInformation(3);

            % if packet duplication is activated submit the PDCP SDU to all
            % RLC entities, otherwise use only the first one
            if obj.EnablePacketDuplication
                for i=1:numel(obj.TxForwardFcn)
                    txFunction=obj.TxForwardFcn{i};
                    if ~isempty(txFunction) && ~isempty(pdcpSDU)
                        txFunction(pdcpSDU, obj.DataTimeToLive, obj.DataTimeToLive, frameTypeIndicator, portionOfFrameTransmitted);
                    end
                end
            else
                txFunction = obj.TxForwardFcn{1};
                % Forward the received SDU to PDCP layer if any callback
                % is registered
                if ~isempty(txFunction) && ~isempty(pdcpSDU)
                    txFunction(pdcpSDU, obj.DataTimeToLive, obj.DataTimeToLive, frameTypeIndicator, portionOfFrameTransmitted);
                end
            end
        end
        function receiveSDU(obj, pdcpSDU, RNTI)

            if obj.EnableIntegrityProtection
                pdcpSDU=pdcpSDU(1:end-32/8);
            end

            if obj.SNSize == 12
                pdcpHeader = int2bit(pdcpSDU(1:2),8);
                rcvd_SN = bit2int(pdcpHeader(5:end),obj.SNSize);
                compressedSDU = pdcpSDU(3:end);
            else
                pdcpHeader = int2bit(pdcpSDU(1:3),8);
                rcvd_SN = bit2int(pdcpHeader(7:end),obj.SNSize);
                compressedSDU = pdcpSDU(4:end);
            end

            windowSize = 2^(obj.SNSize-1);
            [rx_deliv_HFN, rx_deliv_SN] = decodeCountValue(obj,obj.pRx_Deliv);
   
            % determine hyper frame number from SN being out of bounds
            if rcvd_SN < rx_deliv_SN-windowSize
                rcvd_HFN = rx_deliv_HFN + 1;
            elseif rcvd_SN >= rx_deliv_SN+windowSize
                rcvd_HFN = rx_deliv_HFN - 1;
            else
                rcvd_HFN = rx_deliv_HFN;
            end

            rcvd_count = encodeCountValue(obj,rcvd_HFN,rcvd_SN);

            % discard the PDU if it has already been received before
            if any(obj.pRx_Counts == rcvd_count) || rcvd_count<obj.pRx_Deliv
                return;
            else
                obj.pRx_Counts = [obj.pRx_Counts,rcvd_count];
            end
                        
            % update the next count number expected to be received
            if rcvd_count >= obj.pRx_next
                obj.pRx_next = rcvd_count+1;
            end

            % undo ROHC
            sdapSDU = [compressedSDU(1); ones(obj.ProtocolOverhead-obj.CompressedProtocolOverhead,1); compressedSDU(2:end)];
            
            %For IP Logger
            obj.Rx_Packet_Identifier(strcat(obj.Rx_pkt_ID,",",int2str(rcvd_count))) = [obj.IP_Packet_Timer numel(sdapSDU(2:end))];
            %keys(obj.Rx_Packet_Identifier);
            %values(obj.Rx_Packet_Identifier);
            
            % deliver SDU if out of order delivery is activated
            if obj.EnableOutOfOrderDelivery
                obj.RxForwardFcn(sdapSDU, RNTI);
                return
            end

            if rcvd_count == obj.pRx_Deliv % if current packet is the one thats still missing
                % send current packet to upper layers
                obj.RxForwardFcn(sdapSDU);

                % send all other consecutive packets to upper layers which arrived before
                sendConsecutivePackets(obj,rcvd_count+1);

            else % store the SDU in the reception buffer and wait for the missing packets to be received
                [obj.pRx_Counts_buffer,sortingIndex] = sort([obj.pRx_Counts_buffer, rcvd_count]);
                obj.pRx_buffer{end+1} = sdapSDU;
                obj.pRx_buffer = obj.pRx_buffer(sortingIndex);
            end
            
            if obj.pRx_Deliv >= obj.pRx_Reord && obj.pRx_ReorderingTimerActive
                obj.pRx_ReorderingTimerActive = false;
                obj.pRx_ReorderingTimer = obj.ReorderingTimerStartingValue;
            end

            if obj.pRx_Deliv < obj.pRx_next && ~obj.pRx_ReorderingTimerActive
                obj.pRx_Reord = obj.pRx_next;
                obj.pRx_ReorderingTimerActive = true;
            end

        end
        function handleTimerTrigger(obj, currentTime)
            elapsedTime = currentTime - obj.LastRunTime; % In nanoseconds
            elapsedTime = elapsedTime * 1e-6; % convert to miliseconds

            %Packet Timer. Upward Counter used for Logging Latency.
            obj.IP_Packet_Timer = obj.IP_Packet_Timer+elapsedTime;
            %Process 1 millisecond timer trigger and count down all tx discard timers
            for i=1:numel(obj.pTx_DiscardTimers)
                obj.pTx_DiscardTimers(i) = obj.pTx_DiscardTimers(i)-elapsedTime;
            end

            if min(obj.pTx_DiscardTimers)<=0
                expiredDiscardTimers = find(obj.pTx_DiscardTimers<=0);
                for i=1:numel(expiredDiscardTimers)
                    header = generateHeader(obj, obj.pTx_SNs(i));
                    for j = 1:numel(obj.RemoveSDUFcn)
                        obj.RemoveSDUFcn{j}(header);
                    end
                end
                obj.pTx_SNs(expiredDiscardTimers) = [];
                obj.pTx_DiscardTimers(expiredDiscardTimers) = [];
            end

            %Process 1 millisecond timer trigger and count down the rx
            %reordering timer
            if obj.pRx_ReorderingTimerActive
                obj.pRx_ReorderingTimer = obj.pRx_ReorderingTimer - elapsedTime;
            end

            if obj.pRx_ReorderingTimer<=0
                reorderingTimerExpired(obj);
            end
            obj.LastRunTime = currentTime;
        end
    end

    methods(Access = private)
        function count = encodeCountValue(obj,HFN,SN)
                HFN_bin = int2bit(HFN,32-obj.SNSize);
                SN_bin = int2bit(SN,obj.SNSize);
                count = bit2int([HFN_bin;SN_bin],32);
        end
        function [HFN,SN] = decodeCountValue(obj,count)
                count_bin = int2bit(count,32);
                HFN_bin = count_bin(1:32-obj.SNSize);
                HFN = bit2int(HFN_bin,32-obj.SNSize);
                SN_bin = count_bin(32-obj.SNSize+1:end);
                SN = bit2int(SN_bin,obj.SNSize);
        end
        function reorderingTimerExpired(obj)
            % send all packets up to reordering timer
            while obj.pRx_Counts_buffer(1)<obj.pRx_Reord
                sdapSDU = obj.pRx_buffer{1};
                obj.RxForwardFcn(sdapSDU);

                obj.pRx_Counts_buffer = obj.pRx_Counts_buffer(2:end);
                obj.pRx_buffer(2:end);
            end

            % send also all other consecutive packets which have already
            % arrived after
            sendConsecutivePackets(obj,obj.pRx_Reord);

            if obj.pRx_Deliv < obj.pRx_next
                obj.pRx_ReorderingTimer = obj.ReorderingTimerStartingValue;
                obj.pRx_Reord = obj.pRx_next;
                obj.pRx_ReorderingTimerActive = true;
            else
                obj.pRx_ReorderingTimer = obj.ReorderingTimerStartingValue;
                obj.pRx_ReorderingTimerActive = false;
            end
        end
        function sendConsecutivePackets(obj,startingPacket)
            if ~isempty(obj.pRx_Counts_buffer)
                nextInOrderPacket = startingPacket;
                while nextInOrderPacket == obj.pRx_Counts_buffer(1)
                    sdapSDU = obj.pRx_buffer{1};
                    obj.RxForwardFcn(sdapSDU);

                    obj.pRx_Counts_buffer = obj.pRx_Counts_buffer(2:end);
                    obj.pRx_buffer(2:end);

                    nextInOrderPacket = nextInOrderPacket + 1;
                    if isempty(obj.pRx_Counts_buffer)
                        break
                    end
                end
                obj.pRx_Deliv = nextInOrderPacket;
            else
                obj.pRx_Deliv = startingPacket;
            end
        end
        function header = generateHeader(obj, SN)
            % implement the header according to TS38.323
            dataPDUIndication = 1; % no control PDUs are supported in the current implementation
            if obj.SNSize == 12
                numReservedBits = 3;
            else
                numReservedBits = 5;
            end
            header = [dataPDUIndication; zeros(numReservedBits,1); int2bit(SN,obj.SNSize)]; % [bit]
            header = bit2int(header,8); % [byte]
        end
    end
end
