# PROJECT DIRECTORY & FILE GUIDE (A TO Z)
## USTP Capstone: RTL-to-GDSII RV32 RISC-V SoC with DOT4 Hardware Accelerator
**Technology Node:** TSMC 0.18µm (180nm) 6-Metal Layer (`tsmc18_6lm`)  
**Clock Target:** 350.00 MHz ($T_{\text{clk}} = 2.86\text{ ns}$)  
**Author:** Lead Engineer (`heisenberg`) & AI Technical Assistant (Antigravity)  
**Document Purpose:** Beginner-Friendly Complete Map of All Project Files, Folders, and Their Exact Roles in the ASIC Flow.

---

## 1. High-Level Architecture: Yeh Project Kya Hai?

Yeh project ek **RTL-to-GDSII ASIC Flow** hai. Iska maqsad ek 32-bit RISC-V Processor aur uske sath ek custom hardware vector accelerator (**DOT4**) ko software code se lekar factory mein banne wale silicon layout (**GDSII**) tak le jana hai.

ASIC flow mein kaam alag alag stages (Phases) mein hota hai, is liye repository ko standard industry structure ke mutabiq organize kiya gaya hai:

```text
RiscV_dotAcc_work/
├── sw/                  # [Phase 0] Software Firmware (Assembly, Hex, Compilers)
├── rtl/                 # [Phase 1] Hardware Verilog Source Code (Design)
├── tb/                  # [Phase 1 & 4] Simulation Testbenches
├── sim/                 # [Phase 1 & 4] Cadence Xcelium Simulation Workspace
├── pdk/                 # Foundry Technology Kit (TSMC 180nm Timing, LEF, Cells)
├── asic/                # ASIC Backend Implementation
│   ├── constraints/     # [Phase 2] Timing Constraints (SDC)
│   ├── synth/           # [Phase 3] Cadence Genus Logic Synthesis
│   ├── reports/         # [Phase 3 & 4] Timing, Area, Power & GLS Reports
│   └── pnr/             # [Phase 5-10] Cadence Innovus Place & Route (Layout)
└── project_tracking/    # Engineering History, Decision Logs & Formal Reports
```

---

## 2. Directory-by-Directory Deep Dive

---

### 📁 `sw/` (Software & Firmware)
* **Kyun Hai? (Purpose):**  
  Hamara RISC-V Processor tab tak kuch nahi kar sakta jab tak uske paas chalane ke liye koi software program na ho. Yeh folder processor ke firmware aur software tools ko contain karta hai.

* **Files Detail:**
  1. **`dot4_demo.s` (RISC-V Assembly Program):**  
     * **Kya karta hai?** Yeh hamara main firmware hai. Ismein RISC-V assembly instructions likhi hain jo memory se 4x4 matrices uthati hain, hardware accelerator ko command bhejti hain, aur result wapas check karti hain. Aakhir mein success hone par status `0x0A` (10) likhti hain.
  2. **`asm.py` (Custom Python Assembler):**  
     * **Kya karta hai?** Yeh assembly code (`.s`) ko machine language binary/hex (`.hex`) mein convert karta hai jise digital circuit samajh sake.
  3. **`program.hex` (Machine Code ROM File):**  
     * **Kya karta hai?** `asm.py` ka banaya hua output. Ismein hexadecimal numbers hain jo simulation ke waqt RAM memory ke andar pre-load hotay hain.
  4. **`dot4_demo.c` (C Language Implementation):**  
     * **Kya karta hai?** Reference C implementation jisse software aur hardware results ko match kiya jata hai.
  5. **`read_uart.py` & `build_docx.py`:**  
     * Helper utilities serial output read karne aur document generate karne ke liye.

---

### 📁 `rtl/` (Register Transfer Level — Hardware Source Code)
* **Kyun Hai? (Purpose):**  
  Yeh hamare pooray chip ka digital architecture hai jo Verilog HDL mein likha gaya hai. Isko do hisson mein taqseem kiya gaya hai taake report mein **Before vs. After** ka comparison dikhaya ja sake.

#### 📂 `rtl/baseline/` (Original Architecture — Before Optimization)
* Yeh woh original design hai jo un-optimized tha aur 300–400 MHz target par fail ho raha tha (sirf 218 MHz tak chal sakta tha).
  1. `rv32i_core.v` — Baseline 5-stage RISC-V core (Execute stage mein critical delay tha).
  2. `dot4_datapath.v` — Single-cycle combinational multiplier/adder tree (3.76 ns delay — FAIL).
  3. `dot4_accel_top.v` — Baseline FSM wrapper.
  4. `uart_tx.v` — Simple UART transmitter module.
  5. `ram.v` — Dual-port behavioral 8KB SRAM model.
  6. `riscv_soc_top.v` — Baseline monolithic top-level system.

#### 📂 `rtl/optimized/` (Final Architecture — 350 MHz Timing Closed)
* Yeh hamara optimized aur final synthesizable hardware hai jo 350 MHz ($2.86\text{ ns}$) par timing close karta hai:
  1. **`dot4_datapath_pipelined.v`:**  
     * 16x16 multiplier aur 32-bit adder ke darmiyan 2-stage pipeline register daala gaya. Delay 3.76 ns se gir kar 1.84 ns ho gaya!
  2. **`dot4_accel_top_fast.v`:**  
     * Accelerator FSM jo Multicycle Path (MCP = 2 cycles) handle karta hai aur interrupts generate karta hai.
  3. **`rv32i_core_fast.v`:**  
     * Optimized RV32I Core: Decode stage mein branch adder alag kar diya gaya, jis se Execute cycle ka critical path khatam ho gaya.
  4. **`bus_interconnect.v`:**  
     * Memory-mapped bus decoder: Address `0x0000_xxxx` ko RAM, `0x8000_xxxx` ko Accelerator, aur `0x9000_xxxx` ko Host Status output par route karta hai.
  5. **`rv32_dot4_system.v` (Top-Level ASIC Chip Module):**  
     * **Most Important File!** Capstone requirement (Option 1) ke mutabiq strictly 3 principal blocks (Core + Interconnect + Accelerator) ko encapsulate karta hai. Memory bus bahar nikli hui hai jo chip I/O pads se connect hogi.

---

### 📁 `tb/` (Testbenches)
* **Kyun Hai? (Purpose):**  
  Testbench circuit ke ird-gird ek aisi "Virtual Testing Lab" hoti hai jo clock generate karti hai, reset dabati hai, aur output ko check karti hai ke nateeja theek aaya ya nahi.

* **Files Detail:**
  1. **`tb_rv32_dot4_system.v` (Frontend RTL Testbench):**  
     * RTL simulation ke liye testbench jo 3-block system aur RAM ko aapas mein jor kar 4x4 matrix multiplication chalati hai.
  2. **`tb_rv32_dot4_system_gls.v` (Gate-Level Simulation Testbench):**  
     * Gate-level netlist (12,667 mapped gates) ko 350 MHz clock par test karne ke liye testbench.
  3. **`tb_dot4_accel_top.v`:**  
     * Standalone accelerator testbench (208 random test vectors verify karta hai).
  4. **`tb_riscv_soc_top.v`:**  
     * Baseline monolithic SoC testbench.

---

### 📁 `sim/` (Simulation Execution Workspace)
* **Kyun Hai? (Purpose):**  
  Cadence Xcelium simulator ko chalane ki dedicated jagah. Isse root folder mein kachra (temporary log files, compiled databases) jama nahi hota.

* **Files Detail:**
  1. **`Makefile`:**  
     * Automation file. Sirf `make gls`, `make accel`, `make system` likhne se poori simulation khud chal jati hai.
  2. **`run_gls.sh`:**  
     * Round A (Functional Gate-Level Simulation at 350 MHz) chalane ka executable bash script.
  3. **`run_gls_sdf.sh`:**  
     * Round B (Timing SDF Delays Gate-Level Simulation) chalane ka script.
  4. **`run_soc.sh` & `run_accel.sh`:**  
     * RTL level simulation scripts.
  5. **`xcelium.d/`:**  
     * Cadence Xcelium ka compiled binary cache database folder.

---

### 📁 `pdk/` (Process Design Kit — TSMC 180nm)
* **Kyun Hai? (Purpose):**  
  Yeh TSMC foundry (semiconductor factory) ka physical aur mathematical data hai. Synthesis aur Layout tools (Genus aur Innovus) ko iske baghair pata hi nahi chal sakta ke transistor ka size kya hai, gate kitna lamba hai, aur signal kitni der mein guzrega. Hamara PDK fully portable hai aur project ke andar hi majood hai.

* **Sub-Folders Detail:**
  1. **`pdk/lib/` (Liberty Timing Models):**
     * `slow.lib` — Worst-case slow corner ($1.62\text{ V}, 125^\circ\text{C}$). Setup timing signoff ke liye use hota hai.
     * `fast.lib` — Best-case fast corner ($1.98\text{ V}, -40^\circ\text{C}$). Hold timing signoff ke liye use hota hai.
     * `tpz973gwc-lite_slow.lib` & `tpz973gbc-lite_fast.lib` — Chip ke I/O Pad cells ki timing libraries.
     * `ram_*_syn.lib` & `pllclk_*.lib` — Memory macros aur PLL clock timing models.
  2. **`pdk/lef/` (Library Exchange Format — Physical Geometries):**
     * `all.lef` — Chip ke har standard cell aur metal layer ka physical naksha (dimensions, pin locations, DRC design rules).
  3. **`pdk/captable/` (Interconnect Capacitance):**
     * `t018s6mlv.capTbl` — 6-layer metal wires ki capacitance tables (parasitic calculation ke liye).
  4. **`pdk/QRC/` (Parasitic Extraction):**
     * `t018s6mm.tch` & `t018s6mm.ict` — Detailed RC extraction rules (routing ke baad actual wire resistance nikalne ke liye).
  5. **`pdk/CDB/` (Noise & Signal Integrity):**
     * `slow.cdb`, `fast.cdb` — Crosstalk noise aur signal integrity check karne ke libraries.
  6. **`pdk/verilog/` (Simulation Models):**
     * `tsmc18.v` — Tamam 143 mapped standard cells ke Verilog behavioral simulation models (Gate-Level Simulation ke liye).

---

### 📁 `asic/` (ASIC Implementation Backend)
* **Kyun Hai? (Purpose):**  
  Yeh ASIC synthesis aur Physical Design (PnR) ka central hub hai.

#### 📂 `asic/constraints/` (Timing Constraints)
* **`rv32_dot4_system_350mhz.sdc` / `rv32_dot4_system.sdc`:**  
  Synopsys Design Constraints (SDC) file. Ismein tool ko bataya gaya hai ke:
  * Clock ka period $2.86\text{ ns}$ (350 MHz) hona chahiye.
  * Clock jitter/uncertainty kitni rakhni hai.
  * Multi-cycle path (MCP = 2 cycles) kahan lagana hai.
  * Input/Output delays aur driving cell ki strength kya hai.

#### 📂 `asic/synth/` (Logic Synthesis — Cadence Genus)
* Yeh folder logic synthesis ke scripts aur outputs rakhta hai:
  1. **`run_synth_350mhz.tcl`:**  
     * Primary automation script jo RTL ko read karta hai, TSMC 180nm `slow.lib` par map karta hai, 350 MHz timing optimize karta hai, aur GUI open karta hai.
  2. **`run_synth_325mhz.tcl`:**  
     * Guardband exploration script (325 MHz fallback target).
  3. **`view_gui_350mhz.tcl`:**  
     * Genus schematic viewer ko instant open karne ka script (bina dobara synthesis run kiye 2 second mein open hota hai).
  4. **`netlist/`:**  
     * `rv32_dot4_system.v` — Mapped gate-level netlist (1.79 MB, 12,667 cells).
  5. **`sdf/`:**  
     * `rv32_dot4_system.sdf` — Standard Delay Format file (4.4 MB) jis mein har gate aur wire ka exact calculated picosecond delay likha hota hai.
  6. **`outputs/350mhz/`:**  
     * Synthesis ke final deliverables jo Innovus PnR mein import honge (`.v`, `.sdc`, `.sdf`, `.db`).

#### 📂 `asic/reports/` (Audit Reports & Quality of Results)
* Yahan Genus aur Xcelium ke banaye huay sabhi technical reports save hain:
  * `timing_summary.rpt` — Setup slack ($WNS = 0.0\text{ ps}$ MET).
  * `timing.rpt` — Top 20 critical timing paths.
  * `qor_mapped.rpt` — Quality of Results (0 violating paths, 12,667 cells).
  * `area_mapped.rpt` — Total cell area ($273,855.8\,\mu\text{m}^2$).
  * `power_mapped.rpt` — Total power consumption ($68.37\text{ mW}$).
  * `gates_mapped.rpt` — Gate counts (1,711 DFFs, 8,662 logic gates, 0 latches).
  * `lint.rpt` — Zero unresolved references, zero multidriven nets.
  * `gls/` — Phase 4 Gate-Level Simulation ke official raw logs (`gls_roundA_functional_350mhz.log`, etc.).

#### 📂 `asic/pnr/` (Physical Layout — Cadence Innovus)
* **Kyun Hai? (Purpose):**  
  Yeh hamara **Phase 5 se Phase 10** tak ka physical layout workspace hai. Iski scaffolding professional standard labs (`innovus_lab03`) ke mutabiq banayi gayi hai:
  * `work/` — **Strict Execution Sandbox:** Innovus ko hamesha is folder ke andar se launch kiya jata hai taake scratch files baki folders ko pollute na karein.
  * `dbs/` — **Checkpointing & Rollback:** Har milestone par full design state yahan save hoti hai (`01_init.enc`, `02_floorplan.enc`, `03_power.enc`, etc.).
  * `design/` — Mapped gate-level netlist (`rv32_dot4_system.v`), future `chip.io`, `design.globals`.
  * `lef/` — Technology LEF (`all.lef`).
  * `lib/` — Timing libraries (`slow.lib`, `fast.lib`, IO pads).
  * `captable/` — Capacitance table (`t018s6mlv.capTbl`).
  * `tcl/` — Modular PnR scripts (`01_init.tcl` through `08_signoff.tcl`).
  * `outputs/` — Final tapeout deliverables (GDSII, DEF, SPEF).

---

### 📁 `project_tracking/` (Permanent Documentation & Engineering History)
* **Kyun Hai? (Purpose):**  
  Yeh folder project ki "Black Box Flight Recorder" hai. Ismein har architectural decision, math verification, aur phase reports preserved hain.

* **Files Detail:**
  1. **`MASTER_EXECUTION_PLAN_AND_CHECKLIST.md`:**  
     * Master 13-Phase roadmap jismein har phase ke checkboxes interactive hain.
  2. **`DECISION_AND_PROGRESS_LOG.md`:**  
     * Persistent chronological log jismein tamam technical discussions (Log Entry 01 se Log Entry 16 tak) darj hain.
  3. **`OPERATIONAL_PROTOCOL_AND_RULES.md`:**  
     * Project ka permanent charter: User-driven hands-on execution, zero-hallucination rules, frequency narrative mandates.
  4. **Phase Reports:**
     * `PHASE_1_FRONTEND_VERIFICATION_REPORT.md` (208/208 checks passed).
     * `PHASE_2_SDC_CONSTRAINTS_REPORT.md` (350 MHz constraint formulation).
     * `PHASE_3_GENUS_SYNTHESIS_REPORT.md` (Synthesis timing closure: Baseline FAIL to 350 MHz PASS).
     * `PHASE_4_GATE_LEVEL_SIMULATION_REPORT.md` (GLS Round A & B verification report).

---

### 📄 Root Directory Key Files
1. **`setup_env.sh`:**  
   * Cadence EDA environment setup script (`source setup_env.sh`). Genus, Innovus, Xcelium, aur PDK ke paths set karta hai.
2. **`program.hex`:**  
   * Root level hex copy jo simulation runs ke liye directly access hoti hai.
3. **`COMPREHENSIVE_PROJECT_REPORT.docx` & `RISC_V_DOT4_DETAILED_REPORT.docx`:**  
   * Capstone documentation deliverables for academic submission.
4. **`USTP_Capstone_Visio_Updated.docx`:**  
   * Capstone Section 1, 2, aur 6 ka official Microsoft Visio floorplan aur architecture diagram.

---

## 3. Quick Navigation: "Mujhe X dekhna ho to kahan jaoon?"

| Sawal / Requirement | Kahan Jana Hai? (Exact Path) |
| :--- | :--- |
| **Chip ka Verilog source code kahan hai?** | [`rtl/optimized/rv32_dot4_system.v`](file:///home/heisenberg/Desktop/RiscV_dotAcc_work/rtl/optimized/rv32_dot4_system.v) |
| **Pipelined hardware accelerator kahan hai?** | [`rtl/optimized/dot4_datapath_pipelined.v`](file:///home/heisenberg/Desktop/RiscV_dotAcc_work/rtl/optimized/dot4_datapath_pipelined.v) |
| **Firmware Assembly code kahan hai?** | [`sw/dot4_demo.s`](file:///home/heisenberg/Desktop/RiscV_dotAcc_work/sw/dot4_demo.s) |
| **Synthesis ka mapped Gate Netlist kahan hai?** | [`asic/synth/outputs/350mhz/rv32_dot4_system_syn.v`](file:///home/heisenberg/Desktop/RiscV_dotAcc_work/asic/synth/outputs/350mhz/rv32_dot4_system_syn.v) |
| **Synthesis ke Timing / Area / Power reports kahan hain?** | [`asic/reports/`](file:///home/heisenberg/Desktop/RiscV_dotAcc_work/asic/reports/) |
| **Gate-Level Simulation ka testbench kahan hai?** | [`tb/tb_rv32_dot4_system_gls.v`](file:///home/heisenberg/Desktop/RiscV_dotAcc_work/tb/tb_rv32_dot4_system_gls.v) |
| **Gate-Level Simulation ka PASS log kahan hai?** | [`asic/reports/gls/gls_roundA_functional_350mhz.log`](file:///home/heisenberg/Desktop/RiscV_dotAcc_work/asic/reports/gls/gls_roundA_functional_350mhz.log) |
| **TSMC 180nm Cell Libraries kahan hain?** | [`pdk/lib/slow.lib`](file:///home/heisenberg/Desktop/RiscV_dotAcc_work/pdk/lib/slow.lib) aur [`pdk/lef/all.lef`](file:///home/heisenberg/Desktop/RiscV_dotAcc_work/pdk/lef/all.lef) |
| **Cadence Innovus PnR kahan run hoga?** | [`asic/pnr/work/`](file:///home/heisenberg/Desktop/RiscV_dotAcc_work/asic/pnr/work/) |
| **Project ka overall roadmap aur checklist kahan hai?** | [`project_tracking/MASTER_EXECUTION_PLAN_AND_CHECKLIST.md`](file:///home/heisenberg/Desktop/RiscV_dotAcc_work/project_tracking/MASTER_EXECUTION_PLAN_AND_CHECKLIST.md) |

