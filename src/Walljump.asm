// Walljump.asm (code by Fray, modified by goom)
if !{defined __WALLJUMP__} {
define __WALLJUMP__()
print "included Walljump.asm\n"

// walljump.asm
// wall collision byte offset = 0xCF, 01 = left wall, 20 = right wall

// 801402FC = load current jumps byte
// 8013FDC4 = change action
// 8013FEBC = update x momentum
// 8013FED4 = update current jumps byte

// @ Description
// Jump off walls and stuff
// Note: currently you can walljump facing AWAY from wall as well (probably fine?)
scope Walljump {

    // @ Description
    // check wall hook
    scope checkwall: {
        // // // // // OS.patch_start(0xBAD40, 0x80140300)
        // // // // // j       checkwall
        // // // // // nop
        checkwall_return:
        // // // // // OS.patch_end()
        // struct in a0, a2

        lw      t2, 0x0064(t1)              // original line 1
        slt     at, t0, t2                  // original line 2

        addiu   sp, sp,-0x0010              // store t0, t1 and t2
        sw      t0, 0x0004(sp)
        sw      t1, 0x0008(sp)
        sw      t2, 0x000C(sp)
        lhu     t0, 0x0026(a0)              // load current action value
        ori     t1, r0, 0x003A              // load special fall value
        beq     t0, t1, end                 // if character is in special fall, skip
        nop
        // // Kirby and Yoshi crash the game
        // also Ness, Lucas, Mewtwo, Peach
        // Jiggs and DDD don't crash but nothing happens
        // Marina works, surpringly
        // TODO this will need to be tweaked and handled cleaner
        // // lbu     t0, 0x000B(a0)              // load character id
        // // ori     t1, r0, 0x0006              // load yoshi's id
        // // beq     t0, t1, end                 // if character is yoshi, skip
        // // nop
        // // sltiu   t0, t0, 0x000A              // flag 1 if character id < A
        // // beqz    t0, end                     // if character id < A, skip
        // // nop
        lbu     t0, 0x00CF(a0)              // load wall collision byte
        ori     t1, r0, 0x0001              // load left wall value
        and     t2, t0, t1                  // branch logic
        beq     t2, t1, continue
        nop
        ori     t1, r0, 0x0020              // load right wall value
        and     t2, t0, t1                  // branch logic
        beq     t0, t1, continue
        nop
        b       end                         // if wall collision is not detected, skip
        nop

        continue:
        li      t0, walljumpstruct          // load struct pointer
        lbu     t2, 0x000D(a0)              // load player port
        addu    t0, t0, t2                  // add player port to struct pointer
        sb      t1, 0x0000(t0)              // store walljump value
        ori     at, r0, 0x0001              // overwrite at (used to determine whether or not the player has a jump)

        end:
        lw      t0, 0x0004(sp)              // load t0, t1, and t2
        lw      t1, 0x0008(sp)
        lw      t2, 0x000C(sp)
        addiu   sp, sp, 0x0010
        j       checkwall_return            // end
        nop

    }

    // @ Description
    // walljump action hook
    scope walljumpaction: {
        // // // // // OS.patch_start(0xBA804, 0x8013FDC4)
        // // // // // j       walljumpaction
        // // // // // nop
        walljumpaction_return:
        // // // // // OS.patch_end()

        // struct in s0, action in a1

        addiu   sp, sp,-0x0010              // store t0, t1 and t2
        sw      t0, 0x0004(sp)
        sw      t1, 0x0008(sp)
        sw      t2, 0x000C(sp)
        li      t0, walljumpstruct          // load struct pointer
        lbu     t1, 0x000D(s0)              // load player port
        addu    t1, t0, t1                  // add player port to struct pointer
        lbu     t0, 0x0000(t1)              // load wj value
        beqz    t0, end                     // if wj value = 0, skip
        nop
        ori     a1, r0, 0x0016              // change action value to 16 (ground forward jump)
        li      t1, 0xFFFFFFFF              // load left facing direction
        sw      t1, 0x0044(s0)              // store left facing direction
        ori     t1, r0, 0x0001              // load left wall value
        beq     t0, t1, end                 // if wj value = 01 (left wall), end
        nop
        ori     t1, r0, 0x0001              // load right facing direction
        sw      t1, 0x0044(s0)              // store right facing direction

        end:
        lw      t0, 0x0004(sp)              // load t0, t1, and t2
        lw      t1, 0x0008(sp)
        lw      t2, 0x000C(sp)
        addiu   sp, sp, 0x0010
        jal     0x800E6F24                  // original line 1
        sw      t0, 0x0028(sp)              // original line 2
        j       walljumpaction_return       // end
        nop

    }

    // @ Description
    // walljump momentum hook
    scope wj_momentum: {
        // // // // // OS.patch_start(0xBA900, 0x8013FEC0)
        // // // // // j       wj_momentum
        // // // // // nop
        wj_momentum_return:
        // // // // // OS.patch_end()

        //struct in s0, x momentum offset = 0x0048, y = 0x004C

        lbu     t4, 0x0148(s0)              // original line 1
        lbu     t8, 0x0192(s0)              // original line 2
        addiu   sp, sp,-0x0014              // store t0, t1, t2, t3
        sw      t0, 0x0004(sp)
        sw      t1, 0x0008(sp)
        sw      t2, 0x000C(sp)
        sw      t3, 0x0010(sp)
        li      t0, walljumpstruct          // load struct pointer
        lbu     t1, 0x000D(s0)              // load player port
        addu    t1, t0, t1                  // add player port to struct pointer
        lbu     t3, 0x0000(t1)              // load wj value
        beqz    t3, end                     // if wj value = 0, skip
        nop
        addiu   t0, t0, 0x0004              // offset struct pointer to table
        lbu     t2, 0x000B(s0)              // load character id
        // can force Mario ID (for testing) X,Y momentum will always be his
        // // addiu   t2, r0, 0
        sll     t1, t2, 0x3                 // get table offset
        addu    t0, t0, t1                  // add offset to pointer

        lw      t1, 0x0000(t0)              // load x momentum value
        ori     t2, r0, 0x0020              // load right wall value
        beq     t2, t3, continue            // if wj value = 20 (right wall), branch
        nop
        lui     t2, 0x8000                  // negative float conversion logic
        or      t1, t1, t2

        continue:
        sw      t1, 0x0048(s0)              // store x momentum value
        lw      t1, 0x0004(t0)              // load y momentum value
        sw      t1, 0x004C(s0)              // store y momentum value

        end:
        lw      t0, 0x0004(sp)              // load t0, t1, t2, t3
        lw      t1, 0x0008(sp)
        lw      t2, 0x000C(sp)
        lw      t3, 0x0010(sp)
        addiu   sp, sp, 0x0014
        j       wj_momentum_return          // end
        nop

    }

    // @ Description
    // walljump flag hook
    scope wj_jumpflag: {
        // // // // // OS.patch_start(0xBA910, 0x8013FED0)
        // // // // // j       wj_jumpflag
        // // // // // nop
        wj_jumpflag_return:
        // // // // // OS.patch_end()

        ori     t9, t8, 0x0080              // original line 1
        addiu   sp, sp,-0x000C              // store t0 and t1
        sw      t0, 0x0004(sp)
        sw      t1, 0x0008(sp)
        li      t0, walljumpstruct          // load struct pointer
        lbu     t1, 0x000D(s0)              // load player port
        addu    t1, t0, t1                  // add player port to struct pointer
        lbu     t0, 0x0000(t1)              // load wj value
        bnez    t0, end                     // if wj value =/= 0, skip
        nop
        sb      t5, 0x0148(s0)              // update jump value

        end:
        sb      r0, 0x0000(t1)              // overwrite walljump value with 0
        lw      t0, 0x0004(sp)              // load t0 and t1
        lw      t1, 0x0008(sp)
        addiu   sp, sp, 0x000C
        j       wj_jumpflag_return
        nop

    }


    walljumpstruct:
    dw  0x00000000                          // p1, p2, p3, p4 walljump value

    //table of walljump values; X,Y
    dw  0x420C0000                          // mario
    dw  0x42960000
    dw  0x42300000                          // fox
    dw  0x42D20000
    dw  0x42180000                          // dk
    dw  0x42A00000
    dw  0x42400000                          // samus
    dw  0x42780000
    dw  0x41F00000                          // luigi
    dw  0x429C0000
    dw  0x42200000                          // link
    dw  0x42960000
    dw  0x00000000                          // yoshi (ignore)
    dw  0x00000000                          // needs values if we get him working
    dw  0x42300000                          // falcon
    dw  0x42A40000
    dw  0x00000000                          // kirby (ignore)
    dw  0x00000000
    dw  0x42480000                          // rat
    dw  0x428C0000
}
} // __WALLJUMP__
