# 5G NR Augmented Reality Simulator

## Simulator Overview and Capabilities
The present 5G AR system level simulation framework allows simulation of the transmission of AR video streams over a 5G NR radio cell. The simulator utilizes Matlab's 5G toolbox and the main simulation script was based on Matlab’s cell interference modelling example [1]. 

The developed simulator is capable of system-level simulations where transmissions to multiple users are performed in parallel. Moreover, also multiple same-frequency cells, whose signals are interfering with each other, are simulated. Multiple users are placed within a cell with pre-defined cell radius, uniform randomly. It is also randomly chosen if a user is indoors or outdoors, and if the user experiences line of sight or non-line of sight conditions. 

In terms of traffic, uplink and downlink cloud-rendering AR traffic can be simulated. Additionally, also uplink and downlink background traffic models for web-browsing, voice over IP calls, video-streaming and virtual conference calls can be selected. 

The 5G simulator natively implements the physical layer (PHY), medium access control layer (MAC) and radio link control layer (RLC) functionalities. The most important functionalities of the missing packet data convergence protocol layer (PDCP) and service data adaptation protocol layer (SDAP) were added to the implementation as part of this study. 

In terms of radio propagation effects, path-loss, shadowing and small-scale fading models according to 3GPP specification are implemented. The 3GPP communications scenarios urban macro-cell (UMa), representing cities with base stations mounted on rooftop level, urban micro-cell (UMi), representing cities with skyscrapers where base stations are mounted below rooftop levels, and rural macro-cell (RMa), representing rural areas, can be selected. Based on the chosen scenario the probability for indoor/outdoor users, LOS/NLOS conditions, as well as the used path loss, shadowing and small-scale fading parameters are changing. 

## Running the Simulator
The simulator is run by executing the main simulation file main.m. 

Before running the simulator, the applications for every user and the protocol stack for every application have to be configured using main_createSimulationConfig.m. The helper script generates configuration files for the SDAP, PDCP and RLC layer of 5G NR, as well as a configuration file for the application traffic. Other configurable parameters, e.g., PHY and MAC parameters or the cell radius, can be changed directly in main.m by altering the variable simParameters.

After a finished simulation run, two files simulationLogs.mat and simulationMetrics.mat are generated. By using the helper script main_plotSimulationLogs.m the results can be visualized.

The simulator was tested with Matlab r2022a & r2022b.

## Literature

[1] Matlab, "Intercell Interference Modelling Example," [Online]. Available: https://de.mathworks.com/help/5g/ug/nr-intercell-interference-modelling.html.