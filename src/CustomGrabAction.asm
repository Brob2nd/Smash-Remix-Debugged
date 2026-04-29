// CustomGrabAction.asm
if !{defined __CUSTOMGRABACTION__} {
define __CUSTOMGRABACTION__()
print "included CustomGrabAction.asm\n"

scope CustomGrabAction: {
    // @ Description
    // Change the action used when a caracter is being grabbed
    // rather than the usual CapturePulled action (0xAB)
    // Used by Wario, Mad Piano to set the ThrownDK action (character is on their back, struggling)
    scope capture_action_override_: {
        OS.patch_start(0xC534C, 0x8014A90C)
        j       capture_action_override_
        nop
        _return:
        OS.patch_end()

        // v0 = grabbing player struct
        lw      t0, 0x0008(v0)  // t0 = grabbing player character id

        sll     t0, t0, 2
        li      at, Character.custom_capture_action.table
        addu    t0, t0, at              // t0 = entry
        lw      at, 0x0000(t0)          // at = characters entry in table
        beqz    at, _end                // skip if no entry
        ori     a1, r0, Action.CapturePulled // original line 1 (original action)
        
        or     a1, r0, at // captured player action = entry in table

        _end:
        addiu   a2, r0, 0x0000              // original line 2
        j       _return                     // return
        nop
    }

    // @ Description
    // Attempts to fix the position of the grabbed character on frame 1 when using a custom
    // action for the grabbed opponent on our GrabPull action.
    // Not perfect, but a big improvement.
    scope capture_position_fix_: {
        OS.patch_start(0xC539C, 0x8014A95C)
        j       capture_position_fix_
        nop
        _return:
        OS.patch_end()

        lw      a0, 0x0044(sp)              // ~
        lw      a0, 0x0084(a0)              // v0 = grabbing player struct
        lw      a0, 0x0008(a0)              // a0 = grabbing player character id

        sll     t0, a0, 2
        li      at, Character.custom_capture_action.table
        addu    t0, t0, at              // t0 = entry
        lw      at, 0x0000(t0)          // at = characters entry in table
        bnez    at, _custom
        nop
        
        // vanilla if if no entry
        _no_override:
        jal     0x8014A6B4                  // original line 1
        or      a0, s1, r0                  // original line 2
        j       _return                     // return
        nop

        _custom:
        // Usually, 8014A6B4 is used to set the captured player's position on the first frame of
        // being grabbed, with 8014AB64 being used on subsequent frames.
        // If the grabbing character overrides the action for the grabbed opponent,
        // 8014AB64 will be used on the first frame instead.
        jal     0x8014AB64                  // modified original line 1
        or      a0, s1, r0                  // original line 2
        j       _return                     // return
        nop
    }

    // @ Description
    // Modifies the subroutine which handles mashing/breaking out of the ThrownDK action.
    scope capture_dk_break_fix_: {
        OS.patch_start(0xC8F14, 0x8014E4D4)
        j       capture_dk_break_fix_
        nop
        _return:
        OS.patch_end()

        lw      a2, 0x0084(a0)              // a2 = captured player struct
        lw      a2, 0x0844(a2)              // a2 = player.entity_captured_by
        lw      a2, 0x0084(a2)              // a2 = grabbing player struct
        lw      t7, 0x0008(a2)              // a2 = grabbing player character id

        sll     t0, t7, 2
        li      at, Character.custom_capture_dk_interrupt.table
        addu    t0, t0, at              // t0 = entry
        lw      at, 0x0000(t0)          // at = characters entry in table
        beqz    at, _vanilla            // default if no entry
        nop

        addiu sp, sp, -0x10 // allocate stack space
        sw ra, 0x4(sp) // save ra
        or v0, r0, r0
        jalr at // execute custom function
        nop
        lw ra, 0x4(sp) // restore ra
        addiu sp, sp, 0x10

        bnez    v0, _skip_function // if function returns 1 (not zero), skip the whole function
        nop
        
        _vanilla:
        addiu   sp, sp, 0xFFD8              // original line 1
        sw      ra, 0x0014(sp)              // original line 2
        j       _return                     // return (and continue subroutine)
        nop

        _skip_function:
        jr      ra                          // end subroutine
        nop
    }
}

} // __CUSTOMGRABACTION__
