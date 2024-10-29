function [PMISet,info] = hDLPMISelect(carrier,csirs,reportConfig,nLayers,H,varargin)
%hDLPMISelect PDSCH precoding matrix indicator calculation
%   [PMISET,INFO] = hDLPMISelect(CARRIER,CSIRS,REPORTCONFIG,NLAYERS,H)
%   returns the precoding matrix indicator (PMI) values, as defined in
%   TS 38.214 Section 5.2.2.2, for the specified carrier configuration
%   CARRIER, CSI-RS configuration CSIRS, channel state information (CSI)
%   reporting configuration REPORTCONFIG, number of transmission layers
%   NLAYERS, and estimated channel information H.
%
%   CARRIER is a carrier specific configuration object, as described in
%   <a href="matlab:help('nrCarrierConfig')">nrCarrierConfig</a>. Only these object properties are relevant for this
%   function:
%
%   SubcarrierSpacing - Subcarrier spacing in kHz
%   CyclicPrefix      - Cyclic prefix type
%   NSizeGrid         - Number of resource blocks (RBs) in
%                       carrier resource grid
%   NStartGrid        - Start of carrier resource grid relative to common
%                       resource block 0 (CRB 0)
%   NSlot             - Slot number
%   NFrame            - System frame number
%
%   CSIRS is a CSI-RS specific configuration object to specify one or more
%   CSI-RS resources, as described in <a href="matlab:help('nrCSIRSConfig')">nrCSIRSConfig</a>. Only these object
%   properties are relevant for this function:
%
%   CSIRSType           - Type of a CSI-RS resource {'ZP', 'NZP'}
%   CSIRSPeriod         - CSI-RS slot periodicity and offset
%   RowNumber           - Row number corresponding to a CSI-RS resource, as
%                         defined in TS 38.211 Table 7.4.1.5.3-1
%   Density             - CSI-RS resource frequency density
%   SymbolLocations     - Time-domain locations of a CSI-RS resource
%   SubcarrierLocations - Frequency-domain locations of a CSI-RS resource
%   NumRB               - Number of RBs allocated for a CSI-RS resource
%   RBOffset            - Starting RB index of CSI-RS allocation relative
%                         to carrier resource grid
%   For better results, it is recommended to use the same CSI-RS
%   resource(s) that are used for channel estimate, because the resource
%   elements (REs) that does not contain the CSI-RS may have the
%   interpolated channel estimates. Note that the CDM lengths and the
%   number of ports configured for all the CSI-RS resources must be same.
%
%   REPORTCONFIG is a CSI reporting configuration structure with these
%   fields:
%   NSizeBWP        - Size of the bandwidth part (BWP) in terms of number
%                     of physical resource blocks (PRBs). It must be a
%                     scalar and the value must be in the range 1...275.
%                     Empty ([]) is also supported and it implies that the
%                     value of NSizeBWP is equal to the size of carrier
%                     resource grid
%   NStartBWP       - Starting PRB index of BWP relative to common resource
%                     block 0 (CRB 0). It must be a scalar and the value
%                     must be in the range 0...2473. Empty ([]) is also
%                     supported and it implies that the value of NStartBWP
%                     is equal to the start of carrier resource grid
%   CodebookType    - Optional. The type of codebooks according to which
%                     the CSI parameters must be computed. It must be a
%                     character array or a string scalar. It must be one of
%                     {'Type1SinglePanel', 'Type1MultiPanel', 'Type2'}. In
%                     case of 'Type1SinglePanel', the PMI computation is
%                     performed using TS 38.214 Tables 5.2.2.2.1-1 to
%                     5.2.2.2.1-12. In case of 'Type1MultiPanel', the PMI
%                     computation is performed using TS 38.214 Tables
%                     5.2.2.2.2-1 to 5.2.2.2.2-6. In case of 'Type2' the
%                     computation is performed according to TS 38.214
%                     Section 5.2.2.2.3. The default value is
%                     'Type1SinglePanel'
%   PanelDimensions - Antenna panel configuration.
%                        - When CodebookType field is specified as
%                          'Type1SinglePanel' or 'Type2', this field is a
%                          two-element vector in the form of [N1 N2]. N1
%                          represents the number of antenna elements in
%                          horizontal direction and N2 represents the
%                          number of antenna elements in vertical
%                          direction. Valid combinations of [N1 N2] are
%                          defined in TS 38.214 Table 5.2.2.2.1-2. This
%                          field is not applicable when the number of
%                          CSI-RS ports is less than or equal to 2
%                        - When CodebookType field is specified as
%                          'Type1MultiPanel', this field is a three element
%                          vector in the form of [Ng N1 N2], where Ng
%                          represents the number of antenna panels. Valid
%                          combinations of [Ng N1 N2] are defined in TS
%                          38.214 Table 5.2.2.2.2-1
%   PMIMode         - Optional. It represents the mode of PMI reporting. It
%                     must be a character array or a string scalar. It must
%                     be one of {'Subband', 'Wideband'}. The default value
%                     is 'Wideband'
%   SubbandSize     - Subband size for PMI reporting, provided by the
%                     higher-layer parameter NSBPRB. It must be a positive
%                     scalar and must be one of two possible subband sizes,
%                     as defined in TS 38.214 Table 5.2.1.4-2. It is
%                     applicable only when the PMIMode is provided as
%                     'Subband' and the size of BWP is greater than or
%                     equal to 24 PRBs
%   PRGSize         - Optional. Precoding resource block group (PRG) size
%                     for CQI calculation, provided by the higher-layer
%                     parameter pdsch-BundleSizeForCSI. This field is
%                     applicable when the PMI reporting is needed for the
%                     CSI report quantity cri-RI-i1-CQI, as defined in
%                     TS 38.214 Section 5.2.1.4.2. This report quantity
%                     expects only the i1 set of PMI to be reported as part
%                     of CSI parameters and PMI mode is expected to be
%                     'Wideband'. But, for the computation of the CQI in
%                     this report quantity, PMI i2 values are needed for
%                     each PRG. Hence, the PMI output, when this field is
%                     configured, is given as a set of i2 values, one for
%                     each PRG of the specified size. It must be a scalar
%                     and it must be one of {2, 4}. Empty ([]) is also
%                     supported to represent that this field is not
%                     configured by higher layers. If it is present and not
%                     configured as empty, irrespective of the PMIMode,
%                     PRGSize is considered for the number of subbands
%                     calculation instead of SubbandSize and the function
%                     reports PMI for each PRG. This field is applicable
%                     only when the CodebookType is specified as
%                     'Type1SinglePanel'. The default value is []
%   CodebookMode    - Optional. It represents the codebook mode and it must
%                     be a scalar. The value must be one of {1, 2}.
%                        - When CodebookType is specified as
%                          'Type1SinglePanel', this field is applicable
%                          only if the number of transmission layers is 1
%                          or 2 and number of CSI-RS ports is greater than
%                          2
%                        - When CodebookType is specified as
%                          'Type1MultiPanel', this field is applicable for
%                          all the number of transmission layers and the
%                          CodebookMode value 2 is applicable only for the
%                          panel configurations with Ng value 2
%                     This field is not applicable for CodebookType
%                     'Type2'. The default value is 1
%   CodebookSubsetRestriction
%                   - Optional. It is a binary vector (right-msb) which
%                     represents the codebook subset restriction.
%                       - When the CodebookType is specified as
%                         'Type1SinglePanel' or 'Type1MultiPanel' and the
%                         number of CSI-RS ports is greater than 2, the
%                         length of the input vector must be N1*N2*O1*O2,
%                         where N1 and N2 are panel configurations obtained
%                         from PanelDimensions field and O1 and O2 are the
%                         respective discrete Fourier transform (DFT)
%                         oversampling factors obtained from TS.38.214
%                         Table 5.2.2.2.1-2 for 'Type1SinglePanel' codebook
%                         type or TS.38.214 Table 5.2.2.2.2-1 for
%                         'Type1MultiPanel' codebook type. When the number
%                         of CSI-RS ports is 2, the applicable codebook
%                         type is 'Type1SinglePanel' and the length of the
%                         input vector must be 6, as defined in TS 38.214
%                         Section 5.2.2.2.1
%                       - When CodebookType is specified as 'Type2', this
%                         field is a bit vector which is obtained by
%                         concatenation of two bit vectors [B1 B2]. B1 is a
%                         bit vector of 11 bits (right-msb) when N2 of the
%                         panel dimensions is greater than 1 and 0 bits
%                         otherwise.  B2 is a combination of 4 bit vectors,
%                         each of length 2*N1*N2. B1 denotes 4 sets of beam
%                         groups for which restriction is applicable. B2
%                         denotes the maximum allowable amplitude for each
%                         of the DFT vectors in each of the respective beam
%                         groups denoted by B1. The default value is empty
%                         ([]), which means there is no codebook subset
%                         restriction
%   i2Restriction   - Optional. It is a binary vector which represents the
%                     restricted i2 values in a codebook. Length of the
%                     input vector must be 16. First element of the input
%                     binary vector corresponds to i2 as 0, second element
%                     corresponds to i2 as 1, and so on. Binary value 1
%                     indicates that the precoding matrix associated with
%                     the respective i2 is unrestricted and 0 indicates
%                     that the precoding matrix associated with the
%                     respective i2 is restricted. For a precoding matrices
%                     codebook, if the number of possible i2 values are
%                     less than 16, then only the required binary elements
%                     are considered and the trailing extra elements in the
%                     input vector are ignored. This field is applicable
%                     only when the number of CSI-RS ports is greater than
%                     2 and the CodebookType field is specified as
%                     'Type1SinglePanel'. The default value is empty ([]),
%                     which means there is no i2 restriction
%   NumberOfBeams   - It is a scalar which represents the number of beams
%                     to be considered in the beam group. This field is
%                     applicable only when the CodebookType is specified as
%                     'Type2'. The value must be one of {2, 3, 4}
%   PhaseAlphabetSize
%                   - Optional. It is a scalar which represents the range
%                     of the phases that are to be considered for the
%                     computation of PMI i2 indices. This field is
%                     applicable only when the CodebookType is specified as
%                     'Type2'. The value must be one of {4, 8}. The value 4
%                     represents the phases corresponding to QPSK and the
%                     value 8 represents the phases corresponding to 8-PSK.
%                     The default value is 4
%   SubbandAmplitude
%                   - Optional. It is a logical scalar which enables the
%                     reporting of amplitudes per subband when set to true
%                     and disables subband amplitude in PMI reporting when
%                     set to false. The value must be one of {true, false}.
%                     This field is applicable when CodebookType is
%                     specified as 'Type2' and PMIMode is 'Subband'. The
%                     default value is false
%
%   For the CodebookSubsetRestriction,
%   - When CodebookType field is specified as 'Type1SinglePanel' or
%   'Type1MultiPanel', the element N2*O2*l+m+1 (1-based) is associated with
%   the precoding matrices based on vlm (l = 0...N1*O1-1, m = N2*O2-1). If
%   the associated binary value is zero, then all the precoding matrices
%   based on vlm are restricted.
%   - When CodebookType field is specified as 'Type1SinglePanel', only if
%   the number of transmission layers is one of {3, 4} and the number of
%   CSI-RS ports is greater than or equal to 16, the elements
%   {mod(N2*O2*(2*l-1)+m,N1*O1*N2*O2)+1, N2*O2*(2*l)+m+1,
%   N2*O2*(2*l+1)+m+1} (1-based) are each associated with all the precoding
%   matrices based on vbarlm (l = 0....(N1*O1/2)-1, m = 0....N2*O2), as
%   defined in TS 38.214 Section 5.2.2.2.1. If one or more of the
%   associated binary values is zero, then all the precoding matrices based
%   on vbarlm are restricted.
%
%   NLAYERS is a scalar representing the number of transmission layers.
%   When CodebookType is specified as 'Type1SinglePanel', its value must be
%   in the range of 1...8. When CodebookType is specified as
%   'Type1MultiPanel', its value must be in the range of 1...4. When
%   CodebookType is specified as 'Type2', its value must be in the range of
%   1...2.
%
%   H is the channel estimation matrix. It is of size
%   K-by-L-by-nRxAnts-by-Pcsirs, where K is the number of subcarriers in
%   the carrier resource grid, L is the number of orthogonal frequency
%   division multiplexing (OFDM) symbols spanning one slot, nRxAnts is the
%   number of receive antennas, and Pcsirs is the number of CSI-RS antenna
%   ports. Note that the number of transmission layers provided must be
%   less than or equal to min(nRxAnts,Pcsirs).
%
%   PMISET is an output structure with these fields:
%   i1 - Indicates wideband PMI (1-based).
%           - It is a three-element vector in the form of [i11 i12 i13],
%             when CodebookType is specified as 'Type1SinglePanel'. Note
%             that i13 is not applicable when the number of transmission
%             layers is one of {1, 5, 6, 7, 8}. In that case, function
%             returns the value of i13 as 1
%           - It is a six-element vector in the form of
%             [i11 i12 i13 i141 i142 i143] when CodebookType is specified
%             as 'Type1MultiPanel'. Note that when CodebookMode is 1 and
%             number of antenna panels is 2, i142 and i143 are not
%             applicable and when CodebookMode is 2, i143 is not
%             applicable. In both the codebook modes, i13 value is not
%             applicable when the number of transmission layers is 1. In
%             these cases, the function returns the respective values as 1
%           - It is an array with the elements in the following order
%             [q1 q2 i12 i131 AmplitudeSet1 i132 AmplitudeSet2] when
%             CodebookType is specified as 'Type2'. AmplitudeSet1 and
%             AmplitudeSet2 are each vectors with the amplitude values
%             corresponding to the number of beams for each polarization on
%             each layer respectively. i131 and i132 values represent the
%             strongest beam indices for each layer respectively. The
%             elements are placed in this order according to TS 38.214
%             Section 5.2.2.2.3
%   i2 - Indicates subband PMI (1-based).
%           - For 'Type1SinglePanel' codebook type
%                - When PMIMode is specified as 'wideband', it is a scalar
%                  representing one i2 indication for the entire band
%                - When PMIMode is specified as 'subband' or when PRGSize
%                  is configured as other than empty ([]), one subband
%                  indication i2 is reported for each subband or PRG,
%                  respectively. Length of the i2 vector in the latter case
%                  equals to the number of subbands or PRGs
%           - For 'Type1MultiPanel' codebook type
%                - When PMIMode is specified as 'wideband', it is a
%                  three-element column vector in the form of
%                  [i20; i21; i22] representing one i2 set for the entire
%                  band
%                - When PMIMode is configured as 'subband', it is a matrix
%                  of size 3-by-numSubbands, where numSubbands represents
%                  the number of subbands. In subband PMIMode, each column
%                  represents an indices set [i20; i21; i22] for each
%                  subband and each row consists of an array of elements of
%                  length numSubbands. Note that when CodebookMode is
%                  specified as 1, i21 and i22 are not applicable. In that
%                  case i2 is considered as i20 (first row), and i21 and
%                  i22 are given as ones
%           - For 'Type2' codebooks it is an array with the elements in
%             the following order
%                -  When SubbandAmplitude is true,
%                   For single layer:
%                   the index set for each subband is in the form of
%                   [i211 i221] with the size
%                   2*reportConfig.NumberOfBeams-by-2-by-numSubbands.
%                   For two layers:
%                   the index set for each subband is in the form of
%                   [i211 i221 i212 i222] with the size
%                   2*reportConfig.NumberOfBeams-by-4-by-numSubbands. i211
%                   and i212 are column vectors corresponding to the
%                   co-phasing factors for both the polarizations for each
%                   layer and the values are in the range
%                   of 0:PhaseAlphabetSize-1. i221 and i222 are column
%                   vectors corresponding to subband amplitudes for both
%                   the polarizations for each layer, as defined in TS
%                   38.214 Table 5.2.2.2.3-3. According to the TS 38.214
%                   Section 5.2.2.2.3, the subband amplitude values that
%                   are not reported are given as NaNs
%                -  When SubbandAmplitude is false,
%                   For single layer:
%                   the index set for each subband is in the form of
%                   i211 with the size
%                   2*reportConfig.NumberOfBeams-by-1-by-numSubbands.
%                   For two layers:
%                   the index set for each subband is in the form of
%                   [i211 i212] with the size
%                   2*reportConfig.NumberOfBeams-by-2-by-numSubbands. i211
%                   and i212 are column vectors corresponding to the
%                   co-phasing factors for both the polarizations for each
%                   layer and the values are in the range
%                   of 0:PhaseAlphabetSize-1.
%
%   Note that when the number of CSI-RS ports is 2, the applicable codebook
%   type is 'Type1SinglePanel'. In this case, the precoding matrix is
%   obtained by a single index (i2 field here) based on TS 38.214 Table
%   5.2.2.2.1-1. The function returns the i1 as [1 1 1] to support same
%   indexing for all INFO fields according to 'Type1SinglePanel' codebook
%   type.  When the number of CSI-RS ports is 1, all the values of i1 and
%   i2 fields are returned as ones, considering the dimensions of type I
%   single-panel codebook index set.
%
%   INFO is an output structure with these fields:
%   SINRPerRE      - It represents the linear signal to noise plus
%                    interference ratio (SINR) values in each RE within the
%                    BWP for all the layers and all the precoding matrices.
%                    When CodebookType is specified as 'Type1SinglePanel',
%                    it is a multidimensional array of size
%                       - N-by-L-by-nLayers-by-i2Length-by-i11Length-by-i12Length-by-i13Length
%                         when the number of CSI-RS ports is greater than 2
%                       - N-by-L-by-nLayers-by-i2Length when the number of
%                         CSI-RS ports is 2
%                       - N-by-L when the number of CSI-RS ports is 1
%                    N is the number of subcarriers in the BWP resource
%                    grid, i2Length is the maximum number of possible i2
%                    values and i11Length, i12Length, i13Length are the
%                    maximum number of possible i11, i12, and i13 values
%                    for the given report configuration respectively.
%                    When CodebookType is specified as 'Type1MultiPanel',
%                    it is a multidimensional array of size
%                    N-by-L-by-nLayers-by-i20Length-by-i21Length-by-i22Length-by-i11Length-by-i12Length-by-i13Length-by-i141Length-by-i142Length-by-i143Length
%                    i20Length, i21Length, i22Length, i141Length,
%                    i142Length and i143Length are the maximum number of
%                    possible i20, i21, i22, i141, i142, and i143 values
%                    for the given configuration respectively. 
%                    When CodebookType is specified as 'Type2', the PMI
%                    computation process uses the average channel matrix
%                    but not the RE level channel matrices. In this case,
%                    this field is not applicable and returned as []
%   SINRPerREPMI   - When CodebookType is specified as 'Type1SinglePanel'
%                    or 'Type1MultiPanel', it represents the linear SINR
%                    values in each RE within the BWP for all the layers
%                    for the reported precoding matrix. It is of size
%                    N-by-L-by-nLayers
%                    When CodebookType is specified as 'Type2', this field
%                    is not applicable and it is returned as []
%   SINRPerSubband - It represents the linear SINR values in each subband
%                    for all the layers. SINR value in each subband is
%                    formed by averaging SINRPerRE estimates across each
%                    subband (i.e. in the appropriate region of the N
%                    dimension and across the L dimension).
%                    When CodebookType is specified as 'Type1SinglePanel',
%                    it is a multidimensional array of size
%                       - numSubbands-by-nLayers-by-i2Length-by-i11Length-by-i12Length-by-i13Length
%                         when the number of CSI-RS ports is greater than 2
%                       - numSubbands-by-nLayers-by-i2Length when the
%                         number of CSI-RS ports is 2
%                       - numSubbands-by-1 when the number of CSI-RS ports
%                         is 1
%                    When CodebookType is specified as 'Type1MultiPanel',
%                    it is a multidimensional array of size
%                       - numSubbands-by-nLayers-by-i20Length-by-i21Length-by-i22Length-by-i11Length-by-i12Length-by-i13Length-by-i141Length-by-i142Length-by-i143Length
%                    When CodebookType is specified as 'Type2' this field
%                    is of dimensions numSubbands-by-numLayers. In this
%                    case the PMI computation process uses the average
%                    channel matrix but not the RE level channel matrices
%   Codebook       - Multidimensional array containing precoding matrices
%                    based on the CSI reporting configuration.
%                    When CodebookType is specified as 'Type1SinglePanel',
%                    it is a multidimensional array of size
%                       - Pcsirs-by-nLayers-by-i2Length-by-i11Length-by-i12Length-by-i13Length
%                         when the number of CSI-RS ports is greater than 2
%                       - 2-by-nLayers-by-i2Length when the number of
%                         CSI-RS ports is 2
%                       - 1-by-1 with the value 1 when the number of CSI-RS
%                         ports is 1
%                    When CodebookType is specified as 'Type1MultiPanel',
%                    it is a multidimensional array of size
%                       - Pcsirs-by-nLayers-by-i20Length-by-i21Length-by-i22Length-by-i11Length-by-i12Length-by-i13Length-by-i141Length-by-i142Length-by-i143Length
%                    When CodebookType is specified as 'Type2', it is
%                    reported as []
%                    Note that the restricted precoding matrices as per the
%                    report configuration are returned as all zeros, for
%                    type I codebooks
%   W              - Precoding matrix that corresponds to the reported
%                    PMI in each subband. It is a matrix of size
%                    Pcsirs-by-numLayers-by-numSubbands. For wideband case,
%                    numSubbands will be 1
%   PMIFullSet     - When CodebookType is specified as 'Type2', it is a
%                    structure with the PMISet containing the original
%                    values that are considered as NaNs in the reported
%                    PMISet according to TS 38.214 Section 5.2.2.2.3
%
%   [PMISET,INFO] = hDLPMISelect(...,NVAR) specifies the estimated noise
%   variance at the receiver NVAR as a nonnegative scalar. By default, the
%   value of nVar is considered as 1e-10, if it is not given as input.
%
%   Note that i1 and i2 fields of PMISET and SINRPerRE and SINRPerSubband
%   fields of INFO are returned as array of NaNs for these cases:
%   - When CSI-RS is not present in the operating slot or in the BWP
%   - When all the precoding matrices in a codebook are restricted
%   Also note that the PMI i2 index (or indices set) is reported as NaNs in
%   the subbands where CSI-RS is not present.
%
%   % Example:
%   % This example demonstrates how to calculate PMI.
%
%   % Carrier configuration
%   carrier = nrCarrierConfig;
%
%   % CSI-RS configuration
%   csirs = nrCSIRSConfig;
%   csirs.CSIRSType = {'nzp','nzp'};
%   csirs.RowNumber = [4 4];
%   csirs.Density = {'one','one'};
%   csirs.SubcarrierLocations = {0 0};
%   csirs.SymbolLocations = {0,5};
%   csirs.NumRB = 52;
%   csirs.RBOffset = 0;
%   csirs.CSIRSPeriod = [4 0];
%
%   % Configure the number of transmit and receive antennas
%   nTxAnts = max(csirs.NumCSIRSPorts);
%   nRxAnts = nTxAnts;
%
%   % Configure the number of transmission layers
%   numLayers = 1;
%
%   % Generate CSI-RS indices and symbols
%   csirsInd = nrCSIRSIndices(carrier,csirs);
%   csirsSym = nrCSIRS(carrier,csirs);
%
%   % Resource element mapping
%   txGrid = nrResourceGrid(carrier,nTxAnts);
%   txGrid(csirsInd) = csirsSym;
%
%   % Get OFDM modulation related information
%   OFDMInfo = nrOFDMInfo(carrier);
%
%   % Perform OFDM modulation
%   txWaveform = nrOFDMModulate(carrier,txGrid);
%
%   % Configure the channel parameters.
%   channel = nrTDLChannel;
%   channel.NumTransmitAntennas = nTxAnts;
%   channel.NumReceiveAntennas = nRxAnts;
%   channel.SampleRate = OFDMInfo.SampleRate;
%   channel.DelayProfile = 'TDL-C';
%   channel.DelaySpread = 300e-9;
%   channel.MaximumDopplerShift = 5;
%   chInfo = info(channel);
%
%   % Calculate the maximum channel delay
%   maxChDelay = ceil(max(chInfo.PathDelays*OFDMInfo.SampleRate)) + chInfo.ChannelFilterDelay;
%
%   % Pass the time-domain waveform through the channel
%   rxWaveform = channel([txWaveform; zeros(maxChDelay,nTxAnts)]);
%
%   % Calculate the timing offset
%   offset = nrTimingEstimate(carrier,rxWaveform,csirsInd,csirsSym);
%
%   % Perform timing synchronization
%   rxWaveform = rxWaveform(1+offset:end,:);
%
%   % Add AWGN
%   SNRdB = 20;          % in dB
%   SNR = 10^(SNRdB/10); % Linear value
%   sigma = 1/(sqrt(2.0*channel.NumReceiveAntennas*double(OFDMInfo.Nfft)*SNR)); % Noise standard deviation
%   rng('default');
%   noise = sigma*complex(randn(size(rxWaveform)),randn(size(rxWaveform)));
%   rxWaveform = rxWaveform + noise;
%   rxGrid = nrOFDMDemodulate(carrier,rxWaveform);
%
%   % Perform the channel estimate
%   [H,nVar] = nrChannelEstimate(rxGrid,csirsInd,csirsSym,'CDMLengths',[2 1]);
%
%   % Configure the parameters related to CSI reporting
%   reportConfig.NStartBWP = 0;
%   reportConfig.NSizeBWP = 52;
%   reportConfig.PanelDimensions = [2 1];
%   reportConfig.PMIMode = 'Subband';
%   reportConfig.SubbandSize = 4;
%   reportConfig.PRGSize = [];
%   reportConfig.CodebookMode = 2;
%   reportConfig.CodebookSubsetRestriction = [];
%   reportConfig.i2Restriction = [];
%
%   % Calculate the PMI values
%   [PMISet,PMIInfo] = hDLPMISelect(carrier,csirs,reportConfig,numLayers,H,nVar)

%   Copyright 2020-2022 The MathWorks, Inc.

    narginchk(5,6);
    if (nargin == 6)
        nVar = varargin{1};
    else
        % Consider a small noise variance value by default, if the noise
        % variance is not given
        nVar = 1e-10;
    end
    [reportConfig,csirsIndSubs,nVar] = validateInputs(carrier,csirs,reportConfig,nLayers,H,nVar);

    % Get the PMI subband related information
    subbandInfo = hDLPMISubbandInfo(carrier,reportConfig);

    numCSIRSPorts = csirs.NumCSIRSPorts(1);

    % Set isType1SinglePanel flag to true if the codebook type is
    % 'Type1SinglePanel'
    isType1SinglePanel = strcmpi(reportConfig.CodebookType,'Type1SinglePanel');
    isType1MultiPanel = strcmpi(reportConfig.CodebookType,'Type1MultiPanel');
    isType2 = strcmpi(reportConfig.CodebookType,'Type2');

    if isType1SinglePanel
        if numCSIRSPorts == 1
            % Codebook is a scalar with the value 1, when the number of CSI-RS
            % ports is 1
            codebook = 1;
        else
            % Codebook is a multidimensional matrix of size
            % Pcsirs-by-nLayers-by-i2Length-by-i11Length-by-i12Length-by-i13Length
            % or Pcsirs-by-nLayers-by-i2Length based on the number of
            % CSI-RS ports
            codebook = getPMIType1SinglePanelCodebook(reportConfig,nLayers);
        end
        % Get the size of Codebook
        [~,~,i2Length,i11Length,i12Length,i13Length] = size(codebook);

        % Store the sizes of the indices in a variable
        indexSetSizes = [i2Length,i11Length,i12Length,i13Length];
    elseif isType1MultiPanel
        % Codebook is a multidimensional matrix of size
        % Pcsirs-by-nLayers-by-i20Length-by-i21Length-by-i22Length-by-i11Length-by-i12Length-by-i13Length-by-i141Length-by-i142Length-by-i143Length
        codebook = getPMIType1MultiPanelCodebook(reportConfig,nLayers);
        [~,~,i20Length,i21Length,i22Length,i11Length,i12Length,i13Length,i141Length,i142Length,i143Length] = size(codebook);

        % Store the sizes of the indices in a variable
        indexSetSizes = [i20Length,i21Length,i22Length,i11Length,i12Length,i13Length,i141Length,i142Length,i143Length];
    else % Type II codebooks
        codebook = [];
        indexSetSizes = [];
    end

    % Calculate the start of BWP relative to the carrier
    bwpStart = reportConfig.NStartBWP - carrier.NStartGrid;

    % Consider only the RE indices corresponding to the first CSI-RS port
    csirsIndSubs_k = csirsIndSubs(:,1);
    csirsIndSubs_l = csirsIndSubs(:,2);

    % Extract the CSI-RS indices which are present in the BWP
    csirsIndSubs_k = csirsIndSubs_k((csirsIndSubs_k >= bwpStart*12 + 1) & csirsIndSubs_k <= (bwpStart + reportConfig.NSizeBWP)*12);
    csirsIndSubs_l = csirsIndSubs_l((csirsIndSubs_k >= bwpStart*12 + 1) & csirsIndSubs_k <= (bwpStart + reportConfig.NSizeBWP)*12);
    csirsIndSubs_length = numel(csirsIndSubs_k);

    % Make the CSI-RS subscripts relative to BWP
    csirsIndSubs_k = csirsIndSubs_k - bwpStart*12;

    % Generate PMI set and output information structure with NaNs
    if isType2
        numi1Indices = 3 + (1 + 2*reportConfig.NumberOfBeams)*nLayers;
        numI2Columns = nLayers*(1+reportConfig.SubbandAmplitude);
        numI2Rows = 2*reportConfig.NumberOfBeams;
        PMINaNSet.i1 = NaN(1,numi1Indices);
        PMINaNSet.i2 = NaN(numI2Rows,numI2Columns,subbandInfo.NumSubbands);
        nanInfo.SINRPerRE = [];
        nanInfo.SINRPerREPMI = NaN(reportConfig.NSizeBWP*12,carrier.SymbolsPerSlot,nLayers);
        nanInfo.SINRPerSubband = NaN(subbandInfo.NumSubbands,nLayers);
        nanInfo.Codebook = [];
        nanInfo.W = NaN(numCSIRSPorts,nLayers,subbandInfo.NumSubbands);
        nanInfo.PMIFullSet = PMINaNSet;
    else
        if isType1SinglePanel
            PMINaNSet.i1 = NaN(1,3);
            PMINaNSet.i2 = NaN(1,subbandInfo.NumSubbands);
        else
            PMINaNSet.i1 = NaN(1,6);
            PMINaNSet.i2 = NaN(3,subbandInfo.NumSubbands);
        end
        nanInfo.SINRPerRE = NaN([reportConfig.NSizeBWP*12,carrier.SymbolsPerSlot,nLayers,indexSetSizes]);
        nanInfo.SINRPerREPMI = NaN([reportConfig.NSizeBWP*12,carrier.SymbolsPerSlot,nLayers]);
        nanInfo.SINRPerSubband = NaN([subbandInfo.NumSubbands,nLayers,indexSetSizes]);
        nanInfo.Codebook = codebook;
        nanInfo.W = NaN(numCSIRSPorts,nLayers);
    end

    if (isType2 && isempty(csirsIndSubs_k)) || (~isType2 && ((isempty(csirsIndSubs_k) || ~any(codebook(:))))) || all(isnan(H(:)))
        % Report the outputs as all NaNs, if there are no CSI-RS resources
        % present in the BWP or all the precoding matrices of the codebook
        % are restricted
        PMISet = PMINaNSet;
        info = nanInfo;        
    else
        % Rearrange the channel matrix dimensions from
        % K-by-L-by-nRxAnts-by-Pcsirs to nRxAnts-by-Pcsirs-by-K-by-L
        H = permute(H,[3,4,1,2]);

        if strcmpi(reportConfig.CodebookType,'Type2')
            Havg = mean(H,[3 4]);
            [W,PMISet,SubbandSINRs] = getType2PMI(reportConfig,Havg,nVar,nLayers);
            Htemp = reshape(H,size(H,1),size(H,2),[]);
            Hcsi = Htemp(:,:,csirsIndSubs_k+(csirsIndSubs_l-1)*size(H,3));
            SINRPerRETemp = NaN(csirsIndSubs_length,nLayers);
            SINRPerREPMI = NaN(reportConfig.NSizeBWP*12,carrier.SymbolsPerSlot,nLayers);
            if any(W,'all')
                % Calculate the linear SINR values of all the CSI-RS
                % REs for each precoding matrix
                SINRPerRETemp(:,:) = reshape(getPrecodedSINR(Hcsi,nVar,W),csirsIndSubs_length,nLayers);

                % Map the calculated SINR values to corresponding RE indices
                for re = 1:csirsIndSubs_length
                    k = csirsIndSubs_k(re);
                    l = csirsIndSubs_l(re);
                    SINRPerREPMI(k,l,:) = SINRPerRETemp(re,:);
                end
            end            
        else
            % Select the page matrix based on number of elements in channel
            % matrix and precoding matrices
            if(csirsIndSubs_length < prod(indexSetSizes)) % Consider precoding matrix as page matrix
                SINRPerRE = NaN([reportConfig.NSizeBWP*12,carrier.SymbolsPerSlot,nLayers,indexSetSizes]);
                for reIdx = 1:numel(csirsIndSubs_k)
                    % Calculate the linear SINR values for each CSI-RS RE
                    % by considering all unrestricted precoding matrices
                    k = csirsIndSubs_k(reIdx);
                    l = csirsIndSubs_l(reIdx);
                    Htemp = H(:,:,k,l);
                    sinr = getPrecodedSINR(Htemp,nVar,codebook);
                    SINRPerRE(k,l,:) = sinr(:);
                end
            else % Consider channel matrix as page matrix
                Htemp = reshape(H,size(H,1),size(H,2),[]);
                Hcsi = Htemp(:,:,csirsIndSubs_k+(csirsIndSubs_l-1)*size(H,3));
                SINRPerRETemp = NaN([csirsIndSubs_length,nLayers,indexSetSizes]);
                for Indx = 1:prod(indexSetSizes)
                    if any(codebook(:,:,Indx),'all')
                        % Calculate the linear SINR values of all the CSI-RS
                        % REs for each precoding matrix
                        SINRPerRETemp(:,:,Indx) = reshape(getPrecodedSINR(Hcsi,nVar,codebook(:,:,Indx)),csirsIndSubs_length,nLayers);
                    end
                end

                % Map the calculated SINR values to corresponding RE indices
                SINRPerRE = NaN([reportConfig.NSizeBWP*12,carrier.SymbolsPerSlot,nLayers,indexSetSizes]);
                for re = 1:csirsIndSubs_length
                    k = csirsIndSubs_k(re);
                    l = csirsIndSubs_l(re);
                    SINRPerRE(k,l,:) = SINRPerRETemp(re,:);
                end
            end

            % Calculate the total SINR value for the entire grid
            % corresponding to each index to check which index gives the
            % maximum wideband SINR value
            % If the SINRPerRE values result as all NaNs, report the
            % PMISet as NaNs
            if ~all(isnan(SINRPerRE(:)))
                totalSINR = squeeze(sum(SINRPerRE,[1 2 3],'omitnan')); % Sum of SINRs across the BWP for all layers for each PMI index
                % Round the total SINR value to four decimals, to avoid the
                % fluctuations in the PMI output because of the minute
                % variations among the SINR values corresponding to different
                % PMI indices
                totalSINR = round(reshape(totalSINR,indexSetSizes),4,'decimals');
                % Find the set of indices that correspond to the precoding
                % matrix with maximum SINR
                if isType1SinglePanel
                    [i2,i11,i12,i13] = ind2sub(size(totalSINR),find(totalSINR == max(totalSINR,[],'all'),1));
                    PMISet.i1 = [i11 i12 i13];
                    PMISet.i2 = i2;
                    W = codebook(:,:,i2,i11,i12,i13);
                    SINRPerREPMI = SINRPerRE(:,:,:,i2,i11,i12,i13);
                else
                    [i20,i21,i22,i11,i12,i13,i141,i142,i143] = ind2sub(size(totalSINR),find(totalSINR == max(totalSINR,[],'all'),1));
                    PMISet.i1 = [i11 i12 i13 i141 i142 i143];
                    PMISet.i2 = [i20; i21; i22];
                    W = codebook(:,:,i20,i21,i22,i11,i12,i13,i141,i142,i143);
                    SINRPerREPMI = SINRPerRE(:,:,:,i20,i21,i22,i11,i12,i13,i141,i142,i143);
                end
                SubbandSINRs = reshape(squeeze(mean(mean(SINRPerRE,'omitnan'),'omitnan')),[1 nLayers indexSetSizes]);
            else
                PMISet = PMINaNSet;
                W = nanInfo.W;
                SubbandSINRs = NaN([subbandInfo.NumSubbands,nLayers,indexSetSizes]);
                SINRPerREPMI = NaN([reportConfig.NSizeBWP*12,carrier.SymbolsPerSlot,nLayers]);
            end
        end
        % Get the number of subbands
        numSubbands = subbandInfo.NumSubbands;
        % Consider the starting position of the first subband as 0, which
        % is the start of BWP
        subbandStart = 0;
        pmiTemp = struct('i1',PMISet.i1,'i2',PMISet.i2);

        if numSubbands > 1 || (isType2 && reportConfig.SubbandAmplitude)
            SubbandSINRs = NaN([subbandInfo.NumSubbands,nLayers,indexSetSizes]);
            SINRPerREPMI = NaN([reportConfig.NSizeBWP*12,carrier.SymbolsPerSlot,nLayers]);
            W = zeros(numCSIRSPorts,nLayers,subbandInfo.NumSubbands);
            % Loop over all the subbands
            for SubbandIdx = 1:numSubbands
                % Extract the SINR values in the subband
                kRangeSB = (subbandStart*12 + 1):(subbandStart+ subbandInfo.SubbandSizes(SubbandIdx))*12;
                if ~isType2                                        
                    sinrValuesPerSubband = SINRPerRE(kRangeSB,:,:,:,:,:,:,:,:,:);
                    if all(isnan(sinrValuesPerSubband(:))) % CSI-RS is absent in the subband
                        % Report i2 as NaN for the current subband as CSI-RS is not
                        % present
                        pmiTemp.i2(:,SubbandIdx) = NaN;
                    else % CSI-RS is present in the subband
                        % Average the SINR per RE values across the subband for all
                        % the PMI indices
                        SubbandSINRs(SubbandIdx,:,:,:,:,:,:,:,:) = squeeze(mean(mean(sinrValuesPerSubband,'omitnan'),'omitnan'));

                        % Add the subband SINR values across all the layers for
                        % each PMI i2 index set.
                        if ~isType1SinglePanel
                            tempSubbandSINR = round(sum(SubbandSINRs(SubbandIdx,:,:,:,:,pmiTemp.i1(1),pmiTemp.i1(2),pmiTemp.i1(3),pmiTemp.i1(4),pmiTemp.i1(5),pmiTemp.i1(6)),2,'omitnan'),4,'decimals');
                            % Report i2 indices set [i20; i21; i22] corresponding
                            % to the maximum SINR for current subband
                            [i20,i21,i22] = ind2sub(size(squeeze(tempSubbandSINR)),find(tempSubbandSINR == max(tempSubbandSINR,[],'all'),1));
                            pmiTemp.i2(:,SubbandIdx) = [i20;i21;i22];
                            W(:,:,SubbandIdx) = codebook(:,:,i20,i21,i22,pmiTemp.i1(1),pmiTemp.i1(2),pmiTemp.i1(3),pmiTemp.i1(4),pmiTemp.i1(5),pmiTemp.i1(6));
                            SINRPerREPMI(kRangeSB,:,:) = SINRPerRE(kRangeSB,:,:,i20,i21,i22,pmiTemp.i1(1),pmiTemp.i1(2),pmiTemp.i1(3),pmiTemp.i1(4),pmiTemp.i1(5),pmiTemp.i1(6));
                        else
                            tempSubbandSINR = round(sum(SubbandSINRs(SubbandIdx,:,:,pmiTemp.i1(1),pmiTemp.i1(2),pmiTemp.i1(3)),2,'omitnan'),4,'decimals');

                            % Report i2 index corresponding to the maximum SINR for
                            % current subband
                            [~,pmiTemp.i2(SubbandIdx)] = max(tempSubbandSINR);
                            W(:,:,SubbandIdx) = codebook(:,:,pmiTemp.i2(SubbandIdx),pmiTemp.i1(1),pmiTemp.i1(2),pmiTemp.i1(3));
                            SINRPerREPMI(kRangeSB,:,:) = SINRPerRE(kRangeSB,:,:,pmiTemp.i2(SubbandIdx),pmiTemp.i1(1),pmiTemp.i1(2),pmiTemp.i1(3));
                        end
                    end
                else
                    csirsSBInd = find(csirsIndSubs_k >= kRangeSB(1) & csirsIndSubs_k <= kRangeSB(end));
                    if ~(all(isnan(PMISet.i1)) && all(isnan(PMISet.i2(:)))) && ~isempty(csirsSBInd)
                        Havg_sb = mean(H(:,:,kRangeSB,:),[3 4]);
                        [Wsubband,PMISetSubband,SubbandSINR] = getType2PMI(reportConfig,Havg_sb,nVar,nLayers,PMISet);

                        csirs_sb_k = csirsIndSubs_k(csirsSBInd);
                        csirs_sb_l = csirsIndSubs_l(csirsSBInd);
                        numCSIRSInd_SB = numel(csirs_sb_k);
                        Htemp = reshape(H,size(H,1),size(H,2),[]);
                        Hcsi = Htemp(:,:,csirs_sb_k+(csirs_sb_l-1)*size(H,3));
                        SINRPerRETemp = NaN(numCSIRSInd_SB,nLayers);
                        SINRPerRE_SB = NaN(reportConfig.NSizeBWP*12,carrier.SymbolsPerSlot,nLayers);
                        if any(Wsubband,'all')
                            % Calculate the linear SINR values of all the CSI-RS
                            % REs for each precoding matrix
                            SINRPerRETemp(:,:) = reshape(getPrecodedSINR(Hcsi,nVar,Wsubband),numCSIRSInd_SB,nLayers);

                            % Map the calculated SINR values to corresponding RE indices
                            for re = 1:numCSIRSInd_SB
                                k = csirs_sb_k(re);
                                l = csirs_sb_l(re);
                                SINRPerRE_SB(k,l,:) = SINRPerRETemp(re,:);
                            end
                        end                       
                        SINRPerREPMI(kRangeSB,:,:) = SINRPerRE_SB(kRangeSB,:,:);

                        % Store the subband precoding matrix and SINR value
                        W(:,:,SubbandIdx) = Wsubband;
                        pmiTemp.i2(:,1:nLayers*(1+reportConfig.SubbandAmplitude),SubbandIdx) = PMISetSubband.i2;
                        SubbandSINRs(SubbandIdx,:) = SubbandSINR;
                    else
                        W(:,:,SubbandIdx) = NaN(numCSIRSPorts,nLayers);
                        pmiTemp.i2(:,1:nLayers*(1+reportConfig.SubbandAmplitude),SubbandIdx) = NaN;
                        SubbandSINRs(SubbandIdx,:) = NaN;
                    end
                end
                % Compute the starting position of next subband
                subbandStart = subbandStart + subbandInfo.SubbandSizes(SubbandIdx);
            end
        end               
        if ~isType2 % Type I codebooks
            SubbandSINRs = reshape(SubbandSINRs,[subbandInfo.NumSubbands,nLayers,indexSetSizes]);
            % Form the output structure
            info.SINRPerRE = SINRPerRE;         % SINR value per RE for all the layers for all PMI indices
            info.SINRPerREPMI = SINRPerREPMI;   % SINR value per RE for all the layers for the reported PMI
            info.SINRPerSubband = SubbandSINRs; % SINR value per subband for all the layers for all PMI indices
            info.Codebook = codebook;           % PMI codebook containing the precoding matrices corresponding to all PMI indices
            info.W = W;                         % Precoding matrix corresponding to the reported PMI
            PMISet = pmiTemp;
        else % Type II codebooks
            info.SINRPerRE = [];
            info.SINRPerREPMI = SINRPerREPMI;
            info.SINRPerSubband = SubbandSINRs; % SINR value per subband for all the layers for the reported PMI
            info.Codebook = [];
            info.W = W;                         % Precoding matrix corresponding to the reported PMI
            info.PMIFullSet = pmiTemp;
            if any(isnan(pmiTemp.i1),'all') || any(isnan(pmiTemp.i2),'all')
                PMISet = pmiTemp;
            else
                PMISet = getType2PMISetToReport(pmiTemp,reportConfig.SubbandAmplitude,nLayers);
            end
        end
    end
end

function [reportConfigOut,csirsInd,nVar] = validateInputs(carrier,csirs,reportConfig,nLayers,H,nVar)
%   [REPORTCONFIGOUT,CSIRSIND,NVAR] = validateInputs(CARRIER,CSIRS,REPORTCONFIG,NLAYERS,H,NVAR)
%   validates the inputs arguments and returns the validated CSI report
%   configuration structure REPORTCONFIGOUT along with the NZP-CSI-RS
%   indices CSIRSIND and noise variance NVAR.

    fcnName = 'hDLPMISelect';
    validateattributes(carrier,{'nrCarrierConfig'},{'scalar'},fcnName,'CARRIER');
    % Validate 'csirs'
    validateattributes(csirs,{'nrCSIRSConfig'},{'scalar'},fcnName,'CSIRS');
    if ~isscalar(unique(csirs.NumCSIRSPorts))
        error('nr5g:hDLPMISelect:InvalidCSIRSPorts',...
            'All the CSI-RS resources must be configured to have the same number of CSI-RS ports.');
    end
    if iscell(csirs.CDMType)
        cdmType = csirs.CDMType;
    else
        cdmType = {csirs.CDMType};
    end
    if ~all(strcmpi(cdmType,cdmType{1}))
        error('nr5g:hDLPMISelect:InvalidCSIRSCDMTypes',...
            'All the CSI-RS resources must be configured to have the same CDM lengths.');
    end

    % Validate 'reportConfig'
    % Validate 'NSizeBWP'
    if ~isfield(reportConfig,'NSizeBWP')
        error('nr5g:hDLPMISelect:NSizeBWPMissing','NSizeBWP field is mandatory.');
    end
    nSizeBWP = reportConfig.NSizeBWP;
    if ~(isnumeric(nSizeBWP) && isempty(nSizeBWP))
        validateattributes(nSizeBWP,{'double','single'},{'scalar','integer','positive','<=',275},fcnName,'the size of BWP');
    else
        nSizeBWP = carrier.NSizeGrid;
    end
    % Validate 'NStartBWP'
    if ~isfield(reportConfig,'NStartBWP')
        error('nr5g:hDLPMISelect:NStartBWPMissing','NStartBWP field is mandatory.');
    end
    nStartBWP = reportConfig.NStartBWP;
    if ~(isnumeric(nStartBWP) && isempty(nStartBWP))
        validateattributes(nStartBWP,{'double','single'},{'scalar','integer','nonnegative','<=',2473},fcnName,'the start of BWP');
    else
        nStartBWP = carrier.NStartGrid;
    end
    if nStartBWP < carrier.NStartGrid
        error('nr5g:hDLPMISelect:InvalidNStartBWP',...
            ['The starting resource block of BWP ('...
            num2str(nStartBWP) ') must be greater than '...
            'or equal to the starting resource block of carrier ('...
            num2str(carrier.NStartGrid) ').']);
    end
    % Check whether BWP is located within the limits of carrier or not
    if (nSizeBWP + nStartBWP)>(carrier.NStartGrid + carrier.NSizeGrid)
        error('nr5g:hDLPMISelect:InvalidBWPLimits',['The sum of starting resource '...
            'block of BWP (' num2str(nStartBWP) ') and the size of BWP ('...
            num2str(nSizeBWP) ') must be less than or equal to '...
            'the sum of starting resource block of carrier ('...
            num2str(carrier.NStartGrid) ') and size of the carrier ('...
            num2str(carrier.NSizeGrid) ').']);
    end
    reportConfigOut.NStartBWP = nStartBWP;
    reportConfigOut.NSizeBWP = nSizeBWP;

    % Check for the presence of 'CodebookType' field
    if isfield(reportConfig,'CodebookType')
        reportConfigOut.CodebookType = validatestring(reportConfig.CodebookType,{'Type1SinglePanel','Type1MultiPanel','Type2'},fcnName,'CodebookType field');
    else
        reportConfigOut.CodebookType = 'Type1SinglePanel';
    end

    % Set the flags for the respective codebook types to use the parameters
    % accordingly
    isType1SinglePanel = strcmpi(reportConfigOut.CodebookType,'Type1SinglePanel');
    isType1MultiPanel = strcmpi(reportConfigOut.CodebookType,'Type1MultiPanel');
    isType2 = strcmpi(reportConfigOut.CodebookType,'Type2');

    % Validate 'CodebookMode'
    if isfield(reportConfig,'CodebookMode')
        validateattributes(reportConfig.CodebookMode,{'numeric'},...
            {'scalar','integer','positive','<=',2},fcnName,'CodebookMode field');
        reportConfigOut.CodebookMode = reportConfig.CodebookMode;
    else
        reportConfigOut.CodebookMode = 1;
    end

    % Validate 'PanelDimensions'
    N1 = 1;
    N2 = 1;
    O1 = 1;
    O2 = 1;
    NumCSIRSPorts = csirs.NumCSIRSPorts(1);

    % Hence the panel dimensions are common for both type1 single-panel and
    % type II, consider type I multi-panel flag
    if ~isType1MultiPanel
        if NumCSIRSPorts > 2
            if ~isfield(reportConfig,'PanelDimensions')
                error('nr5g:hDLPMISelect:PanelDimensionsMissing',...
                    'PanelDimensions field is mandatory.');
            end
            if isType2
                codebookType = 'Type II';
            else
                codebookType = 'Type I Single-Panel';
            end
            validateattributes(reportConfig.PanelDimensions,...
                {'double','single'},{'vector','numel',2},fcnName,['PanelDimensions field for ' codebookType ' codebooks']);
            N1 = reportConfig.PanelDimensions(1);
            N2 = reportConfig.PanelDimensions(2);
            Pcsirs = 2*prod(reportConfig.PanelDimensions);
            if Pcsirs ~= NumCSIRSPorts
                error('nr5g:hDLPMISelect:InvalidPanelDimensions',...
                    ['For the configured number of CSI-RS ports (' num2str(NumCSIRSPorts)...
                    '), the given panel configuration [' num2str(N1) ' ' num2str(N2)...
                    '] is not valid. Note that, two times the product of panel dimensions ('...
                    num2str(Pcsirs) ') must be equal to the number of CSI-RS ports (' num2str(NumCSIRSPorts) ').']);
            end
            % Supported panel configurations and oversampling factors for
            % type I single-panel codebooks, as defined in
            % TS 38.214 Table 5.2.2.2.1-2
            panelConfigs = [2     2     4     3     6     4     8     4     6    12     4     8    16   % N1
                            1     2     1     2     1     2     1     3     2     1     4     2     1   % N2
                            4     4     4     4     4     4     4     4     4     4     4     4     4   % O1
                            1     4     1     4     1     4     1     4     4     1     4     4     1]; % O2
            configIdx = find(panelConfigs(1,:) == N1 & panelConfigs(2,:) == N2,1);
            if isempty(configIdx)
                error('nr5g:hDLPMISelect:InvalidPanelConfiguration',['The given panel configuration ['...
                    num2str(reportConfig.PanelDimensions(1)) ' ' num2str(reportConfig.PanelDimensions(2)) '] ' ...
                    'is not valid for the given CSI-RS configuration. '...
                    'For a number of CSI-RS ports, the panel configuration should ' ...
                    'be one of the possibilities from TS 38.214 Table 5.2.2.2.1-2.']);
            end

            % Extract the oversampling factors
            O1 = panelConfigs(3,configIdx);
            O2 = panelConfigs(4,configIdx);
        elseif isType2
            error('nr5g:hDLPMISelect:InvalidCSIRSPortsConfigurationForType2',...
                'The minimum required number of CSI-RS ports for Type II codebooks is 4.');
        end
        reportConfigOut.PanelDimensions = [N1 N2];
    else
        if ~any(NumCSIRSPorts == [8 16 32])
            error('nr5g:hDLPMISelect:InvalidNumCSIRSPortsForMultiPanel',['For' ...
                ' type I multi-panel codebook type, the number of CSI-RS ports must be 8, 16, or 32.']);
        end
        if ~isfield(reportConfig,'PanelDimensions')
            error('nr5g:hDLPMISelect:PanelDimensionsMissing',...
                'PanelDimensions field is mandatory.');
        end
        validateattributes(reportConfig.PanelDimensions,...
            {'double','single'},{'vector','numel',3},fcnName,'PanelDimensions field for type I multi-panel codebooks');
        N1 = reportConfig.PanelDimensions(2);
        N2 = reportConfig.PanelDimensions(3);
        Pcsirs = 2*prod(reportConfig.PanelDimensions);
        Ng = reportConfig.PanelDimensions(1);
        if Pcsirs ~= NumCSIRSPorts
            error('nr5g:hDLPMISelect:InvalidMultiPanelDimensions',...
                ['For the configured number of CSI-RS ports (' num2str(NumCSIRSPorts)...
                '), the given panel configuration [' num2str(Ng) ' ' num2str(N1) ' ' num2str(N2)...
                '] is not valid. Note that, two times the product of panel dimensions ('...
                num2str(Pcsirs) ') must be equal to the number of CSI-RS ports (' num2str(NumCSIRSPorts) ').']);
        end
        % Supported panel configurations and oversampling factors for
        % type I multi-panel codebooks, as defined in
        % TS 38.214 Table 5.2.2.2.2-1
        panelConfigs = [2     2     2     4     2     2     4     4    % Ng
                        2     2     4     2     8     4     4     2    % N1
                        1     2     1     1     1     2     1     2    % N2
                        4     4     4     4     4     4     4     4    % O1
                        1     4     1     1     1     4     1     4 ]; % O2
        configIdx = find(panelConfigs(1,:) == Ng & panelConfigs(2,:) == N1 & panelConfigs(3,:) == N2,1);
        if isempty(configIdx)
            error('nr5g:hDLPMISelect:InvalidMultiPanelConfiguration',['The given panel configuration ['...
                num2str(Ng) ' ' num2str(N1) ' ' num2str(N2) ...
                '] is not valid for the given CSI-RS configuration. '...
                'For a number of CSI-RS ports, the panel configuration should ' ...
                'be one of the possibilities from TS 38.214 Table 5.2.2.2.2-1.']);
        end

        if reportConfigOut.CodebookMode == 2 && Ng ~= 2
            error('nr5g:hDLPMISelect:InvalidNumPanelsforGivenCodebookMode',['For' ...
                ' codebook mode 2, number of panels Ng (' num2str(Ng) ') must be 2.' ...
                ' Choose appropriate PanelDimensions.']);
        end
        % Extract the oversampling factors
        O1 = panelConfigs(4,configIdx);
        O2 = panelConfigs(5,configIdx);
        reportConfigOut.PanelDimensions = [Ng N1 N2];
    end
    reportConfigOut.OverSamplingFactors = [O1 O2];

    % Validate 'PMIMode'
    if isfield(reportConfig,'PMIMode')
        reportConfigOut.PMIMode = validatestring(reportConfig.PMIMode,{'Wideband','Subband'},fcnName,'PMIMode field');
    else
        reportConfigOut.PMIMode = 'Wideband';
    end

    % Validate 'PRGSize'
    if isfield(reportConfig,'PRGSize') && isType1SinglePanel
        if ~(isnumeric(reportConfig.PRGSize) && isempty(reportConfig.PRGSize))
            validateattributes(reportConfig.PRGSize,{'double','single'},...
                {'real','scalar'},fcnName,'PRGSize field');
        end
        if ~(isempty(reportConfig.PRGSize) || any(reportConfig.PRGSize == [2 4]))
            error('nr5g:hDLPMISelect:InvalidPRGSize',...
                ['PRGSize value (' num2str(reportConfig.PRGSize) ') must be [], 2, or 4.']);
        end
        reportConfigOut.PRGSize = reportConfig.PRGSize;
    else
        reportConfigOut.PRGSize = [];
    end

    % Validate 'SubbandSize'
    NSBPRB = [];
    if strcmpi(reportConfigOut.PMIMode,'Subband') && isempty(reportConfigOut.PRGSize)
        if nSizeBWP >= 24
            if ~isfield(reportConfig,'SubbandSize')
                error('nr5g:hDLPMISelect:SubbandSizeMissing',...
                    ['For the subband mode, SubbandSize field is '...
                    'mandatory when the size of BWP is more than 24 PRBs.']);
            end
            validateattributes(reportConfig.SubbandSize,{'double','single'},...
                {'real','scalar'},fcnName,'SubbandSize field');
            NSBPRB = reportConfig.SubbandSize;

            % Validate the subband size, based on the size of BWP
            % BWP size ranges
            nSizeBWPRange = [24  72;
                73  144;
                145 275];
            % Possible values of subband size
            nSBPRBValues = [4  8;
                8  16;
                16 32];
            bwpRangeCheck = (nSizeBWP >= nSizeBWPRange(:,1)) & (nSizeBWP <= nSizeBWPRange(:,2));
            validNSBPRBValues = nSBPRBValues(bwpRangeCheck,:);
            if ~any(NSBPRB == validNSBPRBValues)
                error('nr5g:hDLPMISelect:InvalidSubbandSize',['For the configured BWP size (' num2str(nSizeBWP) ...
                    '), subband size (' num2str(NSBPRB) ') must be ' num2str(validNSBPRBValues(1)) ...
                    ' or ' num2str(validNSBPRBValues(2)) '.']);
            end
        end
    end
    reportConfigOut.SubbandSize = NSBPRB;

    % Validate 'CodebookSubsetRestriction'
    if  ~isType2
        if NumCSIRSPorts > 2
            codebookLength = N1*O1*N2*O2;
            codebookSubsetRestriction = ones(1,codebookLength);
            if isfield(reportConfig,'CodebookSubsetRestriction') &&...
                    ~isempty(reportConfig.CodebookSubsetRestriction)
                codebookSubsetRestriction = reportConfig.CodebookSubsetRestriction;
                validateattributes(codebookSubsetRestriction,...
                    {'numeric'},{'vector','binary','numel',codebookLength},fcnName,'CodebookSubsetRestriction field');
            end
        elseif NumCSIRSPorts == 2
            codebookSubsetRestriction = ones(1,6);
            if isfield(reportConfig,'CodebookSubsetRestriction') &&...
                    ~isempty(reportConfig.CodebookSubsetRestriction)
                codebookSubsetRestriction = reportConfig.CodebookSubsetRestriction;
                validateattributes(codebookSubsetRestriction,{'numeric'},{'vector','binary','numel',6},fcnName,'CodebookSubsetRestriction field');
            end
        else
            codebookSubsetRestriction = 1;
        end
    else
        if isfield(reportConfig,'CodebookSubsetRestriction') &&...
                    ~isempty(reportConfig.CodebookSubsetRestriction)
            codebookSubsetRestriction = reportConfig.CodebookSubsetRestriction;
            if N2 == 1
                codebookLength = 8*N1*N2;
            else
                codebookLength = 11 + 8*N1*N2;
            end
            validateattributes(codebookSubsetRestriction,...
                    {'numeric'},{'vector','binary','numel',codebookLength},fcnName,'CodebookSubsetRestriction field');
        else
            codebookSubsetRestriction = [];
        end
        if isempty(codebookSubsetRestriction)
            if N2>1
                codebookSubsetRestriction = [ones(1,11) ones(1,4*2*N1*N2)];
            else
                codebookSubsetRestriction = ones(1,4*2*N1*N2);
            end
        end
    end

    reportConfigOut.CodebookSubsetRestriction = codebookSubsetRestriction;

    % Validate 'i2Restriction'
    i2Restriction = ones(1,16);
    if NumCSIRSPorts > 2 && isType1SinglePanel
        if isfield(reportConfig,'i2Restriction') &&  ~isempty(reportConfig.i2Restriction)
            validateattributes(reportConfig.i2Restriction,...
                {'numeric'},{'vector','binary','numel',16},fcnName,'i2Restriction field');
            i2Restriction = reportConfig.i2Restriction;
        end
    end
    reportConfigOut.i2Restriction = i2Restriction;

    if isType2
        % Validate 'NumberOfBeams'
        if ~isfield(reportConfig,'NumberOfBeams')
            error('nr5g:hDLPMISelect:NumberOfBeamsMissing',...
                'NumberOfBeams is a mandatory field.');
        end
        if ~any(reportConfig.NumberOfBeams == [2 3 4])
            error('nr5g:hDLPMISelect:InvalidNumberOfBeams',...
                ['NumberOfBeams value (' num2str(reportConfig.NumberOfBeams) ') must be 2, 3, or 4.']);
        end
        if NumCSIRSPorts == 4 && reportConfig.NumberOfBeams > 2
            error('nr5g:hDLPMISelect:InvalidNumberOfBeamsFor4Ports',...
                ['NumberOfBeams value (' num2str(reportConfig.NumberOfBeams) ') must be 2 when number of CSI-RS ports is 4.']);
        end
        reportConfigOut.NumberOfBeams = reportConfig.NumberOfBeams;

        % Validate 'PhaseAlphabetSize'
        reportConfigOut.PhaseAlphabetSize = 4;
        if isfield(reportConfig,'PhaseAlphabetSize')
            if ~any(reportConfig.PhaseAlphabetSize == [4 8])
                error('nr5g:hDLPMISelect:InvalidPhaseAlphabetSize',...
                    ['PhaseAlphabetSize value (' num2str(reportConfig.PhaseAlphabetSize) ') must be 4 or 8.']);
            end
            reportConfigOut.PhaseAlphabetSize = reportConfig.PhaseAlphabetSize;
        end

        % Validate 'SubbandAmplitude'
        reportConfigOut.SubbandAmplitude = false;
        if isfield(reportConfig,'SubbandAmplitude')
            validateattributes(reportConfig.SubbandAmplitude,{'logical','double'},{'nonempty'},fcnName,'SubbandAmplitude field');
            reportConfigOut.SubbandAmplitude = reportConfig.SubbandAmplitude;
        end
    end

    % Validate 'nLayers'
    if isType2
        validateattributes(nLayers,{'numeric'},{'scalar','integer','positive','<=',2},fcnName,['NLAYERS(' num2str(nLayers) ') when codebook type is "Type2"']);
    elseif isType1MultiPanel
        validateattributes(nLayers,{'numeric'},{'scalar','integer','positive','<=',4},fcnName,['NLAYERS(' num2str(nLayers) ') when codebook type is "Type1MultiPanel"']);
    else
        validateattributes(nLayers,{'numeric'},{'scalar','integer','positive','<=',8},fcnName,['NLAYERS(' num2str(nLayers) ') when codebook type is "Type1SinglePanel"']);
    end

    % Validate 'H'
    validateattributes(H,{'double','single'},{},fcnName,'H');
    validateattributes(numel(size(H)),{'double'},{'>=',2,'<=',4},fcnName,'number of dimensions of H');

    % Ignore zero-power (ZP) CSI-RS resources, as they are not used for CSI
    % estimation
    if ~iscell(csirs.CSIRSType)
        csirs.CSIRSType = {csirs.CSIRSType};
    end
    numZPCSIRSRes = sum(strcmpi(csirs.CSIRSType,'zp'));
    tempInd = nrCSIRSIndices(carrier,csirs,"IndexStyle","subscript","OutputResourceFormat","cell");
    tempInd = tempInd(numZPCSIRSRes+1:end)'; % NZP-CSI-RS indices
    % Extract the NZP-CSI-RS indices corresponding to first port
    for nzpResIdx = 1:numel(tempInd)
        nzpInd = tempInd{nzpResIdx};
        tempInd{nzpResIdx} = nzpInd(nzpInd(:,3) == 1,:);
    end
    % Extract the indices corresponding to the lowest RE of each CSI-RS CDM
    % group
    if ~strcmpi(cdmType{1},'noCDM')
        for resIdx = 1:numel(tempInd)
            totIndices = size(tempInd{resIdx},1);
            if strcmpi(cdmType{1},'FD-CDM2')
                indicesPerSym = totIndices;
            elseif strcmpi(cdmType{1},'CDM4')
                indicesPerSym = totIndices/2;
            elseif strcmpi(cdmType{1},'CDM8')
                indicesPerSym = totIndices/4;
            end
            tempIndInOneSymbol = tempInd{resIdx}(1:indicesPerSym,:);
            tempInd{resIdx} = tempIndInOneSymbol(1:2:end,:);
        end
    end
    csirsInd = zeros(0,3);
    if ~isempty(tempInd)
        csirsInd = cell2mat(tempInd);
    end
    if ~isempty(csirsInd)
        K = carrier.NSizeGrid*12;
        L = carrier.SymbolsPerSlot;
        validateattributes(H,{class(H)},{'size',[K L NaN NumCSIRSPorts]},fcnName,'H');

        % Validate 'nLayers'
        nRxAnts = size(H,3);
        maxNLayers = min(nRxAnts,NumCSIRSPorts);
        if nLayers > maxNLayers
            error('nr5g:hDLPMISelect:InvalidNumLayers',...
                ['The given antenna configuration (' ...
                num2str(NumCSIRSPorts) 'x' num2str(nRxAnts)...
                ') supports only up to (' num2str(maxNLayers) ') layers.']);
        end
    end

    % Validate 'nVar'
    validateattributes(nVar,{'double','single'},{'scalar','real','nonnegative','finite'},fcnName,'NVAR');
    % Clip nVar to a small noise variance to avoid +/-Inf outputs
    if nVar < 1e-10
        nVar = 1e-10;
    end
end

function  codebook = getPMIType1SinglePanelCodebook(reportConfig,nLayers)
%   CODEBOOK = getPMIType1SinglePanelCodebook(REPORTCONFIG,NLAYERS) returns
%   a codebook CODEBOOK containing type I single-panel precoding matrices,
%   as defined in TS 38.214 Tables 5.2.2.2.1-1 to 5.2.2.2.1-12 by
%   considering these inputs:
%
%   REPORTCONFIG is a CSI reporting configuration structure with these
%   fields:
%   PanelDimensions            - Antenna panel configuration as a
%                                two-element vector ([N1 N2]). It is
%                                not applicable for CSI-RS ports less
%                                than or equal to 2
%   OverSamplingFactors        - DFT oversampling factors corresponding to
%                                the panel configuration
%   CodebookMode               - Codebook mode. Applicable only when the
%                                number of MIMO layers is 1 or 2 and
%                                number of CSI-RS ports is greater than 2
%   CodebookSubsetRestriction  - Binary vector for vlm or vbarlm restriction
%   i2Restriction              - Binary vector for i2 restriction
%
%   NLAYERS      - Number of transmission layers
%
%   CODEBOOK     - Multidimensional array containing unrestricted type I
%                  single-panel precoding matrices. It is of size
%                  Pcsirs-by-nLayers-by-i2Length-by-i11Length-by-i12Length-by-i13Length
%
%   Note that the restricted precoding matrices are returned as all zeros.

    panelDimensions           = reportConfig.PanelDimensions;
    codebookMode              = reportConfig.CodebookMode;
    codebookSubsetRestriction = reportConfig.CodebookSubsetRestriction;
    i2Restriction             = reportConfig.i2Restriction;

    % Create a function handle to compute the co-phasing factor value
    % according to TS 38.214 Section 5.2.2.2.1, considering the co-phasing
    % factor index
    phi = @(x)exp(1i*pi*x/2);

    % Get the number of CSI-RS ports using the panel dimensions
    Pcsirs = 2*panelDimensions(1)*panelDimensions(2);
    if Pcsirs == 2
        % Codebooks for 1-layer and 2-layer CSI reporting using antenna
        % ports 3000 to 3001, as defined in TS 38.214 Table 5.2.2.2.1-1
        if nLayers == 1
            codebook(:,:,1) = 1/sqrt(2).*[1; 1];
            codebook(:,:,2) = 1/sqrt(2).*[1; 1i];
            codebook(:,:,3) = 1/sqrt(2).*[1; -1];
            codebook(:,:,4) = 1/sqrt(2).*[1; -1i];
            restrictedIndices = find(~codebookSubsetRestriction);
            restrictedIndices = restrictedIndices(restrictedIndices <= 4);
            if ~isempty(restrictedIndices)
                restrictedSet = logical(sum(restrictedIndices == [1;2;3;4],2));
                codebook(:,:,restrictedSet) = 0;
            end
        elseif nLayers == 2
            codebook(:,:,1) = 1/2*[1 1;1 -1];
            codebook(:,:,2) = 1/2*[1 1; 1i -1i];
            restrictedIndices = find(~codebookSubsetRestriction);
            restrictedIndices = restrictedIndices(restrictedIndices > 4);
            if ~isempty(restrictedIndices)
                restrictedSet = logical(sum(restrictedIndices == [5;6],2));
                codebook(:,:,restrictedSet) = 0;
            end
        end
    elseif Pcsirs > 2
        N1 = panelDimensions(1);
        N2 = panelDimensions(2);
        O1 = reportConfig.OverSamplingFactors(1);
        O2 = reportConfig.OverSamplingFactors(2);

        % Select the codebook based on the number of layers, panel
        % configuration, and the codebook mode
        switch nLayers
            case 1 % Number of layers is 1
                % Codebooks for 1-layer CSI reporting using antenna ports
                % 3000 to 2999+P_CSIRS, as defined in TS 38.214 Table
                % 5.2.2.2.1-5
                if codebookMode == 1
                    i11_length = N1*O1;
                    i12_length = N2*O2;
                    i2_length = 4;
                    codebook = zeros(Pcsirs,nLayers,i2_length,i11_length,i12_length);
                    % Loop over all the values of i11, i12, and i2
                    for i11 = 0:i11_length-1
                        for i12 = 0:i12_length-1
                            for i2 = 0:i2_length-1
                                l = i11;
                                m = i12;
                                n = i2;
                                bitIndex = N2*O2*l+m;
                                [lmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitIndex,i2,i2Restriction);
                                if ~(lmRestricted || i2Restricted)
                                    vlm = getVlm(N1,N2,O1,O2,l,m);
                                    phi_n = phi(n);
                                    codebook(:,:,i2+1,i11+1,i12+1) = (1/sqrt(Pcsirs))*[vlm ;...
                                        phi_n*vlm];
                                end
                            end
                        end
                    end
                else % codebookMode == 2
                    i11_length = N1*O1/2;
                    i12_length = N2*O2/2;
                    if N2 == 1
                        i12_length = 1;
                    end
                    i2_length = 16;
                    codebook = zeros(Pcsirs,nLayers,i2_length,i11_length,i12_length);
                    % Loop over all the values of i11, i12, and i2
                    for i11 = 0:i11_length-1
                        for i12 = 0:i12_length-1
                            for i2 = 0:i2_length-1
                                floor_i2by4 = floor(i2/4);
                                if N2 == 1
                                    l = 2*i11 + floor_i2by4;
                                    m = 0;
                                else % N2 > 1
                                    lmAddVals = [0 0; 1 0; 0 1;1 1];
                                    l = 2*i11 + lmAddVals(floor_i2by4+1,1);
                                    m = 2*i12 + lmAddVals(floor_i2by4+1,2);
                                end
                                n = mod(i2,4);
                                bitIndex = N2*O2*l+m;
                                [lmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitIndex,i2,i2Restriction);
                                if ~(lmRestricted || i2Restricted)
                                    vlm = getVlm(N1,N2,O1,O2,l,m);
                                    phi_n = phi(n);
                                    codebook(:,:,i2+1,i11+1,i12+1) = (1/sqrt(Pcsirs))*[vlm;...
                                        phi_n*vlm];
                                end
                            end
                        end
                    end
                end

            case 2 % Number of layers is 2
                % Codebooks for 2-layer CSI reporting using antenna ports
                % 3000 to 2999+P_CSIRS, as defined in TS 38.214 Table
                % 5.2.2.2.1-6

                % Compute i13 parameter range and corresponding k1 and k2,
                % as defined in TS 38.214 Table 5.2.2.2.1-3
                if (N1 > N2) && (N2 > 1)
                    i13_length = 4;
                    k1 = [0 O1 0 2*O1];
                    k2 = [0 0 O2 0];
                elseif N1 == N2
                    i13_length = 4;
                    k1 = [0 O1 0 O1];
                    k2 = [0 0 O2 O2];
                elseif (N1 == 2) && (N2 == 1)
                    i13_length = 2;
                    k1 = O1*(0:1);
                    k2 = [0 0];
                else
                    i13_length = 4;
                    k1 = O1*(0:3);
                    k2 = [0 0 0 0] ;
                end

                if codebookMode == 1
                    i11_length = N1*O1;
                    i12_length = N2*O2;
                    i2_length = 2;
                    codebook = zeros(Pcsirs,nLayers,i2_length,i11_length,i12_length,i13_length);
                    % Loop over all the values of i11, i12, i13, and i2
                    for i11 = 0:i11_length-1
                        for i12 = 0:i12_length-1
                            for i13 = 0:i13_length-1
                                for i2 = 0:i2_length-1
                                    l = i11;
                                    m = i12;
                                    n = i2;
                                    lPrime = i11+k1(i13+1);
                                    mPrime = i12+k2(i13+1);
                                    bitIndex = N2*O2*l+m;
                                    [lmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitIndex,i2,i2Restriction);
                                    if ~(lmRestricted || i2Restricted)
                                        vlm = getVlm(N1,N2,O1,O2,l,m);
                                        vlPrime_mPrime = getVlm(N1,N2,O1,O2,lPrime,mPrime);
                                        phi_n = phi(n);
                                        codebook(:,:,i2+1,i11+1,i12+1,i13+1) = ...
                                            (1/sqrt(2*Pcsirs))*[vlm        vlPrime_mPrime;...
                                            phi_n*vlm  -phi_n*vlPrime_mPrime];
                                    end
                                end
                            end
                        end
                    end
                else % codebookMode == 2
                    i11_length = N1*O1/2;
                    if N2 == 1
                        i12_length = 1;
                    else
                        i12_length = N2*O2/2;
                    end
                    i2_length = 8;
                    codebook = zeros(Pcsirs,nLayers,i2_length,i11_length,i12_length,i13_length);
                    % Loop over all the values of i11, i12, i13, and i2
                    for i11 = 0:i11_length-1
                        for i12 = 0:i12_length-1
                            for i13 = 0:i13_length-1
                                for i2 = 0:i2_length-1
                                    floor_i2by2 = floor(i2/2);
                                    if N2 == 1
                                        l = 2*i11 + floor_i2by2;
                                        lPrime = 2*i11 + floor_i2by2 + k1(i13+1);
                                        m = 0;
                                        mPrime = 0;
                                    else % N2 > 1
                                        lmAddVals = [0 0; 1 0; 0 1;1 1];
                                        l = 2*i11 + lmAddVals(floor_i2by2+1,1);
                                        lPrime =  2*i11 + k1(i13+1) + lmAddVals(floor_i2by2+1,1);
                                        m = 2*i12 + lmAddVals(floor_i2by2+1,2);
                                        mPrime =  2*i12 + k2(i13+1) + lmAddVals(floor_i2by2+1,2);
                                    end
                                    n = mod(i2,2);
                                    bitIndex = N2*O2*l+m;
                                    [lmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitIndex,i2,i2Restriction);
                                    if ~(lmRestricted || i2Restricted)
                                        vlm = getVlm(N1,N2,O1,O2,l,m);
                                        vlPrime_mPrime = getVlm(N1,N2,O1,O2,lPrime,mPrime);
                                        phi_n = phi(n);
                                        codebook(:,:,i2+1,i11+1,i12+1,i13+1) = ...
                                            (1/sqrt(2*Pcsirs))*[vlm        vlPrime_mPrime;...
                                            phi_n*vlm  -phi_n*vlPrime_mPrime];
                                    end
                                end
                            end
                        end
                    end
                end

            case {3,4} % Number of layers is 3 or 4
                if (Pcsirs < 16)
                    % For the number of CSI-RS ports less than 16, compute
                    % i13 parameter range, corresponding k1 and k2,
                    % according to TS 38.214 Table 5.2.2.2.1-4
                    if (N1 == 2) && (N2 == 1)
                        i13_length = 1;
                        k1 = O1;
                        k2 = 0;
                    elseif (N1 == 4) && (N2 == 1)
                        i13_length = 3;
                        k1 = O1*(1:3);
                        k2 = [0 0 0];
                    elseif (N1 == 6) && (N2 == 1)
                        i13_length = 4;
                        k1 = O1*(1:4);
                        k2 = [0 0 0 0];
                    elseif (N1 == 2) && (N2 == 2)
                        i13_length = 3;
                        k1 = [O1 0 O1];
                        k2 = [0 O2 O2];
                    elseif (N1 == 3) && (N2 == 2)
                        i13_length = 4;
                        k1 = [O1 0 O1 2*O1];
                        k2 = [0 O2 O2 0];
                    end

                    % For 3 and 4 layers the procedure for computation of W
                    % is same, other than the dimensions of W. Compute W
                    % for either case accordingly
                    i11_length = N1*O1;
                    i12_length = N2*O2;
                    i2_length = 2;
                    codebook = zeros(Pcsirs,nLayers,i2_length,i11_length,i12_length,i13_length);
                    % Loop over all the values of i11, i12, i13, and i2
                    for i11 = 0:i11_length-1
                        for i12 = 0:i12_length-1
                            for i13 = 0:i13_length-1
                                for i2 = 0:i2_length-1
                                    l = i11;
                                    lPrime = i11+k1(i13+1);
                                    m = i12;
                                    mPrime = i12+k2(i13+1);
                                    n = i2;
                                    bitIndex = N2*O2*l+m;
                                    [lmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitIndex,i2,i2Restriction);
                                    if ~(lmRestricted || i2Restricted)
                                        vlm = getVlm(N1,N2,O1,O2,l,m);
                                        vlPrime_mPrime = getVlm(N1,N2,O1,O2,lPrime,mPrime);
                                        phi_n = phi(n);
                                        phi_vlm = phi_n*vlm;
                                        phi_vlPrime_mPrime = phi_n*vlPrime_mPrime;
                                        if nLayers == 3
                                            % Codebook for 3-layer CSI
                                            % reporting using antenna ports
                                            % 3000 to 2999+P_CSIRS, as
                                            % defined in TS 38.214 Table
                                            % 5.2.2.2.1-7
                                            codebook(:,:,i2+1,i11+1,i12+1,i13+1) = ...
                                                (1/sqrt(3*Pcsirs))*[vlm      vlPrime_mPrime      vlm;...
                                                phi_vlm  phi_vlPrime_mPrime  -phi_vlm];
                                        else
                                            % Codebook for 4-layer CSI
                                            % reporting using antenna ports
                                            % 3000 to 2999+P_CSIRS, as
                                            % defined in TS 38.214 Table
                                            % 5.2.2.2.1-8
                                            codebook(:,:,i2+1,i11+1,i12+1,i13+1) = ...
                                                (1/sqrt(4*Pcsirs))*[vlm      vlPrime_mPrime      vlm       vlPrime_mPrime;...
                                                phi_vlm  phi_vlPrime_mPrime  -phi_vlm  -phi_vlPrime_mPrime];
                                        end
                                    end
                                end
                            end
                        end
                    end
                else % Number of CSI-RS ports is greater than or equal to 16
                    i11_length = N1*O1/2;
                    i12_length = N2*O2;
                    i13_length = 4;
                    i2_length = 2;
                    codebook = zeros(Pcsirs,nLayers,i2_length,i11_length,i12_length,i13_length);
                    % Loop over all the values of i11, i12, i13, and i2
                    for i11 = 0:i11_length-1
                        for i12 = 0:i12_length-1
                            for i13 = 0:i13_length-1
                                for i2 = 0:i2_length-1
                                    theta = exp(1i*pi*i13/4);
                                    l = i11;
                                    m = i12;
                                    n = i2;
                                    phi_n = phi(n);
                                    bitValues = [mod(N2*O2*(2*l-1)+m,N1*O1*N2*O2), N2*O2*(2*l)+m, N2*O2*(2*l+1)+m];
                                    [lmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitValues,i2,i2Restriction);
                                    if ~(lmRestricted || i2Restricted)
                                        vbarlm = getVbarlm(N1,N2,O1,O2,l,m);
                                        theta_vbarlm = theta*vbarlm;
                                        phi_vbarlm = phi_n*vbarlm;
                                        phi_theta_vbarlm = phi_n*theta*vbarlm;
                                        if nLayers == 3
                                            % Codebook for 3-layer CSI
                                            % reporting using antenna ports
                                            % 3000 to 2999+P_CSIRS, as
                                            % defined in TS 38.214 Table
                                            % 5.2.2.2.1-7
                                            codebook(:,:,i2+1,i11+1,i12+1,i13+1) = ...
                                                (1/sqrt(3*Pcsirs))*[vbarlm            vbarlm             vbarlm;...
                                                theta_vbarlm      -theta_vbarlm      theta_vbarlm;...
                                                phi_vbarlm        phi_vbarlm         -phi_vbarlm;...
                                                phi_theta_vbarlm  -phi_theta_vbarlm  -phi_theta_vbarlm];
                                        else
                                            % Codebook for 4-layer CSI
                                            % reporting using antenna ports
                                            % 3000 to 2999+P_CSIRS, as
                                            % defined in TS 38.214 Table
                                            % 5.2.2.2.1-8
                                            codebook(:,:,i2+1,i11+1,i12+1,i13+1) = ...
                                                (1/sqrt(4*Pcsirs))*[vbarlm            vbarlm             vbarlm             vbarlm;...
                                                theta_vbarlm      -theta_vbarlm      theta_vbarlm       -theta_vbarlm;...
                                                phi_vbarlm        phi_vbarlm         -phi_vbarlm        -phi_vbarlm;...
                                                phi_theta_vbarlm  -phi_theta_vbarlm  -phi_theta_vbarlm  phi_theta_vbarlm];
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

            case {5,6} % Number of layers is 5 or 6
                i11_length = N1*O1;
                if N2 == 1
                    i12_length = 1;
                else % N2 > 1
                    i12_length = N2*O2;
                end
                i2_length = 2;
                codebook = zeros(Pcsirs,nLayers,i2_length,i11_length,i12_length);
                % Loop over all the values of i11, i12, and i2
                for i11 = 0:i11_length-1
                    for i12 = 0:i12_length-1
                        for i2 = 0:i2_length-1
                            if N2 == 1
                                l = i11;
                                lPrime = i11+O1;
                                l_dPrime = i11+2*O1;
                                m = 0;
                                mPrime = 0;
                                m_dPrime = 0;
                            else % N2 > 1
                                l = i11;
                                lPrime = i11+O1;
                                l_dPrime = i11+O1;
                                m = i12;
                                mPrime = i12;
                                m_dPrime = i12+O2;
                            end
                            n = i2;
                            bitIndex = N2*O2*l+m;
                            [lmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitIndex,i2,i2Restriction);
                            if ~(lmRestricted || i2Restricted)
                                vlm = getVlm(N1,N2,O1,O2,l,m);
                                vlPrime_mPrime = getVlm(N1,N2,O1,O2,lPrime,mPrime);
                                vlDPrime_mDPrime = getVlm(N1,N2,O1,O2,l_dPrime,m_dPrime);
                                phi_n = phi(n);
                                phi_vlm = phi_n*vlm;
                                phi_vlPrime_mPrime = phi_n*vlPrime_mPrime;
                                if nLayers == 5
                                    % Codebook for 5-layer CSI reporting
                                    % using antenna ports 3000 to
                                    % 2999+P_CSIRS, as defined in TS 38.214
                                    % Table 5.2.2.2.1-9
                                    codebook(:,:,i2+1,i11+1,i12+1) = ...
                                        1/(sqrt(5*Pcsirs))*[vlm       vlm        vlPrime_mPrime   vlPrime_mPrime    vlDPrime_mDPrime;...
                                        phi_vlm   -phi_vlm   vlPrime_mPrime   -vlPrime_mPrime   vlDPrime_mDPrime];
                                else
                                    % Codebook for 6-layer CSI reporting
                                    % using antenna ports 3000 to
                                    % 2999+P_CSIRS, as defined in TS 38.214
                                    % Table 5.2.2.2.2-10
                                    codebook(:,:,i2+1,i11+1,i12+1) = ...
                                        1/(sqrt(6*Pcsirs))*[vlm       vlm        vlPrime_mPrime       vlPrime_mPrime        vlDPrime_mDPrime   vlDPrime_mDPrime;...
                                        phi_vlm   -phi_vlm   phi_vlPrime_mPrime   -phi_vlPrime_mPrime   vlDPrime_mDPrime   -vlDPrime_mDPrime];
                                end
                            end
                        end
                    end
                end

            case{7,8} % Number of layers is 7 or 8
                if N2 == 1
                    i12_length = 1;
                    if N1 == 4
                        i11_length = N1*O1/2;
                    else % N1 > 4
                        i11_length = N1*O1;
                    end
                else % N2 > 1
                    i11_length = N1*O1;
                    if (N1 == 2 && N2 == 2) || (N1 > 2 && N2 > 2)
                        i12_length = N2*O2;
                    else % (N1 > 2 && N2 == 2)
                        i12_length = N2*O2/2;
                    end
                end
                i2_length = 2;
                codebook = zeros(Pcsirs,nLayers,i2_length,i11_length,i12_length);
                % Loop over all the values of i11, i12, and i2
                for i11 = 0:i11_length-1
                    for i12 = 0:i12_length-1
                        for i2 = 0:i2_length-1
                            if N2 == 1
                                l = i11;
                                lPrime = i11+O1;
                                l_dPrime = i11+2*O1;
                                l_tPrime = i11+3*O1;
                                m = 0;
                                mPrime = 0;
                                m_dPrime = 0;
                                m_tPrime = 0;
                            else % N2 > 1
                                l = i11;
                                lPrime = i11+O1;
                                l_dPrime = i11;
                                l_tPrime = i11+O1;
                                m = i12;
                                mPrime = i12;
                                m_dPrime = i12+O2;
                                m_tPrime = i12+O2;
                            end
                            n = i2;
                            bitIndex = N2*O2*l+m;
                            [lmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitIndex,i2,i2Restriction);
                            if ~(lmRestricted || i2Restricted)
                                vlm = getVlm(N1,N2,O1,O2,l,m);
                                vlPrime_mPrime = getVlm(N1,N2,O1,O2,lPrime,mPrime);
                                vlDPrime_mDPrime = getVlm(N1,N2,O1,O2,l_dPrime,m_dPrime);
                                vlTPrime_mTPrime = getVlm(N1,N2,O1,O2,l_tPrime,m_tPrime);
                                phi_n = phi(n);
                                phi_vlm = phi_n*vlm;
                                phi_vlPrime_mPrime = phi_n*vlPrime_mPrime;
                                if nLayers == 7
                                    % Codebook for 7-layer CSI reporting
                                    % using antenna ports 3000 to
                                    % 2999+P_CSIRS, as defined in TS 38.214
                                    % Table 5.2.2.2.1-11
                                    codebook(:,:,i2+1,i11+1,i12+1) = ...
                                        1/(sqrt(7*Pcsirs))*[vlm       vlm        vlPrime_mPrime       vlDPrime_mDPrime   vlDPrime_mDPrime    vlTPrime_mTPrime   vlTPrime_mTPrime;...
                                        phi_vlm   -phi_vlm   phi_vlPrime_mPrime   vlDPrime_mDPrime   -vlDPrime_mDPrime   vlTPrime_mTPrime   -vlTPrime_mTPrime];
                                else
                                    % Codebook for 8-layer CSI reporting
                                    % using antenna ports 3000 to
                                    % 2999+P_CSIRS, as defined in TS 38.214
                                    % Table 5.2.2.2.1-12
                                    codebook(:,:,i2+1,i11+1,i12+1) = ...
                                        1/(sqrt(8*Pcsirs))*[vlm       vlm        vlPrime_mPrime       vlPrime_mPrime        vlDPrime_mDPrime   vlDPrime_mDPrime    vlTPrime_mTPrime   vlTPrime_mTPrime;...
                                        phi_vlm   -phi_vlm   phi_vlPrime_mPrime   -phi_vlPrime_mPrime   vlDPrime_mDPrime   -vlDPrime_mDPrime   vlTPrime_mTPrime   -vlTPrime_mTPrime];
                                end
                            end
                        end
                    end
                end
        end
    end
end

function codebook = getPMIType1MultiPanelCodebook(reportConfig,nLayers)
%   CODEBOOK = getPMIType1MultiPanelCodebook(REPORTCONFIG,NLAYERS) returns
%   a codebook CODEBOOK containing type I multi-panel precoding matrices, as
%   defined in TS 38.214 Tables 5.2.2.2.2-1 to 5.2.2.2.2-6 by considering
%   these inputs:
%
%   REPORTCONFIG is a CSI reporting configuration structure with these
%   fields:
%   PanelDimensions            - Antenna panel configuration as a
%                                three-element vector ([Ng N1 N2]),
%                                as defined in TS 38.214 Table
%                                5.2.2.2.2-1
%   OverSamplingFactors        - DFT oversampling factors
%                                corresponding to the panel
%                                configuration
%   CodebookMode               - Codebook mode
%   CodebookSubsetRestriction  - Binary vector for vlm restriction
%
%   NLAYERS      - Number of transmission layers
%
%   CODEBOOK     - Multidimensional array containing unrestricted type I
%                  multi-panel precoding matrices. It is of size
%                  Pcsirs-by-nLayers-by-i20Length-by-i21Length-by-i22Length-by-i11Length-by-i12Length-by-i13Length-i141Length-by-i142Length-by-i143Length
%
%   Note that the restricted precoding matrices are returned as all zeros.

    % Extract the panel dimensions
    Ng = reportConfig.PanelDimensions(1);
    N1 = reportConfig.PanelDimensions(2);
    N2 = reportConfig.PanelDimensions(3);

    % Extract the oversampling factors
    O1 = reportConfig.OverSamplingFactors(1);
    O2 = reportConfig.OverSamplingFactors(2);

    % Compute the number of ports
    Pcsirs = 2*Ng*N1*N2;

    % Create function handles to compute the co-phasing factor values
    % according to TS 38.214 Section 5.2.2.2.2, considering the co-phasing
    % factor indices
    phi = @(x)exp(1i*pi*x/2);
    a = @(x)exp(1i*pi/4 + 1i*pi*x/2);
    b = @(x)exp(-1i*pi/4 + 1i*pi*x/2);

    % Set the lengths of the common parameters to both codebook modes and
    % all the panel dimensions
    i11_length = N1*O1;
    i12_length = N2*O2;
    i13_length = 1; % Update this value according to number of layers
    i20_length = 2;
    i141_length = 4;

    % Set the lengths of the parameters respective to the codebook mode.
    % Consider the length of undefined values for a particular codebook
    % mode and/or number of panels as 1
    if reportConfig.CodebookMode == 1
        if Ng == 2
            i142_length = 1;
            i143_length = 1;
        else
            i142_length = 4;
            i143_length = 4;
        end
        i21_length = 1;
        i22_length = 1;
    else
        i142_length = 4;
        i143_length = 1;
        i21_length = 2;
        i22_length = 2;
    end

    % Select the codebook based on the number of layers, panel
    % configuration, and the codebook mode
    switch nLayers
        case 1 % Number of layers is 1
            i13_length = 1;
            i20_length = 4;
            codebook = zeros(Pcsirs,nLayers,i20_length,i21_length,i22_length,i11_length,i12_length,i13_length,i141_length,i142_length,i143_length);
            % Loop over all the values of all the indices
            for i11 = 0:i11_length-1
                for i12 = 0:i12_length-1
                    for i13 = 0:i13_length-1
                        l = i11;
                        m = i12;
                        bitIndex = N2*O2*l+m;
                        lmRestricted = isRestricted(reportConfig.CodebookSubsetRestriction,bitIndex,[],reportConfig.i2Restriction);
                        if ~(lmRestricted)
                            vlm = getVlm(N1,N2,O1,O2,l,m);
                            for i141 = 0:i141_length-1
                                for i142 = 0:i142_length-1
                                    for i143 = 0:i143_length-1
                                        for i20 = 0:i20_length-1
                                            for i21 = 0:i21_length-1
                                                for i22 = 0:i22_length-1
                                                    if reportConfig.CodebookMode == 1
                                                        n = i20;
                                                        phi_n = phi(n);
                                                        if Ng == 2
                                                            p = i141;
                                                            phi_p = phi(p);
                                                            % Codebook for 1-layer CSI
                                                            % reporting using antenna ports
                                                            % 3000 to 2999+P_CSIRS, as
                                                            % defined in TS 38.214 Table
                                                            % 5.2.2.2.2-3
                                                            codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(Pcsirs))*[vlm ;...
                                                                phi_n*vlm;...
                                                                phi_p*vlm;...
                                                                phi_n*phi_p*vlm];
                                                        else % Ng is 4
                                                            p1 = i141;
                                                            p2 = i142;
                                                            p3 = i143;
                                                            phi_p1 = phi(p1);
                                                            phi_p2 = phi(p2);
                                                            phi_p3 = phi(p3);
                                                            % Codebook for 1-layer CSI
                                                            % reporting using antenna ports
                                                            % 3000 to 2999+P_CSIRS, as
                                                            % defined in TS 38.214 Table
                                                            % 5.2.2.2.2-3
                                                            codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(Pcsirs))*[vlm ;...
                                                                phi_n*vlm;...
                                                                phi_p1*vlm;...
                                                                phi_n*phi_p1*vlm
                                                                phi_p2*vlm ;...
                                                                phi_n*phi_p2*vlm;...
                                                                phi_p3*vlm;...
                                                                phi_n*phi_p3*vlm];
                                                        end
                                                    else % Codebook mode 2
                                                        n0 = i20;
                                                        phi_n0 = phi(n0);
                                                        p1 = i141;
                                                        ap1 = a(p1);
                                                        n1 = i21;
                                                        bn1 = b(n1);
                                                        p2 = i142;
                                                        ap2 = a(p2);
                                                        n2 = i22;
                                                        bn2 = b(n2);
                                                        % Codebook for 1-layer CSI
                                                        % reporting using antenna ports
                                                        % 3000 to 2999+P_CSIRS, as
                                                        % defined in TS 38.214 Table
                                                        % 5.2.2.2.2-3
                                                        codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(Pcsirs))*[vlm ;...
                                                            phi_n0*vlm;...
                                                            ap1*bn1*vlm;...
                                                            ap2*bn2*vlm];

                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        case 2 % Number of layers is 2
            % Compute i13 parameter range and corresponding k1 and k2,
            % as defined in TS 38.214 Table 5.2.2.2.1-3
            if (N1 > N2) && (N2 > 1)
                i13_length = 4;
                k1 = [0 O1 0 2*O1];
                k2 = [0 0 O2 0];
            elseif N1 == N2
                i13_length = 4;
                k1 = [0 O1 0 O1];
                k2 = [0 0 O2 O2];
            elseif (N1 == 2) && (N2 == 1)
                i13_length = 2;
                k1 = O1*(0:1);
                k2 = [0 0];
            else
                i13_length = 4;
                k1 = O1*(0:3);
                k2 = [0 0 0 0] ;
            end
            codebook = zeros(Pcsirs,nLayers,i20_length,i21_length,i22_length,i11_length,i12_length,i13_length,i141_length,i142_length,i143_length);
            % Loop over all the values of all the indices
            for i11 = 0:i11_length-1
                for i12 = 0:i12_length-1
                    for i13 = 0:i13_length-1
                        l = i11;
                        m = i12;
                        lPrime = i11 + k1(i13+1);
                        mPrime = i12 + k2(i13+1);
                        bitIndex = N2*O2*l+m;
                        lmRestricted = isRestricted(reportConfig.CodebookSubsetRestriction,bitIndex,[],reportConfig.i2Restriction);
                        if ~(lmRestricted)
                            vlm = getVlm(N1,N2,O1,O2,l,m);
                            vlPrime_mPrime = getVlm(N1,N2,O1,O2,lPrime,mPrime);
                            for i141 = 0:i141_length-1
                                for i142 = 0:i142_length-1
                                    for i143 = 0:i143_length-1
                                        for i20 = 0:i20_length-1
                                            for i21 = 0:i21_length-1
                                                for i22 = 0:i22_length-1
                                                    if reportConfig.CodebookMode == 1
                                                        n = i20;
                                                        phi_n = phi(n);
                                                        if Ng == 2
                                                            p = i141;
                                                            phi_p = phi(p);
                                                            % Codebook for 2-layer CSI
                                                            % reporting using antenna ports
                                                            % 3000 to 2999+P_CSIRS, as
                                                            % defined in TS 38.214 Table
                                                            % 5.2.2.2.2-4
                                                            codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(nLayers*Pcsirs))*[vlm                vlPrime_mPrime;...
                                                                phi_n*vlm         -phi_n*vlPrime_mPrime;...
                                                                phi_p*vlm          phi_p*vlPrime_mPrime;...
                                                                phi_n*phi_p*vlm   -phi_n*phi_p*vlPrime_mPrime];
                                                        else % Ng is 4
                                                            p1 = i141;
                                                            p2 = i142;
                                                            p3 = i143;
                                                            phi_p1 = phi(p1);
                                                            phi_p2 = phi(p2);
                                                            phi_p3 = phi(p3);
                                                            % Codebook for 2-layer CSI
                                                            % reporting using antenna ports
                                                            % 3000 to 2999+P_CSIRS, as
                                                            % defined in TS 38.214 Table
                                                            % 5.2.2.2.2-4
                                                            codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(2*Pcsirs))*[vlm                  vlPrime_mPrime;...
                                                                phi_n*vlm           -phi_n*vlPrime_mPrime;...
                                                                phi_p1*vlm           phi_p1*vlPrime_mPrime;...
                                                                phi_n*phi_p1*vlm    -phi_n*phi_p1*vlPrime_mPrime
                                                                phi_p2*vlm           phi_p2*vlPrime_mPrime;...
                                                                phi_n*phi_p2*vlm    -phi_n*phi_p2*vlPrime_mPrime;...
                                                                phi_p3*vlm           phi_p3*vlPrime_mPrime;...
                                                                phi_n*phi_p3*vlm    -phi_n*phi_p3*vlPrime_mPrime];
                                                        end
                                                    else % Codebook mode is 2
                                                        n0 = i20;
                                                        phi_n0 = phi(n0);
                                                        n1 = i21;
                                                        bn1 = b(n1);
                                                        n2 = i22;
                                                        bn2 = b(n2);
                                                        p1 = i141;
                                                        ap1 = a(p1);
                                                        p2 = i142;
                                                        ap2 = a(p2);
                                                        % Codebook for 2-layer CSI
                                                        % reporting using antenna ports
                                                        % 3000 to 2999+P_CSIRS, as
                                                        % defined in TS 38.214 Table
                                                        % 5.2.2.2.2-4
                                                        codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(2*Pcsirs))*[vlm             vlPrime_mPrime;...
                                                            phi_n0*vlm     -phi_n0*vlPrime_mPrime;...
                                                            ap1*bn1*vlm     ap1*bn1*vlPrime_mPrime;...
                                                            ap2*bn2*vlm    -ap2*bn2*vlPrime_mPrime];
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        case {3,4} % Number of layers is 3 or 4
            % Compute i13 parameter range, corresponding k1 and k2,
            % according to TS 38.214 Table 5.2.2.2.2-2
            if (N1 == 2) && (N2 == 1)
                i13_length = 1;
                k1 = O1;
                k2 = 0;
            elseif (N1 == 4) && (N2 == 1)
                i13_length = 3;
                k1 = O1*(1:3);
                k2 = [0 0 0];
            elseif (N1 == 8) && (N2 == 1)
                i13_length = 4;
                k1 = O1*(1:4);
                k2 = [0 0 0 0];
            elseif (N1 == 2) && (N2 == 2)
                i13_length = 3;
                k1 = [O1 0 O1];
                k2 = [0 O2 O2];
            elseif (N1 == 4) && (N2 == 2)
                i13_length = 4;
                k1 = [O1 0 O1 2*O1];
                k2 = [0 O2 O2 0];
            end
            codebook = zeros(Pcsirs,nLayers,i20_length,i21_length,i22_length,i11_length,i12_length,i13_length,i141_length,i142_length,i143_length);
            % Loop over all the values of all the indices
            for i11 = 0:i11_length-1
                for i12 = 0:i12_length-1
                    for i13 = 0:i13_length-1
                        l = i11;
                        m = i12;
                        lPrime = i11 + k1(i13+1);
                        mPrime = i12 + k2(i13+1);
                        bitIndex = N2*O2*l+m;
                        lmRestricted = isRestricted(reportConfig.CodebookSubsetRestriction,bitIndex,[],reportConfig.i2Restriction);
                        if ~(lmRestricted)
                            vlm = getVlm(N1,N2,O1,O2,l,m);
                            vlPrime_mPrime = getVlm(N1,N2,O1,O2,lPrime,mPrime);
                            for i141 = 0:i141_length-1
                                for i142 = 0:i142_length-1
                                    for i143 = 0:i143_length-1
                                        for i20 = 0:i20_length-1
                                            for i21 = 0:i21_length-1
                                                for i22 = 0:i22_length-1
                                                    if reportConfig.CodebookMode == 1
                                                        n = i20;
                                                        phi_n = phi(n);
                                                        if Ng == 2
                                                            p = i141;
                                                            phi_p = phi(p);
                                                            if nLayers == 3
                                                                % Codebook for 3-layer CSI
                                                                % reporting using antenna ports
                                                                % 3000 to 2999+P_CSIRS, as
                                                                % defined in TS 38.214 Table
                                                                % 5.2.2.2.2-5
                                                                codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(3*Pcsirs))*[vlm                vlPrime_mPrime                 vlm;...
                                                                    phi_n*vlm          phi_n*vlPrime_mPrime          -phi_n*vlm;...
                                                                    phi_p*vlm          phi_p*vlPrime_mPrime           phi_p*vlm;...
                                                                    phi_n*phi_p*vlm    phi_n*phi_p*vlPrime_mPrime    -phi_n*phi_p*vlm];
                                                            elseif nLayers == 4
                                                                % Codebook for 4-layer CSI
                                                                % reporting using antenna ports
                                                                % 3000 to 2999+P_CSIRS, as
                                                                % defined in TS 38.214 Table
                                                                % 5.2.2.2.2-6
                                                                codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(4*Pcsirs))*[vlm                vlPrime_mPrime                 vlm                 vlPrime_mPrime;...
                                                                    phi_n*vlm          phi_n*vlPrime_mPrime          -phi_n*vlm          -phi_n*vlPrime_mPrime;...
                                                                    phi_p*vlm          phi_p*vlPrime_mPrime           phi_p*vlm           phi_p*vlPrime_mPrime;...
                                                                    phi_n*phi_p*vlm    phi_n*phi_p*vlPrime_mPrime    -phi_n*phi_p*vlm    -phi_n*phi_p*vlPrime_mPrime];
                                                            end
                                                        else % Ng is 4
                                                            p1 = i141;
                                                            p2 = i142;
                                                            p3 = i143;
                                                            phi_p1 = phi(p1);
                                                            phi_p2 = phi(p2);
                                                            phi_p3 = phi(p3);
                                                            if nLayers == 3
                                                                % Codebook for 3-layer CSI
                                                                % reporting using antenna ports
                                                                % 3000 to 2999+P_CSIRS, as
                                                                % defined in TS 38.214 Table
                                                                % 5.2.2.2.2-5
                                                                codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(3*Pcsirs))*[vlm                 vlPrime_mPrime                  vlm;...
                                                                    phi_n*vlm           phi_n*vlPrime_mPrime           -phi_n*vlm;...
                                                                    phi_p1*vlm          phi_p1*vlPrime_mPrime           phi_p1*vlm;...
                                                                    phi_n*phi_p1*vlm    phi_n*phi_p1*vlPrime_mPrime    -phi_n*phi_p1*vlm
                                                                    phi_p2*vlm          phi_p2*vlPrime_mPrime           phi_p2*vlm;...
                                                                    phi_n*phi_p2*vlm    phi_n*phi_p2*vlPrime_mPrime    -phi_n*phi_p2*vlm;...
                                                                    phi_p3*vlm          phi_p3*vlPrime_mPrime           phi_p3*vlm;...
                                                                    phi_n*phi_p3*vlm    phi_n*phi_p3*vlPrime_mPrime    -phi_n*phi_p3*vlm];
                                                            elseif nLayers == 4
                                                                % Codebook for 4-layer CSI
                                                                % reporting using antenna ports
                                                                % 3000 to 2999+P_CSIRS, as
                                                                % defined in TS 38.214 Table
                                                                % 5.2.2.2.2-6
                                                                codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(4*Pcsirs))*[vlm                 vlPrime_mPrime                  vlm                  vlPrime_mPrime;...
                                                                    phi_n*vlm           phi_n*vlPrime_mPrime           -phi_n*vlm           -phi_n*vlPrime_mPrime;...
                                                                    phi_p1*vlm          phi_p1*vlPrime_mPrime           phi_p1*vlm           phi_p1*vlPrime_mPrime;...
                                                                    phi_n*phi_p1*vlm    phi_n*phi_p1*vlPrime_mPrime    -phi_n*phi_p1*vlm    -phi_n*phi_p1*vlPrime_mPrime
                                                                    phi_p2*vlm          phi_p2*vlPrime_mPrime           phi_p2*vlm           phi_p2*vlPrime_mPrime
                                                                    phi_n*phi_p2*vlm    phi_n*phi_p2*vlPrime_mPrime    -phi_n*phi_p2*vlm    -phi_n*phi_p2*vlPrime_mPrime
                                                                    phi_p3*vlm          phi_p3*vlPrime_mPrime           phi_p3*vlm           phi_p3*vlPrime_mPrime
                                                                    phi_n*phi_p3*vlm    phi_n*phi_p3*vlPrime_mPrime    -phi_n*phi_p3*vlm    -phi_n*phi_p3*vlPrime_mPrime];

                                                            end
                                                        end
                                                    else % Codebook mode is 2
                                                        n0 = i20;
                                                        phi_n0 = phi(n0);
                                                        n1 = i21;
                                                        bn1 = b(n1);
                                                        n2 = i22;
                                                        bn2 = b(n2);
                                                        p1 = i141;
                                                        ap1 = a(p1);
                                                        p2 = i142;
                                                        ap2 = a(p2);
                                                        if nLayers == 3
                                                            % Codebook for 3-layer CSI
                                                            % reporting using antenna ports
                                                            % 3000 to 2999+P_CSIRS, as
                                                            % defined in TS 38.214 Table
                                                            % 5.2.2.2.2-5
                                                            codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(3*Pcsirs))*[vlm            vlPrime_mPrime           vlm;...
                                                                phi_n0*vlm     phi_n0*vlPrime_mPrime   -phi_n0*vlm;...
                                                                ap1*bn1*vlm    ap1*bn1*vlPrime_mPrime   ap1*bn1*vlm;...
                                                                ap2*bn2*vlm    ap2*bn2*vlPrime_mPrime  -ap2*bn2*vlm];
                                                        elseif nLayers == 4
                                                            % Codebook for 4-layer CSI
                                                            % reporting using antenna ports
                                                            % 3000 to 2999+P_CSIRS, as
                                                            % defined in TS 38.214 Table
                                                            % 5.2.2.2.2-6
                                                            codebook(:,:,i20+1,i21+1,i22+1,i11+1,i12+1,i13+1,i141+1,i142+1,i143+1) = (1/sqrt(4*Pcsirs))*[vlm            vlPrime_mPrime            vlm            vlPrime_mPrime;...
                                                                phi_n0*vlm     phi_n0*vlPrime_mPrime    -phi_n0*vlm    -phi_n0*vlPrime_mPrime;
                                                                ap1*bn1*vlm    ap1*bn1*vlPrime_mPrime    ap1*bn1*vlm    ap1*bn1*vlPrime_mPrime;
                                                                ap2*bn2*vlm    ap2*bn2*vlPrime_mPrime   -ap2*bn2*vlm   -ap2*bn2*vlPrime_mPrime];
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
    end
end

function vlm = getVlm(N1,N2,O1,O2,l,m)
%   VLM = getVlm(N1,N2,O1,O2,L,M) computes vlm vector according to
%   TS 38.214 Section 5.2.2.2.1 considering the panel configuration
%   [N1, N2], DFT oversampling factors [O1, O2], and vlm indices L and M.

    um = exp(2*pi*1i*m*(0:N2-1)/(O2*N2));
    ul = exp(2*pi*1i*l*(0:N1-1)/(O1*N1)).';
    vlm =  reshape((ul.*um).',[],1);
end

function vbarlm = getVbarlm(N1,N2,O1,O2,l,m)
%   VBARLM = getVbarlm(N1,N2,O1,O2,L,M) computes vbarlm vector according to
%   TS 38.214 Section 5.2.2.2.1 considering the panel configuration
%   [N1, N2], DFT oversampling factors [O1, O2], and vbarlm indices L and M.

    % Calculate vbarlm (DFT vector required to compute the precoding matrix)
    um = exp(2*pi*1i*m*(0:N2-1)/(O2*N2));
    ul = exp(2*pi*1i*l*(0:(N1/2)-1)/(O1*N1/2)).';
    vbarlm = reshape((ul.*um).',[],1);
end

function [vlmRestricted,i2Restricted] = isRestricted(codebookSubsetRestriction,bitIndex,n,i2Restriction)
%   [VLMRESTRICTED,I2RESTRICTED] = isRestricted(CODEBOOKSUBSETRESTRICTION,BITINDEX,N,I2RESTRICTION)
%   returns the status of vlm or vbarlm restriction and i2 restriction for
%   a codebook index set, as defined in TS 38.214 Section 5.2.2.2.1 by
%   considering these inputs:
%
%   CODEBOOKSUBSETRESTRICTION - Binary vector for vlm or vbarlm restriction
%   BITINDEX                  - Bit index or indices (0-based) associated
%                               with all the precoding matrices based on
%                               vlm or vbarlm
%   N                         - Co-phasing factor index
%   I2RESTRICTION             - Binary vector for i2 restriction

    % Get the restricted index positions from the codebookSubsetRestriction
    % binary vector
    restrictedIdx = reshape(find(~codebookSubsetRestriction)-1,1,[]);
    vlmRestricted = false;
    if any(sum(restrictedIdx == bitIndex(:),2))
        vlmRestricted = true;
    end

    restrictedi2List = find(~i2Restriction)-1;
    i2Restricted = false;
    % Update the i2Restricted flag, if the precoding matrices based on vlm
    % or vbarlm are restricted
    if any(restrictedi2List == n)
        i2Restricted = true;
    end
end

function sinr = getPrecodedSINR(H,nVar,W)
%   SINR = getPrecodedSINR(H,NVAR,W) returns the linear SINR values given a
%   channel matrix H, a noise variance NVAR and a precoding matrix W. The
%   channel matrix H is of size Nrx-by-Ntx-by-NREs. This function estimates
%   the SINR for all REs in one go.
%
%   The MMSE SINR metric is gamma = 1/(nVar*(W'H'HW+nVar*I)^(-1)) - 1,
%   nVar noise variance and I identity matrix.
%   If den = (W'H'HW+nVar*I)^(-1) = nVar/(W'H'HW+nVar*I),
%   then gamma = (1./diag(nVar*den)) - 1.
%
%   The implementation in this function relies on the following: For each
%   RE R = H * W, where R = U * S * V', U and V unitary, S diagonal matrix
%   (SVD decomposition). U is RxP, S is diagonal PxP and V is PxP.
%
%   R' * R + nVar*I = V * S' * U' * U * S * V' + nVar*I = V * (S^2+nVar*I) * V'
%   and den = inv(R' * R + nVar*I) = V * inv(S^2+nVar*I) * V' = V * (1./(Sd^(2)+nVar). * I) * V'
%   where Sd is diag(S) and, adding nVar has no impact on U or V, just adds
%   nVar to the singular values of R. The use of SVD avoids the need for a
%   matrix inverse, instead we just need to calculate a1 = 1./(Sd^(2)+nVar).
%
%   The calculation of a2 = 1./diag(nVar*(V.*a1')*V') = 1./(nVar*diag((V.*a1')*V'))
%   is simplified to 1./(nVar * sum(a1'.*(V.*conj(V)), 2)) and sinr values
%   are obtained by calculating real(a2-1).
%
%   In code below, second letter "b" on u, s, and v is short for "big",
%   since we are treating with all REs in one go.

	% Calculate the SINR values as per LMMSE method
    R = pagemtimes(H,W);
    [~, sb, vb] = pagesvd(R,"econ","vector"); % sb in columns

    % If H is a 2D matrix, compute SINR values using W as the page matrix,
    % otherwise, consider using the channel matrix as the page matrix
    if(size(H,3)==1)
        a1 = (1./(sb.^2+nVar)); % 1./(Sd^(2)+nVar)
        a2 = 1./(nVar*squeeze(sum(pagetranspose(a1) .* (abs(vb) .^2), 2))); % Same as 1./diag( nVar*(V.*a1')*V' )
    else
        a1=1./(pagetranspose(sb .* sb)+(nVar*ones(1,size(W,2)))); % 1./(Sd^(2)+nVar)
        a2 = 1 ./ (nVar*squeeze(sum(a1 .* (abs(vb) .^2), 2))).'; % Same as 1./diag( nVar*(V.*a1')*V' )
    end
    sinr = real(a2-1);
end

function [WType2,PMISet,PMISINR] = getType2PMI(reportConfig,Hest,nVar,numLayers,varargin)
% [WTYPE2,PMISET,PMISINR] = getType2PMI(REPORTCONFIG,HEST,NVAR,NUMLAYERS)
% returns the selected wideband precoding matrix WTYPE2 and PMI output
% PMISET for Type II codebooks as defined TS 38.214 Section 5.2.2.2.3 along
% with the corresponding SINR value PMISINR considering these inputs:
%
%   REPORTCONFIG is a CSI reporting configuration structure with these
%   fields:
%   PanelDimensions            - Antenna panel configuration as a
%                                two-element vector ([N1 N2]), as
%                                defined in TS 38.214 Table 5.2.2.2.1-1
%   OverSamplingFactors        - DFT oversampling factors corresponding to
%                                the panel configuration
%   CodebookSubsetRestriction  - Amplitude restrictions for the beam groups
%                                as defined in TS 38.214 Section 5.2.2.2.3
%   PhaseAlphabetSize          - Phase alphabet size or the number of
%                                co-phasing factors with options ({4,8})
%   NumberOfBeams              - Number of beams to be considered per
%                                beam group
%   SubbandAmplitude           - Logical scalar to denote if subband
%                                amplitude reporting is enabled
%
%   NUMLAYERS    - Number of transmission layers
%   HEST         - Channel matrix of dimensions
%                  NRxAnts-by-number of CSI-RS ports
%   NVAR         - noise variance
%
%   WType2 is the precoding matrix size number of CSI-RS ports-by-numLayers
%   as defined in TS 38.214 Table 5.2.2.2.3-5.
%
%   PMISET is an output structure with these fields:
%   i1 - Indicates wideband PMI (1-based)
%        i1 is row vector of indices as [i11 i12 i131 i141 i132 i142]
%   i2 - Indicates subband PMI (1-based)
%        i2 is an array of indices as [i211 i212 i221 i222]
%   i11 denotes q1 q2 rotational factors
%   i12 denotes set of beams
%   i131 denotes the best beam on layer 1
%   i132 denotes the best beam on layer 2
%   i141 denotes wideband amplitudes for all beams on layer 1. It is a row
%   vector of length 2*Number of beams
%   i142 denotes wideband amplitudes for all beams on layer 2. It is a row
%   vector of length 2*Number of beams
%   i211 denotes subband phase on layer1. It is a column vector of length
%   2*Number of beams
%   i221 denotes subband amplitudes for all beams on layer 1. It is a
%   column vector of length 2*Number of beams
%   i212 denotes subband phase on layer2.It is a column vector of length
%   2*Number of beams
%   i222 denotes subband amplitudes for all beams on layer 2. It is a
%   column vector of length 2*Number of beams
%
%   PMISINR gives the SINR value corresponding to the reported PMISET
%
%   [WTYPE2,PMISET,PMISINR] = getType2PMI(REPORTCONFIG,HEST,NVAR,NUMLAYERS,WIDEBANDPMI)
%   returns the selected subband precoding matrix WTYPE2 using the wideband
%   amplitudes computed for the wideband precoding matrix indicator
%   WIDEBANDPMI.

    % Extract the beam group configuration information from reportConfig
    % structure
    N1 = reportConfig.PanelDimensions(1);
    N2 = reportConfig.PanelDimensions(2);
    O1 = reportConfig.OverSamplingFactors(1);
    O2 = reportConfig.OverSamplingFactors(2);
    isSubbandAmplitude = reportConfig.SubbandAmplitude;
    L = reportConfig.NumberOfBeams;
    nPSK = reportConfig.PhaseAlphabetSize;
    totalBeams = 2*L;

    % Check for the number of arguments. For wideband mode, the PMI set is
    % computed in the code and fourth argument is not necessary. For
    % subband mode, only amplitudes and phases are required to be computed
    % for the reported wideband PMI. Thus computed wideband PMI in given as
    % input (varargin{1})
    narginchk(4,5)

    % Compute the channel covariance matrix
    Hcov = Hest'*Hest;
    [~,~,Hv] = svd(Hcov);

    % Compute the DFT beams and beam combinations
    % Get ranges of each variable
    q1Range = 0:O1-1; % Oversampled beam index in horizontal direction
    q2Range = 0:O2-1; % Oversampled beam index in vertical direction

    % Compute the total number of beam combinations available for computation
    n1n2Prod = N1*N2;
    totBeamCombs = nchoosek(n1n2Prod,L);

    % Compute the m1 and m2 values for all beam combinations, as defined in
    % TS 38.214 Section 5.2.2.2.3
    n = flipud(nchoosek(0:N1*N2-1,L));
    n1 = mod(n,N1);
    n2 = (n - n1)/N1;
    m1Set = O1*n1 + shiftdim(q1Range,-1);
    m2Set = O2*n2 + shiftdim(q2Range,-1);

    if nargin == 4
        % This case corresponds to wideband. In this case the i11 and i12
        % values must be computed by choosing the best beam set among all
        % possible beam groups
        isSubbandMode = false;
        i12Set = 1:totBeamCombs;
        q1Range = 1:O1;
        q2Range = 1:O2;
    else
        % This case corresponds to subband. In this case the i11 and i12
        % from are obtained from the wideband PMI. The amplitudes and
        % phases must be computed for each subband corresponding to the
        % wideband beam group. Thus, the search among all possible beam
        % combinations in not needed here. Use the beam group reported by
        % the wideband PMI
        isSubbandMode = true;
        WidebandPMI = varargin{1};
        q1Range = WidebandPMI.i1(1);
        q2Range = WidebandPMI.i1(2);
        i12Set = WidebandPMI.i1(3);
        i131 = WidebandPMI.i1(4);
        i132 = WidebandPMI.i1(end-totalBeams);
        i14Vals(1,:) = WidebandPMI.i1(5:5+totalBeams-1);
        i14Vals(2,:) = WidebandPMI.i1(end-totalBeams+1:end);
        ampSetPerLayer = getAmplitudeValsFromi14(i14Vals);
        WBAmps = WidebandPMI.WBBeamAmplitudeSet; % For normalizing the subband amplitudes
    end

    % The amplitude and co-phasing factors of the beams for linear
    % combination are obtained by OMP decomposition. The precoding matrix
    % is formed such that it matches the channel eigenvalues
    EigVector = Hv(:,1:2);

    % Initialize a variable for the co-phasing factor
    phi =  zeros(totalBeams,numLayers,size(i12Set,2),size(m1Set,3),size(m2Set,3));

    % Initialize variables for the amplitude factors
    amplitudeCoeffSet = zeros(totalBeams,numLayers,size(i12Set,2),size(m1Set,3),size(m2Set,3));
    subbandAmpCoeff = 1/sqrt(2).*ones(totalBeams,numLayers);

    % Initialize variable for DFT vectors for all beam groups
    vm1m2 = zeros(n1n2Prod,L,size(m1Set,3),size(m2Set,3),size(i12Set,2));

    % Obtain maximum allowable amplitudes from the codebook subset restriction
    % as defined in TS 38.214 Table 5.2.2.2.3-6
    maxAllowableAmpWithIndex = codebookSubsetRestrictionSetType2(reportConfig.CodebookSubsetRestriction,reportConfig.PanelDimensions);
    W = NaN(2*n1n2Prod,numLayers,numel(i12Set),numel(q1Range),numel(q2Range));
    maximumAmplitudes = ones(L,numel(q1Range),numel(q2Range),numel(i12Set));
    strongBeamIdices = zeros(numLayers,numel(q1Range),numel(q2Range),numel(i12Set));
    wbAmplitudes = zeros(2*L,numLayers,numel(q1Range),numel(q2Range),numel(i12Set));
    for i12 = i12Set
        for q1 = q1Range
            for q2 = q2Range
                % Get the DFT vectors of the beam group corresponding to the
                % i12 q1 q2 indices
                for i = 1:L
                    m1 = m1Set(i12,i,q1);
                    m2 = m2Set(i12,i,q2);
                    vlm = getVlm(N1,N2,O1,O2,m1,m2);
                    vm1m2(:,i,q1,q2,i12) = vlm;
                    if ~isSubbandMode
                        restrictionIdx = find(m1 == maxAllowableAmpWithIndex(:,1) & m2 == maxAllowableAmpWithIndex(:,2));
                        if ~isempty(restrictionIdx)
                            maximumAmplitudes(i,q1,q2,i12) = maxAllowableAmpWithIndex(restrictionIdx,3);
                        end
                    end
                end
                vmats = vm1m2(:,:,q1,q2,i12);
                for i = 1:numLayers
                    % Obtain amplitude coefficients, co-phasing factors
                    eigVecPol1 = EigVector(1:N1*N2,i);
                    eigVecPol2 = EigVector(N1*N2+1:end,i);
                    scalingFactPol1 = (vmats'*eigVecPol1);
                    scalingFactPol2 = (vmats'*eigVecPol2);
                    scalingFactPolAll = [scalingFactPol1,scalingFactPol2]; % Of size L-by-2
                    [theta,amplitude] = cart2pol(real(scalingFactPolAll),imag(scalingFactPolAll));

                    % Quantize amplitudes
                    if isSubbandMode % Subband mode
                        % Get the subband amplitudes by scaling the
                        % obtained amplitude coefficient with wideband
                        % amplitudes
                        sbAmplitude = amplitude(:)./(WBAmps(:,i));
                        i13Value = i131*(i == 1) + i132*(i == 2);
                        amplitudeNormalized = sbAmplitude(:)./(sbAmplitude(i13Value)); % To make the subband amplitude corresponds to i13 index as 1
                        stdSBAmps = [1/sqrt(2) 1];
                        [~,minErrIdices] = min(abs(amplitudeNormalized(:)-stdSBAmps),[],2);
                        amplitudeSBQuantized = reshape(stdSBAmps(minErrIdices),[],2);
                        subbandAmpCoeff(:,i) = amplitudeSBQuantized(:);

                        % Quantized amplitudes
                        amplitudeQuantized = ampSetPerLayer(i,:).'.*amplitudeSBQuantized(:);

                        % Get quantized phases from wideband selection
                        thetaNormalized = theta - theta(i13Value);
                        c = mod(round(thetaNormalized*nPSK/(2*pi)),nPSK);
                    else % Wideband mode, first pass
                        [~,strongestBeamIdx] = max(amplitude(:)); % Strongest beam index across both the polarizations
                        strongBeamIdices(i,q1,q2,i12) = strongestBeamIdx;
                        amplitudeNormalized = amplitude/amplitude(strongestBeamIdx);
                        amplitudeQuantized = zeros(L,2);
                        for polIdx = 1:2
                            for beamIdx = 1:L
                                amplitudeQuantized(beamIdx,polIdx) = mapPVals(amplitudeNormalized(beamIdx,polIdx),maximumAmplitudes(beamIdx,q1,q2,i12));
                            end
                        end
                        % Quantize phases
                        thetaNormalized = theta - theta(strongestBeamIdx);
                        c = mod(round(thetaNormalized*nPSK/(2*pi)),nPSK);
                        wbAmplitudes(:,i,q1,q2,i12) = amplitude(:); % Required for the computation of subband amplitude vaues
                    end

                    % Compute the normalization factor
                    multFact = 1./sqrt(numLayers.*n1n2Prod.*sum(amplitudeQuantized(:).^2));

                    % Compute the precoding corresponding to each layer
                    if isSubbandMode % Subband mode
                        W(:,i) = multFact.*blkdiag(vmats,vmats)*(amplitudeQuantized(:).*exp(1i*2*pi*c(:)/nPSK));
                    else
                        if any(amplitude,'all')
                            W(:,i,i12,q1,q2) = multFact.*blkdiag(vmats,vmats)*(amplitudeQuantized(:).*exp(1i*2*pi*c(:)/nPSK));
                        end
                    end

                    phi(:,i,i12,q1,q2) = c(:);
                    amplitudeCoeffSet(:,i,i12,q1,q2) = amplitudeQuantized(:); % Store wideband scaling values that are required for the subband case
                end
            end
        end
    end
    layerSINRForAllBeamGrps = reshape(getPrecodedSINR(Hest,nVar,W),numLayers,numel(i12Set),numel(q1Range),numel(q2Range));

    % Form PMI indices set
    if ~(all(isnan(layerSINRForAllBeamGrps(:))))
        if ~isSubbandMode % Wideband case
            % Report the best beam group for the wideband mode
            sumSINRForAllBeamGrps = sum(layerSINRForAllBeamGrps,1);
            [i12,q1,q2] = ind2sub(size(layerSINRForAllBeamGrps,[2 3 4]),find(sumSINRForAllBeamGrps == max(sumSINRForAllBeamGrps,[],'all','omitnan'),1));

            % Get the strongest beam index for each layer
            i13Set = strongBeamIdices(:,q1,q2,i12);

            Ampset = amplitudeCoeffSet(:,:,i12,q1,q2); % Of size totBeams-by-numLayers
            i14l = mapToKVals(Ampset)';                % It is of size numLayers-by-totBeams
            i13_i14Set = [i13Set i14l]'; % It is of totBeams+1-by-numLayers
            PMISet.i1 = [q1 q2 i12 i13_i14Set(:)'];
            PMISet.i2 = phi(:,:,i12,q1,q2);
            PMISet.WBBeamAmplitudeSet = wbAmplitudes(:,:,q1,q2,i12);
            WType2 = W(:,:,i12,q1,q2);
            PMISINR = reshape(layerSINRForAllBeamGrps(:,i12,q1,q2),1,[]);
        else % Subband case
            i14l = i14Vals; % It is of size numLayers-by-totBeams
            i13Set = [i131;i132];
            i13_i14Set = [i13Set i14l]'; % It is of totBeams+1-by-numLayers
            PMISet.i1 = [q1 q2 i12 i13_i14Set(:)'];
            if isSubbandAmplitude                
                i22l = ones(size(subbandAmpCoeff));
                i22l(subbandAmpCoeff == 1) = 2; % 1-based indices
                numI2Cols = numLayers*(1+isSubbandAmplitude);
                i2Temp = [phi(:,:,i12,q1,q2) i22l];
                PMISet.i2 = i2Temp(:,[(1:2:numI2Cols) (2:2:numI2Cols)]);
            else
                PMISet.i2 = phi(:,:,i12,q1,q2);
            end
            WType2 = W;
            PMISINR = reshape(layerSINRForAllBeamGrps,1,[]);
        end
    else
        PMISet.i1 = NaN(1, 4 + 2*L + (1 + 2*L)*(numLayers == 2));
        PMISet.i2 = NaN(2*L, numLayers*(1+isSubbandAmplitude));
        WType2 = NaN(2*n1n2Prod,numLayers);
        PMISINR = NaN(numLayers,1);
    end
end

function [i14P] = mapPVals(amplitudeVals,maxAllowableAmp)
% i14P = mapPVals(AMPLITUDEVALS,MAXALLOWABLEAMP) returns the amplitude
% index i14P value for the given amplitude value AMPLITUDEVALS, rounded off
% to the standard defined wideband amplitudes for type II codebooks
% considering the maximum allowable amplitude MAXALLOWBLEAMP, defined from
% codebook subset restriction

    stdAmps = round([0 sqrt(1/64) sqrt(1/32) sqrt(1/16) sqrt(1/8) sqrt(1/4) sqrt(1/2) 1],4,'decimals');
    allowedAmps = stdAmps(1:find(stdAmps == maxAllowableAmp));
    if isscalar(allowedAmps) % Possible amplitude is zero only
        i14P = 0;
    else
        logStdAmps = log(allowedAmps);
        logStdAmps(1) = 2*logStdAmps(2) - logStdAmps(3);
        [~,idx] = min(abs(log(amplitudeVals) - logStdAmps));
        i14P = allowedAmps(idx);
    end
end

function [Amps] = getAmplitudeValsFromi14(i14Vals)
% AMPS = getAmplitudeValuesFromi14(I14VALS) returns the standard defined
% amplitude values AMPS to the corresponding i14 wideband amplitude indices
% I14VALS as defined in TS 38.214 Table 5.2.2.2.3-2
    stdAmps = [1 sqrt(1/2) sqrt(1/4) sqrt(1/8) sqrt(1/16) sqrt(1/32) sqrt(1/64) 0];
    KVals = 8:-1:1;
    Amps = ones(size(i14Vals));
    for i = 1:8
        Amps(i14Vals == KVals(i)) = stdAmps(i);
    end
end

function i14K = mapToKVals(amplitudes)
% i14K = mapToKvals(AMPLITUDES) returns the amplitude index i14K value for
% the given standard defined amplitude value AMPLITUDE mapped to the
% wideband amplitudes as defined in TS 38.214 Table 5.2.2.2.3-2 for type II
% codebooks
    stdAmps = [1 sqrt(1/2) sqrt(1/4) sqrt(1/8) sqrt(1/16) sqrt(1/32) sqrt(1/64) 0];
    KVals = 8:-1:1; % 1-based indices
    i14K = ones(size(amplitudes));
    for i = 1:8
        i14K(amplitudes == stdAmps(i)) = KVals(i);
    end
end

function maxAllowableAmpWithIndex = codebookSubsetRestrictionSetType2(bitVector,panelDimensions)
% MAXALLOWABLEAMPWITHINDEX = codebookSubsetRestrictionSetType2(BITVECTOR,PANELDIMENSIONS)
% returns the maximum allowable amplitude for the indices denoted by the
% codebook subset restriction BITVECTOR. The indices and the corresponding
% maximum amplitudes are extracted from the bit vector BITVECTOR for the
% given panel dimensions PANELDIMENSIONS. This is applicable only to Type II
% codebooks

    N1 = panelDimensions(1);
    N2 = panelDimensions(2);
    O1 = 4;
    O2 = 1 + 3*(N2>1); % 1 for N2 = 1 and 4 for N2 > 1
    r1 = 0:O1-1;
    r2 = repmat(0:O2-1,1,4/O2);
    n1n2Prod = N1*N2;
    o1o2Prod = O1*O2;
    % Obtain the r1 r2 indices from B1 part of bit vector B
    if N2 > 1
        B = bitVector(1:11); % b0,b1,b2,...b10, right-side MSB
        beta1 = bit2int(B(:),11,false); % Convert the bit vector to an integer by considering the right-side MSB
        s = 0;
        g = zeros(1,4);
        for k = 0:3
            y = NaN(o1o2Prod,1);
            for xRange = 3-k:o1o2Prod-1-k
                y(xRange+1) = 0;
                if 4-k <= xRange
                    y(xRange+1) = nchoosek(xRange,4-k);
                end
            end
            e = max(y(y<=(beta1-s)));
            x = find(y==e)-1;
            s = s+e;
            g(k+1) = o1o2Prod-1-x;
            r1(k+1) = mod(g(k+1),O1);
            r2(k+1) = floor((g(k+1) - r1(k+1))/O1);
        end
    end

    % Extract the bit vector B2, which is in the form of [B2(0) B2(1) B2(2) B2(3)]
    if O2>1
        B2 = bitVector(12:end);
    else
        B2 = bitVector; % Entire bit vector represents B2, as B1 is empty
    end

    % Obtain the maximum allowable amplitudes corresponding to the DFT
    % vectors of beam groups denoted by the bit vector B1
    maxAllowableAmpWithIndex = [];
    for k = 0:3
        B2ksequence = B2(2*n1n2Prod*k+1:2*n1n2Prod*(k+1)); % bit vector of length 2N1N2. It is in the form of b2k(0),b2k(1),...,b2k(2N1N2-1)
        for x1= 0:N1-1
            for x2 = 0:N2-1
                extractedbits = [B2ksequence(2*(N1*x2+x1)+1+1); B2ksequence(2*(N1*x2+x1)+1)] ;
                p = round([0 1/sqrt(4) 1/sqrt(2) 1],4,'decimals');
                maxAllowableAmpWithIndex = [maxAllowableAmpWithIndex; N1.*r1(k+1)+x1 N2.*r2(k+1)+x2 p(bit2int(extractedbits,2)+1)]; %#ok<AGROW> 

            end
        end
    end
end

function PMISetOut = getType2PMISetToReport(PMISet,sbAmp,numLayers)
% PMISETOUT = getType2PMISetToReport(PMISET,SBAMP,NUMLAYERS) returns the
% PMI indices set PMISETOUT, for the feedback by following the clauses
% mentioned in TS 38.214 Section 5.2.2.2.3. The values that are to be
% ignored are reported as NaNs.
% Note that NaN value for the phase and amplitude are equivalent to 0 and
% maximum possible amplitude for that beam respectively.

    i1 = PMISet.i1;
    i2 = PMISet.i2;
    totBeams = size(i2,1);
    i13_i14Set = reshape(i1(4:end),[],numLayers);
    i13 = i13_i14Set(1,:) + totBeams*(0:numLayers-1);
    i14 = i13_i14Set(2:end,:);
    i14(i13) = NaN; % Strongest wideband beam is not reported. It is set to NaN
    i13_i14Set(2:end,:) = i14;
    i1(4:end) = i13_i14Set(:)';
    PMISetOut.i1 = i1;

    nullIndices = cell(1,numLayers);
    descendBeamIndices = cell(1,numLayers);
    for layerIdx = 1:numLayers
        % Get the beam indices with zero amplitude
        nullIndices{layerIdx} = find(i14(:,layerIdx) == 1);

        [~,temp] = sort(i14(:,layerIdx),'descend');
        descendBeamIndices{layerIdx} = temp(2:end);
    end
    % Get the number of wideband amplitude values that are greater than 0
    % (including strongest beam amplitude) for each layer
    Ml = sum(i14 > 1) + 1;

    if sbAmp
        i2Cols = numLayers*(1+sbAmp);
        % Compute K for subband amplitude clauses as defined in TS 38.214
        % Table 5.2.2.2.3-4
        K = 4;
        if(totBeams == 8)
            K = 6;
        end

        numStrongBeams = min(Ml,K)-1;
        for sbIdx = 1:size(i2,3)
            % Subband phases
            % One strong beam            : Not reported and set to NaN
            % min(Ml,K)-1 strongest beams: Report the original values
            % Ml-min(Ml,K) weak beams    : Report the values in the range 0...3
            % Remaining 2L-Ml beams      : Not reported and set to NaN
            i21l = i2(:,1:2:i2Cols);
            i21l(i13) = NaN; % Corresponding to the strongest beam
            for layerIdx = 1:numLayers
                i21l(nullIndices{layerIdx},layerIdx) = NaN; % 2L-Ml number of beams
                i21l(descendBeamIndices{layerIdx}(numStrongBeams(layerIdx)+1:end)) = mod(i21l(descendBeamIndices{layerIdx}(numStrongBeams(layerIdx)+1:end)),4); % Phase values in the range 0...3
            end

            % Subband amplitudes
            % One strong beam             : Not reported and set to NaN
            % min(Ml,K)-1 strongest beams : Report the original values
            % Remaining 2L-min(Ml,K) beams: Not reported and amplitude is
            %                               set to NaN
            i22l = i2(:,2:2:i2Cols);
            i22l(i13) = NaN; % Corresponding to the strongest beam
            for layerIdx = 1:numLayers
                i22l([descendBeamIndices{layerIdx}(numStrongBeams(layerIdx)+1:end); nullIndices{layerIdx}]) = NaN;
            end

            % Form i2 indices
            i21l_i22l = [i21l i22l];
            i2 = [i21l_i22l(:,1:2:i2Cols) i21l_i22l(:,2:2:i2Cols)];
            PMISetOut.i2(:,:,sbIdx) = i2;
        end
    else
        for sbIdx = 1:size(i2,3)
            i21l = i2(:,:,sbIdx);
            i21l(i13) = NaN; % Corresponding to the strongest beam
            for layerIdx = 1:numLayers
                i21l(nullIndices{layerIdx},layerIdx) = NaN;
            end
            PMISetOut.i2(:,:,sbIdx) = i21l;
        end
    end
end