.macro PUSH reg
subi sp, sp, 4
stw \reg, 0(sp)
.endm

.macro POP_VAL reg
ldw \reg, 0(sp)
addi sp, sp, 4
.endm

.macro POP
addi sp, sp, 4
.endm