REG = {'zero':0,
       'at':1,
       'v0':2,'v1':3,'a0':4,
       'a1':5,'a2':6,'a3':7,
       't0':8,'t1':9,'t2':10,'t3':11,'t4':12,'t5':13,'t6':14,'t7':15,
       's0':16,'s1':17,'s2':18,'s3':19,'s4':20,'s5':21,'s6':22,'s7':23,
       't8':24,'t9':25,
       'k0':26,'k1':27,
       'gp':28,
       'sp':29,
       'fp':30,
       'ra':31}

OPC = {'R':0x00, 'ADDI':0x08, 'SLTI':0x0A, 'ANDI':0x0C, 'ORI':0x0D, 'XORI':0x0E,
       'LW':0x23, 'SW':0x2B, 'BEQ':0x04, 'BNE':0x05, 'J':0x02, 'JAL':0x03, 'HLT':0x3F}

FUNCT = {
    'ADD': 0x20, 'SUB': 0x22, 'AND': 0x24, 'OR': 0x25, 
    'XOR': 0x26, 'NOR': 0x27, 'SLT': 0x2A, 'SLL': 0x00, 
    'SRL': 0x02, 'SRA': 0x03, 'ROL': 0x10, 'ROR': 0x11, 
    'JR': 0x08, 'NOT': 0x21, 'PASA': 0x23, 'INC': 0x12, 
    'DEC': 0x13, 'MUL': 0x18, 'DIV': 0x1A
}
# encoder ====================================================
def R(mnemonic, rd, rs, rt, shamt=0):
    opcode = OPC['R']
    funct = FUNCT[mnemonic]
    word = (opcode << 26) | (rs << 21) | (rt << 16) | (rd << 11) | (shamt << 6) | funct
    return word

def I(mnemonic, rt, rs, imm):
    opcode = OPC[mnemonic]
    word = (opcode << 26) | (rs << 21) | (rt << 16) | (imm & 0xFF)
    return word

def J(mnemonic, address):
    if address > 0xFF: #8
        raise ValueError(f"jump address {address} exceeds 8-bit range supported by this hardware")
    opcode = OPC[mnemonic]
    word = (opcode << 26) | (address & 0xFF)
    return word

def HLT():
    word = (OPC['HLT']<<26)
    return word

# clean line =======================
def clean_line(line):
    line = line.split("#")[0]
    line = line.split(";")[0]
    line = line.strip()
    if line == "":
        return None
    return line

# tokenize ========================
def tokenize(line):
    words = line.replace(",", " ").split()
    label = None
    if words[0].endswith(":"):
        label = words[0][:-1]
        words = words[1:]

    if len(words)==0:
        mnemonic = None
        operands = []

    else:
        mnemonic = words[0]
        operands = words[1:]

    return(label, mnemonic, operands)

# pass 1 ===============================
def first_pass(lines):
    address = 0
    symbol_table = {}

    for raw_line in lines:
        cleaned = clean_line(raw_line)
        if cleaned is None:
            continue
        label, mnemonic, operands = tokenize(cleaned)

        if label is not None:
            symbol_table[label] = address

        if mnemonic is not None:
            address = address + 1

    return symbol_table
def resolve_reg(token):
      return REG[token.lstrip('$')]
# passs 2 ==========================================
def second_pass(lines, symbol_table):
    address = 0
    words = []

    for raw_line in lines:
        cleaned = clean_line(raw_line)
        if cleaned is None:
            continue

        label, mnemonic, operands = tokenize(cleaned)
        if mnemonic is None:
            continue
        # R-type
        if mnemonic in FUNCT:
            if mnemonic == 'JR':
                rs = resolve_reg(operands[0])
                # rd, rt, and shamt default to 0
                word = R(mnemonic, 0, rs, 0)
                
            elif mnemonic in ['SLL', 'SRL', 'SRA', 'ROL', 'ROR']:
                rd = resolve_reg(operands[0])
                rt = resolve_reg(operands[1])
                shamt = int(operands[2])
                # rs is usually 0 for shifts
                word = R(mnemonic, rd, 0, rt, shamt)
                
            elif mnemonic in ['NOT', 'INC', 'DEC', 'PASA']:
                rd = resolve_reg(operands[0])
                rs = resolve_reg(operands[1])
                # rt defaults to 0
                word = R(mnemonic, rd, rs, 0)
                
            else:
                # Standard 3-register arithmetic (ADD, SUB, AND, etc.)
                rd = resolve_reg(operands[0])
                rs = resolve_reg(operands[1])
                rt = resolve_reg(operands[2])
                word = R(mnemonic, rd, rs, rt)
        # hlt
        elif mnemonic == 'HLT':
            word = HLT()
        # J type
        elif mnemonic in ('J', 'JAL'):
            target_label = operands[0]
            target_addr = symbol_table[target_label]
            word = J(mnemonic, target_addr)
        #branches
        elif mnemonic in ('BEQ', 'BNE'):
            rs = resolve_reg(operands[0])
            rt = resolve_reg(operands[1])
            target_label = operands[2]
            target_addr = symbol_table[target_label]
            offset = target_addr - (address + 1)
            word = I(mnemonic, rt, rs, offset & 0xFF)
        # I type
        elif mnemonic in OPC:
            rt = resolve_reg(operands[0])
            # Handle standard memory syntax: LW rt, imm(rs)
            if mnemonic in ['LW', 'SW'] and '(' in operands[1]:
                imm_str, rs_str = operands[1].split('(')
                imm = int(imm_str, 0)                  # Parse immediate (allows hex)
                rs = resolve_reg(rs_str.replace(')', '')) # Strip closing parenthesis
            # Handle standard I-Type syntax: ADDI rt, rs, imm
            else:
                rs = resolve_reg(operands[1])
                imm = int(operands[2], 0)              # Added 0 to allow hex (0xFF)
                
            word = I(mnemonic, rt, rs, imm)

        else:
            raise ValueError(f'Unknown mnemonic ; {mnemonic}')
        words.append(word)
        address += 1           
        
    return words     

if __name__ == "__main__":
    with open("factorial.asm", "r") as f:
        lines = f.readlines()
        
    symbol_table = first_pass(lines)
    machine_code = second_pass(lines, symbol_table)
    
    with open("instruction_memory.mem", "w") as f:
        for word in machine_code:
            # Format the integer as a 32-bit binary string
            f.write(format(word, '032b') + '\n')
            
    print("Compilation successful! Ready for Verilog simulation.")  


