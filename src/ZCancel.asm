// ZCancel.asm
if !{defined __ZCancel__} {
define __ZCancel__()

include "Color.asm"
include "Global.asm"
include "OS.asm"
include "String.asm"
include "Toggles.asm"

// @ Description
// Z Cancel stuff
scope ZCancel {

    // @ Description
    // An optional toggle to spice things up
    scope _cruel_z_cancel: {
        scope CRUEL_Z_CANCEL_MODE: {
            constant OFF(0)
            constant ON(1)
            constant LAVA(2)
            constant SHIELD_BREAK(3)
            constant INSTANT_KO(4)
            constant FORCE_TAUNT(5)
            constant BURY(6)
            constant LAUGH_TRACK(7)
            constant EGG(8)
            constant SLEEP(9)
            constant TRIP(10)
            constant SWAP_MUSIC(11)
            constant RANDOM(12)
        }

        OS.patch_start(0xCB488, 0x80150A48)
        j       _cruel_z_cancel
        lw      t7, 0x09C4(v1)           // original line 1
        _cruel_z_cancel_return:
        OS.patch_end()

        li      at, ZCancel.missed_z_cancels
        lbu     t8, 0x000D(v1)              // t8 = player index (0 - 3)
        sll     t8, t8, 0x0002              // t8 = player index * 4
        addu    at, at, t8                  // at = address of missed z-cancels for this player
        lw      t8, 0x0000(at)              // t8 = missed z-cancel count
        addiu   t8, t8, 0x0001              // increment
        sw      t8, 0x0000(at)              // store updated z-cancel count

        OS.read_word(Toggles.entry_punish_on_failed_z_cancel + 0x4, t8) // t8 = failed z cancel toggle
        beqz    t8, _end                 // branch if no extra punishment
        lw      t9, 0x0028(v1)           // original line 2

        li      at, _last_known_speed_value
        sw      v0, 0x0000(at)          // save last known landing speed (in case invulnerable)

        OS.read_word(0x800A50E8, at)     // at = ptr to match info
        lb      v0, 0x0000(at)           // v0 = current screen id
        addiu   at, r0, 3                // at = how to play screen id
        bne     at, v0, _get_entry       // skip if current screen id != how to play
        nop
        li      at, _last_known_speed_value
        b       _end
        lw      v0, 0x0000(at)           // load last known landing speed

        _get_entry:
        li      at, jump_table
        sll     t8, t8, 2
        addu    t8, at, t8              // t8 = entry in jump table
        lw      t8, -0x0004(t8)         // ~
        jr      t8
        nop

        jump_table:
        dw  _on
        dw  _lava
        dw  _shield_break
        dw  _instant_ko
        dw  _force_taunt
        dw  _bury
        dw  _laugh
        dw  _egg
        dw  _sleep
        dw  _trip
        dw  _swap_music
        dw  _random

        _swap_music:
        // respect 'Play Music' toggle
        li      t0, Toggles.entry_play_music
        lw      t0, 0x0004(t0)              // t0 = 0 if music is toggled off
        beqz    t0, _swap_music_end         // skip if music is toggled off
        nop
        OS.save_registers()

        // this block loads from the random list using a random int
        li      t0, ZCancel._cruel_z_cancel._swapping_music
        addiu   t8, r0, 0x0001              // ~
        sw      t8, 0x0000(t0)              // set _swapping_music to 1
        jal     BGM.random_music_
        nop
        li      t0, ZCancel._cruel_z_cancel._swapping_music
        sw      r0, 0x0000(t0)              // set _swapping_music to 0
        beqz    v1, _swap_music_restore     // if there were no valid entries in the random table, then don't do anything
        nop
        move    a0, v1                      // a0 - range (0, N-1)

        jal     Global.get_random_int_      // v0 = (0, N-1)
        nop
        li      t0, BGM.random_table        // t0 = random_table
        sll     v0, v0, 0x0002              // v0 = offset = random_int * 4
        addu    t0, t0, v0                  // t0 = random_table + offset
        lw      a1, 0x0000(t0)              // a1 = bgm_id
        b       _play_random
        nop

        _play_random:
        li      a0, BGM.current_track       // a0 = address of current_track
        sw      a1, 0x0000(a0)              // store current_track
        li      t1, BGM.vanilla_current_track // t1 = hardcoded spot for current track
        sw      a1, 0x0000(t1)              // save as override track (vanilla)
        lw      at, 0x0004(t1)              // at = stage music (vanilla)
        sw      a1, 0x0004(t1)              // save as stage music (vanilla)
        beq     at, a1, _swap_music_restore // don't change the music if it's the same track
        nop
        lui     a0, 0x8013
        lw      a0, 0x1300(a0)              // a0 = stage file
        sw      a1, 0x007C(a0)              // store bgm_id

        jal     BGM.play_                   // play music
        addiu   a0, r0, 0x0000

        _swap_music_restore:
        OS.restore_registers()
        _swap_music_end:
        li      at, _last_known_speed_value
        lw      v0, 0x0000(at)           // load last known landing speed
        b       _end                     // branch to end
        lw      t9, 0x0028(v1)           // original line 2

        _trip:
        lbu     at, 0x000D(v1)              // at = player index (0 - 3)
        li      a1, Tripping.tripping.player_trip_flag
        addu    a1, a1, at                  // a1 = address of trip flag for this player
        sb      at, 0x0000(a1)              // at = clear trip flag (just in case)

        addiu   a1, r0, 0x0008              // a1 = 8 frames (note: hitstun needs to be higher value than 'action frame' count)
        sh      a1, 0x0B1A(v1)              // a1 = put player in hitstun

        addiu   a1, r0, Action.DamageLow3   // a1 = DamageLow3 action (0x02D)
        or      a2, r0, r0                  // a2(starting frame) = 0
        lui     a3, 0x3F80                  // a3(frame speed multiplier) = 1.0
        jal     0x800E6F24                  // change action
        sw      r0, 0x0010(sp)              // argument 4 = 0

        // play sound effect
        lli     a0, 0x0456                  // tripstart
        jal     FGM.play_                   // play sfx
        nop

        lw      v1, 0x001C(sp)              // restore player struct
        lbu     at, 0x000D(v1)              // at = player index (0 - 3)
        li      t0, Tripping.tripping.player_trip_flag
        addu    t0, t0, at                  // t0 = address of trip flag for this player
        addiu   at, r0, 0x0001
        sb      at, 0x0000(t0)              // at = update trip flag (true)

        j       0x80150AF0 + 0x4         // and skip to end
        lw      ra, 0x0014(sp)

        _sleep:
        jal     0x801499A4               // set fighter status to sleep
        nop
        j       0x80150AF0 + 0x4         // and skip to end
        lw      ra, 0x0014(sp)

        _on:
        lli     t8, 0x0012               // t8 =  custom surface flag (damage, minimal KB)
        li      at, _last_known_speed_value
        lw      v0, 0x0000(at)           // load last known landing speed
        sh      t8, 0x00F6(v1)           // overwrite surface flag to bring pain to this player

        _end:
        j      _cruel_z_cancel_return + 0x4  // return
        lw     t8, 0x0064(t7)            // original line 3

        _lava:
        lli     t8, 0x001E               // t8 =  cruel lava flag (damage + KB)
        li      at, _last_known_speed_value
        lw      v0, 0x0000(at)           // load last known landing speed (in case invulnerable)
        j       _cruel_z_cancel_return   // return
        sh      t8, 0x00F6(v1)           // overwrite surface flag to bring pain to this player

        _force_taunt:
        jal     0x8014E6E0               // set to taunt action
        nop
        j       0x80150AF0 + 0x4         // and skip to end
        lw      ra, 0x0014(sp)

        _bury:
        jal     Damage.bury_initial_     // bury player
        addiu   a1, r0, 0x0001           // a1 = bury this player
        j       0x80150AF0 + 0x4         // and skip to end
        lw      ra, 0x0014(sp)

        _egg:
        sw      r0, 0x0B18(v1)              //

        addiu   a1, r0, Action.EggLay       // set to egg
        or      a2, r0, r0                  // a2(starting frame) = 0 (doesn't do anything here?)
        lui     a3, 0x3F80                  // a3(frame speed multiplier) = 1.0
        jal     0x800E6F24                  // change action
        sw      r0, 0x0010(sp)              // argument 4 = 0
        jal     0x8014CF0C                  // yoshi egg timer
        lw      a0, 0x0020(sp)              // restore player obj
        lw      a0, 0x0020(sp)              // restore player obj
        lw      t0, 0x0084(a0)              // t0 = player struct
        lh      t1, 0x018C(t0)              // t1 = Common bitfield player flags
        addiu   at, r0, 1                   // at = 1 (player hidden)
        or      t1, t1, at                  // ~
        sh      t1, 0x018C(t0)              // update bitfield

        j       0x80150AF0 + 0x4            // and skip to end
        lw      ra, 0x0014(sp)

        _random:
        lli     a0, CRUEL_Z_CANCEL_MODE.RANDOM - 1 // arg0 = max value - 1
        jal     Global.get_random_int_      // returns a random value from 1 to CRUEL_Z_CANCEL_MODE.RANDOM
        nop
        addiu   v0, v0, 1                   // increase value by 1 so we don't get no punishment
        lw      v1, 0x001C(sp)              // restore
        lw      a0, 0x0020(sp)              // ~
        beqz    v0, _end
        lw      t9, 0x0028(v1)              // original line 2
        b       _get_entry                  // do punishment
        or      t8, v0, r0                  // t8 = random punishment


        _shield_break:
        jal     0x80149488               // set to shield break action
        nop
        lw      v1, 0x001C(sp)           // v1 = player struct
        lui     at, 0x4280               // overwrite vertical velocity
        sw      at, 0x004C(v1)           // ~

        j       0x80150AF0 + 0x4         // and skip to end
        lw      ra, 0x0014(sp)

        _instant_ko:
        li      t0, Global.current_screen   // ~
        lbu     t0, 0x0000(t0)              // t0 = current screen
        addiu   at, r0, 0x0001              // at = 1P mode screen_id
        
        bne     t0, at, _instant_ko_normal  // continue normal path if not on 1p screen (as well as title screen)
        nop
        
        li      at, SinglePlayerModes.STAGE_FLAG
        lb      at, 0x0000(at)           // load current stage
        addiu   t0, r0, 0x000D           // final stage ID
        
        bne     t0, at, _instant_ko_normal  // continue normal path if not on 1p screen (as well as title screen)
        nop
        
        li      at, 0x80131580           // load "match off" byte (gets turned on after fight ends and when pause pressed
        lbu     at, 0x0000(at)
        beqz    at, _instant_ko_skip     // if "match off" byte is set to 0, then you shouldn't be able to KO in the 1p Final Boss (this should possibly always be the case)
        nop
        
        _instant_ko_normal:
        lw      t0, 0x0084(a0)           // t0 = player struct
        sw      r0, 0x0A20(t0)           // clear Overlay Routine
        sw      r0, 0x0A24(t0)           // clear Overlay Routine
        sw      r0, 0x0A28(t0)           // clear Overlay Routine
        sw      r0, 0x0A30(t0)           // clear Overlay Flag
        sw      r0, 0x0A88(t0)           // clear current Overlay
        jal     0x8013C1C4               // set to KO action
        nop
        
        _instant_ko_skip:
        j       0x80150AF0 + 0x4         // and skip to end
        lw      ra, 0x0014(sp)

        _laugh:
        OS.save_registers()
        FGM.play(0x524)                 // audience laugh
        OS.restore_registers()
        li      at, _last_known_speed_value
        lw      v0, 0x0000(at)           // load last known landing speed
        b       _end                     // branch to end
        lw      t9, 0x0028(v1)           // original line 2

        _last_known_speed_value:
        dw 0

        _swapping_music:
        dw 0
    }

    // @ Description
    // Z Cancel options
    scope _z_cancel_opts: {
        OS.patch_start(0xCB480, 0x80150A40)
        j       _z_cancel_opts
        nop
        _z_cancel_opts_return:
        OS.patch_end()
        // s1 = player struct
        // t6 is safe
        // at is boolean for a CPU z cancel that was set in 'AI.z_cancel_'

        bnez    at, _cpu_z_cancel           // branch accordingly
        nop

        li      t6, Toggles.entry_z_cancel_opts
        lw      t6, 0x0004(t6)              // t0 = 0 for DEFAULT, 1 for Disabled, 2 for Melee, 3 for Auto, 4 for Glide
        beqz    t6, _default                // branch accordingly
        lli     at, 0x0001                  // t1 = 1 (Disabled)
        beq     at, t6, _return             // branch accordingly
        lli     at, 0x0002                  // t1 = 2 (Melee)
        beq     at, t6, _z_cancel_melee     // branch accordingly
        lli     at, 0x0003                  // t1 = 3 (Auto)
        beq     at, t6, _z_cancel_success   // branch accordingly
        lli     at, 0x0004                  // t1 = 4 (Glide)
        beq     at, t6, _default            // branch accordingly
        nop

        // if we're here, this is a CPU z cancel
        _cpu_z_cancel:
        li      t6, Toggles.entry_z_cancel_opts
        lw      t6, 0x0004(t6)              // t0 = 0 for DEFAULT, 1 for Disabled, 2 for Melee, 3 for Auto, 4 for Glide
        beqz    t6, _z_cancel_success       // branch accordingly
        lli     at, 0x0001                  // t1 = 1 (Disabled)
        beq     at, t6, _return             // branch accordingly
        lli     at, 0x0002                  // t1 = 2 (Melee)
        beq     at, t6, _z_cancel_success   // branch accordingly
        lli     at, 0x0003                  // t1 = 3 (Auto)
        beq     at, t6, _z_cancel_success   // branch accordingly
        lli     at, 0x0004                  // t1 = 4 (Glide)
        beq     at, t6, _z_cancel_miss      // branch accordingly
        nop

        // Melee cancel window (7 frames instead of 11)
        _z_cancel_melee:
        lw      t6, 0x0160(v1)          // t6 = frames since 'Z' pressed
        slti    at, t6, 0x0007          // melee window is 0x07 (7 frames)
        b       _z_cancel_check
        nop

        _default:
        lw      t6, 0x0160(v1)          // t6 = frames since 'Z' pressed
        slti    at, t6, 0x000B          // default window is 0x0B (11 frames)
        _z_cancel_check:
        beqz    at, _z_cancel_miss
        nop

        _z_cancel_success:
        // bnezl   at, 0x80150AC0       // original line 1 (need to 'j' instead of 'b')
        li      at, ZCancel.successful_z_cancels
        lbu     t6, 0x000D(s1)              // t6 = player index (0 - 3)
        sll     t6, t6, 0x0002              // t6 = player index * 4
        addu    at, at, t6                  // at = address of successful z-cancels for this player
        lw      t6, 0x0000(at)              // t6 = successful z-cancel count
        addiu   t6, t6, 0x0001              // increment
        sw      t6, 0x0000(at)              // store updated z-cancel count

        j       0x80150AC0              // original line 1, modified
        lui     at, 0xC1A0              // original line 2

        _z_cancel_miss:
        // check for 'Glide'
        li      t6, Toggles.entry_z_cancel_opts
        lw      t6, 0x0004(t6)          // t0 = 0 for DEFAULT, 1 for Disabled, 2 for Melee, 3 for Auto, 4 for Glide
        lli     at, 0x0004              // t1 = 4 (Glide)
        bne     at, t6, _return         // branch accordingly
        nop
        lw      t7, 0x09C4(v1)          // line 3 (from below)
        lw      t9, 0x0028(v1)          // line 4 (from below)
        j       0x80150AF4              // skip landing
        lw      ra, 0x0014(sp)

        _return:
        j       _z_cancel_opts_return
        nop
    }

    // @ Description
    // Makes sure egg lay file is present if Cruel Z-Cancel is set to Egg
    scope setup_: {
        OS.read_word(Toggles.entry_punish_on_failed_z_cancel + 0x4, t8) // t8 = failed z cancel toggle
        lli     t0, _cruel_z_cancel.CRUEL_Z_CANCEL_MODE.EGG
        beq     t0, t8, _load_egg_file  // if egg, load file
        lli     t0, _cruel_z_cancel.CRUEL_Z_CANCEL_MODE.RANDOM
        bne     t0, t8, _end            // if not random, skip
        nop

        _load_egg_file:
        addiu   sp, sp, -0x0010         // allocate stack space
        sw      ra, 0x0004(sp)          // save ra

        Render.load_file(0x153, 0x80131000) // load Yoshi Eat Character Egg file to vanilla pointer

        lw      ra, 0x0004(sp)          // load ra
        addiu   sp, sp, 0x0010          // deallocate stack space

        _end:
        jr      ra
        nop
    }

    missed_z_cancels:
    dw  0x00 // p1
    dw  0x00 // p2
    dw  0x00 // p3
    dw  0x00 // p4

    successful_z_cancels:
    dw  0x00 // p1
    dw  0x00 // p2
    dw  0x00 // p3
    dw  0x00 // p4
}

}
