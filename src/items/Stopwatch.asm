// Stopwatch.asm (code by goombapatrol)
// @ Description
// These constants must be defined for an item.
constant SPAWN_ITEM(Item.spawn_custom_item_based_on_tomato_)
constant SHOW_GFX_WHEN_SPAWNED(OS.TRUE)
constant PICKUP_ITEM_MAIN(pickup_stopwatch)
constant PICKUP_ITEM_INIT(0)
constant DROP_ITEM(0x801745FC)
constant THROW_ITEM(0)
constant PLAYER_COLLISION(0)
constant GFX_ROUTINE(0x86)              // custom gfx routine index
constant GFX_ROUTINE_FAST(0x87)         // custom gfx routine index

// @ Description
// Offset to item in file 0xFB.
constant FILE_OFFSET(0x1120)

// @ Description
// Item info array
item_info_array:
constant ITEM_INFO_ARRAY_ORIGIN(origin())
dw 0x0                                  // 0x00 - item ID (will be updated by Item.add_item
dw 0x8018D040                           // 0x04 - hard-coded pointer to file 0xFB
dw FILE_OFFSET                          // 0x08 - offset to item footer in file 0xFB
dw 0x1C000000                           // 0x0C - (value - 1 * 4) + 0x8003DC24 = pointer to draw-related routine, 0x1C = no billboarding and transforms permitted

dw 0                                    // 0x10 - hitbox enabler/offset (0 = none, appends to 0x10C)
dw 0x801744C0                           // 0x14 - spawn behaviour routine (tomato, appends to 0x378)
dw 0x80174524                           // 0x18 - ground transition routine  (appends to 0x37C)
dw 0                                    // 0x1C - hurtbox collision routine (appends to 0x380)

dw 0                                    // 0x20 - collide with shield (appends to 0x384)
dw 0                                    // 0x24 - collide with shield edge (appends to 0x388)
dw 0                                    // 0x28 - collide with hitbox ( appends to 0x38C)
dw 0                                    // 0x2C - collide with reflector (appends to 0x390)

item_state_table:
dw 0                                    // 0x30 - ?
dw 0                                    // 0x34 - ?
dw 0x801744FC                           // 0x38 - ? resting state? (using Maxim Tomato)
dw 0                                    // 0x3C - ?
dw 0, 0, 0, 0                           // 0x40 - 0x4C - ?
dw 0                                    // 0x50 - ?
dw 0x801744C0                           // 0x54 - ? (using Maxim Tomato)
dw 0x80174524                           // 0x58 - ? (using Maxim Tomato)
dw 0                                    // 0x5C - ?
dw 0, 0, 0, 0                           // 0x60 - 0x6C - ?
dw 0                                    // 0x70 - ?
dw 0x801744C0                           // 0x74 - ? (using Maxim Tomato)
dw 0x801745CC                           // 0x78 - ? (using Maxim Tomato)
dw 0                                    // 0x7C - ?
dw 0, 0, 0, 0                           // 0x80 - 0x8C - ?
dw 0, 0, 0, 0                           // 0x90 - 0x9C - ?

// @ Description
// Duration of Stopwatch item
constant BACKFIRE_TABLE_SIZE(20)        // number of speeds in backfire table to pick from
constant FAST_TABLE_SIZE(20)            // number of pairs in fast table to pick from
constant SLOW_TABLE_SIZE(16)            // number of pairs in slow table to pick from
constant SLOWDOWN_DURATION(9*60)        // number of seconds
constant SPEEDUP_DURATION(10*60)        // number of seconds
constant BACKFIRE_ODDS(10)              // percent chance
constant SPEEDUP_ODDS(20)               // percent chance

// @ Description
// Main item pickup routine for Stopwatch.
scope pickup_stopwatch: {

    OS.save_registers()

    addiu   a0, r0, 100                // a0 = small odds of changing Game Speed intead of players
    jal     Global.get_random_int_safe_// v0 = (0, N-1)
    nop
    li      t0, Toggles.entry_stopwatch_behaviour
    lw      t0, 0x0004(t0)             // t0 = entry_stopwatch_behaviour (0 if DEFAULT, 1 if SLOW ALWAYS, 2 if FAST ALWAYS, 3 if BACKFIRE ALWAYS, 4 if BACKFIRE NEVER)
    beqzl   t0, _check_backfire        // if Stopwatch Behaviour is DEFAULT, use normal logic
    sltiu   a0, v0, BACKFIRE_ODDS      // set to branch if v0 < BACKFIRE_ODDS
    lli     a0, 3                      // a0 = 1 ("BACKFIRE ALWAYS")
    beq     t0, a0, _check_backfire    // if Stopwatch Backfires is ALWAYS, set a0 to non-zero so we backfire
    lli     a0, 4                      // a0 = 2 ("BACKFIRE NEVER")
    beq     t0, a0, _check_backfire    // if Stopwatch Backfires is NEVER, set a0 to 0 so we don't backfire
    lli     a0, OS.FALSE               // a0 = 0 (no backfire)

    // safety set (reached if "SLOW ALWAYS" or "FAST ALWAYS")
    lli     a0, OS.FALSE               // a0 = 0 (no backfire)

    _check_backfire:
    li      t0, watch_FGM              // t0 = watch_FGM
    beqz    a0, _no_backfire
    sb      a0, 0x0000(t0)             // set FGM (0 = normal, 1 = backfire)

    li      a0, player_affected        // a0 = player_affected flag
    lli     t6, OS.TRUE                // t6 = true (at least one player was affected)
    sb      t6, 0x0000(a0)             // set flag

    _random_engine_speed:
    li      a0, backfire_bg_object     // a0 = address of backfire_bg_object
    lw      a0, 0x0000(a0)             // a0 = rectangle reference
    bnez    a0, _drew_rectangle        // skip if already being drawn
    nop
    // based on Render.draw_rectangle() macro
    Render.draw_rectangle(0x0, 0xD, 10, 10, 300, 220, 0x00000000, OS.TRUE)
    li      a0, backfire_bg_object
    sw      v0, 0x0000(a0)             // save rectangle reference

    _drew_rectangle:
    // pick a random speed from table
    // hmm which one? ; get_random_int_ ; get_random_int_alt_ ; get_random_int_safe_
    addiu   a0, r0, BACKFIRE_TABLE_SIZE   // a0 = size of backfire speed table
    jal     Global.get_random_int_safe_   // v0 = (0, N-1)
    nop
    li      t0, speed_table         // t0 = address of speed_table
    addu    t0, t0, v0              // t0 = offset to entry in speed_table
    lb      t6, 0x0000(t0)          // load the game_speed value to use
    li      t0, watch_speed_flag
    sb      t6, 0x0000(t0)          // and store it in flag (which is 0 when we clear it)

    _set_bg_color:
    // set BG color depending on the speed
    li      t0, backfire_bg_colors  // t0 = address of backfire_bg_colors
    sltiu   t6, t6, 7               // t6 = 1 if fast, 0 if slow
    // addiu   t6, t6, -1              // t6 = offset in table
    sll     t6, t6, 0x0002          // ~
    addu    t0, t0, t6              // t0 = address of color entry in table
    lw      t0, 0x0000(t0)          // load color from table
    li      t6, backfire_bg_object  // t6 = address of backfire_bg_object
    lw      t6, 0x0000(t6)          // t6 = rectangle reference
    sw      t0, 0x0040(t6)          // set color of backfire_bg_object

    li      t0, watch_speed_flag
    lb      t6, 0x0000(t0)          // t6 = game_speed value
    // set duration depending on the speed (around 10 real seconds)
    slti    t0, t6, 4
    bnezl   t0, _set_duration
    lli     t6, 11*60               // t6 = duration for 1.2x or 1.3x or 1.5x...
    slti    t0, t6, 7
    bnezl   t0, _set_duration
    lli     t6, 17*60               // ... 1.75 or 2.0 or 3.0 ...
    slti    t0, t6, 10
    bnezl   t0, _set_duration
    lli     t6, 3.5*60              // ... 1/4 or 1/3 ...
    slti    t0, t6, 11
    bnezl   t0, _set_duration
    lli     t6, 5*60                // ... 1/2 ...
    // otherwise
    lli     t6, 6*60               // ... 2/3 or 3/4

    _set_duration:
    li      at, engine_speed_timer  // at = engine_speed_timer
    sw      t6, 0x0000(at)          // store value
    b       _check_for_active_players
    nop

    _no_backfire:
    lw      a0, 0x0010(sp)          // restore a0
    j       clock_out_              // add affected players to table
    nop

    _check_for_active_players:
    // check if any player already has activated a Stopwatch
    li      t0, watch_routine_
    lw      t3, 0x0000(t0)              // get current value
    bnez    t3, _watch_for_duplicates   // skip watch setup if there is already an active watch
    sw      t0, 0x0020(sp)              // save address of players watch

    // setup Stopwatch
    Render.register_routine(handle_active_stopwatch_)    // register routine that handles the countdown
    // v0 = routine handler
    lw      a0, 0x0010(sp)              // a0 = player struct
    lw      a2, 0x0018(sp)              // a2 = item object
    lw      t0, 0x0020(sp)              // t0 = watch_routine_ address
    sw      a0, 0x0040(v0)              // save player struct in handler object
    sw      a2, 0x0044(v0)              // save item struct in handler object
    sw      t0, 0x0048(v0)              // save address of players Watch
    sw      v0, 0x0000(t0)              // save routine handler
    b       _end
    nop

    _watch_for_duplicates:
    // anything to do here?

    _end:
    li      a0, player_affected        // a0 = player_affected flag
    lb      t0, 0x0000(a0)             // t0 = 1 if at least one player was affected
    beqz    t0, _end_restore           // skip playing sound if no players were affected
    sb      r0, 0x0000(a0)             // clear flag
    li      t0, watch_FGM              // t0 = watch_FGM
    lb      a0, 0x0000(t0)             // load FGM (0 = normal, 1 = backfire)
    bnezl   a0, pc() + 12              // if we backfired, play alternate sound
    lli     a0, 0x601                  // a0 = FGM TimerBackfire
    lli     a0, 0x600                  // a0 = FGM sounds/misc/timer
    jal     FGM.play_                  // play fgm
    nop
    _end_restore:
    OS.restore_registers()

    // Continue after damage restore routine in tomato/heart pickup routine
    sw      a2, 0x0018(sp)              // save a2 to where the rest of the routine expects it
    j       0x80145C4C
    sw      a3, 0x001C(sp)              // save a3 to where the rest of the routine expects it
}

// @ Description
// Set Slowdown timer for other players than a0
// (borrowed a little code from "lightning_zap_players_")
scope clock_out_: {
    // a0 = watch owner
    addiu   sp, sp, -0x0030                     // allocate stack space
    sw      ra, 0x0004(sp)                      // save registers
    sw      a0, 0x0014(sp)                      // save registers

    li      t0, 0x800466FC
    lw      t0, 0x0000(t0)                      // t0 = first player object
    sw      t0, 0x0010(sp)                      // save player object t0 stack
    lw      t0, 0x0084(t0)                      // t0 = first player struct

    li      t3, Global.match_info               // ~
    lw      t3, 0x0000(t3)                      // t3 = match info struct
    lbu     t4, 0x0002(t3)                      // t4 = team battle flag
    lbu     t3, 0x0009(t3)                      // t3 = team attack flag
    sw      t4, 0x0024(sp)                      // save team battle flag to stack
    sw      t3, 0x0028(sp)                      // save team attack flag to stack

    li      a1, Toggles.entry_stopwatch_behaviour
    lw      a1, 0x0004(a1)                      // a1 = entry_stopwatch_behaviour (0 if DEFAULT, 1 if SLOW ALWAYS, 2 if FAST ALWAYS, 3 if BACKFIRE ALWAYS, 4 if BACKFIRE NEVER)
    lli     a0, 1                               // a0 = 1 ("SLOW ALWAYS")
    beql    a1, a0, _set_fast_slow_flag         // branch accordingly...
    addiu   a0, r0, 0                           // ...and set a0 to slow (0)
    lli     a0, 2                               // a0 = 2 ("FAST ALWAYS")
    beql    a1, a0, _set_fast_slow_flag         // branch accordingly
    addiu   a0, r0, 1                           // ...and set a0 to fast (1)

    // otherwise, random pick
    addiu   a0, r0, 100                         // a0 = small odds of speeding up item user instead or slowing others down
    jal     Global.get_random_int_safe_         // v0 = (0, N-1)
    nop
    sltiu   a0, v0, SPEEDUP_ODDS                // a0 = 1 if v0 < SPEEDUP_ODDS...
    nop
    _set_fast_slow_flag:
    li      a1, fast_or_slow_                   // a1 = fast (1) or slow (0) flag
    sb      a0, 0x0000(a1)                      // set flag accordingly
    // li      t4, watch_FGM                    // t4 = watch_FGM
    // sb      a0, 0x0000(t4)                   // set FGM (0 = slow, 1 = fast?)

    _loop:
    lw      a1, 0x0014(sp)                      // a1 = item owner struct
    lw      a0, 0x0010(sp)                      // a0 = current player object
    lw      t4, 0x0024(sp)                      // load team battle flag from stack
    lw      t3, 0x0028(sp)                      // load team attack flag from stack

    sw      t0, 0x000C(sp)                      // save player struct to stack
    sw      a0, 0x0010(sp)                      // save player object to stack
    beqz    a0, _next                           // if no player object, skip this port
    lw      t2, 0x000C(sp)                      // t2 = player struct
    beq     t2, a1, _speedup_check              // if player is item owner, check for fast (if not skip this port)
    nop

    beqz    t4, _action_check                   // branch if team battle flag = FALSE
    nop

    lbu     t2, 0x000C(t2)                      // t2 = player team
    lbu     t5, 0x000C(a1)                      // t5 = item owner team
    bne     t2, t5, _action_check               // branch if player is not team mate
    nop
    // slow down: if player is team mate, skip this port if team attack is OFF
    // speedup: apply to team mate regardless of team ataack
    li      a0, fast_or_slow_                   // a0 = fast (1) or slow (0) flag
    lb      a0, 0x0000(a0)                      // a0 = value of flag
    bnez    a0, _speedup_random_speed           // branch accordingly
    nop
    beqz    t3, _next                           // branch if team attack flag = FALSE
    nop

    _action_check:
    lw      a0, 0x0024(t0)                      // a0 = players current action
    addiu   at, r0, Action.Revive1              // at = revive1
    beq     at, a0, _next                       // skip if player reviving
    nop
    addiu   at, r0, Action.Revive2              // at = revive2
    beq     at, a0, _next                       // skip if player reviving
    nop
    addiu   at, r0, Action.ReviveWait           // at = reviveWait
    beq     at, a0, _next                       // skip if player reviving
    nop

    lw      a0, 0x05A4(t0)                      // check if player is invulnerable from spawning
    bnez    a0, _next                           // skip this player if they are still spawning
    nop
    lw      a0, 0x05B0(t0)                      // a0 = super star counter
    bnez    a0, _next                           // skip this player if they are using a super star
    nop

    li      a0, fast_or_slow_                   // a0 = fast (1) or slow (0) flag
    lb      a0, 0x0000(a0)                      // a0 = value of flag
    beqz    a0, _slow_player                    // only branch if we rolled slow...
    nop
    b       _next                               // ...otherwise skip
    nop

    _speedup_check:
    li      a0, fast_or_slow_                   // a0 = fast (1) or slow (0) flag
    lb      a0, 0x0000(a0)                      // a0 = value of flag
    beqz    a0, _next                           // skip if we didn't roll fast
    nop
    _speedup_random_speed:
    // pick a random speed from table
    addiu   a0, r0, FAST_TABLE_SIZE             // a0 = size of fast speed pool
    jal     Global.get_random_int_safe_         // v0 = (0, N-1)
    nop

    li      t8, clocked_out_players_
    lw      t0, 0x000C(sp)                      // load player struct
    lw      t2, 0x000C(sp)                      // t2 = player struct

    lbu     t3, 0x000D(t2)                      // t3 = port
    sll     t3, t3, 0x0002                      // t3 = port offset in table

    li      t9, GFXRoutine.port_override.override_table // load override table for gfx routines
    addu    t4, t9, t3                          // get address of player entry in gfx override table
    addiu   t1, r0, GFX_ROUTINE_FAST
    sw      t1, 0x0000(t4)                      // save watch gfx routine in override table

    sll     t3, t3, 0x0001                      // t3 = port offset in table
    li      t9, GFXRoutine.STOPWATCH_FASTED
    sw      t9, 0x0A28(t2)                      // save gfx routine to player struct

    addu    t9, t8, t3                          // t9 = address of fast timer

    li      t4, fast_speed_table                // t4 = address of fast_speed_table
    sll     t1, v0, 1                           // t1 = v0 * 2
    addu    t4, t4, t1                          // t4 = offset to entry in fast_speed_table
    lb      t1, 0x0000(t4)                      // t1 = 'active' frame value to use...
    lb      t4, 0x0001(t4)                      // t4 = 'total'  ...which we store in clocked_out_players_
    sb      t1, 0x0000(t9)                      // store Delay Timer initial value
    sb      t1, 0x0001(t9)                      // store 'active' frame value
    sb      t4, 0x0002(t9)                      // store 'total'  frame value

    lli     a0, SPEEDUP_DURATION                // a0 = X seconds
    sh      a0, 0x0004(t9)                      // store Remaining Time in table

    addiu   a0, r0, 1                           // a0 = 1 (Fast)
    sh      a0, 0x0006(t9)                      // set speed type flag

    b       _player_was_affected
    nop

    _slow_player:
    // pick a random speed from table
    addiu   a0, r0, SLOW_TABLE_SIZE             // a0 = size of slow speed pool
    jal     Global.get_random_int_safe_         // v0 = (0, N-1)
    nop

    li      t8, clocked_out_players_
    lw      t0, 0x000C(sp)                      // load player struct
    lw      t2, 0x000C(sp)                      // t2 = player struct

    lbu     t3, 0x000D(t2)                      // t3 = port
    sll     t3, t3, 0x0002                      // t3 = port offset in table

    li      t9, GFXRoutine.port_override.override_table // load override table for gfx routines
    addu    t4, t9, t3                          // get address of player entry in gfx override table
    addiu   t1, r0, GFX_ROUTINE
    sw      t1, 0x0000(t4)                      // save watch gfx routine in override table

    sll     t3, t3, 0x0001                      // t3 = port offset in table
    li      t9, GFXRoutine.STOPWATCH_SLOWED
    sw      t9, 0x0A28(t2)                      // save gfx routine to player struct

    addu    t9, t8, t3                          // t9 = address of slow timer

    li      t4, slow_speed_table                // t4 = address of slow_speed_table
    sll     t1, v0, 1                           // t1 = v0 * 2
    addu    t4, t4, t1                          // t4 = offset to entry in slow_speed_table
    lb      t1, 0x0000(t4)                      // t1 = 'active' frame value to use...
    lb      t4, 0x0001(t4)                      // t4 = 'total'  ...which we store in clocked_out_players_
    sb      t1, 0x0000(t9)                      // store Delay Timer initial value
    sb      t1, 0x0001(t9)                      // store 'active' frame value
    sb      t4, 0x0002(t9)                      // store 'total'  frame value

    lli     a0, SLOWDOWN_DURATION               // a0 = X seconds
    sh      a0, 0x0004(t9)                      // store Remaining Time in table

    sh      r0, 0x0006(t9)                      // set speed type flag as 0 (Slow)

    _player_was_affected:
    li      a0, player_affected                 // a0 = player_affected flag
    lli     t4, OS.TRUE                         // t4 = true (at least one player was affected)
    sb      t4, 0x0000(a0)                      // set flag

    _next:
    lw      a0, 0x0010(sp)                      // a0 = current player object
    lw      a0, 0x0004(a0)                      // a0 = next player object
    sw      a0, 0x0010(sp)                      // save next player object
    bnezl   a0, _loop                           // if more players, keep looping
    lw      t0, 0x0084(a0)                      // t0 = next player struct

    addiu   sp, sp, 0x0030                      // deallocate stack space

    j       pickup_stopwatch._check_for_active_players
    nop
}

// @ Description
// handles an active Stopwatch. No Stopwatch item exists at this point.
scope handle_active_stopwatch_: {
    addiu   sp, sp, -0x24           // allocate sp
    sw      ra, 0x0014(sp)          // store registers
    sw      a0, 0x0020(sp)          // save routine handler
    sw      s1, 0x0004(sp)

    // 0x0034(a0) gfx routine
    // 0x0038(a0) reflect flag
    // 0x003C(a0) reflect hitbox struct
    // 0x0040(a0) player struct
    // 0x0044(a0) item struct
    // 0x0048(a0) pointer to player entry in Watch array
    // 0x004C(a0) timer
    lw      a0, 0x0020(sp)          // a0 = handler object
    lw      a1, 0x0040(a0)          // a1 = item owner struct
    li      at, watch_end_FGM_playing
    sb      r0, 0x0000(at)          // clear flag

    _subtract_timer:
    or     t3, r0, r0               // clear t3
    OS.read_word(0x800466FC, at)    // at = first player object

    _loop:
    // beq     at, a1, _advance_port // if we're the item owner, skip check
    // nop

    // per-player timer (not all cleared at once)
    li      t0, clocked_out_players_
    lw      at, 0x0084(at)          // at = player struct
    lbu     t8, 0x000D(at)          // t8 = port
    sll     t8, t8, 0x0003          // t8 = offset to player entry
    addu    t0, t8, t0              // t0 = address of players timer

    lh      t8, 0x0004(t0)          // load timer for port
    beqz    t8, _advance_port       // if timer is already zero, skip
    nop

    lhu     t2, 0x0026(at)          // t2 = action
    sltiu   t8, t2, 0x0004          // t8 = 1 if player just died
    bnezl   t8, pc() + 12           // if player died...
    addiu   t8, r0, 1               // ...set timer to be cleared
    lh      t8, 0x0004(t0)          // load timer for port 1
    addiu   t8, t8, -1              // t8 = t8 - 1
    sh      t8, 0x0004(t0)          // update timer
    beqzl   t8, _timer_exhausted    // if timer is exhausted...
    sw      r0, 0x0000(t0)          // ...clear slowness

    lli     t3, OS.TRUE             // t3 = true (at least one timer is active)

    lbu     t8, 0x0000(t0)          // t8 = player's Delay timer
    addiu   t8, t8, -0x0001         // t8--
    bltzl   t8, pc() + 8            // if t8 was 0 reset timer to max value for current speed...
    lbu     t8, 0x0002(t0)          // t8 = 'total' frame count from table
    sb      t8, 0x0000(t0)          // reset timer

    b       _advance_port
    nop

    // if timer is exhausted, remove GFX routine for that player
    _timer_exhausted: {
        addiu   sp, sp, -0x30       // allocate memory
        sw      a0, 0x04(sp)
        sw      a1, 0x08(sp)
        sw      a3, 0x0C(sp)
        sw      t8, 0x10(sp)
        sw      t3, 0x18(sp)
        sw      at, 0x1C(sp)
        sw      t0, 0x20(sp)
        sw      ra, 0x24(sp)

        sh      r0, 0x0006(t0)      // clear speed type flag
        _remove_gfx_routine:
        li      t8, GFXRoutine.port_override.override_table
        lw      at, 0x1C(sp)        // at = player struct
        lbu     t3, 0x000D(at)      // t3 = port
        sll     t0, t3, 0x0002      // t0 = offset to player entry
        addu    t0, t8, t0          // t0 = address of players gfx routine
        addiu   t8, r0, GFX_ROUTINE // t8 = stopwatch gfx routine index
        lw      t3, 0x0000(t0)      // t3 = current players override gfx routine
        beq     t8, t3, pc() + 12   // continue if stopwatch gfx routine is here
        addiu   t8, r0, GFX_ROUTINE_FAST // t8 = stopwatch gfx routine 2 index
        bne     t8, t3, _play_end_sfx    // branch if neither stopwatch gfx routine is here
        lw      a0, 0x0004(at)      // a0 = player object
        jal     0x800E98D4          // run players default gfx routine
        sw      r0, 0x0000(t0)      // remove stopwatch gfx override flag

        _play_end_sfx:
        lw      at, 0x1C(sp)        // at = player struct
        lhu     t3, 0x0026(at)      // t3 = action
        sltiu   t8, t3, 0x0004      // t8 = 1 if player just died
        bnez    t8, _timer_exhausted_end  // skip playing SFX and circle GFX if player died...
        nop
        li      t8, watch_end_FGM_playing
        lb      t3, 0x0000(t8)           // t3 = 1 if already playing Timer end FGM...
        bnez    t3, _generate_white_circle_gfx  // ...in which we skip playing another
        lli     t3, OS.TRUE              // t3 = true
        sb      t3, 0x0000(t8)           // set flag to non-zero
        jal     FGM.play_                // play fgm
        lli     a0, 0x605                // a0 = FGM Timer End

        _generate_white_circle_gfx:
        // generate white circle effect
        lw      a1, 0x1C(sp)        // a1 = player struct
        lw      a0, 0x4(a1)

        lw      t8, 0x09C8(a1)      // t8 = player attributes
        lwc1    f8, 0x00A0(t8)      // f8 = ecb center y height

        lw      t0, 0x0078(a1)      // location vector base
        lwc1    f4, 0x4(t0)         // f4 = location y

        add.s   f8, f8, f4          // f8 = Y+ECB_Y

        addiu   sp, sp, -0x30       // allocate memory

        lw      t1, 0x0(t0)         // ~
        sw      t1, 0x18(sp)        // x
        swc1    f8, 0x1c(sp)        // y
        lw      t1, 0x8(t0)         // ~
        sw      t1, 0x20(sp)        // z - create (X, Y+ECB_Y, Z) vec3 at 0x18

        lw      a0, 0x0004(a1)      // a0 = player object
        addiu   a0, sp, 0x18        // arg0 (location)

        // scale effect size with topjoint model scale
        lli         t0, 20          // effect size
        mtc1        t0, f8          // f8 = effect size
        lw          t1, 0x8E8(a1)   // t1 = defender's topjoint transform bone
        lwc1        f4, 0x0040(t1)  // f4 = defender's topjoint X scale
        cvt.s.w     f8, f8          // convert effect size to float
        mul.s       f4, f4, f8      // muliply by size
        trunc.w.s   f4, f4          // convert to int
        mfc1        a1, f4          // arg1 size

        jal         0x80100BF0      // efManagerSetOffMakeEffect(Vec3f *pos, s32 size)
        nop

        addiu   sp, sp, 0x30        // deallocate memory

        _timer_exhausted_end:
        lw      a0, 0x04(sp)
        lw      a1, 0x08(sp)
        lw      a3, 0x0C(sp)
        lw      t8, 0x10(sp)
        lw      t3, 0x18(sp)
        lw      at, 0x1C(sp)
        lw      t0, 0x20(sp)
        lw      ra, 0x24(sp)
        addiu   sp, sp, 0x30        // deallocate memory
    }

    _advance_port:
    lw      at, 0x0004(at)          // at = player object
    lw      at, 0x0004(at)          // at = next player object
    bnez    at, _loop               // loop while there are more players to check
    nop

    // global item timer
    _subtract_timer_2:
    li      at, engine_speed_timer  // at = engine_speed_timer
    lw      v0, 0x0000(at)          // v0 = timer value
    beqz    v0, _timer_check        // branch if timer is not active...
    nop

    // bg color saturation shift
    li      a0, backfire_bg_object  // a0 = address of backfire_bg_object
    lw      a0, 0x0000(a0)          // a0 = rectangle reference
    // sltiu   t8, v0, 0xCC            // t8 = 1 if division would result in lower than 0x33
    // bnez    t8, _update_bg_alpha    // branch if it has gone below range
    // srl     t8, v0, 2               // t8 = timer value / 4
    // sb      t8, 0x0040(a0)          // update Red color of backfire_bg_object
    // b       _updated_bg_color
    // nop

    // fade out near end of timer
    _update_bg_alpha:
    sltiu   t8, v0, 240             // t8 = 1 if timer < 240 frames left
    beqz    t8, _updated_bg_color   // skip if not near end of timer
    andi    t8, v0, 3               // fade every 4 frames
    bnez    t8, _updated_bg_color   // skip if not on a good frame
    nop
    lb      t8, 0x0043(a0)          // t8 = alpha of backfire_bg_object
    sltiu   t3, t8, 0x33            // t3 = 1 if alpha is less than 0x33
    bnez    t3, _updated_bg_color   // skip if it has gone below our range
    nop
    sltiu   t8, t8, 0x66            // t8 = 0 if alpha is greater than 0x66
    beqzl   t8, pc() + 12           // fade rate depends on how much is left to go
    lli     t3, -3                  // t3 = -3
    lli     t3, -1                  // t3 = -1
    lb      t8, 0x0043(a0)          // t8 = alpha of backfire_bg_object
    addu    t8, t8, t3              // t8 = t8 - t3 (fade amount)
    sb      t8, 0x0043(a0)          // update alpha of backfire_bg_object

    _updated_bg_color:
    addiu   t3, OS.TRUE             // t3 = true (at least one timer is active)
    addiu   t8, v0, 0xFFFF          // timer -= 1
    bltzl   t8, pc() + 8            // safety (this shouldn't happen)
    or      t8, r0, r0              // t8 = 0
    sw      t8, 0x0000(at)          // save timer
    bnez    t8, _timer_check        // branch if timer has not depleted...
    nop                             // ...otherwise, clear speed flag
    li      t8, watch_speed_flag    // t8 = watch_speed_flag
    sb      r0, 0x0000(t8)          // clear flag
    // if backfire timer is 0, make BG rectangle transparent
    li      t8, backfire_bg_object  // t8 = address of backfire_bg_object
    lw      t8, 0x0000(t8)          // t8 = rectangle reference
    sw      r0, 0x0040(t8)          // set color of backfire_bg_object
    li      t8, watch_end_FGM_playing
    lb      v0, 0x0000(t8)           // v0 = 1 if already playing Timer end FGM...
    bnez    v0, _timer_check         // ...in which we skip playing another
    nop
    jal     FGM.play_                // play fgm
    lli     a0, 0x606                // a0 = FGM Backfire Timer End

    _timer_check:
    bnez    t3, _end                    // keep watch so long as at least one of the timers is active
    nop                                 // otherwise, destroy it
    _destroy_watch:
    li      t8, watch_routine_          // t8 = array to clear
    sw      r0, 0x0000(t8)              // ~

    _play_destroy_sfx:
    addiu   sp, sp, -0x0020
    sw      a0, 0x0010(sp)
    // jal     FGM.play_
    // lli     a0, FGM.announcer.fight.TIME_UP
    lw      a0, 0x0010(sp)
    addiu   sp, sp, 0x0020
    lw      at, 0x0048(a0)              // at = pointer to players index in array
    sw      r0, 0x0000(at)              // remove player from array

    li      t0, clocked_out_players_
    sw      r0, 0x0000(t8)              // clear table
    sw      r0, 0x0004(t8)              // ~
    sw      r0, 0x0008(t8)              // ~
    sw      r0, 0x000C(t8)              // ~
    sw      r0, 0x0010(t8)              // ~
    sw      r0, 0x0014(t8)              // ~
    sw      r0, 0x0018(t8)              // ~
    sw      r0, 0x001C(t8)              // ~

    jal     Render.DESTROY_OBJECT_
    lw      a0, 0x0020(sp)              // argument = routine handler

    li      t3, backfire_bg_object     // t3 = address of backfire_bg_object
    lw      a0, 0x0000(t3)             // a0 = rectangle to destroy
    jal     Render.DESTROY_OBJECT_
    sw      r0, 0x0000(t3)             // clear rectangle reference

    _end:
    lw      s1, 0x0004(sp)              //
    lw      ra, 0x0014(sp)              // restore registers
    jr      ra                          // return
    addiu   sp, sp, 0x24                // deallocate sp
}

// @ Description
// This checks for and applies 'Stopwatch' Slowdown effect (per-player)
// t9 = function to run
// t3 and t6 should be safe
// Returns t3 (0 = normal, 1 = skip, 2 = run twice)
scope check_function_: {
    li      t6, Item.Stopwatch.watch_routine_
    lw      t6, 0x0000(t6)
    beqzl   t6, _end                // skip if no watches are active
    lli     t3, OS.FALSE            // t3 = normal

    li      t3, projectile_ID_speed_limit // t3 = address of projectile_ID_speed_limit
    sw      r0, 0x0000(t3)                // clear projectile_ID_speed_limit flag
    li      t3, function_abbr       // t3 = address of function_abbr flag
    sw      r0, 0x0000(t3)          // clear function_abbr flag

    li      t3, 0x800E1260          // update player animations/actions (ftMainProcUpdate)
    beq     t9, t3, _player_check
    nop
    li      t3, 0x800E2604          // update player physics (ftMainProcPhysicsMapDefault)
    beq     t9, t3, _player_check_held_item
    nop
    li      t3, 0x801662BC          // handle projectiles (wpProcessProcWeaponMain)
    beq     t9, t3, _player_check_projectile
    nop
    // li      t3, 0x800FBAD0                       // handle stage collision (mpCollisionPlayYakumonoAnim)
    // beql    t9, t3, _stage_collision_check       // note: this one desyncs platform with stage transitions (e.g. Time Twister)
    // or      at, r0, r0              // at = 0    // but keeping framework below to perhaps use with a different function

    // are these useful too?
    //// li      t3, 0x800E3EBC     // ftMainProcessHitCollisionStatsMain
    //// beq     t9, t3, _player_check
    //// nop
    //// li      t3, 0x800E61EC     // ftMainProcUpdateMain
    //// beq     t9, t3, _player_check
    //// nop
    //// li      t3, 0x800E2660     // ftMainProcPhysicsMapCapture
    //// beq     t9, t3, _player_check
    //// nop
    //// li      t3, 0x80166954     // wpProcessProcSearchHitWeapon
    //// beq     t9, t3, _player_check_projectile
    //// nop
    //// li      t3, 0x80166BE4     // wpProcessProcHitCollisions
    //// beq     t9, t3, _player_check_projectile
    //// nop

    // if we're here, the current function isn't relevant to Stopwatch
    b       _end
    lli     t3, OS.FALSE            // t3 = normal

    // loop through all players and see if any are slow and skipping update
    _stage_collision_check:
    sll     t6, at, 0x0003          // t6 = offset to player entry
    li      t3, Item.Stopwatch.clocked_out_players_
    addu    t6, t3, t6              // t6 = address of players timer, if any
    lw      t3, 0x0004(t6)          // get current value
    beqz    t3, _stage_collision_check_next // skip if there isn't an active timer
    lh      t3, 0x0006(t6)          // t3 = player's speed type flag (0 = slow, 1 = fast)
    bnez    t3, _stage_collision_check_next // skip if not slow
    nop
    lb      t3, 0x0000(t6)          // t3 = player's Delay timer
    lbu     t6, 0x0001(t6)          // load the number of 'active' frames of timer
    sltu    t3, t3, t6              // t3 = 1 if it's within 'active' range
    beqzl   t3, _end                // if any timer has not been met, skip for this frame...
    lli     t3, OS.TRUE             // t3 = skip

    _stage_collision_check_next:
    sltiu   t6, at, 0x0003          // t6 = 1 if more ports to check
    bnezl   t6, _stage_collision_check
    addiu   at, at, 0x0001          // at = next port
    b       _end                    // branch if all ports were checked
    lli     t3, OS.FALSE            // t3 = normal

    _player_check_held_item:
    // check for Barrel/Crate Held item (which cause issues if platform despawns)
    // note: with function_abbr implemented, this may no longer be an issue
    b       _player_check
    nop
    // lw      t6, 0x0084(a0)          // t6 = player struct
    // lw      t6, 0x084C(t6)          // t6 = player held item pointer
    // beqz    t6, _player_check       // if player is not holding an item, skip
    // nop
    // lw      t6, 0x0084(t6)          // t6 = item struct
    // lw      t6, 0x000C(t6)          // t6 = item ID
    // sltiu   at, t6, 2               // at = 1 if ID is Crate (0) or Barrel (1)
    // bnezl   at, _end                // skip if holding either
    // lli     t3, OS.FALSE            // t3 = normal
    // b       _player_check           // otherwise, continue
    // nop

    _player_check_projectile:
    // check for any Projectile IDs that should be skipped
    // note: if we're here, a0 = projectile object
    lw      t6, 0x0084(a0)            // t6 = projectile struct
    lw      t6, 0x000C(t6)            // t6 = projectile ID
    li      at, projectile_ID_speed_limit // at = address of projectile_ID_speed_limit
    addiu   t3, r0, 0x000E            // t3 = 'PK thunder head' projectile ID
    beq     t6, t3, _run_normal       // branch if pk thunder head
    addiu   t3, r0, 0x000F            // t3 = 'PK thunder tail' projectile ID
    beq     t6, t3, _run_normal       // branch if pk thunder tail
    nop
    // No projectiles will run at 'Fast' speed, only 'Slow'
    lli     t6, OS.TRUE               // t6 = skip
    sh      t6, 0x0002(at)            // ...set in 'Fast' slot of flag
    _proj_get_Struct:
    // get player struct from projectile object
    lw      t6, 0x0084(a0)          // t6 = projectile struct
    lw      t6, 0x0008(t6)          // t6 = projectile owner struct
    beqz    t6, _run_normal         // run normal if no owner (e.g. Saffron Pokemon)
    nop
    lw      t6, 0x0084(t6)          // t6 = player struct
    b       _port_check_table       // branch
    nop

    _player_check:
    // check table to see which players are currently affected
    // note: if we're here, a0 = player object
    lw      t6, 0x0084(a0)          // t6 = player struct
    _port_check_table:
    lbu     t6, 0x000D(t6)          // t6 = port
    sll     t6, t6, 0x0003          // t6 = offset to player entry
    li      t3, Item.Stopwatch.clocked_out_players_
    addu    t6, t3, t6              // t6 = address of players timer, if any
    lw      t3, 0x0004(t6)          // get current value
    beqzl   t3, _end                // branch if there isn't an active timer
    lli     t3, OS.FALSE            // t3 = normal

    // Initiating PK Thunder doesn't cooperate with speed change...
    // ...so skip if that is our current action (voila, no glitchy Hitbox)
    _ness_lucas_check:
    li      t3, 0x800E1260          // continue only if function is animations/actions...
    beq     t9, t3, pc() + 20
    li      t3, 0x800E2604          // ...or player physics
    bne     t9, t3, _check_spd_type // otherwise, skip
    nop
    lw      at, 0x0084(a0)          // at = player struct
    lw      at, 0x0008(at)          // at = char_id
    lli     t3, Character.id.NESS   // branch accordingly
    beq     t3, at, action_check._PK_thunder
    lli     t3, Character.id.JNESS
    beq     t3, at, action_check._PK_thunder
    lli     t3, Character.id.LUCAS
    beq     t3, at, action_check._PK_thunder
    lli     t3, Character.id.CRASH
    beq     t3, at, action_check.crash
    nop
    b       _captured_check         // branch if none of the above characters
    nop

    scope action_check: {
        crash:
        lw      at, 0x0084(a0)          // at = player struct
        lw      at, 0x0024(at)          // at = current action id
        lli     t3, 0x0E5               // t3 = CRASH DSP 'DigginItBegin' action
        beq     at, t3, _run_normal     // skip if action matches
        nop
        b       _captured_check
        nop

        _PK_thunder:
        lw      at, 0x0084(a0)          // at = player struct
        lw      at, 0x0024(at)          // at = current action id
        lli     t3, Action.NESS.PKThunderStart1
        beq     at, t3, _run_normal     // skip if PK Thunder action matches
        lli     t3, Action.NESS.PKThunderStart2
        beq     at, t3, _run_normal
        lli     t3, Action.NESS.PKThunderStartAir
        beq     at, t3, _run_normal
        lli     t3, Action.NESS.PKThunderAir
        beq     at, t3, _run_normal
        nop                                // proceed if no action match
    }

    _captured_check:
    lw      t3, 0x0084(a0)             // t3 = player struct
    lw      t3, 0x0844(t3)             // t3 = player captured by
    bnezl   t3, _end                   // skip if player is captured (grab, EggLayPull, inhale etc)
    lli     t3, OS.FALSE               // t3 = normal

    _check_spd_type:
    lh      t3, 0x0006(t6)             // t3 = player's speed type flag (0 = slow, 1 = fast)
    bnez    t3, _timer_check_fast      // branch accordingly
    nop

    // for slowdown
    _timer_check:
    li      t3, projectile_ID_speed_limit // t3 = address of projectile_ID_speed_limit
    lh      t3, 0x0000(t3)          // t3 = non-zero if this is a fast-only projectile
    bnez    t3, _run_normal         // branch if so
    lb      t3, 0x0000(t6)          // t3 = player's Delay timer
    lbu     t6, 0x0001(t6)          // load the number of 'active' frames of timer
    sltu    t3, t3, t6              // t3 = 1 if it's within 'active' range
    bnez    t3, _run_normal         // if timer has been met, don't skip for this frame...
    nop

    li      t3, 0x800E2604          // check if player physics
    bne     t9, t3, _end            // branch if not physics function
    lli     t3, OS.TRUE             // t3 = skip
    // li      t3, 0x800E1260          // continue only if function is animations/actions...
    // beq     t9, t3, pc() + 20
    // li      t3, 0x800E2604          // ...or player physics
    // bne     t9, t3, _end            // otherwise, skip
    // lli     t3, OS.TRUE             // t3 = skip

    li      t3, function_abbr       // set flag to skip part of upcoming physics function
    lli     t6, OS.TRUE             // ~
    sw      t6, 0x0000(t3)          // (this will effectively spoof hitlag to 'freeze' them for the frame)

    _run_normal:
    lli     t3, OS.FALSE            // t3 = normal
    b       _end
    nop

    // for speedup
    _timer_check_fast:
    li      t3, projectile_ID_speed_limit // t3 = address of projectile_ID_speed_limit
    lh      t3, 0x0002(t3)          // t3 = non-zero if this is a slow-only projectile
    bnez    t3, _run_normal         // branch if so
    lb      t3, 0x0000(t6)          // t3 = player's Delay timer
    lbu     t6, 0x0001(t6)          // load the number of 'active' frames of timer
    sltu    t3, t3, t6              // t3 = 1 if it's not within 'active' range
    bnezl   t3, _end                // if timer has been met, run normal for this frame...
    lli     t3, OS.FALSE            // t3 = normal
                                    // otherwise...
    _run_fast:
    li      t3, 0x801662BC          // safety check fast projectiles
    beql    t9, t3, _end            // ~
    lli     t3, 2                   // t3 = run twice

    // store Temporary flags to check after first update
    lw      t3, 0x0084(a0)          // t3 = player struct
    li      at, moveset_flag_vars   // at = address of moveset_flag_vars
    lw      t6, 0x017C(t3)          // remember temp variable 1
    sw      t6, 0x0000(at)
    lw      t6, 0x0180(t3)          // remember temp variable 2
    sw      t6, 0x0004(at)
    lw      t6, 0x0184(t3)          // remember temp variable 3
    sw      t6, 0x0008(at)
    li      at, initializing_hbox   // at = address of initializing_hbox
    lbu     t6, 0x018C(t3)          // get flag initializing/ending hitboxes
    sw      t6, 0x0000(at)          // remember flag
    li      at, kinetic_state       // at = address of kinetic_state
    lw      t6, 0x014C(t3)          // get Kinetic State (0 = grounded, 1 = aerial)
    sw      t6, 0x0000(at)          // remember Kinetic state

    OS.save_registers()
    jalr    ra, t9                  // (call update function)
    nop
    OS.restore_registers()

    // handle if hitbox is initializing from extra update
    lw      t3, 0x0084(a0)          // t3 = player struct
    lbu     t6, 0x018C(t3)          // get flag initializing/ending hitboxes
    li      at, initializing_hbox   // at = address of initializing_hbox
    lw      at, 0x0000(at)          // load flag
    bnel    at, t6, _end            // skip running twice if initializing/ending hitboxes
    lli     t3, OS.TRUE             // t3 = skip
    // handle if Kinetic State changed
    lw      t6, 0x014C(t3)          // get Kinetic State (0 = grounded, 1 = aerial)
    li      at, kinetic_state       // at = address of kinetic_state
    lw      at, 0x0000(at)          // load flag
    bnel    at, t6, _end            // skip running twice if Kinetic State changed
    lli     t3, OS.TRUE             // t3 = skip
    // check if Temporary flags changed
    lw      t3, 0x0084(a0)          // t3 = player struct
    li      at, moveset_flag_vars   // at = address of moveset_flag_vars
    lw      t6, 0x017C(t3)          // load temp variable 1
    lw      at, 0x0000(at)          // load stored value 1
    bnel    at, t6, _end            // skip running twice if it changed value
    lli     t3, OS.TRUE             // t3 = skip
    li      at, moveset_flag_vars   // at = address of moveset_flag_vars
    lw      t6, 0x0180(t3)          // load temp variable 2
    lw      at, 0x0004(at)          // load stored value 2
    bnel    at, t6, _end            // skip running twice if it changed value
    lli     t3, OS.TRUE             // t3 = skip
    li      at, moveset_flag_vars   // at = address of moveset_flag_vars
    lw      t6, 0x0184(t3)          // load temp variable 3
    lw      at, 0x0008(at)          // load stored value 3
    bnel    at, t6, _end            // skip running twice if it changed value
    lli     t3, OS.TRUE             // t3 = skip
    // otherwise, set to run a second time
    // note: here we use 0 (normal) and not 2 (twice) because it already ran above
    lli     t3, OS.FALSE            // t3 = normal

    _end:
    jr      ra                      // return
    nop
}

// Temporary Variables to compare
moveset_flag_vars:
dw 0,0,0
initializing_hbox:
dw 0
kinetic_state:
dw 0

scope physics_map: {
    OS.patch_start(0x5D888, 0x800e2088)
    j       hitlag_check_1          // various physics
    nop
    nop
    _return_1:
    OS.patch_end()
    OS.patch_start(0x5DC0C, 0x800E240C)
    j       hitlag_check_2          // ftMainUpdateMotionEventsDefaultEffect
    nop
    nop
    _return_2:
    OS.patch_end()
    OS.patch_start(0x5DC20, 0x800E2420)
    j       hitlag_check_3          // proc_accessory
    nop
    nop
    _return_3:
    OS.patch_end()

    // if we're on a Slow 'freeze' frame, take hitlag branch to skip stuff
    hitlag_check_1:
    lw      t3, 0x0008(t8)               // original line 1
    sw      t3, 0x0008(t9)               // original line 2
    li      t4, function_abbr            // t4 = function_abbr flag
    lw      t4, 0x0000(t4)               // t4 = 1 if on a 'freeze' frame
    beqzl   t4, pc() + 8                 // only need to load hitlag if flag was false
    lw      t4, 0x0040(s1)               // t4 = player hitlag (original line 3)
    j       _return_1
    nop

    // hitlag branch for moveset commands (ftMainUpdateMotionEventsDefaultEffect)
    hitlag_check_2:
    jal     0x800EB528                   // original line 1
    lw      a0, 0x08E8(s1)               // original line 2
    li      v0, function_abbr            // v0 = function_abbr flag
    lw      v0, 0x0000(v0)               // v0 = 1 if on a 'freeze' frame
    beqzl   v0, pc() + 8                 // only need to load hitlag if flag was false
    lw      v0, 0x0040(s1)               // v0 = player hitlag (original line 3)
    j       _return_2
    nop

    // hitlag branch for updating 'proc_accessory'
    hitlag_check_3:
    jal     0x800e0654                   // original line 1
    lw      a0, 0x0070(sp)               // original line 2
    li      v0, function_abbr            // v0 = function_abbr flag
    lw      v0, 0x0000(v0)               // v0 = 1 if on a 'freeze' frame
    beqzl   v0, pc() + 8                 // only need to load hitlag if flag was false
    lw      v0, 0x0040(s1)               // v0 = player hitlag (original line 3)
    j       _return_3
    nop
}

// scope proc_update: {

    // // OS.patch_start(0x5CEB4, 0x800E16B4)
    // // j       hitlag_check_4               // hitlag countdown -> lagend
    // // nop
    // // _return_4:
    // // OS.patch_end()
    // OS.patch_start(0x5CEEC, 0x800E16EC)
    // j       hitlag_check_5               // ftMainPlayAnimNoEffect
    // nop
    // _return_5:
    // OS.patch_end()
    // OS.patch_start(0x5D158, 0x800E1958)
    // j       hitlag_check_6               // various stuff + kinetics
    // nop
    // _return_6:
    // OS.patch_end()

    // // hitlag_check_4:
    // // li      v0, function_abbr            // v0 = function_abbr flag
    // // lw      v0, 0x0000(v0)               // v0 = 1 if on a 'freeze' frame
    // // bnez    v0, _j_0x800E16E8            // skip if so (?)
    // // nop
    // // lw      v0, 0x0040(a2)               // v0 = player hitlag (original line)
    // // beqz    v0, _j_0x800E16E8            // original line 1
    // // addiu   t4, v0, 0xFFFF               // original line 2
    // // j       _return_4
    // // nop
    // // _j_0x800E16E8:
    // // j       0x800E16E8                   // original line 1, modified to jump
    // // nop

    // hitlag_check_5:
    // ori     t2, t9, 0x0080               // original line 2
    // li      t3, function_abbr            // t3 = function_abbr flag
    // lw      t3, 0x0000(t3)               // t3 = 1 if on a 'freeze' frame
    // beqzl   t3, pc() + 8                 // only need to load hitlag if flag was false
    // lw      t3, 0x0040(a2)               // t3 = player hitlag (original line 1)
    // j       _return_5
    // nop

    // hitlag_check_6:
    // li      t3, function_abbr            // t3 = function_abbr flag
    // lw      t3, 0x0000(t3)               // t3 = 1 if on a 'freeze' frame
    // beqzl   t3, pc() + 8                 // only need to load hitlag if flag was false
    // lw      t3, 0x0040(a2)               // t3 = player hitlag (original line)
    // bnezl   t3, _j_0x800E1CD0            // original line 1
    // mtc1    r0, f14                      // original line 2
    // j       _return_6
    // nop
    // _j_0x800E1CD0:
    // j       0x800E1CD0                   // original line 1, modified to jump
    // nop
// }

// @ Description
// Clears the pointers for Stopwatch users
scope clear_active_stopwatch_: {
    li      t8, watch_routine_          // t8 = array to clear
    sw      r0, 0x0000(t8)              // ~
    li      t8, engine_speed_timer      // t8 = thing to clear
    sw      r0, 0x0000(t8)              // ~
    li      t8, clocked_out_players_    // t8 = table to clear
    sw      r0, 0x0000(t8)              // clear table
    sw      r0, 0x0004(t8)              // ~
    sw      r0, 0x0008(t8)              // ~
    sw      r0, 0x000C(t8)              // ~
    sw      r0, 0x0010(t8)              // ~
    sw      r0, 0x0014(t8)              // ~
    sw      r0, 0x0018(t8)              // ~
    sw      r0, 0x001C(t8)              // ~
    li      t8, backfire_bg_object      // t8 = object to clear
    sw      r0, 0x0000(t8)              // ~
    li      t8, watch_speed_flag        // t8 = flag to clear
    sb      r0, 0x0000(t8)              // ~
    li      t8, fast_or_slow_           // t8 = flag to clear
    sb      r0, 0x0000(t8)              // ~
    li      t8, projectile_ID_speed_limit  // t8 = flag to clear
    sw      r0, 0x0000(t8)                 // ~
    li      t8, function_abbr           // t8 = flag to clear
    sw      r0, 0x0000(t8)              // ~
    li      t8, player_affected         // t8 = flag to clear
    sb      r0, 0x0000(t8)              // ~
    li      t8, watch_end_FGM_playing   // t8 = flag to clear
    jr      ra                          // ~
    sb      r0, 0x0000(t8)              // clear ptrs
}

// @ Description
// Flag to keep track of speed of watches (0 if inactive)
watch_speed_flag:
db 0
// Flag to keep track of which FGM we play (0 = normal, 1 = backfire)
watch_FGM:
db 0
// Flag to keep track if we're currently playing FGM
watch_end_FGM_playing:
db 0
// Flag to keep track of if any players were affected by Stopwatch
player_affected:
db 0
// @ Description
// Flag to indicate whether we are speeding up (1) or slowing down (0)
fast_or_slow_:
db 0
OS.align(4)

// Flag to indicate that we need to skip part of function
function_abbr:
dw 0

// @ Description
// Flag to assist blacklisting Projectiles
// Future Proofing (So far only been needed for PK Thunder 'head')
// (First halfword written for Slow, second for Fast)
projectile_ID_speed_limit:
dh 0,0

// @ Description
// Appropriate duration for the selected Game Engine speed
// Note: this is used ONLY if we roll a "affect everybody" spin
// (we have duration per-port below)
engine_speed_timer:
dw   0x00000000

// @ Description
// Pointer to current routine handler object for stopwatch.
watch_routine_:
dw   0x00000000

// @ Description
// Timers for Players currently affected by Stopwatch
clocked_out_players_:
db   0, 0, 0, 0; dh 0; dh 0    // Delay Timer, Delay ('active'/'total' frames), 0; Remaining Time, Fast (1) or Slow (0) flag
dw   0, 0
dw   0, 0
dw   0, 0

// @ Description
// Rectangle object reference for BG effect during backfire
backfire_bg_object:
dw   0
// Color table for BG, corresponding with speed
backfire_bg_colors:
dw   0x0066AA77          // slow down (blue)
dw   0xA1333399          // speed up  (red)

// We randomly select an entry from this table (with weighted odds, 1/20)
// Note: speeds match up with 'game_speed' toggle values
// Old Note: omitted 3.0x and 1/8 from being picked because they aren't fun to randomly get
speed_table:
db 1,1,1,1,1             // 1.2x speed
db 2,2,2,2,2,2           // 1.3x speed
                         // 1.4x speed
db 4,4                   // 1.5x speed
                         // 1.6x speed
                         // 1.75 speed
                         // 2.0x speed
                         // 3.0x speed
                         // 1/8 speed
                         // 1/6 speed
                         // 1/5 speed
                         // 1/4 speed
                         // 1/3 speed
db 14,14                 // 1/2 speed
db 15,15,15,15,15        // 2/3 speed
                         // 3/4 speed
OS.align(4)

slow_speed_table:
db 1,3,1,3                                // 1/4 speed
db 1,2,1,2,1,2,1,2                        // 1/3 speed
db 1,1,1,1,1,1,1,1,1,1,1,1                // 1/2 speed
db 2,2,2,2,2,2,2,2                        // 2/3 speed
OS.align(4)
fast_speed_table:
db 5,5,5,5,5,5,5,5,5,5,5,5,5,5            // 1.2x speed
db 3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3    // 1.3x speed
db 2,2,2,2,2,2,2,2                        // 1.5x speed
OS.align(4)

// @ Description
// This prevents the game from crashing if a platform disappears while a player is standing on it,
// which is seemingly only a problem with stopwatch active.
scope platform_despawn_shadow_crash_fix: {
    OS.patch_start(0xB5A54, 0x8013B014)
    j       platform_despawn_shadow_crash_fix
    swc1    f4, 0x0090(sp)              // original line 2
    _return:
    OS.patch_end()

    // v0 = player struct

    OS.read_word(Global.stage_clipping.info, v1) // v1 = stage clipping info

    lw      t0, 0x00EC(v0)              // t0 = clipping ID
    // copied below from 0x800F4240
    sll     t7, t0, 2
    addu    t7, t7, t0
    sll     t7, t7, 1
    addu    t8, v1, t7                  // t8 = offset to clipping struct
    lbu     t9, 0x0000(t8)
    lui     t7, 0x8013
    lw      t7, 0x1304(t7)
    sll     v1, t9, 2
    addu    t8, t7, v1
    lw      t2, 0x0000(t8)
    lw      t9, 0x0084(t2)              // get clipping status
    slti    at, t9, 0x0003              // if cliff >= 3, at = 0

    bnez    at, _original               // normal logic
    nop

    // if here, the platform disappeared
    jal     0x8013F9E0                  // set aerial idle
    lw      a0, 0x0004(v0)              // a0 = player obj

    addiu   a1, sp, 0x0124              // restore a1
    addiu   a2, sp, 0x0090              // restore a2
    or      a3, r0, r0                  // restore a3
    j       _return                     // skip the branch to treat as aerial case
    lw      v0, 0x0140(sp)              // restore player struct

    _original:
    j       0x8013B03C                  // original line 1, modified to jump
    nop
}