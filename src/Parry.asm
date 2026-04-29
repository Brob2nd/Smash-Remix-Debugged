// Parry.asm
if !{defined __PARRY__} {
define __PARRY__()
print "included Parry.asm\n"
scope Parry {
    constant PARRY_SFX(0x5BB) // sound effect used for parrying

    constant PARRY_ACTIVATION_FRAMES(0x5)

    // Is set to 1 if the user's hit was parried
    // Used to apply extra hitlag on attacker
    is_hit_parry:
    db 0x00 //p1
    db 0x00 //p2
    db 0x00 //p3
    db 0x00 //p4

    // 800E4870 + 4C8
    scope direct_hit_parry_bubble_check: {
        OS.patch_start(0x60538, 0x800E4D38)
        j       direct_hit_parry_bubble_check
        nop
        _return:
        OS.patch_end()

        Toggles.read(entry_parry, at)      // at = Parry toggle
        beqz    at, _original              // branch if toggle is disabled
        nop

        lw      a0, 0x00a0(sp) // a0 = defender struct

        // skip if in the air
        lw      at, 0x014C(a0) // t9 = kinetic state
        bnez    at, _original // branch if aerial
        nop

        _check_action:
        lw      t0, 0x0024(a0)                      // t0 = current players action
        addiu   at, r0, Action.ShieldOff            // at = ShieldOff action
        beq     t0, at, _action_passed              // branch if shield dropping
        addiu   at, r0, Action.ShieldOn             // at = ShieldOn action
        beq     t0, at, _action_passed              // branch if shield dropping
        addiu   at, r0, Action.Shield               // at = Shield action
        beq     t0, at, _action_passed              // branch if shield dropping
        nop

        b _original
        nop

        _action_passed:
        lli     at, PARRY_ACTIVATION_FRAMES // parry activation frames
        lw      t1, 0x1C(a0)                // current frame of current action
        bgt     t1, at, _original           // current frame > activation frames, too bad!
        nop

        lw      at, 0xB24(a0) // fp->status_vars.common.guard.is_release (true if shield is being released)
        beq     at, r0, _original // branch if shield is not being released
        nop

        addiu   sp, sp,-0x0070              // allocate stack space
        sw      a0, 0x0010(sp)              // ~
        sw      a1, 0x0014(sp)              // ~
        sw      a2, 0x0018(sp)              // ~
        sw      a3, 0x001C(sp)              // ~
        sw      t5, 0x0028(sp)              // ~
        sw      ra, 0x006C(sp)              // save registers

        _loop_prepare:
        addiu   t8, s1, 0x0294              // t8 = attacker first hitbox struct
        addiu   t9, t8, 0xC4 * 3            // t9 = last hitbox struct
        or      t6, r0, r0                  // t6 = 0
        or      v0, r0, r0                  // set return to false
        _loop:
        lw      t0, 0x0000(t8)              // t0 = hitbox state
        beqz    t0, _loop_check_end         // skip if hitbox is disabled
        nop

        addiu   sp, sp,-0x0070              // allocate stack space
        sw      a0, 0x0010(sp)              // ~
        sw      a1, 0x0014(sp)              // ~
        sw      a2, 0x0018(sp)              // ~
        sw      a3, 0x001C(sp)              // ~
        sw      t8, 0x0020(sp)              // ~
        sw      t9, 0x0024(sp)              // ~
        sw      ra, 0x006C(sp)              // save registers

        // a0 = defender object
        // s1 = attacker hitbox
        addiu   sp,sp,-0x30
        // function args:
        // a0 = player struct
        // a1 = hitbox pos vec3
        // a2 = hitbox prev pos vec3
        // a3 = hitbox size
        // 0x10(sp) = hitbox update mode
        lw      t0, 0x0(s1)
        sw      t0, 0x10(sp)     // hitbox update mode
        addiu   a1, s1, 0x44    // hitbox pos vec3 pointer
        lw      a3, 0x24(s1)    // hitbox size

        addiu   at, r0, 0x2
        slt     t0, at, t0 // at = 1 if hitbox is in inactive, fresh or transfer states, 0 if it is interpolate
        beqzl   at, _check_continue
        addu    a2, a1, r0 // if not interpolating, use previous_pos = current_pos
        addiu   a2, s1, 0x50 // hitbox previous pos vec3 pointer

        _check_continue:
        jal check_parry_collision // v0 = 1 if a hitbox was found in the parry range
        nop
        addiu   sp,sp,0x30

        lw      a0, 0x0010(sp)              // ~
        lw      a1, 0x0014(sp)              // ~
        lw      a2, 0x0018(sp)              // ~
        lw      a3, 0x001C(sp)              // ~
        lw      t8, 0x0020(sp)              // ~
        lw      t9, 0x0024(sp)              // ~
        lw      ra, 0x006C(sp)              // load registers
        addiu   sp, sp,0x0070               // deallocate stack space

        _loop_check_end:
        bnez    v0, _collision_detected     // if we detected a collision, break out of the loop
        nop
        bne     t8, t9, _loop               // loop if t8 != last hitbox struct
        addiu   t8, t8, 0x00C4              // t8 = next hitbox struct

        b _end                         // loop ended without finding collisions. quit
        nop

        _collision_detected:
        lw      a0, 0x0010(sp) // a0 = defender struct
        jal     activate_parry
        lw      a0, 0x0004(a0) // a0 = defender object

        _register_hit:
        // register hit: ftMainSetHitInteractStats(attacker_fp, attacker_hit->group_id, victim_gobj, nGMHitTypeShield, 0, 0);
        lw      t0, 0x0010(sp) // t0 = defender struct

        addiu   sp, sp, -0x0020             // allocate stack space
        or      a0, r0, s7   // a0 = attacker struct
        lw      a1,4(s1)     // a1 = attacker_hit->group_id
        lw      a2, 0x4(t0)  // a2 = defender object
        li      a3, 1        // a3 = nGMHitTypeShield
        sw      r0, 0x10(sp) // arg4 = 0
        sw      r0, 0x14(sp) // arg5 = False
        jal     0x800E26BC
        nop
        addiu   sp, sp, 0x0020              // deallocate stack space

        _set_parry_flag:
        // Update parry flag
        addiu   sp, sp, -0x0020             // allocate stack space
        sw      t1, 0x001C(sp)              // ~
        sw      t2, 0x0010(sp)              // ~
        sw      t3, 0x0014(sp)              // save registers

        lbu     t1, 0x000D(s7)              // t1 = attacker port
        li      t2, is_hit_parry            // ~
        addu    t3, t2, t1                  // t3 = px is_hit_parry address
        lbu     t1, 0x0000(t3)              // t2 = is_hit_parry
        addi    t1, 0x1                     // is_hit_parry += 1
        sb      t1, 0x0000(t3)              // update is_hit_parry

        lw      t1, 0x001C(sp)              // ~
        lw      t2, 0x0010(sp)              // ~
        lw      t3, 0x0014(sp)              // restore registers
        addiu   sp, sp, 0x0020              // deallocate stack space

        _calculate_hitlag:
        // Calculate hitbox hitlag
        lw      t0, 0x0010(sp) // t0 = defender struct
        lw      t1, 0xC(s1)   // t1 = hitbox damage
        lw      t2, 0x38(s1) // t2 = hitbox shield damage
        add     t1, t1, t2  // hitbox damage += shield damage

        sw t1, 0x7b0(s7) // save hitbox damage to attacker

        addiu   sp, sp, -0x0020             // allocate stack space
        sw      s1, 0x001C(sp)              // ~
        sw      t0, 0x0010(sp)              // ~
        sw      t2, 0x0014(sp)              // save registers

        // s32 gmCommon_DamageCalcHitLag(s32 damage, s32 status_id, f32 hitlag_mul)
        or  a0, r0, t1         // a0 = hitbox damage
        lw  a1, 0x0024(t0)     // a1 = current players action
        //lw a2, 0x7E0(s5)
        lui a2, 0x3F80 // TODO: should load hitlag multiplier

        jal 0x800EA1C0 // gmCommon_DamageCalcHitLag
        nop

        sw v0, 0x0040(s7) // save hitlag

        lw      s1, 0x001C(sp)              // ~
        lw      t0, 0x0010(sp)              // ~
        lw      t2, 0x0014(sp)              // restore registers
        addiu   sp, sp, 0x0020              // deallocate stack space

        lw      t0, 0x0010(sp) // t0 = defender struct
        lw      t3, 0x0040(s7) // t3 = attacker original hitlag
        addi    t3, t3, 11 // add 11
        sw      t3, 0x0040(t0) // save to defender

        _end_parried:
        lw      a0, 0x0010(sp)              // ~
        lw      a1, 0x0014(sp)              // ~
        lw      a2, 0x0018(sp)              // ~
        lw      a3, 0x001C(sp)              // ~
        lw      t5, 0x0028(sp)              // ~
        lw      ra, 0x006C(sp)              // restore registers
        j       0x800E4870+0x544            // jump out of for loop
        addiu   sp, sp,0x0070               // deallocate stack space

        _end:
        lw      a0, 0x0010(sp)              // ~
        lw      a1, 0x0014(sp)              // ~
        lw      a2, 0x0018(sp)              // ~
        lw      a3, 0x001C(sp)              // ~
        lw      t5, 0x0028(sp)              // ~
        lw      ra, 0x006C(sp)              // restore registers
        addiu   sp, sp,0x0070               // deallocate stack space

        _original:
        lw  t7, 0x018C(t5)
        lui s6, 0x8013

        j       _return
        nop
    }

    // 800E4ED4 + 3EC
    scope projectile_hit_parry_bubble_check: {
        OS.patch_start(0x60AC0, 0x800E52C0)
        j       projectile_hit_parry_bubble_check
        nop
        _return:
        OS.patch_end()

        Toggles.read(entry_parry, at)      // at = Parry toggle
        beqz    at, _original              // branch if toggle is disabled
        nop

        // skip if in the air
        lw      at, 0x014C(s7) // t9 = kinetic state
        bnez    at, _original // branch if aerial
        nop

        _check_action:
        lw      t0, 0x0024(s7)                      // t0 = current players action
        addiu   at, r0, Action.ShieldOff            // at = ShieldOff action
        beq     t0, at, _action_passed              // branch if shield dropping
        addiu   at, r0, Action.ShieldOn             // at = ShieldOn action
        beq     t0, at, _action_passed              // branch if shield dropping
        addiu   at, r0, Action.Shield               // at = Shield action
        beq     t0, at, _action_passed              // branch if shield dropping
        nop

        b _original
        nop

        _action_passed:
        lli     at, PARRY_ACTIVATION_FRAMES // parry activation frames
        lw      t1, 0x1C(s7)                // current frame of current action
        bgt     t1, at, _original           // current frame > activation frames, too bad!
        nop

        lw      at, 0xB24(s7) // fp->status_vars.common.guard.is_release (true if shield is being released)
        beq     at, r0, _original // branch if shield is not being released
        nop

        _loop_prepare:
        lw      t5, 0x50(s6)
        li      s5, 0x801311A0
        blez    t5, _end
        or      s4, r0, r0
        or      v0, r0, r0                  // set return to false
        _loop:
        // check if hitbox is active
        lw      t8, 0(s5)
        bnez    t8, _perform_check
        lw      t7, 0x88(sp)
        b       _loop_check_end // if not, skip
        lw      v0, 0x50(t7)

        _perform_check:
        addiu   sp, sp,-0x0070              // allocate stack space
        sw      a0, 0x0010(sp)              // ~
        sw      a1, 0x0014(sp)              // ~
        sw      a2, 0x0018(sp)              // ~
        sw      a3, 0x001C(sp)              // ~
        sw      t8, 0x0020(sp)              // ~
        sw      t9, 0x0024(sp)              // ~
        sw      ra, 0x006C(sp)              // save registers

        // s6 = wp_hit = hitbox
        // s7 = fp = player struct
        // s8 = wp = projectile struct
        // 0xb8(sp) = fighter obj

        addiu   sp,sp,-0x30
        // function args:
        // a0 = player struct
        // a1 = hitbox pos vec3
        // a2 = hitbox prev pos vec3
        // a3 = hitbox size
        // 0x10(sp) = hitbox update mode
        or      a0, r0, s7      // player struct

        // this wp_hit is one annoying struct
        // s6 = wp_hit
        // s4 = loop index
        sll     t8, s4, 0x2
        subu    t8, t8, s4
        sll     t8, t8, 0x5
        addu    t0, s6, t8

        lw      t1, 0x0(s6)
        sw      t1, 0x10(sp)    // hitbox update mode
        addiu   a1, t0, 0x54    // hitbox pos vec3 pointer
        lw      a3, 0x28(s6)    // hitbox size

        addiu   at, r0, 0x2
        slt     t1, at, t1 // at = 1 if hitbox is in inactive, fresh or transfer states, 0 if it is interpolate
        beqzl   at, _check_continue
        addu    a2, a1, r0 // if not interpolating, use previous_pos = current_pos
        addiu   a2, t0, 0x60 // hitbox previous pos vec3 pointer

        _check_continue:
        jal check_parry_collision // v0 = 1 if a hitbox was found in the parry range
        nop
        addiu   sp,sp,0x30

        lw      a0, 0x0010(sp)              // ~
        lw      a1, 0x0014(sp)              // ~
        lw      a2, 0x0018(sp)              // ~
        lw      a3, 0x001C(sp)              // ~
        lw      t8, 0x0020(sp)              // ~
        lw      t9, 0x0024(sp)              // ~
        lw      ra, 0x006C(sp)              // load registers
        addiu   sp, sp,0x0070               // deallocate stack space

        _loop_check_end:
        bnez    v0, _collision_detected     // if we detected a collision, break out of the loop
        nop
        lw      t9, 0x88(sp)
        lw      v0, 0x50(t9)
        addiu   s4, s4, 1
        slt     at, s4, v0
        bnez    at, _loop   // get back to loop if conditions are met
        addiu   s5, s5, 4
        b   _end // loop ended, no collisions found
        nop

        _collision_detected:
        or      a0, r0, s7      // player struct
        jal     activate_parry
        lw      a0, 0x0004(a0) // a0 = defender object
        nop

        _register_hit:
        // wpProcessUpdateHitInteractStatsGroupID(wp, wp_hit, fighter_gobj, (wp_hit->can_rehit_fighter) ? nGMHitTypeHurtRehit : nGMHitTypeHurt, 0);
        or      t0, r0, s7      // t0 = player struct

        addiu   sp, sp, -0x0020     // allocate stack space

        or      a0, r0, s8          // a0 = wp struct
        or      a1, r0, s6          // a1 = wp hit
        lw      a2, 0x4(t0)         // a2 = defender object
        lli     a3, 2               // a3 = nGMHitTypeShieldRehit
        sw      r0, 0x10(sp)        // arg4 = 0
        jal     0x8016679C
        nop

        jal     0x80168128          // v0 damage = wpMainGetStaledDamage(wp);
        or      a0, r0, s8          // a0 = wp struct
        // v0 = damage (float)

        // here we could add shield damage to the calculation, but the game doesn't do that
        // this would result in more hitlag from parrying than shielding normally
        // would still be better because no shield drop, but still wouldn't have the desired effect
        // lw      t0, 0x3C(s6) // shield damage
        // addu    v0, v0, t0 // v0 = total damage = damage + shield damage

        sw      v0, 0x234(s8) // set hitbox dealt damage for the game to despawn it

        addiu   sp, sp, 0x0020      // deallocate stack space

        _calculate_hitlag:
        // Calculate hitbox hitlag
        addiu   sp, sp, -0x0020             // allocate stack space
        sw      s1, 0x001C(sp)              // ~
        sw      a0, 0x0010(sp)              // ~
        sw      t2, 0x0014(sp)              // save registers

        // s32 gmCommon_DamageCalcHitLag(s32 damage, s32 status_id, f32 hitlag_mul)
        or  a0, r0, v0         // a0 = hitbox damage

        or      t0, r0, s7      // t0 = player struct
        lw  a1, 0x0024(t0)     // a1 = current players action
        //lw a2, 0x7E0(s5)
        lui a2, 0x3F80 // TODO: should load hitlag multiplier

        jal 0x800EA1C0 // gmCommon_DamageCalcHitLag
        nop

        beqz    v0, _save_hitlag // prevents endless hitlag if v0 = 0
        or      t0, r0, s7 // t0 = player struct

        addiu   v0, v0, -1    // hitlag -= 1
        _save_hitlag:
        sw v0, 0x0040(t0)     // save hitlag to defender

        lw      s1, 0x001C(sp)              // ~
        lw      a0, 0x0010(sp)              // ~
        lw      t2, 0x0014(sp)              // restore registers
        addiu   sp, sp, 0x0020              // deallocate stack space

        // skip to outer next object collision check
        j       (0x800E4ED4 + 0x6CC)
        lw      t9, 0xb4(sp)

        _end:
        _original:
        lw      t9,0x18c(s7)
        sll     t1,t9,0x5

        j       _return
        nop
    }

    // 800E55DC + 3C4
    scope item_hit_parry_bubble_check: {
        OS.patch_start(0x611A0, 0x800E59A0)
        j       item_hit_parry_bubble_check
        nop
        _return:
        OS.patch_end()

        Toggles.read(entry_parry, at)      // at = Parry toggle
        beqz    at, _original              // branch if toggle is disabled
        nop

        // skip if in the air
        lw      at, 0x014C(s7) // t9 = kinetic state
        bnez    at, _original // branch if aerial
        nop

        _check_action:
        lw      t0, 0x0024(s7)                      // t0 = current players action
        addiu   at, r0, Action.ShieldOff            // at = ShieldOff action
        beq     t0, at, _action_passed              // branch if shield dropping
        addiu   at, r0, Action.ShieldOn             // at = ShieldOn action
        beq     t0, at, _action_passed              // branch if shield dropping
        addiu   at, r0, Action.Shield               // at = Shield action
        beq     t0, at, _action_passed              // branch if shield dropping
        nop

        b _original
        nop

        _action_passed:
        lli     at, PARRY_ACTIVATION_FRAMES // parry activation frames
        lw      t1, 0x1C(s7)                // current frame of current action
        bgt     t1, at, _original           // current frame > activation frames, too bad!
        nop

        lw      at, 0xB24(s7) // fp->status_vars.common.guard.is_release (true if shield is being released)
        beq     at, r0, _original // branch if shield is not being released
        nop

        _loop_prepare:
        lw      t2, 0x54(s6)
        li      s5, 0x801311A0
        blez    t2, _end
        or      s4, r0, r0
        or      v0, r0, r0                  // set return to false
        _loop:
        // check if hitbox is active
        lw      t3, 0(s5)
        bnez    t3, _perform_check
        lw      t4, 0x88(sp)
        b       _loop_check_end // if not, skip
        lw      v0, 0x54(t4)

        _perform_check:
        addiu   sp, sp,-0x0070              // allocate stack space
        sw      a0, 0x0010(sp)              // ~
        sw      a1, 0x0014(sp)              // ~
        sw      a2, 0x0018(sp)              // ~
        sw      a3, 0x001C(sp)              // ~
        sw      t8, 0x0020(sp)              // ~
        sw      t9, 0x0024(sp)              // ~
        sw      ra, 0x006C(sp)              // save registers

        // s4 = loop counter
        // s6 = item hitbox
        // s7 = defender struct
        // s8 = item struct

        addiu   sp,sp,-0x30
        // function args:
        // a0 = player struct
        // a1 = hitbox pos vec3
        // a2 = hitbox prev pos vec3
        // a3 = hitbox size
        // 0x10(sp) = hitbox update mode
        or      a0, r0, s7      // player struct

        // this item hitbox is one annoying struct
        // s6 = item hitbox
        // s4 = loop index
        sll     t8, s4, 0x2
        subu    t8, t8, s4
        sll     t8, t8, 0x5
        addu    t0, s6, t8

        addiu   a1, t0, 0x58    // hitbox pos vec3 pointer
        
        lw      a2, 0x0000(s6) // load item hitbox state flag (0 inactive, 1 fresh, 2 "transfer", 3 interpolate)
        addiu   a3, r0, 0x0002
        slt     a2, a3, a2 // a2 = 1 if hitbox is in inactive, fresh or transfer states, 0 if it is interpolate
        beqzl   a2, _size
        addu    a2, a1, r0 // if not interpolating, use previous_pos = current_pos
        addiu   a2, t0, 0x64 // hitbox previous pos vec3 pointer
        
        _size:
        lw      a3, 0x2C(s6)    // hitbox size
        lw      t0, 0x0(s6)
        sw      t0, 0x10(sp)    // hitbox update mode

        jal check_parry_collision // v0 = 1 if a hitbox was found in the parry range
        nop
        addiu   sp,sp,0x30

        lw      a0, 0x0010(sp)              // ~
        lw      a1, 0x0014(sp)              // ~
        lw      a2, 0x0018(sp)              // ~
        lw      a3, 0x001C(sp)              // ~
        lw      t8, 0x0020(sp)              // ~
        lw      t9, 0x0024(sp)              // ~
        lw      ra, 0x006C(sp)              // load registers
        addiu   sp, sp,0x0070               // deallocate stack space

        _loop_check_end:
        bnez    v0, _collision_detected     // if we detected a collision, break out of the loop
        lw      t5, 0x88(sp)
        lw      v0, 0x54(t5)
        addiu   s4, s4, 1
        slt     at, s4, v0
        bnez    at, _loop
        addiu   s5, s5, 4
        lw      v0,0x18c(s7)
        b   _end // loop ended, no collisions found
        nop

        _collision_detected:
        or      a0, r0, s7 // a0 = player struct
        jal     activate_parry
        lw      a0, 0x0004(a0) // a0 = defender object
        nop

        _register_hit:
        // itProcessSetHitInteractStats(it_hit, fighter_gobj, (it_hit->can_rehit_fighter) ? nGMHitTypeHurtRehit : nGMHitTypeHurt, 0);
        or      t0, r0, s7      // t0 = player struct

        addiu   sp, sp, -0x0020     // allocate stack space

        or      a0, r0, s6          // a0 = it hit
        lw      a1, 0x4(t0)         // a1 = defender object
        lli     a2, 2               // a2 = nGMHitTypeShieldRehit
        or      a3, r0, r0          // a3 = 0
        jal     0x8016F930
        nop

        jal     0x801727F4          // v0 damage = itMainGetDamageOutput(itStruct *ip)
        or      a0, r0, s8          // a0 = it struct
        // v0 = damage (float)

        sw      v0, 0x264(s8) // set hitbox dealt damage for the game to despawn it

        addiu   sp, sp, 0x0020      // deallocate stack space

        _calculate_hitlag:
        // Calculate hitbox hitlag
        addiu   sp, sp, -0x0020             // allocate stack space
        sw      s1, 0x001C(sp)              // ~
        sw      a0, 0x0010(sp)              // ~
        sw      t2, 0x0014(sp)              // save registers

        // s32 gmCommon_DamageCalcHitLag(s32 damage, s32 status_id, f32 hitlag_mul)
        or  a0, r0, v0         // a0 = hitbox damage

        or      t0, r0, s7      // t0 = player struct
        lw  a1, 0x0024(t0)     // a1 = current players action
        //lw a2, 0x7E0(s5)
        lui a2, 0x3F80 // TODO: should load hitlag multiplier

        jal 0x800EA1C0 // gmCommon_DamageCalcHitLag
        nop

        beqz    v0, _save_hitlag // prevents endless hitlag if v0 = 0
        or      t0, r0, s7 // t0 = player struct

        addiu   v0, v0, -1    // hitlag -= 1
        _save_hitlag:
        sw v0, 0x0040(t0)     // save hitlag to defender

        lw      s1, 0x001C(sp)              // ~
        lw      a0, 0x0010(sp)              // ~
        lw      t2, 0x0014(sp)              // restore registers
        addiu   sp, sp, 0x0020              // deallocate stack space

        // skip to outer next object collision check
        j       (0x800E55DC + 0x618)
        lw      t5,0xb4(sp)

        _end:
        _original:
        lw      v0,0x18c(s7)    // original line 1
        sll     t8,v0,0x5       // original line 2

        j       _return
        nop
    }

    // 800E61EC + 4a8
    scope apply_attacker_extra_hitlag: {
        OS.patch_start(0x61E90, 0x800E6690)
        j       apply_attacker_extra_hitlag
        nop
        _return:
        OS.patch_end()

        Toggles.read(entry_parry, at)      // at = Parry toggle
        beqz    at, _end                   // branch if toggle is disabled
        nop

        // s0 = player struct
        // v0 = hitlag

        lbu     t1, 0x000D(s0)              // t1 = attacker port
        li      t2, is_hit_parry            // ~
        addu    t3, t2, t1                  // t3 = px is_hit_parry address
        lbu     t1, 0x0000(t3)              // t2 = is_hit_parry

        beq     t1, r0, _end                // our hitbox wasn't parried
        nop

        addi    v0, v0, 0xE                 // add 14
        sb      r0, 0x0000(t3)              // update is_hit_parry = 0

        _end:
        beqz    v0, _j_0x800E66B0
        sw      v0, 0x0040(s0)

        j       _return
        nop

        _j_0x800E66B0:
        j       0x800E66B0
        nop
    }

    // a0 = player object
    scope activate_parry: {
        addiu   sp, sp,-0x0070              // allocate stack space
        sw      a0, 0x0010(sp)              // ~
        sw      a1, 0x0014(sp)              // ~
        sw      a2, 0x0018(sp)              // ~
        sw      a3, 0x001C(sp)              // ~
        sw      t8, 0x0020(sp)              // ~
        sw      t9, 0x0024(sp)              // ~
        sw      t5, 0x0028(sp)              // ~
        sw      ra, 0x006C(sp)              // save registers

        addiu   sp, sp,-0x0030              // allocate stack space
        sw      a0, 0x0018(sp)              // 0x0018(sp) = player object
        sw      r0, 0x0010(sp)              // argument 4 = 0
        lli     a1, Action.ClangRecoil      // a1 = Action.ClangRecoil
        lui     a2, 0x3F80                  // a2(starting frame) = 0.0
        jal     0x800E6F24                  // change action
        lui     a3, 0x3F80                  // a3 = float: 1.0

        // Overwrite GFX routine
        lw      a0, 0x0018(sp)              // a0 = player object
        lw      a1, 0x0084(a0)              // a1 = player struct
        lli     t1, 0x0003                  // ~
        sb      t1, 0x05BB(a1)              // set hurtbox state to 0x0003(intangible)
        lli     a1, GFXRoutine.id.PARRY     // a1 = PARRY id
        jal     0x800E9814                  // begin gfx routine
        or      a2, r0, r0                  // a2 = 0

        // set fp->status_vars.common.rebound.rebound_timer = 0
        // so we get free from this animation in the first available frame
        lw      a0, 0x0018(sp)              // a0 = player object
        lw      a1, 0x0084(a0)              // a1 = player struct
        sw      r0, 0xB1C(a1)

        // clear damage values to ensure the action isn't changed prematurely
        sw      r0, 0x0040(a1)              // remove hitstun
        sw      r0, 0x07CC(a1)              // remove shield damage
        sw      r0, 0x07C8(a1)              // incoming damage = 0

        // play sound effect
        lli     a0, PARRY_SFX               // parry sfx
        jal     FGM.play_                   // play sfx
        nop

        // generate white circle effect
        lw      a0, 0x0018(sp)          // a0 = player object
        lw      a1, 0x0084(a0)          // a1 = player struct
        lw      t8, 0x09C8(a1)          // t8 = player attributes
        lwc1    f8, 0x00A0(t8)          // f8 = ecb center y height

        lw      t0, 0x0078(a1)          // location vector base
        lwc1    f4, 0x4(t0)             // f4 = location y

        add.s   f8, f8, f4              // f8 = Y+ECB_Y

        addiu   sp, sp, -0x30     // allocate memory

        lw      t1, 0x0(t0)  // ~
        sw      t1, 0x18(sp) // x
        swc1    f8, 0x1c(sp) // y
        lw      t1, 0x8(t0)  // ~
        sw      t1, 0x20(sp) // z - create (X, Y+ECB_Y, Z) vec3 at 0x18

        addiu   a0, sp, 0x18    // arg0 location

        // scale effect size with topjoint model scale
        lli         t0, 20          // effect size
        mtc1        t0, f8          // f8 = effect size
        lw          t1, 0x8E8(a1)   // t1 = defender's topjoint transform bone
        lwc1        f4, 0x0040(t1)  // f4 = defender's topjoint X scale
        cvt.s.w     f8, f8          // convert effect size to float
        mul.s       f4, f4, f8      // muliply by size
        trunc.w.s   f4, f4          // convert to int
        mfc1        a1, f4          // arg1 size

        jal     0x80100BF0      // efManagerSetOffMakeEffect(Vec3f *pos, s32 size)
        nop

        addiu   sp, sp, 0x30 // deallocate memory

        // Generate ground bump effect
        lw      a0, 0x0018(sp)              // a0 = player object
        lw      a1, 0x0084(a0)              // a1 = player struct
        addiu   sp,sp,-0x30
        sw      r0, 0x10(sp)
        lw      t2, 0x44(a1)
        lli     a1, 0x16                    // shockwave GFX
        sw      r0, 0x1c(sp)
        sw      r0, 0x18(sp)
        or      a2, r0, r0
        or      a3, r0, r0
        jal     0x800EABDC
        sw      t2, 0x14(sp)
        addiu   sp,sp,0x30

        addiu   sp, sp, 0x0030

        lw      a0, 0x0010(sp)              // ~
        lw      a1, 0x0014(sp)              // ~
        lw      a2, 0x0018(sp)              // ~
        lw      a3, 0x001C(sp)              // ~
        lw      t8, 0x0020(sp)              // ~
        lw      t9, 0x0024(sp)              // ~
        lw      t5, 0x0028(sp)              // ~
        lw      ra, 0x006C(sp)              // load registers
        addiu   sp, sp,0x0070               // deallocate stack space

        jr      ra                          // return
        nop
    }

    // a0 = player struct
    // a1 = hitbox pos vec3
    // a2 = hitbox prev pos vec3
    // a3 = hitbox size
    // 0x10(sp) = hitbox update mode
    // Returns: v0 = 1 if a hitbox was found in the parry range, 0 if not
    scope check_parry_collision: {
        constant SIZE_MULTI(0x3FC0) // 1.5F multiplies shield size by this for the parry check

        addiu   sp, sp,-0x0070              // allocate stack space
        sw      a0, 0x0054(sp)              // save defender struct
        sw      a1, 0x0058(sp)              // save hitbox pos vec3
        sw      a2, 0x005C(sp)              // save hitbox prev pos vec3
        sw      a3, 0x0060(sp)              // save hitbox size
        sw      t8, 0x0064(sp)              // ~
        sw      t9, 0x0068(sp)              // ~
        sw      ra, 0x006C(sp)              // save registers

        // prepare for function call
        // gmCollisionTestSphere(
        //  Vec3f *hitpos_current, Vec3f *hitpos_prev, f32 hitsize,
        //  s32 update_state, Mtx44f mtx, Vec3f *sphere_offset,
        //  Vec3f *sphere_size, Vec3f *arg7, s32 sphit_kind,
        //  f32 *p_angle, Vec3f *argA)

        // arguments 0, 1, 2, 3 (hitbox current pos, previous pos, hit size, update state)
        lw      a0, 0x58(sp)     // arg0 = hitbox pos vec3 pointer
        lw      a1, 0x5C(sp)     // arg1 = hitbox prev pos vec3 pointer
        lw      a2, 0x60(sp)     // arg2 = hitbox size
        lw      a3, 0x70+0x10(sp)     // hitbox update mode

        // arg 0x10 (hurtbox matrix?)
        lw      t0, 0x0054(sp)  // t0 = defender struct
        lw      t1, 0x8E8(t0)   // t1 = defender's topjoint transform bone
        lw      t2, 0x84(t1)    // unk_dobjdata

        addiu   t0, t2, 0x9C  // t0 = unk9c
        sw      t0, 0x10(sp)  // argument 4 = joint unk9c

        // 2 unknown function calls that need to be made
        addiu   sp, sp, -0x0080 // allocate stack space
        sw      a0,0x54(sp)
        sw      a1,0x58(sp)
        sw      a2,0x5C(sp)
        sw      t2,0x60(sp)
        sw      t1,0x64(sp) // defender's TopJoint transform bone

        jal     0x800EDE00 // some unknown function call 1
        lw      a0, 0x0064(sp) // a0 = defender's TopJoint transform bone

        jal     0x800EDE5C // some unknown function call 2
        lw      a0, 0x0064(sp) // a0 = defender's TopJoint transform bone

        lw      a0,0x54(sp)
        lw      a1,0x58(sp)
        lw      a2,0x5C(sp)
        lw      t2,0x60(sp)
        lw      t1,0x64(sp)
        addiu   sp, sp, 0x0080 // deallocate stack space

        // 0x14 (sphere offset)
        // 0x1C (some vector3 that is used for a division at the function start)
        lw      t8, 0x0054(sp)          // t8 = player struct
        lw      t8, 0x09C8(t8)          // t8 = player attributes
        lwc1    f8, 0x00A0(t8)          // f8 = ecb center y height

        sw      r0, 0x48(sp)
        swc1    f8, 0x4c(sp)
        sw      r0, 0x50(sp)            // create (0, ECB_Y, 0) vec3 at 0x48
        addiu   t0, sp, 0x48
        sw      t0, 0x14(sp)            // save arg 0x14

        addiu   t0, t2, 0x90
        sw      t0, 0x1C(sp)            // save arg 0x1C

        // 0x18 (sphere size)
        lw      t8, 0x0054(sp)          // t8 = player struct
        lw      t8, 0x09C8(t8)          // t8 = player attributes
        lw      at, 0x74(t8)            // at = shield size
        mtc1    at, f4                  // f4 = shield size
        lui     at, SIZE_MULTI          // at = SIZE_MULTI
        mtc1    at, f2                  // f2 = SIZE_MULTI
        mul.s   f4, f4, f2              // f4 = SIZE_MULTI * max shield size
        swc1    f4, 0x3c(sp)
        swc1    f4, 0x40(sp)
        swc1    f4, 0x44(sp)            // create vec3 at 0x3C
        addiu   t0, sp, 0x3c
        sw      t0, 0x18(sp)

        // 0x20 part scale (used as a padding? works as zero)
        sw      r0, 0x20(sp)

        // 0x24 &angle (we don't care about the collision angle here)
        addiu   t0, sp, 0x34
        sw      t0, 0x24(sp) // angle will be returned to this address but we'll ignore it

        // 0x28
        sw      r0, 0x28(sp)

        jal 0x800EE750 // collision check
        nop

        // v0 = 1 if a hitbox was found in the parry range

        lw      a0, 0x0054(sp)              // ~
        lw      a1, 0x0058(sp)              // ~
        lw      a2, 0x005C(sp)              // ~
        lw      a3, 0x0060(sp)              // ~
        lw      t8, 0x0064(sp)              // ~
        lw      t9, 0x0068(sp)              // ~
        lw      ra, 0x006C(sp)              // load registers
        addiu   sp, sp,0x0070               // deallocate stack space

        jr      ra                          // return
        nop
    }
}

} // __PARRY__
