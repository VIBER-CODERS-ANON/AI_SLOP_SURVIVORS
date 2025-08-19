# Ability Implementation Checklist

Use this checklist when creating a new ability to ensure nothing is missed.

## Pre-Development

- [ ] **Define Ability Concept**
  - [ ] Name and description
  - [ ] Type (damage, heal, buff, movement, etc.)
  - [ ] Visual theme
  - [ ] Target audience (player, enemy, both)

- [ ] **Design Specifications**
  - [ ] Damage/effect values
  - [ ] Cooldown duration
  - [ ] Resource costs
  - [ ] Range/radius
  - [ ] Special mechanics

- [ ] **Asset Requirements**
  - [ ] Visual effects needed
  - [ ] Sound effects needed
  - [ ] Animation requirements
  - [ ] UI icons

## Development

### Core Implementation

- [ ] **Create Ability File**
  - [ ] Location: `systems/ability_system/abilities/your_ability.gd`
  - [ ] Extend `BaseAbility`
  - [ ] Add class_name

- [ ] **Set Required Properties**
  - [ ] `ability_id` (unique identifier)
  - [ ] `ability_name`
  - [ ] `ability_description`
  - [ ] `ability_tags` (for tag system integration)
  - [ ] `ability_type` (ACTIVE/PASSIVE/TOGGLE)
  - [ ] `base_cooldown`
  - [ ] `targeting_type`
  - [ ] `base_range`

- [ ] **Resource Configuration**
  - [ ] Define `resource_costs` dictionary
  - [ ] Set mana/health/custom resource costs
  - [ ] Leave empty if no cost

- [ ] **Implement Core Methods**
  - [ ] `_init()` - Initialize properties
  - [ ] `on_added()` - Preload resources
  - [ ] `can_execute()` - Validation logic
  - [ ] `_execute_ability()` - Main execution
  - [ ] `_perform_ability_logic()` - Ability-specific logic

### Visual & Audio

- [ ] **Visual Effects**
  - [ ] Create/assign effect scenes
  - [ ] Implement spawn logic
  - [ ] Configure particle systems
  - [ ] Add telegraphs (if needed)
  - [ ] Set up trails/persistent effects

- [ ] **Audio**
  - [ ] Add cast sound
  - [ ] Add impact sound
  - [ ] Add loop sound (if applicable)
  - [ ] Configure audio parameters

- [ ] **Animations**
  - [ ] Define animation names
  - [ ] Implement animation calls
  - [ ] Sync with ability timing

### Integration

- [ ] **Entity Integration**
  - [ ] Add to player abilities
  - [ ] Add to NPC/enemy abilities
  - [ ] Configure item grants (if applicable)

- [ ] **Input Binding**
  - [ ] Set default keybind
  - [ ] Add to ability bar UI
  - [ ] Configure gamepad support

- [ ] **Action Feed Integration**
  - [ ] Add action feed reporting
  - [ ] Create custom messages
  - [ ] Handle chatter-specific text

### Tag System

- [ ] **Apply Ability Tags**
  - [ ] Damage type tags (Physical, Fire, Ice, etc.)
  - [ ] Ability type tags (Projectile, AoE, DoT, etc.)
  - [ ] Special tags (Ultimate, Channeled, etc.)

- [ ] **Propagate Tags**
  - [ ] Add tags to projectiles
  - [ ] Add tags to damage instances
  - [ ] Add tags to effects/buffs

### Special Considerations

- [ ] **Performance**
  - [ ] Limit max targets for AoE
  - [ ] Optimize particle counts
  - [ ] Use object pooling for frequent spawns
  - [ ] Profile ability performance

- [ ] **Multiplayer (if applicable)**
  - [ ] Add network synchronization
  - [ ] Handle lag compensation
  - [ ] Validate on server

- [ ] **Scalability**
  - [ ] Use `get_modified_value()` for scaling
  - [ ] Support entity stat modifiers
  - [ ] Allow upgrade paths

### Death Attribution - CRITICAL

- [ ] **Understand the Type System**
  - [ ] Resources (abilities) CANNOT be passed as damage source
  - [ ] Only Nodes can be damage sources
  - [ ] Use metadata approach for Resource-based abilities

- [ ] **Projectile Attribution**
  - [ ] Projectiles pass themselves as damage source
  - [ ] Implement `get_killer_display_name()` method
  - [ ] Implement `get_attack_name()` method
  - [ ] Implement `get_chatter_color()` method
  - [ ] Store owner reference with `set_meta("original_owner", owner)`
  - [ ] Test kill message shows correct username and ability

- [ ] **Area Effect Attribution**
  - [ ] Store spawner with `set_meta("original_spawner", spawner)`
  - [ ] Store source name immediately: `set_meta("source_name", spawner.get_chatter_username())`
  - [ ] Implement all attribution methods
  - [ ] Pass self as damage source in `take_damage()`
  - [ ] Handle case where spawner might be freed

- [ ] **Direct Damage Attribution**
  - [ ] Entity passes self as damage source
  - [ ] Entity implements `get_killer_display_name()` method
  - [ ] Entity implements `get_chatter_color()` method
  - [ ] Entity implements `get_attack_name()` method (if applicable)

- [ ] **Resource-Based Abilities**
  - [ ] NEVER pass ability (self) to take_damage
  - [ ] Use metadata pattern:
    ```gdscript
    entity.set_meta("active_ability_name", "ability name")
    target.take_damage(damage, entity, tags)
    entity.remove_meta("active_ability_name")
    ```

- [ ] **Signal Compatibility**
  - [ ] All `died` signal connections accept new parameters
  - [ ] Use `_` prefix for unused parameters to avoid warnings

## Testing

### Functional Testing

- [ ] **Basic Functionality**
  - [ ] Ability executes on input
  - [ ] Cooldown works correctly
  - [ ] Resource consumption works
  - [ ] Targeting works as expected

- [ ] **Edge Cases**
  - [ ] Works when entity is moving
  - [ ] Handles entity death during cast
  - [ ] Works at max/min range
  - [ ] Handles invalid targets gracefully

- [ ] **Integration Testing**
  - [ ] Works with all entity types
  - [ ] Interacts with buff system
  - [ ] Respects status effects (stun, silence)
  - [ ] Works with ability combos

### Visual Testing

- [ ] **Effects**
  - [ ] All effects spawn correctly
  - [ ] Effects clean up properly
  - [ ] No visual glitches
  - [ ] Proper layering/z-order

- [ ] **Performance**
  - [ ] No frame drops
  - [ ] Memory usage acceptable
  - [ ] Effect pooling works

### Balance Testing

- [ ] **Numbers**
  - [ ] Damage values appropriate
  - [ ] Cooldown feels right
  - [ ] Resource cost balanced
  - [ ] Range/radius suitable

- [ ] **Gameplay**
  - [ ] Fun to use
  - [ ] Clear visual feedback
  - [ ] Satisfying impact
  - [ ] Strategic depth

## Documentation

- [ ] **Code Documentation**
  - [ ] Class documentation header
  - [ ] Export variable descriptions
  - [ ] Method documentation
  - [ ] Complex logic comments

- [ ] **Usage Documentation**
  - [ ] Add to ability guide
  - [ ] Create example usage
  - [ ] Document special mechanics
  - [ ] Note any limitations

## Polish

- [ ] **Quality of Life**
  - [ ] Range indicators
  - [ ] Cooldown UI feedback
  - [ ] Resource cost preview
  - [ ] Target validation feedback

- [ ] **Juice**
  - [ ] Screen shake (if appropriate)
  - [ ] Hit pause/slow motion
  - [ ] Particle burst on impact
  - [ ] Dynamic lighting

## Final Checks

- [ ] **Code Review**
  - [ ] Follows project conventions
  - [ ] No hardcoded values
  - [ ] Proper error handling
  - [ ] Clean and readable

- [ ] **Testing Sign-off**
  - [ ] All tests pass
  - [ ] No known bugs
  - [ ] Performance acceptable
  - [ ] Fun factor confirmed

- [ ] **Integration Complete**
  - [ ] Merged to main branch
  - [ ] Added to ability roster
  - [ ] Documented in wiki
  - [ ] Team notified

## Notes Section

Use this space to track specific issues or considerations for your ability:

```
Example:
- Fireball should interact with oil puddles
- Consider adding charge-up variant later
- May need balance adjustment vs bosses
```
