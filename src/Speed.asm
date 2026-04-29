// Speed.asm (code by goombapatrol)
if !{defined __SPEED__} {
define __SPEED__()
print "included Speed.asm\n"

// @ Description
constant advance_frame(0x8000A5E4)

scope Speed {
    // @ Description
    // Runs various functions
    // t9 = function to run
    scope process_update_: {
        OS.patch_start(0xB118, 0x8000A518)
        j       process_update_
        nop
        nop
        nop
        _return:
        OS.patch_end()

        sw      a3, 0x0020(sp)  // original line 1
        lw      t9, 0x001C(a3)  // original line 2
        nop

        jal     Item.Stopwatch.check_function_
        nop                     // returns t3 (0 = normal, 1 = skip, 2 = run twice)

        addiu   t9, r0, 1       // t9 = 1 (skip)
        beq     t3, t9, _end    // if t3 = 1, skip running the update function
        lw      t9, 0x001C(a3)  // original line 2 (restore t9)
        beqz    t3, _update     // if t3 = 0, run the update function
        nop

        // if we're here, t3 = 2 and we need to run function twice for speedup
        // note: certain fast functions run the extra update within Stopwatch.asm, and not here
        // so this isn't being used currently (commented out for safety)
        _additional_update:
        // OS.save_registers()
        // jalr    ra, t9          // original line 3 (call update function)
        // nop
        // OS.restore_registers()

        _update:
        jalr    ra, t9          // original line 3 (call update function)
        nop                     // original line 4

        _end:
        j       _return         // return
        nop
    }

    // @ Description
    // Handles 'Game Speed' toggle and speed-related Items
    // note: not written to be compatible with Training (it already has advance_frame_ and speed control)
    // t6 t7 t8 and 'at' are safe
    scope handle_rate_: {
        OS.patch_start(0x8FA7C, 0x8011427C)
        j       handle_rate_
        nop
        _return:
        OS.patch_end()

        // check if any Stopwatch items are affecting Game Engine Speed
        li      t6, Item.Stopwatch.watch_speed_flag
        lb      t6, 0x0000(t6)              // t6 != 0 if active
        bnez    t6, _handle_2x_3x           // if Stopwatch active, we skip checking the Toggle (overrides)
        nop

        _check_game_speed_toggle:
        li      t6, Toggles.entry_game_speed
        lw      t6, 0x0004(t6)              // t6 = entry_game_speed (0 if DEFAULT 1/1; ranges from 1/8 to 3x)
        beqz    t6, _frame_advance          // if Speed is default, proceed normally
        nop

        _handle_2x_3x:
        // 2x and 3x speeds don't need a timer check (or table read)
        addiu   t7, r0, 5                           // t7 = 5 (2.0x speed)
        beq     t6, t7, _additional_frame_advance   // branch if 2x speed
        addiu   t7, r0, 6                           // t7 = 6 (3.0x speed)
        beq     t6, t7, _additional_frame_advance_3 // branch if 3x speed
        nop

        // the frame information on the table
        addiu   t6, t6, -1              // correction for table
        li      t7, waiting_time_table  // t7 = waiting_time_table address
        sll     t6, t6, 0x0001          // t6 = offset
        addu    t7, t7, t6              // t7 = entry in waiting_time_table

        lbu     t6, 0x0000(t7)          // load the number of 'active' and total frames of timer
        lbu     t7, 0x0001(t7)          // ~

        // handle wait time for various slower/faster speeds
        li      t8, waiting_timer       // t8 = address of waiting_timer
        lw      at, 0x0000(t8)          // at = waiting timer value
        addiu   at, at, -1              // at--
        bltzl   at, pc() + 8            // safety, in case it goes into negatives
        or      at, r0, r0              // at = 0
        beqzl   at, pc() + 12           // if at = 0 reset timer to max value for current speed...
        sw      t7, 0x0000(t8)
        sw      at, 0x0000(t8)          // ...otherwise, just save updated timer
        sltu    at, at, t6              // at = 1 if it's within 'active' range

        li      t6, Item.Stopwatch.watch_speed_flag
        lb      t6, 0x0000(t6)              // t6 != 0 if active
        bnez    t6, pc() + 20               // branch if Stopwatch active (skip checking the Toggle)
        nop
        li      t6, Toggles.entry_game_speed
        lw      t6, 0x0004(t6)              // t6 = entry_game_speed (0 if DEFAULT 1/1; ranges from 1/8 to 3x)

        sltiu   t6, t6, 7                   // t6 (speed value in table) = 0 if speed value is 'slow'
        beqz    t6, slow_down               // branch accordingly
        nop

        speed_up:
        // handle wait time for various faster speeds
        bnez    at, _frame_advance          // ...skip additional frame advance if not in active range, otherwise...
        nop
        b       _additional_frame_advance   // ...additional frame advance (you guessed it)
        nop

        slow_down:
        beqz    at, _end                    // ...skip if not in active range, otherwise frame advance
        nop
        b       _frame_advance
        nop

        // for x3 speed, we need an additional additional frame advance
        _additional_frame_advance_3:
        li      t6, additional_advance      // t6 = additional_advance flag
        lli     at, OS.TRUE                 // set flag to indicate this is an additional advance
        sw      at, 0x0000(t6)              // ~
        jal     advance_frame               // original line 1
        nop

        // if we're here, we do an extra frame advance before the regular one
        _additional_frame_advance:
        li      t6, additional_advance      // t6 = additional_advance flag
        lli     at, OS.TRUE                 // set flag to indicate this is an additional advance
        sw      at, 0x0000(t6)              // ~
        jal     advance_frame               // original line 1
        nop

        // normal
        _frame_advance:
        li      t6, additional_advance      // t6 = additional_advance flag
        sw      r0, 0x0000(t6)              // clear flag
        jal     advance_frame               // original line 1
        nop

        _end:
        j       _return
        nop
    }

    // @ Description
    // Handles 'Game Speed' toggle and speed-related Items (Training version)
    // t6 = skip_advance bool
    scope handle_rate_training: {
        // safety check
        li      t0, 0x80190B70                      // t0 = address of Training speed multiplier
        lw      t0, 0x0000(t0)                      // t0 = 0 if speed is 1/1
        bnez    t0, _return                         // if Training speed is changed to not default 1/1, don't override speed
        nop

        // check if any Stopwatch items are affecting Game Engine Speed
        li      t6, Item.Stopwatch.watch_speed_flag
        lb      t6, 0x0000(t6)              // t6 != 0 if active
        bnez    t6, _handle_2x_3x           // if Stopwatch active, we skip checking the Toggle (overrides)
        nop

        _check_game_speed_toggle:
        li      t6, Toggles.entry_game_speed
        lw      t6, 0x0004(t6)              // t6 = entry_game_speed (0 if DEFAULT 1/1; ranges from 1/8 to 3x)
        beqz    t6, _frame_advance          // if Speed is default, proceed normally
        nop

        _handle_2x_3x:
        // 2x and 3x speeds don't need a timer check (or table read)
        addiu   t7, r0, 5                           // t7 = 5 (2.0x speed)
        beq     t6, t7, _additional_frame_advance   // branch if 2x speed
        addiu   t7, r0, 6                           // t7 = 6 (3.0x speed)
        beq     t6, t7, _additional_frame_advance_3 // branch if 3x speed
        nop

        // the frame information on the table
        addiu   t6, t6, -1              // correction for table
        li      t7, waiting_time_table  // t7 = waiting_time_table address
        sll     t6, t6, 0x0001          // t6 = offset
        addu    t7, t7, t6              // t7 = entry in waiting_time_table

        lbu     t6, 0x0000(t7)          // load the number of 'active' and total frames of timer
        lbu     t7, 0x0001(t7)          // ~

        // handle wait time for various slower/faster speeds
        li      t8, waiting_timer       // t8 = address of waiting_timer
        lw      at, 0x0000(t8)          // at = waiting timer value
        addiu   at, at, -1              // at--
        bltzl   at, pc() + 8            // safety, in case it goes into negatives
        or      at, r0, r0              // at = 0
        beqzl   at, pc() + 12           // if at = 0 reset timer to max value for current speed...
        sw      t7, 0x0000(t8)
        sw      at, 0x0000(t8)          // ...otherwise, just save updated timer
        sltu    at, at, t6              // at = 1 if it's within 'active' range

        li      t6, Item.Stopwatch.watch_speed_flag
        lb      t6, 0x0000(t6)              // t6 != 0 if active
        bnez    t6, pc() + 20               // branch if Stopwatch active (skip checking the Toggle)
        nop
        li      t6, Toggles.entry_game_speed
        lw      t6, 0x0004(t6)              // t6 = entry_game_speed (0 if DEFAULT 1/1; ranges from 1/8 to 3x)

        sltiu   t6, t6, 7                   // t6 (speed value in table) = 0 if speed value is 'slow'
        beqz    t6, slow_down               // branch accordingly
        nop

        speed_up:
        // handle wait time for various faster speeds
        bnez    at, _frame_advance          // ...skip additional frame advance if not in active range, otherwise...
        nop
        b       _additional_frame_advance   // ...additional frame advance (you guessed it)
        nop

        slow_down:
        beqz    at, _skip_advance           // ...skip if not in active range, otherwise frame advance
        nop
        b       _frame_advance
        nop

        // for x3 speed, we need an additional additional frame advance
        _additional_frame_advance_3:
        OS.save_registers()
        li      t6, additional_advance      // t6 = additional_advance flag
        lli     at, OS.TRUE                 // set flag to indicate this is an additional advance
        sw      at, 0x0000(t6)              // ~
        jal     advance_frame               // original line 1
        nop
        jal     advance_frame               // original line 1
        nop
        b       _additional_frame_advance_done
        nop

        // if we're here, we do an extra frame advance before the regular one
        _additional_frame_advance:
        OS.save_registers()

        li      t6, additional_advance      // t6 = additional_advance flag
        lli     at, OS.TRUE                 // set flag to indicate this is an additional advance
        sw      at, 0x0000(t6)              // ~
        jal     advance_frame               // original line 1
        nop
        _additional_frame_advance_done:
        OS.restore_registers()

        // normal
        _frame_advance:
        b       _end
        lli     t6, OS.FALSE

        _skip_advance:
        lli     t6, OS.TRUE

        _end:
        li      t0, Training.skip_advance   // address of Training skip_advance
        sw      t6, 0x0000(t0)              // update skip_advance bool

        _return:
        jr      ra                          // return
        nop
    }

// values are 'normal' frames and total frames
// e.g. 3,4 would apply to three frames of the four
waiting_time_table:
// faster increase speed (note: fractions are flipped)
db 5,6      // 1.2x speed
db 3,4      // 1.3x speed
db 2,3      // 1.5x speed
db 4,7      // 1.75 speed
db 0,2      // 2.0x speed
db 0,3      // 3.0x speed (branch specially for this one)
// slower decrease speed
db 1,8      // 1/8 speed
db 1,4      // 1/4 speed
db 1,3      // 1/3 speed
db 1,2      // 1/2 speed
db 2,3      // 2/3 speed
db 3,4      // 3/4 speed
OS.align(4)

waiting_timer:
dw 1

additional_advance:
dw 0

training_skip_advance:
dw 0
}

} // __SPEED__
