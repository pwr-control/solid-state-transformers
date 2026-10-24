# CLLC-DCX model: saved simulations

Model `single_phase_cllc_param.slx` of the FBK CLLC-DCX (PROP-2026-011-FBK-BIDCDC).
This file lists the runs saved as `sim_results_XX.mat` and how each one was set up.
The `.mat` files are not in git (`*.mat` in `.gitignore`). They are large (about 400 MB each).

Last update: 07/10/2026 evening (runs 06 and 07 with C_i = 2 mF).

## Common setup

- Numbers in `init_model.m` and `private/cllc_fbk_dcx_param.m`.
- DCX 660 V -> 73.3 V, n = 9 (two cells 18:4), 61 kW nominal.
- fs = 35 kHz, fr = 37 kHz, dead time 300 ns.
- Tank: Lr1 = 10 uH, Cr1 = 1.85 uF, Lr2 = 123 nH, Cr2 = 150 uF, Lm = 390 uH (Im 12 A).
- DC links: Cdc_dc1 = 3.6 mF (ESR 1 mOhm), LFi_dc1 = LFi_dc2 = 250 uH.
- C_i (Cdc_dc2) = 2 mF, ESR 0.15 mOhm: about 20 film capacitors of 100 uF / 100 V.
  The count comes from the ripple current (about 440 A rms at 70 kHz). Runs up to 06a and 07a used 500 uF and 1 mOhm.
- Run length 0.25 s. Only the last 50 ms are logged (`t_measure = simlength/5`).
- Log step and Simscape local solver step: tc = 62.5 ns. Backward Euler. `use_coss = 1`.
- Bench in load (`param.sim.sink = 0`): `battery_1` (about 656 V) on side 1, Controlled Current Source on side 2
  (`load`), I2 = +790 A with a 20 ms ramp (`param.cllc.sink.I2`, `param.cllc.sink.t_ramp`).
  Runs up to 06a used the resistor 0.088 Ohm of `load/passive load` (now commented out).
- Bridge 2 as synchronous rectifier on i2 (`sr_gate_logic`): on at 50 A, off at 20 A.

## Runs

| Run | Date | Power flow | What changes | Status of the file |
|-----|------|-----------|--------------|--------------------|
| 01 | 06/10 | load | Many early versions, overwritten. Last ones: first tries with `mos_simple_2th`. | Deleted |
| 02 | 06/10 | load | SR bank 16 x IPT025N15NM6. Primary SKM1700. | Deleted |
| 03 | 06/10 | load | Primary CAB006M12GM3. Previous library MOSFET block. | Can be deleted |
| 05 | 07/10 | load | `mos_simple_2th` in both bridges, Backward Euler, `use_coss = 0`. | Can be deleted |
| 06a | 06/10 | load | As 05, with `use_coss = 1`. C_i 500 uF, load resistor. Reference of report rev2. | Overwritten by 06 |
| 06 | 07/10 | load | As 06a, C_i = 2 mF (0.15 mOhm), current source +790 A. **Reference load run.** | Keep |
| 04 | 07/10 | sink | Mirror bench (`param.sim.sink = 2`), C_i 500 uF. | Keep (check of the sink mode) |
| 07a | 07/10 | sink | Battery + current source (`param.sim.sink = 1`), C_i 500 uF, 60 ms, all logged. | Overwritten by 07 |
| 07 | 07/10 | sink | As 07a, C_i = 2 mF (0.15 mOhm), 0.25 s, last 50 ms. **Reference sink run.** | Keep |

The numbers of all runs are saved in the project files, in
`AAA_design/cllc_dcx/data/rXX.json` (script `py/analyse_run.py`), also r06a and r07a.
Figures are in `simulazioni/` and in the CLLC-DCX report (`cllc_dcx_fbk_rev3`).

## Load runs: main numbers

Averages over the last 50 switching periods.

| Run | P in (kW) | P out (kW) | u out (V) | i out (A) | eta DC-DC | R_eq (mOhm) | Primary (W/switch) | SR (W/switch) | Q1 current at turn-on (A) |
|-----|-----------|------------|-----------|-----------|-----------|-------------|--------------------|---------------|---------------------------|
| 01 (SR, SKM1700 both bridges) | 57.2 | 54.1 | 69.8 | 776 | 94.5 % | 4.15 | 9 | 405 | -7 to +11 (no ZVS) |
| 02 | 58.5 | 56.7 | 71.4 | 794 | 96.9 % | 1.93 | 12.8 | 83.6 | -6 to +22 (partial ZVS) |
| 03 | 58.2 | 56.5 | 71.3 | 793 | 97.1 % | 2.10 | 36.8 | 83.3 | -9.0 (ZVS) |
| 05 | 58.0 | 56.4 | 71.2 | 792 | 97.1 % | 2.10 | 36.2 | 83.7 | -9.0 (ZVS) |
| 06a | 58.0 | 56.3 | 71.2 | 791 | 97.1 % | 2.12 | 35.2 | 83.6 | -4.2 (ZVS) |
| 06 (C_i 2 mF) | 57.9 | 56.5 | 71.5 | 790 | 97.5 % | 1.78 | 34.7 | 82.0 | -4.2 (ZVS) |

Notes:

- 05 matches 03 within 0.1 %: `mos_simple_2th` is validated against the previous block.
- In 05 the ZVS snubber of the library is in practice open (4.6 kOhm and 23 kOhm in series).
  So the dead-time transitions happen in one step, and the SR node sits at 34 V while i2 = 0.
- From 06a the Czvs blocks are the Coss of the devices (CAB006 0.79 nF, SR bank 36.8 nF, tau 10 ns).
  The Q1 transition takes about 125 ns, inside the 300 ns dead time.
  While i2 = 0 the SR node rings at about 1.5 MHz between 22 and 38 V. This is physical (Coss with the leakage).
- 06 against 06a: losses 1.44 kW instead of 1.66 kW. Almost all the difference is the ESR of C_i
  (29 W at 441 A rms instead of about 210 W at 457 A). The ESR loss is also seen in R_eq (2.12 -> 1.78 mOhm).
  u_i ripple 1.4 V p-p instead of 6.0 V (sizing 1.2 V p-p from the capacitance alone).
- The tank shows about 900 W against 173 W of physical losses.
  The difference (about 730 W) is numerical damping of Backward Euler at 62.5 ns.
  Without it the DCX is at about 98.8 % (sizing 98.6 %).
- Use Backward Euler. The Partitioning solver gave chatter at every zero of i2 and did not converge
  with the smooth diode (first versions of run 01).

## Sink runs

In sink the power flows from side 2 to side 1, and the bridges swap their roles:

- Bridge 2 is driven by the modulator at 50 % duty (`param.cllc.sr.mode = 0`).
- Bridge 1 is a synchronous rectifier on i1 (`param.cllc.sr1.mode = 1`, `sr1_gate_logic`):
  i1 > 0 -> Q2 + Q3, i1 < 0 -> Q1 + Q4, on at 5.6 A, off at 2.2 A.
  With `sr1.mode = 2` bridge 1 is a diode rectifier.
- `init_model.m` sets both modes from `param.sim.sink`. Keep `use_coss = 1` and Backward Euler.
- Initial voltages of CFi_dc1 and CFi_dc2: `param.cllc.ic.vc_dc1` and `param.cllc.ic.vc_dc2`.

### Run 04: mirror bench (`param.sim.sink = 2`, C_i 500 uF)

- Side 1: `battery_1` replaced by a resistor R1 = 7.14 Ohm (`param.cllc.sink.R1`).
- Side 2: DC voltage source U2 = 75.1 V (`param.cllc.sink.U2`) in place of the load.
  U2 is set so that u1 = 660 V on R1 with R_eq = 2.1 mOhm.
- LFi_dc2 = 3.1 uH (LFi_dc1/n^2). With 250 uH the bench resonates at 19 Hz and does not settle in 0.25 s.
- CFi_dc1 starts at 660 V, CFi_dc2 at 75.1 V.
- Results: 61.1 kW on R1, 62.9 kW from the source, 97.1 %, 838 A, R_eq 1.97 mOhm,
  bridges 151 W / 379 W (135 W / 338 W scaled to 790 A), ZVS of Q5 at -36 A.
  It still has C_i = 500 uF with 1 mOhm (about 220 W of ESR loss).

### Run 07: battery + current source (`param.sim.sink = 1`)

- Side 1: `battery_1` as in load. It is charged.
- Side 2: the same Controlled Current Source as in load, + on `load(+)`.
  Ramp from 0 to I2 = -790 A in 20 ms. Same |i2| as run 06, so load and sink compare at the same current.
- LFi_dc2 = 250 uH, as in load (in series with the current source it has no effect).
- Start (seen in 07a, logged from t = 0): DC link 1 at the battery voltage (676 V), C_i empty.
  The source charges C_i in about 1.4 ms with 500 uF (about 2.8 ms with 2 mF), 790 A at 20 ms,
  steady state after about 35 ms.
- First tries (07/10 morning): **not valid**, the bus started at about 5e12 V. Cause: "Start simulation from steady state"
  with the battery cell model. The state of charge is clamped (z.der = 0 for z <= 0 and z >= 1), and the off-state
  resistance of the bridge always draws a small current, so a steady state with 0 < z < 1 does not exist and the
  solver picks a z far outside the range. Fix (07/10, Davide): a 1 mF capacitor with initial voltage
  `battery_voltage_init_m` at the terminals of the battery block in the library
  (`masked_models/lithium_ion_batteries/lithium_ion_battery.slx`, local change, not committed yet).
- Results (last 50 periods), compared with run 06 at the same current:

| Quantity | Run 06 (load) | Run 07 (sink) | Run 07a (sink, 500 uF) |
|----------|---------------|---------------|------------------------|
| Power, 660 V side | 57.9 kW in | 60.3 kW out (into the battery) | 60.2 kW out |
| Power, 73 V side | 56.5 kW out | 61.8 kW in (from the source) | 61.9 kW in |
| Efficiency | 97.5 % | 97.7 % | 97.3 % |
| Losses | 1.44 kW | 1.45 kW | 1.65 kW |
| DC current, 73 V side | 790 A | 790 A | 790 A |
| u1 / u2 | 655.9 V / 71.5 V | 691.5 V / 78.2 V | 691.4 V / 78.3 V |
| u2 ripple | 1.4 V p-p | 1.4 V p-p | about 5.8 V p-p |
| i1 rms / i2 rms | 100.5 A / 905 A | 99.9 A / 899 A | 100.6 A / 905 A |
| Im peak | 11.8 A | 12.7 A | 12.6 A |
| R_eq | 1.78 mOhm | 1.70 mOhm | 1.91 mOhm |
| Bridge losses, side 1 / side 2 | 139 W / 328 W | 133 W / 335 W | 134 W / 339 W |
| Tank, physical / numerical | 173 W / 729 W | 177 W / 735 W | 178 W / 752 W |
| C_i rms current / ESR loss | 441 A / 29 W | 429 A / 28 W | 441 A / about 195 W |

- The bus goes from 676 V to 691 V because the battery is charged with 87 A. With the AFE it would stay at 660 V.
- ZVS of bridge 2 (active): u_ds of Q5 falls in one step, -39 A at the gate turn-on.
- Bridge 1 (SR on i1) switches at zero current; ringing of about 1.45 MHz between about 215 and 415 V
  for about 1.1 us per half period, Q1 max 696 V.

## Scripts

- `init_model.m`: parameters. Run it before every simulation.
- The one-shot scripts that edited the model (`add_sr_current_sync.m`, `add_sr1_current_sync.m`,
  `set_sr_device_in_model.m`, `set_mos_simple_alpha_r.m`) and the backups `single_phase_cllc_param_before_*.slx`
  were removed from the folder on 07/10. Their changes are in the model; the files are in the git history.
