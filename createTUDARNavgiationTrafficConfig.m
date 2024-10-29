function [appTable, sdapTable, pdcpTable, rlcTable] = createTUDARNavgiationTrafficConfig(simParamters)

numUEs = simParamters.NumUEs;
RNTI = 1:numUEs;

%%
App_RNTI_full = [];
App_ID_full = [];
App_ProtocolOverhead_full = [];
App_HostDevice_full = []; % 0 => gNB, 1 => UE
App_Name_full = strings(0);
App_Parameter1 = strings(0);
App_Parameter2 = strings(0);
App_Parameter3 = strings(0);
App_Parameter4 = strings(0);

SDAP_ReflectiveQoS_full = [];
SDAP_MappingRule_full = [];
SDAP_RNTI_full = [];
SDAP_AppID_5QI_Mapping = [];

PDCP_RNTI_full = [];
PDCP_DRBID_full = [];
PDCP_LCIDs_full = [];
PDCP_DataTimeToLive_full = [];
PDCP_IntegrityProtection_full = [];
PDCP_PacketDuplication_full = [];
PDCP_OutOfOrderDelivery_full = [];
PDCP_ReorderingTimer_full = [];
PDCP_ProtocolOverhead_full = [];
PDCP_CompressedProtocolOverhead_full = [];

RLCRNTI_full = [];
RLC_LCID_full = [];
RLC_LCGID_full = []; 
RLC_SeqNumFieldLength_full = [];
RLC_MaxTxBufferSDUs_full = [];
RLC_ReassemblyTimer_full = [];
RLC_EntityType_full = [];
RLC_Priority_full = [];
RLC_PBR_full = [];
RLC_BSD_full = [];

for i = 1:numUEs
    % App config
    App_Name_full(end+1,1) = "ARTUD"; % DL video App
    App_RNTI_full(end+1,1) = RNTI(i);
    App_ID_full(end+1,1) = 1;
    App_ProtocolOverhead_full(end+1,1) = 40;
    App_HostDevice_full(end+1,1) = 0;
    App_Parameter1(end+1,1) = "Navigation";
    App_Parameter2(end+1,1) = "8K";
    App_Parameter3(end+1,1) = "inf";
    App_Parameter4(end+1,1) = "8";

    App_Name_full(end+1,1) = "ARperiodicTraffic"; % DL audio/data
    App_RNTI_full(end+1,1) = RNTI(i);
    App_ID_full(end+1,1) = 2;
    App_ProtocolOverhead_full(end+1,1) = 40;
    App_HostDevice_full(end+1,1) = 0;
    App_Parameter1(end+1,1) = "audio/data_1";
    App_Parameter2(end+1,1) = "";
    App_Parameter3(end+1,1) = "";
    App_Parameter4(end+1,1) = "";

    App_Name_full(end+1,1) = "ARperiodicTraffic"; % UL pose/control
    App_RNTI_full(end+1,1) = RNTI(i);
    App_ID_full(end+1,1) = 3;
    App_ProtocolOverhead_full(end+1,1) = 40;
    App_HostDevice_full(end+1,1) = 1;
    App_Parameter1(end+1,1) = "pose/control";
    App_Parameter2(end+1,1) = "";
    App_Parameter3(end+1,1) = "";
    App_Parameter4(end+1,1) = "";

    % SDAP config
    SDAP_RNTI_full(end+1,1) = RNTI(i);
    SDAP_ReflectiveQoS_full(end+1,1) = 0;
    SDAP_MappingRule_full = [SDAP_MappingRule_full; [1 2 3 0]];
    SDAP_AppID_5QI_Mapping = [SDAP_AppID_5QI_Mapping; [80 80 80]]; % index indicates AppId, content indicates 5QI value

    % PDCP config
    PDCP_RNTI_full(end+1,1) = RNTI(i);
    PDCP_DRBID_full(end+1,1) = 1;
    PDCP_LCIDs_full = [PDCP_LCIDs_full; [4 0 0]];
    PDCP_DataTimeToLive_full(end+1,1) = 10; % time to live of data
    PDCP_IntegrityProtection_full(end+1,1) = false;
    PDCP_PacketDuplication_full(end+1,1) = false;
    PDCP_OutOfOrderDelivery_full(end+1,1) = true;
    PDCP_ReorderingTimer_full(end+1,1) = inf;
    PDCP_ProtocolOverhead_full(end+1,1) = 40;
    PDCP_CompressedProtocolOverhead_full(end+1,1) = 3;

    PDCP_RNTI_full(end+1,1) = RNTI(i);
    PDCP_DRBID_full(end+1,1) = 2;
    PDCP_LCIDs_full = [PDCP_LCIDs_full; [5 0 0]];
    PDCP_DataTimeToLive_full(end+1,1) = 10;
    PDCP_IntegrityProtection_full(end+1,1) = false;
    PDCP_PacketDuplication_full(end+1,1) = false;
    PDCP_OutOfOrderDelivery_full(end+1,1) = true;
    PDCP_ReorderingTimer_full(end+1,1) = inf;
    PDCP_ProtocolOverhead_full(end+1,1) = 40;
    PDCP_CompressedProtocolOverhead_full(end+1,1) = 3;

    PDCP_RNTI_full(end+1,1) = RNTI(i);
    PDCP_DRBID_full(end+1,1) = 3;
    PDCP_LCIDs_full = [PDCP_LCIDs_full; [6 0 0]];
    PDCP_DataTimeToLive_full(end+1,1) = 10;
    PDCP_IntegrityProtection_full(end+1,1) = false;
    PDCP_PacketDuplication_full(end+1,1) = false;
    PDCP_OutOfOrderDelivery_full(end+1,1) = true;
    PDCP_ReorderingTimer_full(end+1,1) = inf;
    PDCP_ProtocolOverhead_full(end+1,1) = 40;
    PDCP_CompressedProtocolOverhead_full(end+1,1) = 3;

    % RLC config
    RLCRNTI_full(end+1,1) = RNTI(i);
    RLC_LCID_full(end+1,1) = 4;
    RLC_LCGID_full(end+1,1) = 1; % buffer status report is done per logical channel group - BSR is for a UE to indicate the BS the amount of data there is to transmit
    RLC_SeqNumFieldLength_full(end+1,1) = 12;
    RLC_MaxTxBufferSDUs_full(end+1,1) = 512; % if buffer size is exceeded packet is dropped
    RLC_ReassemblyTimer_full(end+1,1) = 10; % if reassembly timer expires and previous packets have not arrived yet, packets are dropped
    RLC_EntityType_full(end+1,1) = 2; % The values 0, 1, 2, and 3 indicate RLC UM unidirectional DL entity, RLC UM unidirectional UL entity, RLC UM bidirectional entity, and RLC AM entity,
    RLC_Priority_full(end+1,1) = 5;
    RLC_PBR_full(end+1,1) = 0; % [kB/s]
    RLC_BSD_full(end+1,1) = 10; % bucket size duration [ms] together with PBR determines the minimum number of bits that should be within a grant, ref. Erik Dahlman 5G NR The Next Generation Wireless Access Technology

    RLCRNTI_full(end+1,1) = RNTI(i);
    RLC_LCID_full(end+1,1) = 5;
    RLC_LCGID_full(end+1,1) = 1;
    RLC_SeqNumFieldLength_full(end+1,1) = 12;
    RLC_MaxTxBufferSDUs_full(end+1,1) = 128;
    RLC_ReassemblyTimer_full(end+1,1) = 10;
    RLC_EntityType_full(end+1,1) = 2;
    RLC_Priority_full(end+1,1) = 2;
    RLC_PBR_full(end+1,1) = 8;
    RLC_BSD_full(end+1,1) = 10;

    RLCRNTI_full(end+1,1) = RNTI(i);
    RLC_LCID_full(end+1,1) = 6;
    RLC_LCGID_full(end+1,1) = 1;
    RLC_SeqNumFieldLength_full(end+1,1) = 12;
    RLC_MaxTxBufferSDUs_full(end+1,1) = 128;
    RLC_ReassemblyTimer_full(end+1,1) = 10;
    RLC_EntityType_full(end+1,1) = 2;
    RLC_Priority_full(end+1,1) = 1;
    RLC_PBR_full(end+1,1) = 8;
    RLC_BSD_full(end+1,1) = 10;
end

%% export as table

appTable = table(App_RNTI_full, App_HostDevice_full, App_Name_full, App_ID_full, App_ProtocolOverhead_full, App_Parameter1, App_Parameter2, App_Parameter3, App_Parameter4, 'VariableNames',{'RNTI','HostDevice','ApplicationName','AppID', 'ProtocolOverhead', 'AppParameter1', 'AppParameter2', 'AppParameter3', 'AppParameter4'});
sdapTable = table(SDAP_RNTI_full, SDAP_ReflectiveQoS_full, SDAP_MappingRule_full, SDAP_AppID_5QI_Mapping, 'VariableNames',{'RNTI','ReflectiveQoS','MappingRule','AppIDto5QIMapping'});
pdcpTable = table(PDCP_RNTI_full, PDCP_DRBID_full, PDCP_LCIDs_full, PDCP_DataTimeToLive_full, PDCP_IntegrityProtection_full, PDCP_PacketDuplication_full, PDCP_OutOfOrderDelivery_full, PDCP_ReorderingTimer_full, PDCP_ProtocolOverhead_full, PDCP_CompressedProtocolOverhead_full, 'VariableNames',{'RNTI','DRBID','LCIDs','DataTimeToLive','IntegrityProtection', 'PacketDuplication', 'OutOfOrderDelivery', 'ReorderingTimer', 'ProtocolOverhead', 'CompressedProtocolOverhead'});
rlcTable = table(RLCRNTI_full, RLC_LCID_full, RLC_LCGID_full, RLC_SeqNumFieldLength_full, RLC_MaxTxBufferSDUs_full, RLC_ReassemblyTimer_full, RLC_EntityType_full, RLC_Priority_full, RLC_PBR_full, RLC_BSD_full, 'VariableNames',{'RNTI','LogicalChannelID','LCGID','SeqNumFieldLength', 'MaxTxBufferSDUs', 'ReassemblyTimer', 'EntityType', 'Priority', 'PBR', 'BSD'});

end