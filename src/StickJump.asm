// Stick Jump by Halofactory
// @halofactorymoon

// @ Description
// These constants must be defined for a menu item.
define LABEL("Tap Jump")
constant VALUE_TYPE(CharacterSelectDebugMenu.value_type.STRING)
constant MIN_VALUE(0)
constant MAX_VALUE(1)
constant DEFAULT_VALUE(0)
// bitmask: [vs] [1p] [training] [bonus1] [bonus2] [allstar]
constant APPLIES_TO(0b111111)
// bitmask: [human] [cpu]
constant APPLIES_TO_HUMAN_CPU(0b10)
constant VALUE_ARRAY_POINTER(StickJump.stick_jump_table)
constant ONCHANGE_HANDLER(0)
constant DISABLES_HIGH_SCORES(OS.FALSE)

// @ Description
// Holds pointers to value labels
string_table:
dw string_on
dw string_off

// @ Description
// Value labels
string_on:; String.insert("On")
string_off:; String.insert("Off")

constant UP_SMASH_DEADZONE(10)

// @ Description
// Check if tap jump disabled before multi air jump
// s0 = player struct, a1 = jump type (2 = cpad, 1 = stick)
// v0 and a3 safe to use
scope check_jump_type_kirby_: {
    OS.patch_start(0xBA98C, 0x8013FF4C)
    j        check_jump_type_kirby_
    lw        at, 0x0020(s0)            // check if cpu
    _return:
    OS.patch_end()

    bnezl    at, _original            // do normal branch if CPU player
    addiu    at, r0, 0x0008            // og line 1

    addiu    at, r0, 0x0002            // skip if c-jump
    beql    at, a1, _original
    addiu    at, r0, 0x0008            // og line 1

    // if here, player is holding up 
    lb        at, 0x000D(s0)            // at = player port
    li        a3, stick_jump_table    // a3 = stick jump table
    sll        at, at, 0x0002
    addu    a3, a3, at                // a3 = player entry in stick_jump_table
    lw        at, 0x0000(a3)            // at = entry
    beqzl    at, _original            // branch if disabled
    addiu    at, r0, 0x0008            // og line 1
    
    // if here, stick jump is disabled
    // check if player is holding C
    lh      at, 0x01BC(s0)              // at =  buttons held
    andi    at, at, 0x000F              // at = 0 if no c buttons are held
    bnez    at, _original
    addiu   at, r0, 0x0008
    j       0x8014011C                // if here, skip whole routine (don't jump)
    lw      ra, 0x0024(sp)
    
    _original:
    //     addiu    at, r0, 0x0008        // og line 1 (in delay slots)
    addiu    a2, r0, 0x0000            // og line 2
    j        0x8013FF58                // original logic
    lw        v0, 0x0008(s0)
}

// @ Description
// Check if tap jump disabled before performing a stick jump while idle. grounded or aerial
scope check_jump_type_idle_: {
    OS.patch_start(0xB9ECC, 0x8013F48C)
    j        check_jump_type_idle_
    lw        at, 0x0020(a0)            // check if cpu
    _return:
    OS.patch_end()
    
    // a0 = player struct
    
    bnezl    at, _normal                // do normal branch if CPU player
    lbu        t7, 0x0269(a0)            // original line 1, get stick angle
    lb        at, 0x000D(a0)            // at = player port
    li        t7, stick_jump_table    // t7 = stick jump table
    sll        at, at, 0x0002
    addu    t7, t7, at                // t7 = player entry in stick_jump_table
    lw        at, 0x0000(t7)            // at = entry
    
    beqzl    at, _normal                // proceed normally if it's disabled.
    lbu        t7, 0x0269(a0)            // original line 1, get stick angle

    srl        at, at, 0x0001
    beqz    at, _end                // branch if disabled
    nop
    
    // if here, check if grounded
    lw        at, 0x014C(a0)            // at = kinetic state
    bnezl    at, _end                // branch if aerial
    lli        at, 0x0000                // return 0
    lbu        t7, 0x0269(a0)            // original line 1, get stick angle
    
    _normal:
    slti    at, t7, 0x0004            // original line 2

    _end:
    j        _return
    nop

}

// @ Description
// Check if tap jump disabled before performing a stick jump (during dash, run)
// Can initiate an up special or smash attack if A or B held.
scope check_jump_type_running_: {
    OS.patch_start(0xB9F94, 0x8013F554)
    j        check_jump_type_running_
    lw        at, 0x0020(a0)            // check if cpu
    _return:
    OS.patch_end()
    
    // a0 = player struct
    bnez    at, _normal                 // do normal branch if CPU player
    lbu     t7, 0x0269(a0)              // original line 1, get stick angle
    lb      at, 0x000D(a0)              // at = player port
    li      t7, stick_jump_table        // t7 = stick jump table
    sll     at, at, 0x0002
    addu    t7, t7, at                  // t7 = player entry in stick_jump_table
    lw      at, 0x0000(t7)              // at = entry
    
    beqzl   at, _normal                 // proceed normally if stick jump enabled
    lbu     t7, 0x0269(a0)              // original line 1, get stick angle
    
    // tap jump is disabled
    _check_up_special:
    lh      t7, 0x01BE(a0)              // get button pressed
    andi    at, t7, Joypad.B            // check if B pressed
    bnezl   at, _up_special             // USP if B pressed
    lw      t2, 0x0008(a0)              // get character id

    _check_up_smash:
    lh      t7, 0x01BE(a0)              // get button pressed
    andi    at, t7, Joypad.A            // check if A pressed
    bnez    at, _no_jump_normal         // no USP if A pressed
    lh      t7, 0x01BC(a0)              // get buttons held
    andi    at, t7, Joypad.A            // check if A held
    beqzl   at, _no_jump_normal         // branch if A not held
    nop
    
    _up_smash:
    jal     0x801505F0                  // do up smash
    lw      a0, 0x0004(a0)              // argument = player object
    b       _exit_initial
    nop
    
    _dash_attack:
    jal      0x8014F670                 // do dash attack
    lw        a0, 0x0004(a0)            // argument = player object
    b        _exit_initial
    nop

    _up_special:
    constant UPPER(Character.ground_usp.table >> 16)
    constant LOWER(Character.ground_usp.table & 0xFFFF)
    if LOWER > 0x7FFF {
        lui     t7, (UPPER + 0x1)   // original line 1 (modified)
    } else {
        lui     t7, UPPER           // original line 1 (modified)
    }
    sll     at, t2, 0x2
    addu    t7, t7, at
    lw      t7, LOWER(t7)
    beqz    t7, _exit_initial       // exit if no NSP routine (idk why there wouldn't be one)
    nop
    // if here, polygon check
    lw      at, 0x09C8(a0)          // at = attributes table
    lh      at, 0x0102(at)          // at = up b enabled flag
    beqz    at, _exit_initial
    nop

    // do usp
    jalr    ra, t7                  // do characters ground NSP routine
    lw      a0, 0x0004(a0)          // argument = player object
     
    _exit_initial:
    addiu   sp, sp, 0x18            // deallocate stackspace
    lw      ra, 0x0014(sp)          // get return address
    li      at, 0x8013EEB4          // at = RA while in a run action
    bnel    at, ra, _no_jump_normal // branch if not running (usually because dashing)
    addiu   sp, sp, -0x18           // re-allocate stackspace
    j       0x8013EED8              // go to end of routine for running
    lli     v0, 0x0001              // return 1 (don't transition to run stop)
    
    _no_jump_normal:
    j        _return
    lli      at, 0x0000             // return 0 (no jump)

    _normal:
    j       _return
    slti    at, t7, 0x0004          // original line 2

}

// the following was used to prevent dash attack if player is pointing stick up, it was causing too many issues

// Description
// hook into dash attack initial. disables dash attack if tap jump disabled and stick pointing up
// scope dash_attack_check_: {
    // OS.patch_start(0xCA170, 0x8014F730)
    // j        dash_attack_check_
    // lw        at, 0x0020(v0)        // check if cpu
    // OS.patch_end()

    // bnez    at, _dash_attack        // do normal branch if CPU player
    // lb      at, 0x000D(v0)          // at = player port
    // li      a1, stick_jump_table    // a1 = stick jump table
    // sll     at, at, 0x0002
    // addu    a1, a1, at              // a1 = player entry in stick_jump_table
    // lw      at, 0x0000(a1)          // at = entry

    // beqzl   at, _dash_attack        // proceed normally if it's disabled.
    // nop

    // // if here, tap jump disabled
    // lbu     a1, 0x01C3(v0)          // get stick Y
    // srl     at, a1, 0x0007
    // bnez    at, _dash_attack        // dash attack if pointing stick downwards
    // nop
    // // if here, stick Y is => 0, check dead zone
    // slti    at, a1, UP_SMASH_DEADZONE // at = 0 if UP_SMASH_DEADZONE or greater
    // bnez    at, _dash_attack        // dash attack if stick Y not pointing anywhere
    // nop

    // // if here, then skip dash attack
    // _up_smash:
    // j        0x8014F744             // return to original routine
    // addiu    v0, r0, 0x0001         // return 1

    // _dash_attack: // checks for dash attack
    // jal      0x8014F670             // original line 1
    // nop
    // j        0x8014F744             // return to original routine
    // addiu    v0, r0, 0x0001         // return 1

// }

// tap jump
// 0 = on
// 1 = off

stick_jump_table:
dw  0
dw  0
dw  0
dw  0
