// DKMode.asm
// Coded by HaloFactory
scope DKMode {

    // 1 = DK mode, 2 = Lanky mode
    dk_mode_enabled:
    dw 0

    constant HEAD_SIZE_MULTIPLIER(0x3FC0)
    constant LANKY_SIZE_MULTIPLIER(0x3F00)
    constant ARM_SIZE_MULTIPLIER(0x3FC0)

    // render player object 0x800F293C
    // todo: find a better hook location and have it work with animation scaling

    scope _resize_head: {
        OS.patch_start(0x6E16C, 0x800F296C)
        j       _resize_head
        nop
        _return:
        OS.patch_end()
        // s8 (fp) = player struct
        // safe registers... s3, s6, t6, t7, t8, t9, at

        OS.read_word(dk_mode_enabled, t6)
        beqz    t6, _normal             // branch if DK Mode disabled
        lui     at, HEAD_SIZE_MULTIPLIER // at = float
        addiu   t7, r0, 2           // t7 = 2
        beql    t7, t6, _dk_mode_on
        lui     at, LANKY_SIZE_MULTIPLIER // at = float
        _dk_mode_on:
        li      t7, Character.fighter_DK_mode.table
        lw      t6, 0x0008(s8)      // t6 = character id
        addiu   s3, r0, Character.id.SANDBAG // s3 = Sandbag
        beq     t6, s3, _normal     // skip if Sandbag
        sll     t6, t6, 2           // t6 = offset in table
        addu    s3, t7, t6          // s3 = entry in table
        lw      t6, 0x0000(s3)
        beqzl   t6, _loop_initial
        addiu   s3, t7, 0          // if nothing is present, use marios table entry

        _loop_initial:
        addiu   t8, s8, 0x08F8      // t8 = first bone in array
        addiu   t9, r0, 0           // t9 = loop count

        _loop_start:
        lb      t6, 0x0000(s3)      // t6 = bone index
        beqz    t6, _loop_exit      // exit loop if bone index = 0
        sll     t6, t6, 2           // t6 = offset to entry
        addu    t7, t8, t6          // t7 = address of bone
        lw      t6, 0x0000(t7)      // t6 = player head
        sw      at, 0x0040(t6)      // overwrite x scale
        sw      at, 0x0044(t6)      // ~ y scale
        sw      at, 0x0048(t6)      // ~ z scale
        lui     at, ARM_SIZE_MULTIPLIER // at = float

        _loop_increment:
        b       _loop_start
        addiu   s3, s3, 1        // s3 += 1

        _loop_exit:

        _normal:
        lui     s3, 0x8013          // og line 1
        j       _return
        addiu   s3, s3, 0x12F0      // og line 2
    }

    // manually set DK mode for specific characters
    // CHARACTERS DON'T NEED THIS DONE IF THEY HAVE A GENERIC RIG
    // joint 1 = head
    // joint 2 = left arm
    // joint 3 = right arm

    // pika based
    Character.table_patch_start(fighter_DK_mode, Character.id.JPIKA, 0x4)
    db 0x7, 0x5, 0xD, 0x0;   OS.patch_end();   // copy of pika
    Character.table_patch_start(fighter_DK_mode, Character.id.EPIKA, 0x4)
    db 0x7, 0x5, 0xD, 0x0;   OS.patch_end();   // copy of pika
    // kirby/puff based
    Character.table_patch_start(fighter_DK_mode, Character.id.JKIRBY, 0x4)
    db 0x2, 0x6, 0xB, 0x0;   OS.patch_end();   // copy of kirby
    Character.table_patch_start(fighter_DK_mode, Character.id.JPUFF, 0x4)
    db 0x2, 0x6, 0xA, 0x0;   OS.patch_end();   // copy of puff
    Character.table_patch_start(fighter_DK_mode, Character.id.EPUFF, 0x4)
    db 0x2, 0x6, 0xA, 0x0;   OS.patch_end();   // copy of puff
    // yoshi based
    Character.table_patch_start(fighter_DK_mode, Character.id.JYOSHI, 0x4)
    db 0x3, 0x7, 0xB, 0x0;   OS.patch_end();   // copy of yoshi
    Character.table_patch_start(fighter_DK_mode, Character.id.BOWSER, 0x4)
    db 0x3, 0x7, 0xB, 0x0;   OS.patch_end();   // copy of yoshi
    Character.table_patch_start(fighter_DK_mode, Character.id.GBOWSER, 0x4)
    db 0x3, 0x7, 0xB, 0x0;   OS.patch_end();   // copy of yoshi
    Character.table_patch_start(fighter_DK_mode, Character.id.NBOWSER, 0x4)
    db 0x3, 0x7, 0xB, 0x0;   OS.patch_end();   // copy of yoshi
    // samus based
    Character.table_patch_start(fighter_DK_mode, Character.id.DSAMUS, 0x4)
    db 0x9, 0x4, 0xB, 0x0;   OS.patch_end();   // copy of Samus
    Character.table_patch_start(fighter_DK_mode, Character.id.NDSAMUS, 0x4)
    db 0x9, 0x4, 0xB, 0x0;   OS.patch_end();   // copy of Samus
    Character.table_patch_start(fighter_DK_mode, Character.id.ESAMUS, 0x4)
    db 0x9, 0x4, 0xB, 0x0;   OS.patch_end();   // copy of Samus
    Character.table_patch_start(fighter_DK_mode, Character.id.JSAMUS, 0x4)
    db 0x9, 0x4, 0xB, 0x0;   OS.patch_end();   // copy of Samus
    // link based
    Character.table_patch_start(fighter_DK_mode, Character.id.ELINK, 0x4)
    db 0x12, 0x4, 0x9, 0x0;   OS.patch_end();   // copy of Link
    Character.table_patch_start(fighter_DK_mode, Character.id.JLINK, 0x4)
    db 0x12, 0x4, 0x9, 0x0;   OS.patch_end();   // copy of Link
    Character.table_patch_start(fighter_DK_mode, Character.id.YLINK, 0x4)
    db 0x12, 0x4, 0x9, 0x0;   OS.patch_end();   // copy of Link
    Character.table_patch_start(fighter_DK_mode, Character.id.NYLINK, 0x4)
    db 0x12, 0x4, 0x9, 0x0;   OS.patch_end();   // copy of Link
    // mewtwo
    Character.table_patch_start(fighter_DK_mode, Character.id.MTWO, 0x4)
    db 0x7, 0x4, 0xC, 0x0;   OS.patch_end();   // copy of yoshi
    Character.table_patch_start(fighter_DK_mode, Character.id.NMTWO, 0x4)
    db 0x7, 0x4, 0xC, 0x0;   OS.patch_end();   // copy of yoshi
    // marina
    Character.table_patch_start(fighter_DK_mode, Character.id.MARINA, 0x4)
    db 0x8, 0x4, 0xB, 0x0;   OS.patch_end();   // Marina
    Character.table_patch_start(fighter_DK_mode, Character.id.NMARINA, 0x4)
    db 0x8, 0x4, 0xB, 0x0;   OS.patch_end();   // NMarina
    // marth based
    Character.table_patch_start(fighter_DK_mode, Character.id.MARTH, 0x4)
    db 0x8, 0x4, 0xB, 0x0;   OS.patch_end();   // Marth
    Character.table_patch_start(fighter_DK_mode, Character.id.NMARTH, 0x4)
    db 0x8, 0x4, 0xB, 0x0;   OS.patch_end();   // NMarth
     Character.table_patch_start(fighter_DK_mode, Character.id.ROY, 0x4)
    db 0x8, 0x4, 0xB, 0x0;   OS.patch_end();   // Roy
    // piano
    Character.table_patch_start(fighter_DK_mode, Character.id.PIANO, 0x4)
    db 0x8, 0x4, 0xA, 0x0;   OS.patch_end();   // Piano
    // ddd
    Character.table_patch_start(fighter_DK_mode, Character.id.DEDEDE, 0x4)
    db 0x8, 0x4, 0xB, 0x0;   OS.patch_end();   // DDD
    Character.table_patch_start(fighter_DK_mode, Character.id.NDEDEDE, 0x4)
    db 0x8, 0x4, 0xB, 0x0;   OS.patch_end();   // NDDD
    // peach
    Character.table_patch_start(fighter_DK_mode, Character.id.PEACH, 0x4)
    db 0x8, 0x4, 0xB, 0x0;   OS.patch_end();   // Peach
    Character.table_patch_start(fighter_DK_mode, Character.id.NPEACH, 0x4)
    db 0x8, 0x4, 0xB, 0x0;   OS.patch_end();   // NPeach
    // crash
    Character.table_patch_start(fighter_DK_mode, Character.id.CRASH, 0x4)
    db 0x7, 0x4, 0xE, 0x0;   OS.patch_end();   // Crash
    // Character.table_patch_start(fighter_DK_mode, Character.id.NCRASH, 0x4)
    // db 0x7, 0x4, 0xE, 0x0;   OS.patch_end();   // NCrash
    // lanky
    Character.table_patch_start(fighter_DK_mode, Character.id.LANKY, 0x4)
    db 0x7, 0x4, 0xB, 0x0;   OS.patch_end();   // Lanky

    // Required Easter egg to activate (via 12cb portraits)
    scope _check_portraits: {
        // check for 'DK' or 'LK' in the id tables
        li      t3, TwelveCharBattle.id_table_p2
        li      t2, dk_mode_table_K
        jal     _table_read                 // check p2 table for 'K'
        nop
        beqzl   t4, _set_toggle             // t4 = 0 if incorrect pattern
        lli     t2, 0                       // t2 = 0 (OFF)
        li      t3, TwelveCharBattle.id_table_p1
        li      t2, dk_mode_table_D
        jal     _table_read                 // check p1 table for 'D'
        nop
        bnezl   t4, _set_toggle             // t4 = 1 if correct pattern
        lli     t2, 1                       // t2 = 1 (DK Mode)
        li      t3, TwelveCharBattle.id_table_p1
        li      t2, dk_mode_table_L
        jal     _table_read                 // alt check p1 table for 'L'
        nop
        bnezl   t4, _set_toggle             // t4 = 1 if correct pattern
        lli     t2, 2                       // t2 = 2 (Lanky Mode)
        lli     t2, 0                       // t2 = 0 (OFF)

        _set_toggle:
        li      t4, dk_mode_enabled
        sw      t2, 0x0000(t4)
        j       TwelveCharBattle.update_portrait_id_table_._DKMode_return
        nop

        _table_read:
        // t3 = id_table, t2 = letter table
        // note: all successive portraits will reference slot 1
        lbu     a0, 0x0000(t3)              // a0 = character_id slot 1
        lw      t2, 0x0000(t2)              // t2 = letter bitmask indicating which slots we should match
        or      at, r0, r0                  // clear at (loop index)
        _table_read_loop:
        lbu     a1, 0x0000(t3)              // a1 = character_id in checked slot
        sltiu   t4, at, 24                  // t4 = 0 if end of loop (NUM_SLOTS)
        beqzl   t4, _end                    // loop until all checked
        lli     t4, OS.TRUE                 // t4 = true (correct pattern)
        addiu   t3, t3, 0x0001              // id_table++
        addiu   at, at, 0x0001              // at++ (increment loop index)
        xor     a1, a1, a0                  // a1 = 0 if matched character_id, nonzero if different
        sltu    a1, r0, a1                  // a1 = matched? (0 or 1)
        andi    t4, t2, 1                   // isolate bitmask bit (0 = match, 1 = don't match)
        bnel    t4, a1, _end                // branch if incorrect
        lli     t4, OS.FALSE                // t4 = false (incorrect pattern)
        b       _table_read_loop            // continue loop
        srl     t2, t2, 1                   // next bitmask bit

        _end:
        jr      ra                          // return t4
        nop

        // Letter Patterns to Match (right to left)
        dk_mode_table_K:
        dw 0b101010101100110010101010
        dk_mode_table_D:
        dw 0b110011001010101011001100
        dk_mode_table_L:
        dw 0b100010001110111011101110
    }
}