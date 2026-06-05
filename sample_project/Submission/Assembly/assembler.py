import re
import sys

opcodes = {
	'ADD' : '0001',
	'ADDI' : '0000',
	'SUB' : '0011',
	'SUBI' : '0010',
	'CPY' : '0100',
	'CPYS' : '0101',
	'AND' : '0111',
	'ANDI' : '0110',
	'OR' : '1001',
	'ORI' : '1000',
	'XOR' : '1011',
	'XORI' : '1010',
	'CMP' : '1100',
	'CMPR' : '1101',
	'LDM' : '1110',
	'STM' : '1111',

	'BR' : '00',
	'BRF' : '01',
	'B' : '10',
	'EXIT' : '11',

	'SSL' : '0000',
	'SSLC' : '0001',
	'SSR' : '0010',
	'SSRC' : '0011',
	'HSL' : '0100',
	'HSR' : '0101',
	'INC' : '0110',
	'DEC' : '0111',
	'SPC' : '1000',
	'CLR' : '1010',
	'XORB' : '1011',
	'PRME' : '1100',
	'PRMO' : '1101',
	'NOP' : '1111',

	'LDI' : ''
}

conditions = {
	'' : '000',
	'AL' : '000',
	'EQ' : '001',
	'NE' : '010',
	'GT' : '011',
	'LT' : '100',
	'GTE' : '101',
	'LTE' : '110',
	'Z' : '111'
}

R_type = ['ADD', 'ADDI', 'SUB', 'SUBI', 'CPY', 'CPYS', 'AND', 'ANDI', 'OR', 'ORI', 'XOR', 'XORI', 'CMP', 'CMPR', 'LDM', 'STM']
D_type = ['SSL', 'SSLC', 'SSR', 'SSRC', 'HSL', 'HSR', 'INC', 'DEC', 'SPC', 'CLR', 'XORB', 'PRME', 'PRMO', 'NOP']
I_type = ['LDI']
no_input = ['NOP', 'CMPR', 'EXIT']

registers = {
	'R0' : '00',
	'R1' : '00',
	'R2' : '01',
	'R3' : '01',
	'R4' : '10',
	'R5' : '10',
	'R6' : '11',
	'R7' : '11',
}

pairs = {
	'P0' : '00',
	'P1' : '01',
	'P2' : '10',
	'P3' : '11'
}


def decode_register(reg):
	reg = reg.strip()
	if reg in registers:
		return registers[reg]
	elif reg in pairs:
		return pairs[reg]
	else:
		return ''

def convert(inFile, outFile):
	assembly_file = open(inFile + ".txt", 'r')
	machine_file = open(outFile + ".txt", 'w')
	annotated_file = open(outFile + "_annotated.txt", 'w')
	assembly = list(assembly_file.read().split('\n'))
	
	#reads through file to convert instructions to machine code
	for line in assembly:
		if line.strip().startswith('#') or not line.strip():
			continue

		output = ""
		instr = line.split('#')[0].upper().split(' ', 1)
		opcode = instr[0]

		if len(instr) != 2 and opcode not in no_input:
			print("Invalid assembly: " + line)
			break

		# FORMAT: 0_opcode_reg_reg
		if opcode in R_type:
			output += '0'
			output += opcodes[opcode]

			if opcode in no_input:
				output += '0000'
			else:

				# decode registers
				regs = instr[1].split(',')
				reg2 = ''
				reg1 = ''
				if len(regs) == 1: # pair format
					reg2 = decode_register(regs[0])
					reg1 = reg2
				elif len(regs) == 2:
					reg2 = decode_register(regs[0])
					reg1 = decode_register(regs[1])

				if reg1 == '' or reg2 == '':
					print("Invalid register input: " + line)
					break
				
				output += reg2
				output += reg1

		# FORMAT: 110_opcode_reg
		elif opcode in D_type:
			output += '110'
			output += opcodes[opcode]

			if opcode in no_input:
				output += '00'
			else:

				# decode register
				reg = decode_register(instr[1])
				if reg == '':
					print("Invalid register input: " + line)
					break
				
				output += reg

		# FORMAT: 111_imm_reg
		elif opcode in I_type:
			output += '111'

			inputs = instr[1].split(',')
			if len(inputs) != 2:
				print("Invalid immediate instruction: " + line)
				break

			# decode immediate (binary only)
			if not re.match(r'%[01]{4}', inputs[0]):
				print("Invalid immediate expression: " + line)
				break

			output += inputs[0][1:]

			# decode register
			reg = decode_register(inputs[1])
			if reg == '':
				print("Invalid register input: " + line)
				break

			output += reg

		# branches
		elif opcode.startswith('B'):
			output += '10'
			cond = ''
			if opcode.startswith('BRF'):
				output += '01'
				cond = opcode[3:]
			elif opcode.startswith('BR'):
				output += '00'
				cond = opcode[2:]
			else:
				output += '10'
				cond = opcode[1:]

			# decode cond
			if cond not in conditions:
				print("Invalid branch condition: " + line)
				break

			output += conditions[cond]

			# decode register
			reg = decode_register(instr[1])
			if reg == '':
				print("Invalid register input: " + line)
				break

			output += reg

		elif opcode == 'EXIT':
			output += '101100000'
		
		else:
			print("Unknown instruction: " + line)
			break

		machine_file.write(str(output) + '\n')
		annotated_file.write(str(output) + '\t// ' + line + '\n')


	assembly_file.close()
	machine_file.close()

if len(sys.argv) < 2:
	print("Missing file name argument!")
	exit

convert(sys.argv[1], sys.argv[1] + "_mach")