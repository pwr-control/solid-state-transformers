%[text] # sst\_cllc\_ttype\_inv: model initialization
% Two-module SST: battery -> CLLC-DCX 800 V / 800 V (library block cllc_dcx/cllc_dcx_mod1) -> single-phase three-level
% T-type inverter, 2 x 50 kW, the two inverters in series on a single-phase line. The model reads the struct "param",
% one group per subsystem (README.md). Only the simulation settings are here: the numbers of the bench are in
% ./private/sst_cllc_ttype_param.m, the library objects (timing, DCX blocks, inverter, batteries, heatsink) are built
% by ./private/sst_cllc_ttype_setup.m, the DCX stage is cllc_dcx_param_example.m of the library.

clear;
library_setup;                              % pwr-control/library on the path, cloned next to this repository when missing (./private)
model = init_environment('sst_cllc_ttype_inv');
%[text] ## Simulation
param.sim.simlength = 1.25;                 % [s] StopTime: current reference step at 0.35 s, 1 pu from 0.85 s, the last 0.2 s logged
param.sim.tc = 1e-7;                        % [s] FixedStep and MaxStep, Simscape local solver step, logging base and sample time of
                                            %     the DCX blocks. Backward Euler damps each resonant tank by about
                                            %     2 (w^2 Lr1 tc/2 + tc/(2 Cr1)): 2.5 Ohm at 1 us, 0.25 Ohm at 100 ns (README.md)
param.sim.nonlinear_iterations = 5;         % Simscape solver (Solver Configuration of battery_1, the only one of the model)
param.sim.export_legacy_names = 1;          % 1: the model still reads the flat names of the old init (./private/sst_cllc_ttype_legacy.m);
                                            %     0 after update_sst_cllc_ttype_inv('migrate')
%[text] ## Parameters
param = sst_cllc_ttype_setup(param);        % numbers of the bench and library objects (./private)
%[text] ## Model
open_system(model);
cellfun(@(b) set_param(b, 'Open', 'off'), find_system(model, 'BlockType', 'Scope'));   % scopes closed at start
if param.sim.export_legacy_names
    sst_cllc_ttype_legacy(param);           % glb_time, hwdata, mosfet, heatsink, ... in the base workspace, as the model reads them
end
