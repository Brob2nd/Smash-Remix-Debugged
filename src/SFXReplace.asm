// SFXReplace.asm
if !{defined __SFX_REPLACE__} {
define __SFX_REPLACE__()
print "included SFXReplace.asm\n"

scope SFXReplace {
    // Notes, not up to date with tables! Tables have more sounds
    // step: 69, 6A, 6B, 6C, 6D, 6E, 6F, 70, 71, 72, 73
    // run brake: 80
    // dash: 74, 75, 76, 77, 78, 79, 7C, 7D, 7E, 7F, 82
    // landing: 48, 49, 4A, 4B, 4C, 4D, 4E, 4F, 50, 51, 52, 5A
    // hard landing: 123, 124
    OS.align(4)
    STEP_SOUND_TABLE:
    dw 0x69
    dw 0x6A
    dw 0x6B
    dw 0x6C
    dw 0x6D
    dw 0x6E
    dw 0x6F
    dw 0x70
    dw 0x71
    dw 0x72
    dw 0x73
    dw 0x74
    dw 0x75
    dw 0x76
    dw 0x77
    dw 0x78
    dw 0x79
    dw 0x7C
    dw 0x7D
    dw 0x7E
    dw 0x7F
    dw 0x82
    dw 0x368 // Bowser footstep
    dw 0x0 // table end
    OS.align(4)
    LAND_SOUND_TABLE:
    dw 0x48
    dw 0x49
    dw 0x4A
    dw 0x4B
    dw 0x4C
    dw 0x4D
    dw 0x4E
    dw 0x4F
    dw 0x50
    dw 0x51
    dw 0x52
    dw 0x5A
    dw 0x0 // table end
    OS.align(4)
    HARDLAND_SOUND_TABLE:
    dw 0xC2
    dw 0x121
    dw 0x123
    dw 0x124
    dw 0x126
    dw 0x127
    dw 0x12B
    dw 0x0 // table end
    OS.align(4)

    constant snd_gaw_biip(0x602)
    constant snd_gaw_boop(0x603)
    constant snd_gaw_hardland(0x604)

    scope sfx_replace: {
        OS.patch_start(0x5B064, 0x800DF864)
        jal     sfx_replace
        nop
        OS.patch_end()

        // at = sound id
        lw      a0, 0(v1) // original line 1
        addiu   t7, v1, 4 // original line 2

        _check_if_in_match:
        li      t0, Global.current_screen   // ~
        lbu     t0, 0x0000(t0)              // t0 = current screen
        addiu   t1, r0, Global.screen.VS_BATTLE
        beq     t1, t0, _check_stage
        addiu   t1, r0, Global.screen.TRAINING_MODE
        beq     t1, t0, _check_stage
        addiu   t1, r0, Global.screen.REMIX_MODES
        beq     t1, t0, _check_stage
        nop

        b _return // not in a match, skip
        nop

        _check_stage:
        li      t0, Global.match_info       // ~
        lw      t0, 0x0000(t0)              // t0 = match_info
        lbu     t0, 0x0001(t0)              // t0 = current stage id

        lli     t1, Stages.id.FLAT_ZONE
        beq     t0, t1, _continue
        nop
        lli     t1, Stages.id.FLAT_ZONE_2
        beq     t0, t1, _continue
        nop

        b _return // not in the specified stages, skip
        nop

        // if here, we're going for SFX replacements
        _continue:
        andi    t2, a0, 0xFFFF                 // t2 = fgm_id

        // replace step sounds
        step_loop_prepare:
        li      t0, STEP_SOUND_TABLE
        step_loop:
        lw      t1, 0x0(t0) // load table element
        beqz    t1, step_loop_end // if element == 0, we reached the end of the table
        nop
        bne     t2, t1, step_loop_next // if sfx doesn't match the table element, skip
        nop
        // if here, sfx id matches
        lli     a0, snd_gaw_biip // biip
        b       _return // skip straight to the end
        nop
        step_loop_next:
        addiu   t0, 0x4 // go to next element
        nop
        b       step_loop
        nop
        step_loop_end:

        // replace land sounds
        land_loop_prepare:
        li      t0, LAND_SOUND_TABLE
        land_loop:
        lw      t1, 0x0(t0) // load table element
        beqz    t1, land_loop_end // if element == 0, we reached the end of the table
        nop
        bne     t2, t1, land_loop_next // if sfx doesn't match the table element, skip
        nop
        // if here, sfx id matches
        lli     a0, snd_gaw_boop // boop
        b       _return // skip straight to the end
        nop
        land_loop_next:
        addiu   t0, 0x4 // go to next element
        nop
        b       land_loop
        nop
        land_loop_end:

        // replace hardland sounds
        hardland_loop_prepare:
        li      t0, HARDLAND_SOUND_TABLE
        hardland_loop:
        lw      t1, 0x0(t0) // load table element
        beqz    t1, hardland_loop_end // if element == 0, we reached the end of the table
        nop
        bne     t2, t1, hardland_loop_next // if sfx doesn't match the table element, skip
        nop
        // if here, sfx id matches
        lli     a0, snd_gaw_hardland // hardland
        b       _return // skip straight to the end
        nop
        hardland_loop_next:
        addiu   t0, 0x4 // go to next element
        nop
        b       hardland_loop
        nop
        hardland_loop_end:

        _return:
        jr      ra
        nop
    }

    // note that here we're bringing the SFX function call to inside the patch!
    // 80144428 + 48
    scope sfx_replace_down_bounce: {
        OS.patch_start(0xBEEB0, 0x80144470)
        jal     sfx_replace_down_bounce
        nop
        OS.patch_end()

        // here we're following what's in Character.down_bound_fgm.table
        // because it already overwrites the code to load the FGM from a custom table
        constant LOWER(Character.down_bound_fgm.table & 0xFFFF) // modified as in Character.get_down_bound_fgm_
        lhu     a0, LOWER(a0) // original line 2 (modified)

        _check_stage:
        li      t0, Global.match_info       // ~
        lw      t0, 0x0000(t0)              // t0 = match_info
        lbu     t0, 0x0001(t0)              // t0 = current stage id

        lli     t1, Stages.id.FLAT_ZONE
        beq     t0, t1, _continue
        nop
        lli     t1, Stages.id.FLAT_ZONE_2
        beq     t0, t1, _continue
        nop

        b _end // not in the specified stages, skip
        nop

        // if here, we're going for SFX replacements
        _continue:
        lli     a0, snd_gaw_hardland // hardland

        _end:
        addiu   sp, sp, -0x20
        sw      ra, 0x4(sp)
        jal     0x800269C0 // original line 1: play sound (a0)
        nop
        lw      ra, 0x4(sp)
        addiu   sp, sp, 0x20

        jr      ra
        nop
    }
}

} // __SFX_REPLACE__
