classdef hNRIPLogger < handle
    %hNRIPLogger IP statistics logging object
    %   The class implements per slot logging mechanism
    %   of the IP layer metrics. It is used to log the statistics of a cell

    %   Copyright 2020-2021 The MathWorks, Inc.

    properties (Access = public)
        %NumSlotsFrame Number of slots in a 10ms time frame
        NumSlotsFrame
        
        %Total Number of Cells
        NumCells

        %NumUEs Count of UEs
        NumUEs
        
        %PDCPStatsLog Slot-by-slot log of the IP statistics
        % It is a P-by-Q cell array, where P is the number of slots, and Q
        % is the number of columns in the logs. The column names are
        % specified as keys in ColumnIndexMap
        PDCPStatsLog

        %ColumnIndexMap Mapping the column names of logs to respective column indices
        % It is a map object
        ColumnIndexMap

        %PDCPStatIndexMap Mapping the column names of logs to respective column indices
        % It is a map object
        PDCPStatIndexMap

        %Map Objects that stores Packet-Wise Latency
        Latency = containers.Map('KeyType','char','ValueType','any');
    end

    properties(Access = private)
        %GNB gNB node object
        % It is a scalar and object of type hNRGNB
        GNB
        
        %CurrFrame Current frame
        % It is incremented by 1 frame for every NumSlotsFrame slots
        CurrFrame = -1;

        %CurrSlot Current slot in the frame
        % It is incremented by 1 slot for every call to logIPStats method
        CurrSlot = -1;

        curr_simulation_time

       Logged_Tx_Packet_Keys;
       Logged_Rx_Packet_Keys;

      
       SlotDLStats = containers.Map('KeyType','char','ValueType','any');
       SlotULStats = containers.Map('KeyType','char','ValueType','any');   
       FinalDLStats = containers.Map('KeyType','char','ValueType','any');
       FinalULStats = containers.Map('KeyType','char','ValueType','any');
       
       SlotDLFrameInformation = containers.Map('KeyType','char','ValueType','any');
       SlotULFrameInformation = containers.Map('KeyType','char','ValueType','any');
       SlotDLSegmentationInformation = containers.Map('KeyType','char','ValueType','any');
       SlotULSegmentationInformation = containers.Map('KeyType','char','ValueType','any');
       SlotDLLatency = containers.Map('KeyType','char','ValueType','any');
       SlotULLatency = containers.Map('KeyType','char','ValueType','any');
       FinalDLLatency = containers.Map('KeyType','char','ValueType','any');
       FinalULLatency = containers.Map('KeyType','char','ValueType','any');
       
       Final_DL_Pkt_Info={}; %[IPStatsTitles]
       Final_UL_Pkt_Info={}; %[IPStatsTitles]

       FrameDLStats = containers.Map('KeyType','char','ValueType','any');
       Final_DL_Frame_Stats={}; %[FrameStatsTitles]
       Frame_to_Packet_Stats={}; %[Frame_to_Packet_Stats_Titles]
    end

    properties (Access = private, Constant)
        %IPStatsTitles Title for the columns of IP statistics
        IPStatsTitles = {'AppName','Cell ID', 'RNTI', 'TxPackets', 'TxDataBytes', ...
            'RxPackets','RxDataBytes', 'Packets Lost', 'Data Bytes Lost',...
            'Packet Loss Rate (%)', 'Goodput (Mbps)','Average Packet Latency (ms)', 'Packetwise Latency (ms)', 'Tx Packetwise I/P-frames', 'Tx Portion of the Frame'};

        FrameStatsTitles = {'AppName','Cell ID', 'RNTI', 'Tx P-Frames', 'Tx I-Frames', ...
            'Rx P-Frames','Rx I-Frames', 'Lost P-Frames', 'Lost I-Frames',...
            'Frame Loss Rate (%)', 'AR Goodput (Mbps)','Average Frame Latency (ms)', 'Framewise Latency (ms)'};

        Frame_to_Packet_Stats_Titles = {'AppName','Cell ID', 'RNTI', 'Frame Type(P/I)', 'Frame Count', ...
            'Total Packets','Tx Packets', 'Sent Time (ms)', 'Tx Bytes',...
            'Received Time (ms)', 'Rx Packets','Rx Bytes', 'Dropped Packets', 'Frame Status'};
    end

    methods (Access = public)
        function obj = hNRIPLogger(simParameters, varargin)
            
            obj.NumUEs = simParameters.NumUEs;
            obj.NumSlotsFrame = (10 * simParameters.SCS) / 15; % Number of slots in a 10 ms frame
            obj.NumCells = simParameters.NumCells;  
            
            % IP Stats
            % Each row represents the statistics of each slot and last row
            % of the log represents the cumulative statistics of the entire
            % simulation
            obj.PDCPStatsLog = cell((simParameters.NumFramesSim * obj.NumSlotsFrame) + 1, 5);
            obj.ColumnIndexMap = containers.Map('KeyType','char','ValueType','double');
            obj.ColumnIndexMap('Timestamp') = 1;
            obj.ColumnIndexMap('Frame') = 2;
            obj.ColumnIndexMap('Slot') = 3;
            obj.ColumnIndexMap('DL IP statistics') = 4;
            obj.ColumnIndexMap('UL IP statistics') = 5;
            obj.PDCPStatsLog{1, obj.ColumnIndexMap('Timestamp')} = 0; % Timestamp (in milliseconds)
            obj.PDCPStatsLog{1, obj.ColumnIndexMap('Frame')} = 0; % Frame number
            obj.PDCPStatsLog{1, obj.ColumnIndexMap('Slot')} = 0; % Slot number
            obj.PDCPStatsLog{1, obj.ColumnIndexMap('DL IP statistics')} = cell(1,1); % DL IP statistics
            obj.PDCPStatsLog{1, obj.ColumnIndexMap('UL IP statistics')} = cell(1,1); % UL IP statistics

            % IP stats column index map
            obj.PDCPStatIndexMap = containers.Map(obj.IPStatsTitles,1:length(obj.IPStatsTitles));

            if numel(varargin) == 2
                % Register periodic logging event with network simulator
                slotDuration = (15/simParameters.SCS) * 1e-3; % In seconds
                symbolDuration = slotDuration/14;
                networkSimulator = varargin{1};
                % Seperate the gNB and UE nodes
                obj.GNB = varargin{2};
                scheduleAction(networkSimulator, @obj.logIPStats, [],0, slotDuration);
            end
        end
        
        function logIPStats(obj)

            % Move to the next slot
            obj.CurrSlot = mod(obj.CurrSlot + 1, obj.NumSlotsFrame);
            if(obj.CurrSlot == 0)
                obj.CurrFrame = obj.CurrFrame + 1; % Next frame
            end
            timestamp = obj.CurrFrame * 10 + (obj.CurrSlot * 10/obj.NumSlotsFrame);
            logIndex = obj.CurrFrame * obj.NumSlotsFrame + obj.CurrSlot + 1;
            obj.PDCPStatsLog{logIndex, obj.ColumnIndexMap('Timestamp')} = timestamp;
            obj.PDCPStatsLog{logIndex, obj.ColumnIndexMap('Frame')} = obj.CurrFrame;
            obj.PDCPStatsLog{logIndex, obj.ColumnIndexMap('Slot')} = obj.CurrSlot;
            
            entity = obj.GNB.PDCPEntities{1, 1}; %One Object is enough for quering as all objects share the same property values of packet identifiers
            tx_keys=keys(entity.Tx_Packet_Identifier); %Total Packets Transmitted since the start of the simulation
            rx_keys=keys(entity.Rx_Packet_Identifier); %Total Packets Received since the start of the simulation     
            %tx_values=values(entity.Tx_Packet_Identifier);
            %rx_values=values(entity.Rx_Packet_Identifier);           
            %tx_pkt_count = numel(tx_keys); % Total Number of Transmitted Packets
            %rx_pkt_count = numel(rx_keys); % Total Number of Received Packets

       
            obj.curr_simulation_time = entity.IP_Packet_Timer; %Current Time at all the Nodes

            new_tx_keys=setdiff(tx_keys,obj.Logged_Tx_Packet_Keys); %(Total Packets - Last_Logged) = New Packets for this slot
            new_rx_keys=setdiff(rx_keys,obj.Logged_Rx_Packet_Keys); %(Total Packets - Last_Logged) = New Packets for this slot  
            
            if ~isempty(new_tx_keys)
                entity.Tx_Packet_Identifier.Count;
            end

            new_tx_pkt_count = numel(new_tx_keys); 
            new_rx_pkt_count = numel(new_rx_keys);
            transit_keys = setdiff(obj.Logged_Tx_Packet_Keys,obj.Logged_Rx_Packet_Keys); %Transmitted but not yet received packets. Need to compare TTL
            if(~isempty(new_rx_keys))
                transit_keys = setdiff(transit_keys, new_rx_keys); %if received in this slot remove from transit
            end
            transit_pkt_count = numel(transit_keys);

            Slot_DL_Pkt_Info={};
            Slot_UL_Pkt_Info={};
            
            if (new_tx_pkt_count>0) %If Any New Packet Transmitted
                for i=1:new_tx_pkt_count
                    value =  entity.Tx_Packet_Identifier(new_tx_keys{i});
                    %Segregation into DL/UL & then Distribute the Packet into App Name, Cell ID & RNTI
                    x=str2num(new_tx_keys{i});% -> x = [DL/UL CellID RNTI DRBID COUNT]
                    app_name = entity.App_Name_Identifier(strcat(int2str(x(3)),",",int2str(x(4)))); %Find the App Name from PDCP Entity Container
                    key_to_check = strcat(app_name,",",int2str(x(2)),",",int2str(x(3))); %Make the Key as AppName,CellID,RNTI
                    if x(1)==0 %DL                        
                        if(isKey(obj.SlotDLStats,key_to_check)) %If Some Packet with this Key already transmitted before then append to existing values
                            temp_val = obj.SlotDLStats(key_to_check);
                            temp_val(1:2) = [temp_val(1)+1   temp_val(2)+value(2)]; %Increment TxPkt by 1 and Increment TxBytes by the number of Bytes Transmitted
                            obj.SlotDLStats(key_to_check) = temp_val;
                        else %If No Packet with this Key Exists before
                            obj.SlotDLStats(key_to_check) = [1   value(2) 0 0 0 0 0 0 0];
                        end

                        if(isKey(obj.SlotDLFrameInformation,key_to_check)) % Average Latency Calculation
                            obj.SlotDLFrameInformation(key_to_check) = [obj.SlotDLFrameInformation(key_to_check) value(4)];
                            obj.SlotDLSegmentationInformation(key_to_check) = [obj.SlotDLSegmentationInformation(key_to_check) value(7)/value(6)]; 
                        else
                            obj.SlotDLFrameInformation(key_to_check) = value(4);
                            obj.SlotDLSegmentationInformation(key_to_check) = value(7)/value(6);
                        end  

                        %Frame Logging
                        if(value(4)~=0)% AR Video Packet
                            if(isKey(obj.FrameDLStats,key_to_check)) %If Some Frame with this Key already transmitted before then append to existing values
                                temp_val = obj.FrameDLStats(key_to_check);
                                [result,loc] = ismember(value(4:6),temp_val(:,1:3),'rows');
                                if result==1
                                    temp_val(loc,4)= temp_val(loc,4) + 1; %Increment Tx Pkts
                                    temp_val(loc,6) = temp_val(loc,6) + value(2); %Increment Tx Bytes
                                    if(temp_val(loc,3) == temp_val(loc,4))
                                        temp_val(loc,11) = 1; %Completely Transmitted
                                    end
                                else
                                    temp_val = [temp_val; value(4:7) value(1) value(2) 0 0 0 0 0];
                                end
                                obj.FrameDLStats(key_to_check) = temp_val;
                            else %If No Frame with this Key Exists before
                                obj.FrameDLStats(key_to_check) = [value(4:7) value(1) value(2) 0 0 0 0 0];
                            end                               
                        end                       

                    else %UL
                        if(isKey(obj.SlotULStats,key_to_check)) %If Some Packet with this Key already transmitted before then append to existing values
                            temp_val = obj.SlotULStats(key_to_check);
                            temp_val(1:2) = [temp_val(1)+1   temp_val(2)+value(2)]; %Increment TxPkt by 1 and Increment TxBytes by the number of Bytes TXD
                            obj.SlotULStats(key_to_check) = temp_val;
                        else %If No Packet with this Key Exists before
                            obj.SlotULStats(key_to_check) = [1   value(2) 0 0 0 0 0 0 0];
                        end    
                    end
                end
            end

            if new_rx_pkt_count>0 %If Any New Packet Received
                for i=1:new_rx_pkt_count
                    value1 =  entity.Tx_Packet_Identifier(new_rx_keys{i}); %Transmitted Pkt Time
                    value2 =  entity.Rx_Packet_Identifier(new_rx_keys{i}); %Received Pkt Time
                    obj.Latency(new_rx_keys{i}) = value2(1) - value1(1); %Calculate Latency for each arriving packet                                     
                    %Segregation into DL/UL & then Distribute the Packet into App Name, Cell ID & RNTI
                    x=str2num(new_rx_keys{i}); % -> x = [DL/UL CellID RNTI DRBID COUNT]
                    app_name = entity.App_Name_Identifier(strcat(int2str(x(3)),",",int2str(x(4)))); %Find the App Name from PDCP Entity Container
                    key_to_check = strcat(app_name,",",int2str(x(2)),",",int2str(x(3))); %Make the Key as AppName,CellID,RNTI
                    if x(1)==0 %DL
                        temp_val = obj.SlotDLStats(key_to_check);
                        temp_val(3:4) = [temp_val(3)+1   temp_val(4)+value2(2)]; %Increment RxPkt by 1 and Increment RxBytes by the number of Bytes RCVD
                        temp_val(8) = (temp_val(4) * 8) / ((obj.curr_simulation_time/1000) * 1000 * 1000); % Throughput in Mbps
                        if(isKey(obj.SlotDLLatency,key_to_check)) % Average Latency Calculation
                            obj.SlotDLLatency(key_to_check) = [obj.SlotDLLatency(key_to_check)    obj.Latency(new_rx_keys{i})];
                            temp_val(9) = mean(obj.SlotDLLatency(key_to_check));
                        else
                            temp_val(9) = obj.Latency(new_rx_keys{i});
                            obj.SlotDLLatency(key_to_check) = obj.Latency(new_rx_keys{i});
                        end                
                        obj.SlotDLStats(key_to_check) = temp_val;

                        %Frame Logging
                        if(value1(4)~=0)% AR Video Packet
                                temp_val = obj.FrameDLStats(key_to_check);
                                [result,loc] = ismember(value1(4:6),temp_val(:,1:3),'rows');
                                if result==1        %&& temp_val(loc,11) ~= -1
                                    temp_val(loc,8)= temp_val(loc,8) + 1; %Increment Rx Pkts
                                    temp_val(loc,9) = temp_val(loc,9) + value2(2); %Increment Rx Bytes
                                    if(temp_val(loc,3) == temp_val(loc,8))
                                        temp_val(loc,7) = value2(1); %Last Packet Received Time
                                        temp_val(loc,11) = 2; %Completely Received
                                    end
                                end
                                obj.FrameDLStats(key_to_check) = temp_val;                                                
                        end 

                    else %UL
                        temp_val = obj.SlotULStats(key_to_check);
                        temp_val(3:4) = [temp_val(3)+1   temp_val(4)+value2(2)]; %Increment RxPkt by 1 and Increment RxBytes by the number of Bytes RCVD
                        temp_val(8) = (temp_val(4) * 8) / ((obj.curr_simulation_time/1000) * 1000 * 1000); % Throughput in Mbps
                        if(isKey(obj.SlotULLatency,key_to_check)) % Average Latency Calculation
                            obj.SlotULLatency(key_to_check) = [obj.SlotULLatency(key_to_check)    obj.Latency(new_rx_keys{i})];
                            temp_val(9) = mean(obj.SlotULLatency(key_to_check));
                        else
                            temp_val(9) = obj.Latency(new_rx_keys{i});
                            obj.SlotULLatency(key_to_check) = obj.Latency(new_rx_keys{i});
                        end  
                        obj.SlotULStats(key_to_check) = temp_val;
                    end               
                end                
            end

            if(transit_pkt_count>0) %If Any Packets are sent but not received
               for i=1:transit_pkt_count
                   value =  entity.Tx_Packet_Identifier(transit_keys{i});
                   %Check for Dropped Packets
                   if((obj.curr_simulation_time - value(1)) > value(3)) %(Current Simulation Time  - Packet Creation Time > TTL)
                       obj.Latency(transit_keys{i}) = -1; %Mark as Dropped and Update Container -> -1 Latency means dropped
                       %Segregation into DL/UL & then Distribute the Packet into App Name, Cell ID & RNTI   
                       x=str2num(transit_keys{i}); % -> x = [DL/UL CellID RNTI DRBID COUNT]
                       app_name = entity.App_Name_Identifier(strcat(int2str(x(3)),",",int2str(x(4)))); %Find the App Name from PDCP Entity Container
                       key_to_check = strcat(app_name,",",int2str(x(2)),",",int2str(x(3))); %Make the Key as AppName,CellID,RNTI
                       if x(1)==0 %DL
                            temp_val = obj.SlotDLStats(key_to_check);
                            temp_val(5:6) = [temp_val(5)+1   temp_val(6)+value(2)]; %Increment DroppedPkt by 1 and Increment DroppedBytes by the number of Bytes Dropped
                            if(temp_val(1)~=0)
                                temp_val(7) = (temp_val(5) / temp_val(1)) * 100; %Packet Loss Rate
                            end
%                             if(isKey(obj.SlotDLLatency,key_to_check)) % Store as -1 Latency
%                                 obj.SlotDLLatency(key_to_check) = [obj.SlotDLLatency(key_to_check)    obj.Latency(transit_keys{i})];
%                             else
%                                 obj.SlotDLLatency(key_to_check) = obj.Latency(transit_keys{i});
%                             end 
                            obj.SlotDLStats(key_to_check) = temp_val;
                            
                            %Frame Logging
                            if(value(4)~=0)% AR Video Packet
                                    temp_val = obj.FrameDLStats(key_to_check);
                                    [result,loc] = ismember(value(4:6),temp_val(:,1:3),'rows');
                                    if result==1
                                        temp_val(loc,10)= temp_val(loc,10) + 1; %One Packet Dropped                                 
                                        temp_val(loc,11) = -1; %Count This Frame as Dropped
                                    end
                                    obj.FrameDLStats(key_to_check) = temp_val;                                                
                            end 

                       else %UL
                            temp_val = obj.SlotULStats(key_to_check);
                            temp_val(5:6) = [temp_val(5)+1   temp_val(6)+value(2)]; %Increment DroppedPkt by 1 and Increment DroppedBytes by the number of Bytes Dropped
                            if(temp_val(1)~=0)
                                temp_val(7) = (temp_val(5) / temp_val(1)) * 100; %Packet Loss Rate
                            end
%                             if(isKey(obj.SlotULLatency,key_to_check)) % Store as -1 Latency
%                                 obj.SlotULLatency(key_to_check) = [obj.SlotULLatency(key_to_check)    obj.Latency(transit_keys{i})];
%                             else
%                                 obj.SlotULLatency(key_to_check) = obj.Latency(transit_keys{i});
%                             end
                            obj.SlotULStats(key_to_check) = temp_val;
                       end 
                   end
               end
            end
            obj.Logged_Tx_Packet_Keys = tx_keys;
            obj.Logged_Rx_Packet_Keys = keys(obj.Latency); %Received + dropped packets are logged

            h1=keys(obj.SlotDLStats);
            h2=keys(obj.SlotULStats);
            for i=1:numel(h1)
                out = regexp(h1{i}, ',', 'split');
                if(isKey(obj.SlotDLLatency,h1{i}))
                    if isempty(obj.SlotDLFrameInformation(h1{i}))
                        Slot_DL_Pkt_Info = [Slot_DL_Pkt_Info; out(1) num2cell(str2double(out(2:3))) num2cell(obj.SlotDLStats(h1{i})) obj.SlotDLLatency(h1{i}) NaN NaN];
                    else
                        Slot_DL_Pkt_Info = [Slot_DL_Pkt_Info; out(1) num2cell(str2double(out(2:3))) num2cell(obj.SlotDLStats(h1{i})) obj.SlotDLLatency(h1{i}) obj.SlotDLFrameInformation(h1{i}) obj.SlotDLSegmentationInformation(h1{i})];
                    end
                else
                    if isempty(obj.SlotDLFrameInformation(h1{i}))
                        Slot_DL_Pkt_Info = [Slot_DL_Pkt_Info; out(1) num2cell(str2double(out(2:3))) num2cell(obj.SlotDLStats(h1{i})) 0 0 0];
                    else
                        Slot_DL_Pkt_Info = [Slot_DL_Pkt_Info; out(1) num2cell(str2double(out(2:3))) num2cell(obj.SlotDLStats(h1{i})) 0 obj.SlotDLFrameInformation(h1{i}) obj.SlotDLSegmentationInformation(h1{i})];
                    end
                end
                
                if(isKey(obj.FinalDLStats,h1{i}) && ~all(obj.SlotDLStats(h1{i}) == 0))
                    temp1=obj.SlotDLStats(h1{i});
                    temp2=obj.FinalDLStats(h1{i});
                    temp2(1:6) = [temp1(1)+temp2(1)   temp1(2)+temp2(2) temp1(3)+temp2(3) temp1(4)+temp2(4) temp1(5)+temp2(5) temp1(6)+temp2(6)];
                    temp2(7) = (temp2(5) / temp2(1)) * 100; %Packet Loss Rate
                    temp2(8) = (temp2(4) * 8) / ((obj.curr_simulation_time/1000) * 1000 * 1000); % Throughput in Mbps    
                    if(isKey(obj.FinalDLLatency,h1{i}) && isKey(obj.SlotDLLatency,h1{i}))
                        obj.FinalDLLatency(h1{i}) = [obj.FinalDLLatency(h1{i})    obj.SlotDLLatency(h1{i})];
                        temp2(9) = mean(obj.FinalDLLatency(h1{i})); % Average Latency Calculation
                        remove(obj.SlotDLLatency,h1{i});
                    elseif(isKey(obj.SlotDLLatency,h1{i}))
                        temp2(9) = temp1(9);
                        obj.FinalDLLatency(h1{i}) =  obj.SlotDLLatency(h1{i});
                        remove(obj.SlotDLLatency,h1{i});
                    end
                    obj.FinalDLStats(h1{i}) = temp2;
                elseif(~isKey(obj.FinalDLStats,h1{i}))
                    obj.FinalDLStats(h1{i}) = obj.SlotDLStats(h1{i});
                    if(isKey(obj.SlotDLLatency,h1{i}))
                        obj.FinalDLLatency(h1{i}) =  obj.SlotDLLatency(h1{i});
                        remove(obj.SlotDLLatency,h1{i});
                    end
                end
                obj.SlotDLStats(h1{i}) = [0 0 0 0 0 0 0 0 0];
                obj.SlotDLFrameInformation(h1{i}) = [];
                obj.SlotDLSegmentationInformation(h1{i}) = [];
            end              
            for i=1:numel(h2) 
                out = regexp(h2{i}, ',', 'split');
                if(isKey(obj.SlotULLatency,h2{i}))
                    Slot_UL_Pkt_Info = [Slot_UL_Pkt_Info; out(1) num2cell(str2double(out(2:3))) num2cell(obj.SlotULStats(h2{i})) obj.SlotULLatency(h2{i}) 0 0];
                else
                    Slot_UL_Pkt_Info = [Slot_UL_Pkt_Info; out(1) num2cell(str2double(out(2:3))) num2cell(obj.SlotULStats(h2{i})) 0 0 0];
                end           
                
                if(isKey(obj.FinalULStats,h2{i}) && ~all(obj.SlotULStats(h2{i}) == 0)) %If A New Update Happened on the Vector
                    temp1=obj.SlotULStats(h2{i});
                    temp2=obj.FinalULStats(h2{i});
                    temp2(1:6) = [temp1(1)+temp2(1)   temp1(2)+temp2(2) temp1(3)+temp2(3) temp1(4)+temp2(4) temp1(5)+temp2(5) temp1(6)+temp2(6)];
                    temp2(7) = (temp2(5) / temp2(1)) * 100; %Packet Loss Rate
                    temp2(8) = (temp2(4) * 8) / ((obj.curr_simulation_time/1000) * 1000 * 1000); % Throughput in Mbps                       
                    if(isKey(obj.FinalULLatency,h2{i}) && isKey(obj.SlotULLatency,h2{i}))
                        obj.FinalULLatency(h2{i}) = [obj.FinalULLatency(h2{i})    obj.SlotULLatency(h2{i})];
                        temp2(9) = mean(obj.FinalULLatency(h2{i})); % Average Latency Calculation
                        remove(obj.SlotULLatency,h2{i});
                    elseif(isKey(obj.SlotULLatency,h2{i}))
                        temp2(9) = temp1(9);
                        obj.FinalULLatency(h2{i}) =  obj.SlotULLatency(h2{i});
                        remove(obj.SlotULLatency,h2{i});
                    end
                    obj.FinalULStats(h2{i}) = temp2;
                elseif(~isKey(obj.FinalULStats,h2{i}))
                    obj.FinalULStats(h2{i}) = obj.SlotULStats(h2{i});
                    if(isKey(obj.SlotULLatency,h2{i}))
                        obj.FinalULLatency(h2{i}) =  obj.SlotULLatency(h2{i});
                        remove(obj.SlotULLatency,h2{i});
                    end
                end
                obj.SlotULStats(h2{i}) = [0 0 0 0 0 0 0 0 0];
            end 
            
            obj.PDCPStatsLog{logIndex, obj.ColumnIndexMap('DL IP statistics')} = vertcat(obj.IPStatsTitles, Slot_DL_Pkt_Info);
            obj.PDCPStatsLog{logIndex, obj.ColumnIndexMap('UL IP statistics')} = vertcat(obj.IPStatsTitles, Slot_UL_Pkt_Info);
            
            %{
            %Only for displaying Cummulative IP Stats after every Slot if required
            h1=keys(obj.FinalDLStats);
            h2=keys(obj.FinalULStats);
            for i=1:numel(h1)
                out = regexp(h1{i}, ',', 'split');
                if(isKey(obj.FinalDLLatency,h1{i}))
                    obj.Final_DL_Pkt_Info = [obj.Final_DL_Pkt_Info; out(1) num2cell(str2double(out(2:3))) num2cell(obj.FinalDLStats(h1{i})) obj.FinalDLLatency(h1{i})];
                else
                    obj.Final_DL_Pkt_Info = [obj.Final_DL_Pkt_Info; out(1) num2cell(str2double(out(2:3))) num2cell(obj.FinalDLStats(h1{i})) 0];
                end
            end
            
            for i=1:numel(h2)
                out = regexp(h2{i}, ',', 'split');
                if(isKey(obj.FinalULLatency,h2{i}))
                    obj.Final_UL_Pkt_Info = [obj.Final_UL_Pkt_Info; out(1) num2cell(str2double(out(2:3))) num2cell(obj.FinalULStats(h2{i})) obj.FinalULLatency(h2{i})];
                else
                    obj.Final_UL_Pkt_Info = [obj.Final_UL_Pkt_Info; out(1) num2cell(str2double(out(2:3))) num2cell(obj.FinalULStats(h2{i})) 0];
                end
            end
            obj.Final_DL_Pkt_Info;
            obj.Final_UL_Pkt_Info;
            
            obj.Final_DL_Pkt_Info ={};
            obj.Final_UL_Pkt_Info ={};
            %}
        end

        function IPLogs = getIPLogs(obj)
            if obj.CurrFrame < 0 % Return empty when logging is not started
                IPLogs = [];
                return;
            end
            headings = {'Timestamp','Frame number', 'Slot number', 'DL IP statistics', 'UL IP statistics'};
            % Most recent log index for the current simulation
            lastLogIndex = obj.CurrFrame * obj.NumSlotsFrame + obj.CurrSlot + 1;
            % Create a row at the end of the to store the cumulative
            % statistics of the DL and gNB at the end of the simulation
            lastLogIndex = lastLogIndex + 1;
            h1=keys(obj.FinalDLStats);
            h2=keys(obj.FinalULStats);
            for i=1:numel(h1)
                out = regexp(h1{i}, ',', 'split');
                if(isKey(obj.FinalDLLatency,h1{i}))
                    obj.Final_DL_Pkt_Info = [obj.Final_DL_Pkt_Info; out(1) num2cell(str2double(out(2:3))) num2cell(obj.FinalDLStats(h1{i})) obj.FinalDLLatency(h1{i})];
                else
                    obj.Final_DL_Pkt_Info = [obj.Final_DL_Pkt_Info; out(1) num2cell(str2double(out(2:3))) num2cell(obj.FinalDLStats(h1{i})) 0];
                end
            end
            
            for i=1:numel(h2)
                out = regexp(h2{i}, ',', 'split');
                if(isKey(obj.FinalULLatency,h2{i}))
                    obj.Final_UL_Pkt_Info = [obj.Final_UL_Pkt_Info; out(1) num2cell(str2double(out(2:3))) num2cell(obj.FinalULStats(h2{i})) obj.FinalULLatency(h2{i})];
                else
                    obj.Final_UL_Pkt_Info = [obj.Final_UL_Pkt_Info; out(1) num2cell(str2double(out(2:3))) num2cell(obj.FinalULStats(h2{i})) 0];
                end
            end
                        
            obj.PDCPStatsLog{lastLogIndex, obj.ColumnIndexMap('DL IP statistics')} = vertcat(obj.IPStatsTitles(1:13), obj.Final_DL_Pkt_Info);
            obj.PDCPStatsLog{lastLogIndex, obj.ColumnIndexMap('UL IP statistics')} = vertcat(obj.IPStatsTitles(1:13), obj.Final_UL_Pkt_Info);
            
            %For Frame Logging
            f1=keys(obj.FrameDLStats);
            for i=1:numel(f1)
                out = regexp(f1{i}, ',', 'split');
                temp=obj.FrameDLStats(f1{i});
                x=size(temp,1);
                frames_to_log= find(temp(:,11)~=0); % 0 = Not Fully Transmitted
                p_tx_frames= find(temp(frames_to_log(:),1)==1);
                i_tx_frames= find(temp(frames_to_log(:),1)==2);
                rx_frames_to_log = find(temp(:,11)==2); %2 = Fully Received 
                p_rx_frames= find(temp(rx_frames_to_log(:),1)==1);
                i_rx_frames= find(temp(rx_frames_to_log(:),1)==2);
                dropped_frames_to_log = find(temp(:,11)==-1); %-1 = Dropped 
                p_dropped_frames= find(temp(dropped_frames_to_log(:),1)==1);
                i_dropped_frames= find(temp(dropped_frames_to_log(:),1)==2);
                
                frame_latency=[];
                rx_total_bytes=0;
                avg_frame_latency=0;
                frame_loss_rate = (length(dropped_frames_to_log)/length(frames_to_log)) * 100; %Frame Loss Rate
                for j=1:numel(rx_frames_to_log)
                    frame_latency =[frame_latency temp(rx_frames_to_log(j),7) - temp(rx_frames_to_log(j),5)];
                    rx_total_bytes=rx_total_bytes + temp(rx_frames_to_log(j),9);
                end
                
                if(~isempty(frame_latency))
                    avg_frame_latency = mean(frame_latency);
                end
                throughput = (rx_total_bytes * 8) / ((obj.curr_simulation_time/1000) * 1000 * 1000); % Throughput in MbpS

                temp_value=[length(p_tx_frames) length(i_tx_frames) length(p_rx_frames) length(i_rx_frames) length(p_dropped_frames) length(i_dropped_frames) frame_loss_rate throughput avg_frame_latency];
                if(~isempty(frame_latency))
                    obj.Final_DL_Frame_Stats = [obj.Final_DL_Frame_Stats; out(1) num2cell(str2double(out(2:3))) num2cell(temp_value) frame_latency];
                else
                    obj.Final_DL_Frame_Stats = [obj.Final_DL_Frame_Stats; out(1) num2cell(str2double(out(2:3))) num2cell(temp_value) 0];
                end

                obj.Frame_to_Packet_Stats = [obj.Frame_to_Packet_Stats; repmat(out(1),x,1) repmat(num2cell(str2double(out(2:3))),x,1) num2cell(temp)];
            end
            
            obj.PDCPStatsLog{lastLogIndex+1, obj.ColumnIndexMap('DL IP statistics')} = vertcat(obj.FrameStatsTitles, obj.Final_DL_Frame_Stats);
            obj.PDCPStatsLog{lastLogIndex+1, obj.ColumnIndexMap('UL IP statistics')} = vertcat(obj.Frame_to_Packet_Stats_Titles, obj.Frame_to_Packet_Stats);
            IPLogs = [headings; obj.PDCPStatsLog(1:lastLogIndex+1, :)];

        end
    
    end
    
    methods(Access = private)
        
    end
end
