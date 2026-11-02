#!/usr/bin/env python3
import sys
import re

REGS = {
    'zero': 0, 'x0': 0, 'ra': 1, 'x1': 1, 'sp': 2, 'x2': 2, 'gp': 3, 'x3': 3,
    'tp': 4, 'x4': 4, 't0': 5, 'x5': 5, 't1': 6, 'x6': 6, 't2': 7, 'x7': 7,
    's0': 8, 'fp': 8, 'x8': 8, 's1': 9, 'x9': 9, 'a0': 10, 'x10': 10, 'a1': 11, 'x11': 11,
    'a2': 12, 'x12': 12, 'a3': 13, 'x13': 13, 'a4': 14, 'x14': 14, 'a5': 15, 'x15': 15,
    'a6': 16, 'x16': 16, 'a7': 17, 'x17': 17, 's2': 18, 'x18': 18, 's3': 19, 'x19': 19,
    's4': 20, 'x20': 20, 's5': 21, 'x21': 21, 's6': 22, 'x22': 22, 's7': 23, 'x23': 23,
    's8': 24, 'x24': 24, 's9': 25, 'x25': 25, 's10': 26, 'x26': 26, 's11': 27, 'x27': 27,
    't3': 28, 'x28': 28, 't4': 29, 'x29': 29, 't5': 30, 'x30': 30, 't6': 31, 'x31': 31
}

def parse_val(v, labels, pc):
    v = v.strip()
    if v in labels:
        return labels[v] - pc
    if v in REGS:
        return REGS[v]
    if v.startswith('0x') or v.startswith('0X'):
        return int(v, 16)
    return int(v)

def parse_abs_val(v, labels):
    v = v.strip()
    if v in labels:
        return labels[v]
    if v.startswith('0x') or v.startswith('0X'):
        return int(v, 16)
    return int(v)

def assemble(filename):
    with open(filename, 'r') as f:
        raw_lines = f.readlines()

    equs = {}
    cleaned_lines = []
    for raw_line in raw_lines:
        line = raw_line.split('#')[0].strip()
        if not line:
            continue
        if line.startswith('.'):
            if line.startswith('.equ'):
                parts = line.split()
                name = parts[1].strip(',')
                val = int(parts[2], 16) if '0x' in parts[2] else int(parts[2])
                equs[name] = val
                continue
            elif line.startswith('.word'):
                pass
            else:
                continue
        cleaned_lines.append(line)

    # First expand all pseudo-instructions to get exact instruction sequence
    expanded = []
    for line in cleaned_lines:
        label_prefix = ""
        if ':' in line:
            parts = line.split(':', 1)
            label_prefix = parts[0].strip() + ":"
            line = parts[1].strip()

        if not line:
            if label_prefix:
                expanded.append(label_prefix)
            continue

        tokens = [t.strip() for t in re.split(r'[\s,]+', line) if t.strip()]
        inst = tokens[0]

        if inst == 'ret':
            expanded.append(label_prefix + " jalr x0, ra, 0")
        elif inst == 'j':
            expanded.append(label_prefix + " jal x0, " + tokens[1])
        elif inst == 'bnez':
            expanded.append(label_prefix + " bne " + tokens[1] + ", x0, " + tokens[2])
        elif inst == 'li':
            # li handled in next pass once labels known
            expanded.append(label_prefix + " " + line)
        else:
            expanded.append(label_prefix + " " + line)

    # Pass 1: Measure exact PC for each line
    labels = {}
    pc = 0
    for line in expanded:
        line = line.strip()
        if ':' in line:
            parts = line.split(':', 1)
            label = parts[0].strip()
            labels[label] = pc
            line = parts[1].strip()
            if not line:
                continue

        tokens = [t.strip() for t in re.split(r'[\s,]+', line) if t.strip()]
        inst = tokens[0]
        if inst == 'li':
            val = equs.get(tokens[2], None)
            if val is None and tokens[2] in labels:
                val = labels[tokens[2]]
            if val is None:
                val = int(tokens[2], 16) if '0x' in tokens[2] else int(tokens[2])
            pc += 4 if (-2048 <= val <= 2047) else 8
        else:
            pc += 4

    # Pass 2: Final Statement List
    statements = []
    pc = 0
    for line in expanded:
        line = line.strip()
        if ':' in line:
            line = line.split(':', 1)[1].strip()
            if not line:
                continue

        tokens = [t.strip() for t in re.split(r'[\s,]+', line) if t.strip()]
        inst = tokens[0]

        if inst == 'li':
            reg = tokens[1]
            val = equs.get(tokens[2], None)
            if val is None and tokens[2] in labels:
                val = labels[tokens[2]]
            if val is None:
                val = int(tokens[2], 16) if '0x' in tokens[2] else int(tokens[2])
            if -2048 <= val <= 2047:
                statements.append(('addi', [reg, 'x0', str(val)], pc))
                pc += 4
            else:
                hi = (val + 0x800) >> 12
                lo = val - (hi << 12)
                statements.append(('lui', [reg, hex(hi)], pc))
                pc += 4
                if lo != 0:
                    statements.append(('addi', [reg, reg, str(lo)], pc))
                    pc += 4
        else:
            statements.append((inst, tokens[1:], pc))
            pc += 4

    # Pass 3: Encode Instructions
    words = {}
    for inst, args, pc in statements:
        if inst == '.word':
            val = parse_abs_val(args[0], labels)
            words[pc // 4] = val & 0xFFFFFFFF
            continue

        if inst == 'lui':
            rd = REGS[args[0]]
            imm = parse_abs_val(args[1], labels)
            code = ((imm & 0xFFFFF) << 12) | (rd << 7) | 0x37
        elif inst == 'addi':
            rd = REGS[args[0]]
            rs1 = REGS[args[1]]
            imm = parse_abs_val(args[2], labels) if args[2] in labels else parse_val(args[2], labels, pc)
            code = ((imm & 0xFFF) << 20) | (rs1 << 15) | (0 << 12) | (rd << 7) | 0x13
        elif inst == 'lw':
            rd = REGS[args[0]]
            m = re.match(r'(-?\w+)\((\w+)\)', args[1])
            offset = parse_abs_val(m.group(1), labels) if m.group(1) in labels else parse_val(m.group(1), labels, pc)
            rs1 = REGS[m.group(2)]
            code = ((offset & 0xFFF) << 20) | (rs1 << 15) | (2 << 12) | (rd << 7) | 0x03
        elif inst == 'sw':
            rs2 = REGS[args[0]]
            m = re.match(r'(-?\w+)\((\w+)\)', args[1])
            offset = parse_abs_val(m.group(1), labels) if m.group(1) in labels else parse_val(m.group(1), labels, pc)
            rs1 = REGS[m.group(2)]
            code = (((offset >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | ((offset & 0x1F) << 7) | 0x23
        elif inst == 'bne':
            rs1 = REGS[args[0]]
            rs2 = REGS[args[1]]
            offset = parse_val(args[2], labels, pc)
            imm12 = (offset >> 12) & 1
            imm10_5 = (offset >> 5) & 0x3F
            imm4_1 = (offset >> 1) & 0xF
            imm11 = (offset >> 11) & 1
            code = (imm12 << 31) | (imm10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (1 << 12) | (imm4_1 << 8) | (imm11 << 7) | 0x63
        elif inst == 'jal':
            rd = REGS[args[0]]
            offset = parse_val(args[1], labels, pc)
            imm20 = (offset >> 20) & 1
            imm10_1 = (offset >> 1) & 0x3FF
            imm11 = (offset >> 11) & 1
            imm19_12 = (offset >> 12) & 0xFF
            code = (imm20 << 31) | (imm10_1 << 21) | (imm11 << 20) | (imm19_12 << 12) | (rd << 7) | 0x6F
        elif inst == 'jalr':
            rd = REGS[args[0]]
            rs1 = REGS[args[1]]
            offset = parse_val(args[2], labels, pc)
            code = ((offset & 0xFFF) << 20) | (rs1 << 15) | (0 << 12) | (rd << 7) | 0x67
        else:
            raise ValueError(f"Unknown instruction: {inst} {args}")

        words[pc // 4] = code & 0xFFFFFFFF

    max_addr = max(words.keys()) if words else 0
    full_words = [words.get(i, 0) for i in range(max_addr + 1)]
    return full_words

if __name__ == '__main__':
    src = sys.argv[1]
    out = sys.argv[2]
    words = assemble(src)
    with open(out, 'w') as f:
        for w in words:
            f.write(f"{w:08x}\n")
    print(f"Assembled {len(words)} instructions/words into {out}")
