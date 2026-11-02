#!/usr/bin/env python3
import sys
import re

def process_sdf(input_path, output_path):
    print(f"Processing SDF: {input_path} -> {output_path}")
    with open(input_path, 'r') as fin:
        lines = fin.readlines()

    out_lines = []
    in_clk_cell = False
    count = 0

    for line in lines:
        stripped = line.strip()
        if stripped.startswith('(CELLTYPE "CLKBUF') or stripped.startswith('(CELLTYPE "CLKINV'):
            in_clk_cell = True
            count += 1
        elif stripped.startswith('(CELLTYPE '):
            in_clk_cell = False
        elif stripped == '))':
            pass

        if in_clk_cell:
            if '(PORT ' in line:
                line = re.sub(r'\(PORT\s+(\S+)\s+\([^)]+\)\)', r'(PORT \1 (::0))', line)
            elif '(IOPATH ' in line:
                line = re.sub(r'\(IOPATH\s+(\S+)\s+(\S+)\s+\([^)]+\)\s+\([^)]+\)\)', r'(IOPATH \1 \2 (::0) (::0))', line)

        out_lines.append(line)

    with open(output_path, 'w') as fout:
        fout.writelines(out_lines)

    print(f"Done. Processed {count} clock buffer/inverter cells.")

if __name__ == '__main__':
    inp = sys.argv[1] if len(sys.argv) > 1 else 'asic/synth/outputs/350mhz/rv32_dot4_system.sdf'
    out = sys.argv[2] if len(sys.argv) > 2 else 'asic/synth/outputs/350mhz/rv32_dot4_system_gls.sdf'
    process_sdf(inp, out)

