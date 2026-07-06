// MoveBuffer.asm
if !{defined __MOVEBUFFER__} {
define __MOVEBUFFER__()
print "included MoveBuffer.asm\n"

include "OS.asm"
include "Global.asm"
include "Toggles.asm"
include "Joypad.asm"

// @ Description
// Adds an adjustable input/move buffer, similar to Smash Ultimate's hit-buffer.
// The buffer window is controlled by the "Move Buffer" gameplay toggle
// (Toggles.entry_move_buffer): 0 = disabled, 1-9 = number of frames a buffered
// input is remembered after it could not be acted on.
//
// Strategy (input persistence, full-frame replay):
//   When an action-relevant button is pressed, the FULL relevant controller
//   state of that frame is captured (pressed buttons + stick X/Y). On each later
//   frame it is re-asserted into the player's input until the move comes out or
//   the window expires. Replaying the stick means the buffered move resolves to
//   the variant/direction you actually input (e.g. a forward-air stays a
//   forward-air even if your stick returned to neutral before it fired).
//   The replayed stick tracks the PEAK deflection seen during the window (per
//   axis), not just the press-frame value, so directional inputs like rolls keep
//   their full deflection instead of a partway-through-travel value (which could
//   fall below the roll threshold and come out as a plain shield).
//
// Where we inject (verified by disassembly):
//   The player struct's "buttons pressed" field (+0x01BE) is recomputed every
//   frame inside ftMainProcUpdate by edge-detection on the *held* buttons
//   (vanilla code at 0x800E12E8-0x800E1348). We hook 0x800E134C, immediately
//   AFTER 0x01BE/stick are finalized and BEFORE the action logic reads them, and
//   override them directly. This is on the control-type-0 (human) path only, so
//   it never runs for CPUs.
//
// Consumption ("used") detection:
//   A buffered input is "used" once the move it produced actually comes out. We
//   detect this as: the action becomes an attack/grab/special action
//   (id >= 0xA6 = Action.Grab) that is EITHER different from the action we
//   captured in, OR reached after passing through an actionable state since
//   capture (seen flag). The latter handles "buffer the same move you were in"
//   (e.g. jab during jab). Landing-lag actions (LandingAir 0xD6-0xDB) are NOT
//   treated as "used" so a move can still be buffered out of an aerial's landing.
//   Because capture is allowed in ANY state, you can buffer during the recovery
//   of an attack/special (e.g. DK's Giant Punch), unlike the earlier version
//   which cleared whenever action >= 0xA6. Rolls (RollF/RollB, < 0xA6) get an
//   explicit "used" check so the buffer stops re-injecting once a sideways dodge
//   comes out. Item pickups (LightItemPickup 0x64 / HeavyItemPickup 0x65, < 0xA6)
//   also get an explicit "used" check, otherwise the A that grabbed the item keeps
//   re-asserting and immediately throws it once the item is in hand.
//
// Smash buffering:
//   The engine distinguishes a smash from a tilt by whether the control stick
//   CROSSED the neutral zone this frame (current stick 0x01C2/0x01C3 vs the
//   previous frame's stick 0x01C4/0x01C5) - a fresh flick past the deadzone is a
//   smash, a sustained deflection is a tilt/dash. Replaying the peak stick every
//   frame makes previous == current, so a buffered smash used to degrade into a
//   tilt. When the buffered input is an A press at a near-max deflection, the
//   inject step zeroes the previous-frame stick so every frame looks like a fresh
//   flick and the smash comes out on the first actionable frame.
//
// Notes:
//   - Only pressed buttons + stick are replayed; the held mask (0x01BC) is left
//     alone so buffered inputs don't unintentionally charge smashes / hold
//     specials.
//   - Replaying the stick overrides live stick input for the frames the buffer
//     is active.
scope MoveBuffer {

    // Action-initiating buttons that should be buffered. Tunable.
    // A | B | Z | L | R | C-Up | C-Down | C-Left | C-Right  (= 0xE03F)
    constant BUFFER_MASK(Joypad.A | Joypad.B | Joypad.Z | Joypad.L | Joypad.R | Joypad.CU | Joypad.CD | Joypad.CL | Joypad.CR)

    // First "attack" action id (Action.Grab). Ids >= this are attacks/grabs/
    // specials/captured states.
    constant ATTACK_THRESHOLD(0x00A6)
    // Landing-lag action range (Action.LandingAirN .. Action.LandingAirX). These
    // are >= ATTACK_THRESHOLD but are NOT "a move came out", so they are excluded
    // from "used" detection and treated as bufferable, actionable-ish states.
    constant LANDING_MIN(0x00D6)
    constant LANDING_MAX_P1(0x00DC)     // LandingAirX (0xDB) + 1
    // Roll actions (Action.RollF / Action.RollB). These are < ATTACK_THRESHOLD,
    // so they need their own consumption check: once a buffered input produces a
    // roll we must stop re-injecting (otherwise the repeated shield press can
    // disrupt the shield->roll transition and yield a plain shield instead).
    constant ROLL_F(0x009C)
    constant ROLL_B(0x009D)
    // Item pickup actions (Action.LightItemPickup / Action.HeavyItemPickup).
    // Both are < ATTACK_THRESHOLD, so like rolls they need their own consumption
    // check: the A press that grabs the item is buffered, and once the item is in
    // hand the re-asserted A immediately throws it. Consuming on the pickup action
    // stops the re-assertion so you just grab the item.
    constant LIGHT_ITEM_PICKUP(0x0064)
    constant HEAVY_ITEM_PICKUP(0x0065)
    // Jump actions (Action.JumpSquat .. Action.JumpAerialB = 0x014-0x019:
    // JumpSquat, ShieldJumpSquat, JumpF, JumpB, JumpAerialF, JumpAerialB). These
    // are < ATTACK_THRESHOLD, so like rolls they need their own consumption check:
    // a single C (jump) press would otherwise keep re-asserting after the jump came
    // out and trigger a second (midair) jump. We only consume when a jump action is
    // NEWLY produced (buf_action was not already a jump), so buffering a rising
    // aerial / second jump THROUGH jumpsquat is preserved.
    constant JUMP_MIN(0x0014)           // Action.JumpSquat
    constant JUMP_COUNT(0x0006)         // JumpSquat..JumpAerialB (0x014-0x019), 6 ids

    // Smash detection. The engine reads a smash (vs tilt) when the control stick
    // CROSSES the neutral zone this frame: it compares the current stick
    // (0x01C2/0x01C3) against the PREVIOUS frame's stick (0x01C4/0x01C5, saved at
    // the top of ftMainProcUpdate) and fires when the previous value was inside the
    // +/-0x14 deadzone and the current value is outside it (vanilla routine at
    // 0x8014_95D4). Because the buffer replays the PEAK stick every frame,
    // previous == current, so the crossing never happens and a buffered smash
    // degrades into a tilt/dash. When the buffered input is an A press with a
    // near-max deflection we zero the previous-frame stick each inject frame so it
    // looks like a fresh flick (this is exactly the condition the dpad Smash macro
    // relies on: a fresh crossing with the stick at max). This threshold separates
    // a smash-level deflection from a tilt (the dpad tilt macro uses 0x28, the smash
    // macro 0x50); HW-tunable.
    constant SMASH_STICK_THRESHOLD(0x0040)

    // @ Description
    // Per-port buffer state. 16 bytes per port:
    //   0x00 (halfword) - buffered pressed button mask
    //   0x02 (byte)     - timer (frames remaining in the window)
    //   0x03 (byte)     - used flag (1 once the buffered move has come out)
    //   0x04 (byte)     - captured stick X
    //   0x05 (byte)     - captured stick Y
    //   0x06 (byte)     - seen flag (1 once an actionable state was observed)
    //   0x07 (byte)     - padding
    //   0x08 (word)     - buf_action (action id at the time of capture)
    buffer_table:
    fill (16 * 4)
    OS.align(4)

    // @ Description
    // Buffer bookkeeping + injection for one human player, one frame.
    // Called from inject_ with all registers saved, so it may clobber freely.
    // a2 = player struct.
    scope process_: {
        OS.read_word(Toggles.entry_move_buffer + 0x4, t0)   // t0 = N (0 = off)
        lbu     t1, 0x000D(a2)              // t1 = player port
        li      t2, buffer_table            // ~
        sll     t3, t1, 0x0004             // t3 = port * 16
        addu    t2, t2, t3                 // t2 = this port's buffer entry

        bnez    t0, _enabled                // if toggle on, run
        nop

        _disabled:
        sh      r0, 0x0000(t2)             // clear mask
        sb      r0, 0x0002(t2)             // clear timer
        b       _ret
        sb      r0, 0x0003(t2)             // clear used (delay slot)

        _enabled:
        lw      t3, 0x0024(a2)             // t3 = current action id
        lhu     t4, 0x01BE(a2)             // t4 = this frame's pressed buttons
        andi    t5, t4, BUFFER_MASK        // t5 = new action-relevant presses

        // t6 = isLanding (1 if LANDING_MIN <= action < LANDING_MAX_P1)
        sltiu   t6, t3, LANDING_MIN        // t6 = 1 if action < 0xD6
        xori    t6, t6, 0x0001             // t6 = 1 if action >= 0xD6
        sltiu   t7, t3, LANDING_MAX_P1     // t7 = 1 if action < 0xDC
        and     t6, t6, t7                 // t6 = isLanding

        // t7 = isAttack (1 if action >= ATTACK_THRESHOLD)
        sltiu   t7, t3, ATTACK_THRESHOLD   // t7 = 1 if action < 0xA6
        xori    t7, t7, 0x0001             // t7 = 1 if action >= 0xA6

        beqz    t5, _maintain              // no new press -> maintain existing buffer
        nop

        // --- capture this frame's full input ---
        sh      t5, 0x0000(t2)             // mask = new presses
        sb      t0, 0x0002(t2)             // timer = N
        sb      r0, 0x0003(t2)             // used = 0
        lb      t8, 0x01C2(a2)             // ~
        sb      t8, 0x0004(t2)             // captured stick X
        lb      t8, 0x01C3(a2)             // ~
        sb      t8, 0x0005(t2)             // captured stick Y
        sw      t3, 0x0008(t2)             // buf_action = current action
        xori    t8, t7, 0x0001             // t8 = !isAttack
        or      t8, t8, t6                 // t8 = isActionable (= !isAttack || isLanding)
        b       _ret
        sb      t8, 0x0006(t2)             // seen = isActionable (delay slot)

        _maintain:
        lb      t8, 0x0002(t2)             // t8 = timer
        beqz    t8, _ret                   // nothing buffered -> done
        nop
        lbu     t9, 0x0003(t2)             // t9 = used
        bnez    t9, _ret                   // already consumed -> done
        nop

        // update seen flag if currently in an actionable-ish state
        xori    t9, t7, 0x0001             // !isAttack
        or      t9, t9, t6                 // isActionable
        beqz    t9, _check_used
        nop
        lli     t9, 0x0001                 // ~
        sb      t9, 0x0006(t2)             // seen = 1

        _check_used:
        // a roll (sideways dodge) consumes the buffer immediately
        lli     t9, ROLL_F                 // ~
        beq     t3, t9, _set_used          // RollF -> used
        lli     t9, ROLL_B                 // (delay slot) RollB
        beq     t3, t9, _set_used          // RollB -> used
        nop

        // an item pickup consumes the buffer immediately, so the A press that
        // grabbed the item doesn't re-assert and throw it once it's in hand.
        lli     t9, LIGHT_ITEM_PICKUP      // ~
        beq     t3, t9, _set_used          // LightItemPickup -> used
        lli     t9, HEAVY_ITEM_PICKUP      // (delay slot) HeavyItemPickup
        beq     t3, t9, _set_used          // HeavyItemPickup -> used
        nop

        // a buffered input that NEWLY produces a jump action (JumpSquat..
        // JumpAerialB) consumes the buffer, so one C press can't re-assert into a
        // second (midair) jump. Gated on buf_action NOT already being a jump action,
        // so buffering an aerial / 2nd jump THROUGH jumpsquat keeps working.
        addiu   t9, t3, -JUMP_MIN          // t9 = action - 0x014
        sltiu   t9, t9, JUMP_COUNT         // t9 = 1 if action in [0x014,0x019]
        beqz    t9, _check_attack          // not a jump action -> normal checks
        lw      t8, 0x0008(t2)             // (delay) t8 = buf_action
        addiu   t8, t8, -JUMP_MIN          // t8 = buf_action - 0x014
        sltiu   t8, t8, JUMP_COUNT         // t8 = 1 if buf_action already a jump action
        beqz    t8, _set_used              // jump newly produced -> consume
        nop

        _check_attack:
        // used if isAttack && !isLanding && (action != buf_action || seen)
        beqz    t7, _inject                // not an attack -> not used
        nop
        bnez    t6, _inject                // landing lag -> not used
        nop
        lw      t9, 0x0008(t2)             // t9 = buf_action
        bne     t3, t9, _set_used          // different attack action -> used
        nop
        lbu     t9, 0x0006(t2)             // t9 = seen
        beqz    t9, _inject                // same action & no actionable seen -> not yet
        nop

        _set_used:
        lli     t9, 0x0001                 // ~
        sb      t9, 0x0003(t2)             // used = 1
        sh      r0, 0x0000(t2)             // clear mask
        b       _ret
        sb      r0, 0x0002(t2)             // clear timer (delay slot)

        _inject:
        // Track the PEAK stick deflection seen during the window (per axis). The
        // press-frame stick is often only partway through its travel, so freezing
        // it can fall below the roll threshold and yield a shield. Keeping the
        // strongest deflection makes the buffered move resolve to the intended
        // direction, while still surviving the stick returning to neutral.
        lb      t5, 0x01C2(a2)             // t5 = live stick X
        lb      t6, 0x0004(t2)             // t6 = stored stick X
        sra     t7, t5, 31                 // ~
        xor     t8, t5, t7                 // ~
        subu    t8, t8, t7                 // t8 = |live X|
        sra     t7, t6, 31                 // ~
        xor     t9, t6, t7                 // ~
        subu    t9, t9, t7                 // t9 = |stored X|
        sltu    at, t9, t8                 // at = 1 if |stored X| < |live X|
        beqz    at, _peak_y
        nop
        sb      t5, 0x0004(t2)             // stored X = live X (new peak)

        _peak_y:
        lb      t5, 0x01C3(a2)             // t5 = live stick Y
        lb      t6, 0x0005(t2)             // t6 = stored stick Y
        sra     t7, t5, 31                 // ~
        xor     t8, t5, t7                 // ~
        subu    t8, t8, t7                 // t8 = |live Y|
        sra     t7, t6, 31                 // ~
        xor     t9, t6, t7                 // ~
        subu    t9, t9, t7                 // t9 = |stored Y|
        sltu    at, t9, t8                 // at = 1 if |stored Y| < |live Y|
        beqz    at, _do_inject
        nop
        sb      t5, 0x0005(t2)             // stored Y = live Y (new peak)

        _do_inject:
        lhu     t9, 0x0000(t2)             // t9 = buffered mask
        or      t4, t4, t9                 // pressed | buffered
        sh      t4, 0x01BE(a2)             // inject into pressed buttons
        lb      t9, 0x0004(t2)             // ~
        sb      t9, 0x01C2(a2)             // replay peak stick X
        lb      t9, 0x0005(t2)             // ~
        sb      t9, 0x01C3(a2)             // replay peak stick Y

        // --- smash freshness ---
        // If the buffered input is an A press with a near-max stick deflection
        // (i.e. a smash), zero the previous-frame stick (0x01C4/0x01C5) so the
        // engine's fresh-crossing smash detector fires on whatever frame the
        // character becomes actionable. Without this the held peak stick reads as a
        // sustained deflection -> tilt/dash, never a smash. Non-smash inputs (no A,
        // or below the smash deflection threshold) are left untouched so tilts,
        // rolls, aerials and jumps keep replaying exactly as before.
        lhu     t9, 0x0000(t2)             // t9 = buffered mask
        andi    t9, t9, Joypad.A           // A buffered?
        beqz    t9, _inject_timer          // no A -> not a smash
        nop
        lb      t9, 0x0004(t2)             // t9 = stored (peak) stick X
        sra     at, t9, 31                 // ~
        xor     t9, t9, at                 // ~
        subu    t9, t9, at                 // t9 = |stored X|
        sltiu   at, t9, SMASH_STICK_THRESHOLD  // at = 1 if |X| < threshold
        beqz    at, _force_fresh           // |X| >= threshold -> smash
        nop
        lb      t9, 0x0005(t2)             // t9 = stored (peak) stick Y
        sra     at, t9, 31                 // ~
        xor     t9, t9, at                 // ~
        subu    t9, t9, at                 // t9 = |stored Y|
        sltiu   at, t9, SMASH_STICK_THRESHOLD  // at = 1 if |Y| < threshold
        bnez    at, _inject_timer          // both axes below threshold -> not a smash
        nop

        _force_fresh:
        sb      r0, 0x01C4(a2)             // previous stick X = neutral (fake fresh flick)
        sb      r0, 0x01C5(a2)             // previous stick Y = neutral

        _inject_timer:
        lb      t9, 0x0002(t2)             // timer
        addiu   t9, t9, -0x0001            // timer--
        sb      t9, 0x0002(t2)             // store updated timer
        bnez    t9, _ret                   // window not expired -> done
        nop
        sh      r0, 0x0000(t2)             // window expired -> clear mask

        _ret:
        jr      ra
        nop
    }

    // @ Description
    // Hook inside the human input routine of ftMainProcUpdate, immediately after
    // the pressed mask (0x01BE) and stick are finalized and before the action
    // logic reads them. Reproduces the two overwritten vanilla instructions.
    // a2 = player struct, v0 = a2 + 0x01BC.
    scope inject_: {
        OS.patch_start(0x5CB4C, 0x800E134C)
        j       inject_
        nop
        _return:
        OS.patch_end()

        OS.save_registers()
        jal     process_                    // a2 = player struct
        nop
        OS.restore_registers()

        lhu     a0, 0x0000(v0)             // original line 1 (0x800E134C)
        j       _return
        lw      t4, 0x0040(a2)             // original line 2 (0x800E1350, delay slot)
    }
}

} // __MOVEBUFFER__
