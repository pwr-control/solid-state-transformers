# CLLC-DCX 800 V → 800 V, 50 kW: sizing note

Rev. 01, 2026-10-24. Isolated DC/DC stage of one SST module working as a DC transformer (DCX): fixed
ratio 1:1 between the 800 V DC link of the module (side 1, the DC link of the T-type inverter) and the
isolated 800 V DC link (side 2), 50 kW in both directions. The numbers are in `private/cllc_dcx_param.m`,
the model is `sst_cllc_dcx.slx` (see `README.md`). The first-harmonic (FHA) curves come from
`cllc_analysis.m`, the transformer from `transformer_sizing.m`.

## 1. Operating point

| Quantity | Value | Note |
|---|---|---|
| Side 1 voltage u1 | 800 V | DC link of the SST module |
| Turns ratio n | 1 (11 : 11) | one transformer, no cells in series/parallel |
| Side 2 voltage u2 | 800 V at no load | u1 / n, isolated DC link |
| Power P | 50 kW | at the DCX input, both directions |
| DC current Idc | 62.5 A | both sides |
| Switching frequency fs | 50 kHz | |
| Resonant frequency fr | 52.6 kHz | fn = fs / fr = 0.95 |
| Dead time td | 300 ns | driving bridge, ZVS with Im = 10 A |
| Devices | 1200 V SiC MOSFET half-bridge modules | both bridges, 800 V on both sides |

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

At fn = 1 the gain is 1 for any load; with Ln = 33 and Q ≤ 0.4 the curve is flat around fn = 1
(`cllc_analysis.m`: |M(fs)| within 0.3 % of 1 from 10 % to 100 % load).

**Why fr a little above fs.** With fr = 52.6 kHz the half sine lasts 9.5 µs of the 10 µs half
period: it ends before the commutation also with the tolerances of Lr and Cr, the SR switch off at
zero current and the driving bridge switches Im only. A larger gap (fr = 70 kHz, say) is not a DCX
any more: more conduction losses, a higher voltage on Cr and a gain that moves with the load.

**The DCX does not regulate.** At fs the tank has a small net reactance; referred to side 1 and with
both sides together,

    X(fs) = 2 (ωs Lr1 - 1 / (ωs Cr1)) = 2 (3.77 - 4.18) ≈ -0.82 Ω      (capacitive, fs < fr)

If the two bridges are shifted by an angle φ the tank transfers power like a DAB,

    P(φ) ≈ U1 n U2 / (2 |X|) sin φ ≈ 640 kW · sin φ,      U1 ≈ n U2 ≈ (4/π) u1

so 50 kW need only about 4.5° and the current leads the voltage (capacitive mode, no ZVS). A loop on
φ would have a huge gain and would push the stage into this mode: the DCX runs open loop, with the
two bridges in phase (the current loop of the model is commented out, phase displacement 0). Voltage,
current and power direction are set by the stages around it: the grid-side converter on the DC link of
side 1 and the stage connected to side 2. If a phase-shift control is wanted, the right tank is the one
of the DAB bench (`sst_based_on_full_bridge_ttype_inverter/sst_single_phase_dab_single_phase_ttype_inv`).

## 3. Resonant tank and magnetizing inductance

**Currents.** With fs < fr each half period carries the charge Idc / (2 fs) in a half sine of period
1 / fr: peak I1pk = (π/2) Idc / fn = 103 A, rms over the switching period I1rms = I1pk sqrt(fn/2) =
71.2 A, 71.5 A with the magnetizing triangle. Side 2 carries the same current (n = 1).

**Magnetizing inductance.** Im must charge and discharge the output capacitance of one leg of the
driving bridge within the dead time: Qleg = 2 Coss u1 = 2 · 0.79 nF · 800 V = 1.26 µC, minimum peak
Qleg / td = 4.2 A. With margin, Im = 10 A:

    Lm = u1 / (4 Im fs) = 800 / (4 · 10 · 50 000) = 400 µH,      transition 2 Coss u1 / Im = 126 ns < 300 ns

The upper bound for the ZVS is Lm ≤ td / (8 fs Coss) = 950 µH; with Im = 10 A the leg capacitance
must stay below Im td / u1 = 3.75 nF. Im is 14 % of the resonant current peak and its rms (5.8 A)
adds 0.3 A to the winding current.

**Resonant inductance and capacitance.** Lr1 = 12 µH on side 1, about 4 µH of transformer leakage
and the rest a discrete inductor (Sec. 4). At fr = 52.6 kHz:

    Cr1 = 1 / ((2π fr)² Lr1) = 0.762 µF,   Z0 = sqrt(Lr1 / Cr1) = 3.97 Ω,   Rac = 10.4 Ω,   Q = 0.38,   Ln = 33

Cr1 is a film capacitor for 71 A rms at 50 kHz and 410 V peak (I1pk / (ωr Cr1)); the DC links keep the
DC component off it (full-bridge drive, no DC bias).

**Side 2 tank.** The symmetrical CLLC repeats the tank on side 2: Lr2 = Lr1 / n² = 12 µH and
Cr2 = n² Cr1 = 0.762 µF. In this way the resonance is the same in both power directions and the two
sides see the same currents and voltages.

## 4. Transformer (`transformer_sizing.m`)

| Quantity | Value | Note |
|---|---|---|
| Turns n1 : n2 | 11 : 11 | one layer of litz per winding |
| Voltage, current | 800 V square wave, 71.5 A rms per winding | 113 A peak with Im |
| Core | 3 stacked UU93/152/30 sets, ferrite N87 class | Ae = 25.2 cm², le = 354 mm, 4.5 kg |
| Peak flux density | 0.144 T | core loss sets it, not saturation (0.29 T on the first pulse from zero flux) |
| Air gap | about 0.8 mm in total | for Lm = 400 µH (2.4 mH without gap) |
| Windings | litz 3000 × 0.1 mm, 24 mm² (J = 3 A/mm²), 8.2 mm bundle | 11 turns in one layer of 90 mm, radial build 21 mm of the 37 mm window |
| Insulation | 3 mm barrier + shield between the windings | 800 V DC isolation, bobbin 2 mm |
| Resistance | 3.2 mΩ DC, about 4.7 mΩ AC per winding (Fr = 1.5) | model Rs1 = Rs2 = 6 mΩ with terminations and the discrete inductor |
| Leakage (P-S, no interleaving) | about 4 µH in total | the rest of Lr1 + Lr2 = 24 µH is discrete, about 10 µH per side |
| Losses | about 62 W core + 48 W copper | 0.22 % of 50 kW; model Rfe = u1² / 60 W |

Two stacked sets (16 turns) would need two layers per winding and do not fit the 37 mm window; four
sets (8 turns) have the same copper and 30 % more core loss. The Steinmetz law of the script is
anchored to one datasheet point of the material (49.5 kW/m³ at 35 kHz and 0.156 T, 100 °C) with
exponents 1.5 and 2.5: an assumption to replace with the datasheet of the chosen material, as the AC
resistance factor Fr = 1.5 of the litz winding.

## 5. Semiconductors

Both bridges are full bridges of 1200 V SiC MOSFET half-bridge modules, the same device on both sides
(800 V on both DC links). The model uses the library dataset `wolfspeed_SiC_MOSFET_CAB006M12GM3`:
6.6 mΩ at 100 °C, Coss 0.79 nF (the number of the ZVS sizing above). It has margin at 71.5 A rms and
113 A peak; a module of about 13-16 mΩ is the cost option, with about 70-100 W more per bridge.

- Conduction: 2 Rds_on I1rms² = 68 W per bridge.
- Switching of the driving bridge: ZVS turn-on at any load; turn-off at Im = 10 A only, about 2 W per
  switch with the datasheet Eoff scaled to 10 A and 800 V.
- The SR bridge switches at almost zero current: gate and body-diode losses only.

**SR gate drive.** The rectifying bridge must follow the sign of its own current, not the PWM of the
other bridge: the dead time (300 ns) is already 5.4° at 50 kHz, and a few degrees move tens of
kilowatts (Sec. 2). The blocks `sr_gate_logic` (bridge 2) and `sr1_gate_logic` (bridge 1) of the model
turn a diagonal on when |i| > i_on = 5 A and off when |i| < i_off = 1.9 A; at the zero crossing the
current slope is I1pk ωr = 34 A/µs, so the switch turns on 146 ns after the zero and off 55 ns before
it, with the body diodes conducting in between. In sink mode the roles swap (`param.sim.sink`).

## 6. DC links and chokes

The rectified current is a train of half sines: its AC part is sqrt(I1rms² - Idc²) = 34 A rms at
2 fs = 100 kHz, and the charge of each half period above the mean is 0.105 Idc / fs = 132 µC. With
500 µF per DC link the ripple is 0.26 V p-p; with 1 mΩ of ESR the loss is about 1 W per link. The
capacitors are set by the ripple current rating, not by the ripple: a film bank. In the SST module the
DC link of side 1 is shared with the single-phase inverter and is sized on its 100 Hz ripple (mF
range); 500 µF is the bench value. The DC chokes (250 µH, 2 mΩ, 8 W each) resonate with 500 µF at
450 Hz: the current-source load of the bench ramps in 20 ms, well above that.

## 7. Loss budget at 50 kW (sizing estimate)

| Item | Loss | Basis |
|---|---|---|
| Bridge 1, conduction | 68 W | 2 × 6.6 mΩ × (71.5 A)² |
| Bridge 1, switching and gate | 15 W | ZVS, turn-off at Im |
| Resonant inductors and Cr1, Cr2 | 40 W | about 20 W per side |
| Transformer | 110 W | Sec. 4 |
| Bridge 2, conduction | 68 W | as bridge 1 (SR in load, driving bridge in sink) |
| Bridge 2, gate and body diodes | 15 W | |
| DC chokes and DC link ESR | 18 W | 2 × 8 W + 2 × 1 W |
| Auxiliaries | 30 W | gate drivers, control, fans |
| **Total** | **365 W** | **η ≈ 99.3 %** |

The model has no auxiliaries and adds the numerical damping of Sec. 8 (about 0.63 kW at tc = 50 ns),
so the efficiency between the DC links of a run is expected around 98 %; `power_loss_calculus.m`
separates the two. Seen from side 2 the DCX is a voltage source u1 / n with a series resistance
R_eq ≈ 4 Rds_on + Rs1 + Rs2 + 2 RLdc ≈ 43 mΩ physical (2.7 V at 62.5 A) plus the numerical 125 mΩ.

## 8. Numerical settings

Simscape uses a local solver with the Backward Euler method and a fixed step tc. Backward Euler adds a
numerical damping: at the frequency ω each inductor gets about ω² L tc / 2 of extra series resistance
and each capacitor about tc / (2 C). For the two sides of the tank, referred to side 1,

    R_num ≈ 2 (ωs² Lr1 tc / 2 + tc / (2 Cr1))

| tc | steps per period | R_num | at 71 A rms |
|---|---|---|---|
| 62.5 ns | 320 | 0.156 Ω | 0.79 kW |
| 50 ns (model) | 400 | 0.125 Ω | 0.63 kW |
| 25 ns | 800 | 0.062 Ω | 0.32 kW |

The relative weight of R_num grows with ω Q tc, so at 50 kHz the step must be shorter than at
35 kHz for the same accuracy. The trapezoidal method has no damping but rings on the switching edges,
where the ZVS is read; the Partitioning solver chatters on the SR bridge at every zero of the current.
`param.sim.use_coss = 1` puts the Coss of the devices across each switch (with a 10 ns time constant)
to see the real dead-time transitions and the ringing of the rectifier nodes in the zero-current
interval.

## 9. Checks to do with the model

No run is saved yet. The first runs and what to compare with the sizing:

| Item | Sizing | Simulation | How |
|---|---|---|---|
| Tank currents i1, i2 rms / peak | 71.5 A / 113 A | | `power_loss_calculus.m` |
| Magnetizing current peak | 10 A | | figure 4 of `plotting_results.m` |
| Gain and phase at full load | u2 = u1 / n, i1 in phase with u1 | | `power_loss_calculus.m` |
| ZVS of the driving bridge | 126 ns of 300 ns | | figure 7, `zvs_check` |
| Bridge losses | 68 W + 15 W per bridge | | `power_loss_calculus.m` |
| Cr1 peak voltage | 410 V | | from the peak current |
| DC link 2 ripple and capacitor current | 0.26 V p-p, 34 A rms | | figures 4 and 6 |
| R_eq seen from side 2 | 43 mΩ + 125 mΩ numerical | | `power_loss_calculus.m` |
| Efficiency between the DC links | 99.3 % physical, about 98 % with R_num | | `power_loss_calculus.m` |
| Sink mode (both benches) | same currents and R_eq as load | | `param.sim.sink = 1, 2` |
| Light load 10 % and 50 % | gain within 0.3 %, SR thresholds, ZVS with the same Im | | `param.cllc.sink.I2` |
| Start-up | peak of i1 and of u2 without soft start | | figure 3 |
| Tank tolerances | fr ± 7 % (Cr ± 5 %, Lr ± 10 %) | | two runs at the corners |
