#!/usr/bin/env python3
"""ARIA 9-bit assembler."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


ROM_SIZE = 1024
HALT = 0b111_010_000

ALU_OPS = {
    "ADD": 0x0, "ADDC": 0x1, "SUB": 0x2, "SUBB": 0x3,
    "AND": 0x4, "OR": 0x5, "XOR": 0x6, "CMP": 0x7,
    "LSL": 0x8, "LSR": 0x9, "ROL": 0xA, "ROR": 0xB,
    "NOT": 0xC, "NEG": 0xD, "CLR": 0xE, "GET": 0xF,
}
BR_OPS = {
    "BZ": 0, "BNZ": 1, "BN": 2, "BNN": 3,
    "BC": 4, "BNC": 5, "BRA": 6, "BNV": 7,
}
INV_BR = {
    "JZ": "BNZ", "JNZ": "BZ", "JN": "BNN", "JNN": "BN",
    "JC": "BNC", "JNC": "BC",
}
SPECIAL = {
    "PUT": 0, "JR": 1, "HALT": 2, "NOP": 3,
    "SET6": 4, "SET7": 5, "SETP": 6, "CLC": 7,
}


@dataclass
class SourceLine:
    lineno: int
    text: str


@dataclass
class Item:
    addr: int
    lineno: int
    text: str
    op: str
    args: list[str]
    index: int = 0
    encoded: int | None = None


class AsmError(Exception):
    pass


def strip_comment(line: str) -> str:
    return line.split(";", 1)[0].split("#", 1)[0].strip()


def split_args(s: str) -> list[str]:
    return [a.strip() for a in s.split(",") if a.strip()]


def parse_reg(s: str) -> int:
    m = re.fullmatch(r"[Rr]([0-7])", s.strip())
    if not m:
        raise AsmError(f"expected register R0..R7, got {s!r}")
    return int(m.group(1))


class Assembler:
    def __init__(self, lines: list[str]):
        self.src = [SourceLine(i + 1, line.rstrip("\n")) for i, line in enumerate(lines)]
        self.labels: dict[str, int] = {}
        self.equ: dict[str, int] = {}
        self.items: list[Item] = []

    def parse_int(self, token: str) -> int:
        token = token.strip()
        if not token:
            raise AsmError("empty expression")
        sign = 1
        if token[0] in "+-":
            sign = -1 if token[0] == "-" else 1
            token = token[1:]
        key = token.upper()
        if key in self.equ:
            return sign * self.equ[key]
        if key in self.labels:
            return sign * self.labels[key]
        try:
            return sign * int(token.replace("_", ""), 0)
        except ValueError as e:
            raise AsmError(f"unknown symbol or literal {token!r}") from e

    def first_pass(self) -> None:
        pc = 0
        for line in self.src:
            raw = strip_comment(line.text)
            if not raw:
                continue
            while ":" in raw:
                label, rest = raw.split(":", 1)
                label = label.strip().upper()
                if not re.fullmatch(r"[A-Z_.$][A-Z0-9_.$]*", label):
                    raise AsmError(f"{line.lineno}: bad label {label!r}")
                if label in self.labels:
                    raise AsmError(f"{line.lineno}: duplicate label {label}")
                self.labels[label] = pc
                raw = rest.strip()
                if not raw:
                    break
            if not raw:
                continue
            parts = raw.split(None, 1)
            op = parts[0].upper()
            args = split_args(parts[1] if len(parts) > 1 else "")
            if op == ".EQU":
                if len(args) != 2:
                    raise AsmError(f"{line.lineno}: .equ needs name, value")
                self.equ[args[0].upper()] = self.parse_int(args[1])
                continue
            if op == ".ORG":
                if len(args) != 1:
                    raise AsmError(f"{line.lineno}: .org needs address")
                pc = self.parse_int(args[0])
                if not 0 <= pc < ROM_SIZE:
                    raise AsmError(f"{line.lineno}: .org outside ROM")
                continue
            n = self.expand_size(op, args, line.lineno)
            if pc + n > ROM_SIZE:
                raise AsmError(f"{line.lineno}: program exceeds {ROM_SIZE} words")
            for i in range(n):
                self.items.append(Item(pc + i, line.lineno, raw, op, args, i))
            pc += n

    def expand_size(self, op: str, args: list[str], lineno: int) -> int:
        if op == "LI":
            if len(args) != 1:
                raise AsmError(f"{lineno}: LI needs value")
            return 3
        if op == "JMP":
            if len(args) != 2:
                raise AsmError(f"{lineno}: JMP needs label, register")
            return 6
        if op in INV_BR:
            if len(args) != 2:
                raise AsmError(f"{lineno}: {op} needs label, register")
            return 7
        return 1

    def emit_word(self, item: Item, op: str, args: list[str], addr: int) -> int:
        if op in ALU_OPS:
            if op in {"LSL", "LSR", "ROL", "ROR", "NOT", "NEG", "CLR"}:
                reg = parse_reg(args[0]) if args else 0
            else:
                if len(args) != 1:
                    raise AsmError(f"{item.lineno}: {op} needs register")
                reg = parse_reg(args[0])
            return (ALU_OPS[op] << 3) | reg
        if op in {"LD", "ST"}:
            if len(args) != 2:
                raise AsmError(f"{item.lineno}: {op} needs base register, offset")
            base = parse_reg(args[0])
            off = self.parse_int(args[1])
            if not 0 <= off <= 7:
                raise AsmError(f"{item.lineno}: memory offset must be 0..7")
            m = 1 if op == "LD" else 0
            return (0b01 << 7) | (m << 6) | (base << 3) | off
        if op in BR_OPS:
            if len(args) != 1:
                raise AsmError(f"{item.lineno}: {op} needs target/offset")
            target = self.parse_int(args[0])
            offset = target - (addr + 1) if args[0].strip().upper() in self.labels else target
            if not -8 <= offset <= 7:
                raise AsmError(f"{item.lineno}: branch offset {offset} outside -8..+7")
            return (0b10 << 7) | (BR_OPS[op] << 4) | (offset & 0xF)
        if op == "LDI":
            if len(args) != 1:
                raise AsmError(f"{item.lineno}: LDI needs value")
            val = self.parse_int(args[0])
            if not 0 <= val <= 63:
                raise AsmError(f"{item.lineno}: LDI immediate must be 0..63")
            return (0b110 << 6) | val
        if op in SPECIAL:
            reg = 0
            if op in {"PUT", "JR", "SETP"}:
                if len(args) != 1:
                    raise AsmError(f"{item.lineno}: {op} needs register/value")
                reg = self.parse_int(args[0]) if op == "SETP" and not args[0].upper().startswith("R") else parse_reg(args[0])
                if not 0 <= reg <= 7:
                    raise AsmError(f"{item.lineno}: special register/value must be 0..7")
            elif args:
                raise AsmError(f"{item.lineno}: {op} takes no operands")
            return (0b111 << 6) | (SPECIAL[op] << 3) | reg
        raise AsmError(f"{item.lineno}: unknown op {op}")

    def expanded_ops(self, item: Item) -> list[tuple[str, list[str]]]:
        op, args = item.op, item.args
        if op == "LI":
            val = self.parse_int(args[0])
            if not 0 <= val <= 255:
                raise AsmError(f"{item.lineno}: LI value must be 0..255")
            return [
                ("LDI", [str(val & 0x3F)]),
                ("SET6" if val & 0x40 else "NOP", []),
                ("SET7" if val & 0x80 else "NOP", []),
            ]
        if op == "JMP":
            target = self.parse_int(args[0])
            reg = args[1]
            if not 0 <= target < ROM_SIZE:
                raise AsmError(f"{item.lineno}: jump target outside ROM")
            return [
                ("LDI", [str(target & 0x3F)]),
                ("SET6" if target & 0x40 else "NOP", []),
                ("SET7" if target & 0x80 else "NOP", []),
                ("PUT", [reg]),
                ("SETP", [str((target >> 8) & 3)]),
                ("JR", [reg]),
            ]
        if op in INV_BR:
            return [(INV_BR[op], ["6"])] + self.expanded_ops(Item(item.addr + 1, item.lineno, item.text, "JMP", item.args))
        return [(op, args)]

    def assemble(self) -> list[int]:
        self.first_pass()
        rom = [HALT] * ROM_SIZE
        by_addr: dict[int, Item] = {}
        for item in self.items:
            by_addr.setdefault(item.addr, item)
        for addr in sorted(by_addr):
            item = by_addr[addr]
            exp = self.expanded_ops(item)
            idx = item.index
            if idx >= len(exp):
                continue
            op, args = exp[idx]
            rom[addr] = self.emit_word(item, op, args, addr)
            item.encoded = rom[addr]
        return rom

    def listing(self, rom: list[int]) -> str:
        item_by_addr = {item.addr: item for item in self.items}
        lines = []
        for addr in sorted(item_by_addr):
            item = item_by_addr[addr]
            lines.append(f"{addr:04d} {rom[addr]:09b}  {item.text}")
        return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("-o", "--output", required=True)
    ap.add_argument("--listing")
    ns = ap.parse_args(argv)
    asm = Assembler(Path(ns.source).read_text().splitlines())
    try:
        rom = asm.assemble()
    except AsmError as e:
        print(f"aria_asm: {e}", file=sys.stderr)
        return 1
    Path(ns.output).write_text("".join(f"{w:09b}\n" for w in rom))
    if ns.listing:
        Path(ns.listing).write_text(asm.listing(rom))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
