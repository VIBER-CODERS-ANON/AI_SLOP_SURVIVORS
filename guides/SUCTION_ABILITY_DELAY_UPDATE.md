# Suction Ability - Damage Delay Update

## Overview
The Succubus' suction ability has been updated to include a 200ms damage delay after the channel begins. This gives players a brief reaction window to escape before taking damage.

## Changes Made

### 1. Damage Delay Mechanics
- **Delay Duration**: 200ms (0.2 seconds)
- **Visual Telegraph**: Beam starts weaker/lighter during the warning phase
- **Damage Start**: After 200ms, beam intensifies and damage begins
- **Escape Window**: Players can break the channel by moving out of range during this window

### 2. Visual Feedback

#### Warning Phase (0-200ms)
- Beam width: 70% of normal
- Beam color: Lighter pink (1.0, 0.4, 0.7, 0.5)
- Weaker gradient effect
- No damage dealt

#### Damage Phase (200ms+)
- Beam width: 150% of normal
- Beam color: Intense pink (1.0, 0.1, 0.4, 0.9)
- Strong gradient effect
- Full damage applied

### 3. Implementation Details

```gdscript
# New variables added
var damage_delay: float = 0.2  # 200ms delay
var damage_delay_remaining: float = 0.0
var damage_started: bool = false

# In _update_channel():
if damage_delay_remaining > 0:
    damage_delay_remaining -= delta
    if damage_delay_remaining <= 0:
        damage_started = true
        # Intensify beam visuals
        
# Only apply damage after delay
if damage_started:
    # Apply damage logic
```

## Gameplay Impact

### For Players
- **Reaction Time**: 200ms window to react and escape
- **Skill Expression**: Rewards quick reactions and movement
- **Visual Clarity**: Clear visual difference between warning and damage phases

### For Succubi
- **Still Dangerous**: Total damage unchanged if player doesn't react
- **Zone Control**: Forces player movement even without dealing damage
- **Tactical Use**: Can be used to force players into bad positions

## Design Philosophy
This change transforms the suction ability from an instant-damage channel to a skill-based mechanic. Players who stay alert and mobile can avoid damage entirely, while those who are slow to react or choose to tank it will take full damage.

The 200ms window is intentionally tight - enough time for an attentive player to react, but not so long that the ability becomes trivial to avoid.

## Future Considerations
- Could add a brief slow effect during the warning phase to make escape more challenging
- Could scale the delay based on difficulty or enemy rarity
- Could add audio cues for the damage start (a "charging up" sound)
