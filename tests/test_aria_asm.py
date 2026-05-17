import unittest

from software.aria_asm import Assembler, AsmError


class AriaAsmTest(unittest.TestCase):
    def assemble(self, text):
        return Assembler(text.strip().splitlines()).assemble()

    def test_real_instructions(self):
        rom = self.assemble(
            """
            ADD R2
            ADDC R5
            SUB R3
            SUBB R4
            AND R1
            OR R1
            XOR R5
            CMP R6
            LSL
            LSR
            ROL
            ROR
            NOT
            NEG
            CLR
            GET R3
            LD R3, 1
            ST R6, 4
            BZ 3
            BNZ -4
            BN -2
            BNN 2
            BC 1
            BNC 1
            BRA -7
            BNV 0
            LDI 37
            PUT R4
            JR R5
            HALT
            NOP
            SET6
            SET7
            SETP 2
            CLC
            """
        )
        self.assertEqual(rom[0], int("000000010", 2))
        self.assertEqual(rom[16], int("011011001", 2))
        self.assertEqual(rom[17], int("010110100", 2))
        self.assertEqual(rom[18], int("100000011", 2))
        self.assertEqual(rom[26], int("110100101", 2))
        self.assertEqual(rom[29], int("111010000", 2))
        self.assertEqual(rom[33], int("111110010", 2))

    def test_labels_and_pseudos(self):
        rom = self.assemble(
            """
            .equ one, 1
            start:
              LI 193
              PUT R1
              JZ done, R2
              BRA 0
            done:
              HALT
            """
        )
        self.assertEqual(rom[0], int("110000001", 2))
        self.assertEqual(rom[1], int("111100000", 2))
        self.assertEqual(rom[2], int("111101000", 2))
        self.assertEqual(rom[4], int("100010110", 2))  # inverse BNZ +6
        self.assertEqual(rom[11], int("101100000", 2))  # BRA +0

    def test_org_equ_listing_and_rom_length(self):
        asm = Assembler(
            """
            .equ base, 12
            .org 4
            start: LDI base
            NOP
            """.strip().splitlines()
        )
        rom = asm.assemble()
        self.assertEqual(len(rom), 1024)
        self.assertEqual(rom[0], int("111010000", 2))
        self.assertEqual(rom[4], int("110001100", 2))
        self.assertEqual(rom[5], int("111011000", 2))
        listing = asm.listing(rom)
        self.assertIn("0004 110001100", listing)
        self.assertIn("0005 111011000", listing)

    def test_expected_failures(self):
        for src in [
            "LDI 64",
            "LD R1, 8",
            "BZ 8",
            ".org 1024",
            "PUT R8",
            "missing: HALT\nmissing: NOP",
            "JMP 1024, R1",
        ]:
            with self.subTest(src=src):
                with self.assertRaises(AsmError):
                    self.assemble(src)


if __name__ == "__main__":
    unittest.main()
