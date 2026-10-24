# CLLC-DCX 790 V → 700 V, 50 kW, 35 kHz: sizing note

2026-10-24, 35 kHz variant of the 800 V → 800 V, 50 kHz bench (`../sst_cllc_dcx_800V_800V_50kW`). Isolated
DC/DC stage of one SST module
working as a DC transformer (DCX): fixed ratio 9:8 between a 790 V DC link (side 1) and an isolated 700 V DC link
(side 2), 50 kW in both directions. The
numbers are in `private/cllc_dcx_param.m`, the model is `sst_cllc_dcx_35kHz.slx` (see `README.md`). The
first-harmonic (FHA) curves come from `cllc_analysis.m`, the transformer from `transformer_sizing.m`.

## 1. Operating point

| Quantity | Value | Note |
|---|---|---|
| Side 1 voltage u1 | 790 V | design point of this variant |
| Turns ratio n = n1 / n2 | 9 / 8 = 1.125 | one transformer, no cells in series/parallel |
| Side 2 voltage u2 | 700 V nominal | u1 / n = 702 V at no load, about 699 V at 50 kW (R_eq, Sec. 7) |
| Power P | 50 kW | at the DCX input, both directions |
| DC currents | 63.3 A (side 1), 71.4 A (side 2) | |
| Switching frequency fs | 35 kHz | |
| Resonant frequency fr | 36.8 kHz | fn = fs / fr = 0.95 |
| Dead time td | 300 ns | driving bridge, ZVS with Im = 10 A |
| Devices | 1200 V SiC MOSFET half-bridge modules | both bridges (790 V and 700 V) |

## 2. Operating principle

In a DCX the switching frequency is close to the series resonant frequency of the tank. Both bridges
work with a fixed 50 % duty cycle and in phase. In each half period the resonant current is a half
sine, so:

- the gain is u2 = u1 / n and does not depend on the load;
- the only reactive current is the magnetizing current Im, a small triangle;
- Im gives the ZVS of the driving bridge;
- the rectifying bridge (synchronous rectifier, SR) turns off near zero current (ZCS).

First-harmonic gain of the tank, with Ln = Lm / Lr1, Q = Z0 / Rac, Rac = 8 n² u2² / (π² P):

    M(fn) = n u2 / u1 = 1 / sqrt( [1 + (1/Ln) (1 - 1/fn²)]² + Q² (fn - 1/fn)² )

At fn = 1 the gain is 1 for any load; with Ln = 35 and Q ≤ 0.4 the curve is flat around fn = 1
(`cllc_analysis.m`: |M(fs)| within 0.3 % of 1 from 10 % to 100 % load).

**Why fr a little above fs.** With fr = 36.8 kHz the half sine lasts 13.6 µs of the 14.3 µs half
period: it ends before the commutation also with the tolerances of Lr and Cr, the SR switch off at
zero current and the driving bridge switches Im only. A larger gap (fr = 50 kHz, say) is not a DCX
any more: more conduction losses, a higher voltage on Cr and a gain that moves with the load.

**The DCX does not regulate.** At fs the tank has a small net reactance; referred to side 1 and with
both sides together,

    X(fs) = 2 (ωs Lr1 - 1 / (ωs Cr1)) = 2 (3.52 - 3.90) ≈ -0.76 Ω      (capacitive, fs < fr)

If the two bridges are shifted by an angle φ the tank transfers power like a DAB,

    P(φ) ≈ U1 n U2 / (2 |X|) sin φ ≈ 660 kW · sin φ,      U1 ≈ (4/π) u1,  n U2 ≈ (4/π) n u2

so 50 kW need only about 4.3° and the current leads the voltage (capacitive mode, no ZVS). A loop on
φ would have a huge gain and would push the stage into this mode: the DCX runs open loop, with the
two bridges in phase (the current loop of the model is commented out, phase displacement 0). Voltage,
current and power direction are set by the stages around it: the grid-side converter on the DC link of
side 1 and the stage connected to side 2. If a phase-shift control is wanted, the right tank is the one
of the DAB bench (`sst_based_on_full_bridge_ttype_inverter/sst_single_phase_dab_single_phase_ttype_inv`).

## 3. Resonant tank and magnetizing inductance

**Currents.** With fs < fr each half period carries the charge Idc1 / (2 fs) in a half sine of period
1 / fr: peak I1pk = (π/2) Idc1 / fn = 105 A, rms over the switching period I1rms = I1pk sqrt(fn/2) =
72.1 A, 72.4 A with the magnetizing triangle. Side 2 carries n times the resonant current: 118 A peak,
81.1 A rms.

**Magnetizing inductance.** Im must charge and discharge the output capacitance of one leg of the
driving bridge within the dead time: Qleg = 2 Coss u1 = 2 · 0.79 nF · 790 V = 1.25 µC, minimum peak
Qleg / td = 4.2 A. With margin, Im = 10 A:

    Lm = u1 / (4 Im fs) = 790 / (4 · 10 · 35 000) = 564 µH → 560 µH,      transition 2 Coss u1 / Im = 124 ns < 300 ns

The upper bound for the ZVS is Lm ≤ td / (8 fs Coss) = 1.36 mH; with Im = 10 A the leg capacitance
must stay below Im td / u1 = 3.8 nF. Im is 10 % of the resonant current peak and its rms (5.8 A)
adds 0.3 A to the primary current.

**Resonant inductance and capacitance.** Lr1 = 16 µH on side 1, about 2 µH of transformer leakage
and the rest a discrete inductor (Sec. 4). At fr = 36.8 kHz:

    Cr1 = 1 / ((2π fr)² Lr1) = 1.17 µF,   Z0 = sqrt(Lr1 / Cr1) = 3.70 Ω,   Rac = 10.0 Ω,   Q = 0.37,   Ln = 35

Cr1 is a film capacitor for 72 A rms at 35 kHz and 390 V peak (I1pk / (ωr Cr1)); the DC links keep the
DC component off it (full-bridge drive, no DC bias).

**Side 2 tank.** The symmetrical CLLC repeats the tank on side 2 referred to its own voltage:
Lr2 = Lr1 / n² = 12.6 µH and Cr2 = n² Cr1 = 1.48 µF (81 A rms, 345 V peak). In this way the resonance
is the same in both power directions and the two sides see the same currents and voltages in pu.

## 4. Transformer (`transformer_sizing.m`)

| Quantity | Value | Note |
|---|---|---|
| Turns n1 : n2 | 9 : 8 | one layer of litz per winding; 702 V at no load |
| Voltage, current | 790 V square wave on the primary, 72.4 A rms primary / 81.1 A rms secondary | 115 A / 118 A peak |
| Core | 5 stacked UU93/152/30 sets, ferrite N87 class | Ae = 42 cm², le = 354 mm, 7.5 kg |
| Peak flux density | 0.149 T | core loss sets it, not saturation (0.30 T on the first pulse from zero flux) |
| Air gap | about 0.6 mm in total | for Lm = 560 µH (2.7 mH without gap) |
| Windings | primary litz 3070 × 0.1 mm, 24 mm² (J = 3 A/mm²), 8.3 mm bundle; secondary 3440 × 0.1 mm, 27 mm², 8.8 mm | 9 and 8 turns in one layer each (75 / 70 mm of the 96 mm window), radial build 22 mm of the 37 mm window |
| Insulation | 3 mm barrier + shield between the windings | DC isolation of the two links, bobbin 2 mm |
| Resistance | primary 3.6 mΩ DC, 5.4 mΩ AC; secondary 2.8 mΩ DC, 4.3 mΩ AC (Fr = 1.5) | model Rs1 = 7 mΩ with terminations and the discrete inductor, Rs2 = Rs1 / n² = 5.5 mΩ |
| Leakage (P-S, no interleaving) | about 4 µH in total, referred to the primary | the rest of Lr1 + n² Lr2 = 32 µH is discrete, 14 µH per side referred to the primary (11 µH on side 2) |
| Losses | about 66 W core + 56 W copper | 0.24 % of 50 kW; model Rfe = u1² / 66 W = 9.5 kΩ |

At 35 kHz the volt-seconds per half period are 43 % more than at 50 kHz, so for the same flux density
n1 Ae grows by the same factor: 9 turns of 8.3 mm litz are the most that fit in one layer with the
ratio 9:8, and five sets are needed for 0.15 T. Four sets (0.187 T) save 1.5 kg with 92 W of core loss
instead of 66 W and a first pulse of 0.37 T, close to saturation without a soft start; three sets
need 18:16 (same ratio) in two layers per winding, which fit the 37 mm window only at 4 A/mm² (fill
93 %, about 25 W core + 120-160 W copper, 20 µH of leakage); 17:15 gives 697 V. The Steinmetz law of
the script is anchored to one datasheet point of the material (49.5 kW/m³ at 35 kHz and 0.156 T,
100 °C) with exponents 1.5 and 2.5: an assumption to replace with the datasheet of the chosen
material, as the AC resistance factor Fr = 1.5 of the litz winding.

## 5. Semiconductors

Both bridges are full bridges of 1200 V SiC MOSFET half-bridge modules, the same device on both sides
(790 V and 700 V on the DC links). The model uses the library dataset `wolfspeed_SiC_MOSFET_CAB006M12GM3`:
6.6 mΩ at 100 °C, Coss 0.79 nF (the number of the ZVS sizing above). It has margin at 81 A rms and
118 A peak; a module of about 13-16 mΩ is the cost option, with about 70-100 W more per bridge.

- Conduction: 2 Rds_on I1rms² = 69 W on bridge 1, 2 Rds_on I2rms² = 87 W on bridge 2.
- Switching of the driving bridge: ZVS turn-on at any load; turn-off at Im = 10 A only, about 1.5 W per
  switch with the datasheet Eoff scaled to 10 A and 790 V.
- The SR bridge switches at almost zero current: gate and body-diode losses only.

**SR gate drive.** The rectifying bridge must follow the sign of its own current, not the PWM of the
other bridge: the dead time (300 ns) is already 3.8° at 35 kHz, and a few degrees move tens of
kilowatts (Sec. 2). The blocks `sr_gate_logic` (bridge 2) and `sr1_gate_logic` (bridge 1) of the model
turn a diagonal on when |i| > i_on and off when |i| < i_off: on bridge 2 i_on = 5.7 A and i_off = 2.1 A
(8 % and 3 % of Idc2); at the zero crossing the current slope is I2pk ωr = 27 A/µs, so the switch turns
on 210 ns after the zero and off 79 ns before it, with the body diodes conducting in between. Bridge 1
uses the same thresholds divided by n (5.1 A, 1.9 A, slope 24 A/µs). In sink mode the roles swap
(`param.sim.sink`).

## 6. DC links and chokes

The rectified current is a train of half sines: on side 2 its AC part is sqrt(I2rms² - Idc2²) = 38.5 A
rms at 2 fs = 70 kHz, and the charge of each half period above the mean is 0.105 Idc2 / fs = 214 µC;
on side 1, 34.6 A rms and 190 µC. With 500 µF per DC link the ripple is 0.43 V p-p (side 2) and
0.38 V p-p (side 1); with 1 mΩ of ESR the loss is about 1.5 W and 1.2 W. The capacitors are set by the
ripple current rating, not by the ripple: a film bank. In the SST module the DC link of side 1 is
shared with the single-phase inverter and is sized on its 100 Hz ripple (mF range); 500 µF is the
bench value. The DC chokes (250 µH, 2 mΩ: 8 W on side 1, 10 W on side 2) resonate with 500 µF at
450 Hz: the current-source load of the bench ramps in 20 ms, well above that.

## 7. Loss budget at 50 kW (sizing estimate)

| Item | Loss | Basis |
|---|---|---|
| Bridge 1, conduction | 69 W | 2 × 6.6 mΩ × (72.4 A)² |
| Bridge 1, switching and gate | 15 W | ZVS, turn-off at Im |
| Resonant inductors and Cr1, Cr2 | 40 W | about 20 W per side |
| Transformer | 122 W | Sec. 4 |
| Bridge 2, conduction | 87 W | 2 × 6.6 mΩ × (81.1 A)² (SR in load, driving bridge in sink) |
| Bridge 2, gate and body diodes | 15 W | |
| DC chokes and DC link ESR | 21 W | 8 W + 10 W + 1.2 W + 1.5 W |
| Auxiliaries | 30 W | gate drivers, control, fans |
| **Total** | **399 W** | **η ≈ 99.2 %** |

The model has no auxiliaries and adds the numerical damping of Sec. 8 (about 0.42 kW at tc = 50 ns),
so the efficiency between the DC links of a run is expected around 98.4 %; `power_loss_calculus.m`
separates the two. Seen from side 2 the DCX is a voltage source u1 / n with a series resistance
R_eq ≈ 2 Rds_on + Rs2 + RLdc2 + (2 Rds_on + Rs1 + RLdc1) / n² ≈ 38 mΩ physical (2.7 V at 71 A) plus
the numerical 64 mΩ (0.082 Ω of Sec. 8 referred to side 2).

## 8. Numerical settings

Simscape uses a local solver with the Backward Euler method and a fixed step tc. Backward Euler adds a
numerical damping: at the frequency ω each inductor gets about ω² L tc / 2 of extra series resistance
and each capacitor about tc / (2 C). For the two sides of the tank, referred to side 1,

    R_num ≈ 2 (ωs² Lr1 tc / 2 + tc / (2 Cr1))

| tc | steps per period | R_num | at 72 A rms |
|---|---|---|---|
| 62.5 ns | 457 | 0.102 Ω | 0.53 kW |
| 50 ns (model) | 571 | 0.082 Ω | 0.42 kW |
| 25 ns | 1143 | 0.041 Ω | 0.21 kW |

The relative weight of R_num grows with ω Q tc: at 35 kHz the 50 ns step costs 0.082 Ω against the
0.125 Ω of the 50 kHz design with the same step. The trapezoidal method has no damping but rings on
the switching edges, where the ZVS is read; the Partitioning solver chatters on the SR bridge at every
zero of the current. `param.sim.use_coss = 1` puts the Coss of the devices across each switch (with a
10 ns time constant) to see the real dead-time transitions and the ringing of the rectifier nodes in
the zero-current interval.

## 9. Checks to do with the model

No run is saved yet. The first runs and what to compare with the sizing:

| Item | Sizing | Simulation | How |
|---|---|---|---|
| Tank currents i1, i2 rms / peak | 72.4 A / 115 A and 81.1 A / 118 A | | `power_loss_calculus.m` |
| Magnetizing current peak | 10 A | | figure 4 of `plotting_results.m` |
| Gain and phase at full load | u2 = u1 / n = 702 V at no load, about 699 V at 50 kW, i1 in phase with u1 | | `power_loss_calculus.m` |
| ZVS of the driving bridge | 124 ns of 300 ns | | figure 7, `zvs_check` |
| Bridge losses | 69 W + 15 W (bridge 1), 87 W + 15 W (bridge 2) | | `power_loss_calculus.m` |
| Cr1, Cr2 peak voltage | 390 V, 345 V | | from the peak currents |
| DC link 2 ripple and capacitor current | 0.43 V p-p, 38.5 A rms | | figures 4 and 6 |
| R_eq seen from side 2 | 38 mΩ + 64 mΩ numerical | | `power_loss_calculus.m` |
| Efficiency between the DC links | 99.2 % physical, about 98.4 % with R_num | | `power_loss_calculus.m` |
| Sink mode (both benches) | same currents and R_eq as load | | `param.sim.sink = 1, 2` |
| Light load 10 % and 50 % | gain within 0.3 %, SR thresholds, ZVS with the same Im | | `param.cllc.sink.I2` |
| Start-up | peak of i1 and of u2 without soft start | | figure 3 |
| Tank tolerances | fr ± 7 % (Cr ± 5 %, Lr ± 10 %) | | two runs at the corners |
