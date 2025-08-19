# Boon Implementation Checklist

Use this checklist when creating a new boon to ensure proper implementation and integration.

## Pre-Development

- [ ] **Define Boon Concept**
  - [ ] Name and theme
  - [ ] Type (stat, percentage, weapon modifier, unique)
  - [ ] Target stat or mechanic
  - [ ] Visual identity (color)

- [ ] **Design Specifications**
  - [ ] Base value (Common rarity)
  - [ ] Scaling type (MORE vs Increased)
  - [ ] Stack behavior
  - [ ] Special mechanics (if unique)

- [ ] **Balance Considerations**
  - [ ] Compare to similar boons
  - [ ] Test value at each rarity
  - [ ] Consider stack implications
  - [ ] Check for broken combos

## Development

### Core Implementation

- [ ] **Create Boon File**
  - [ ] Location: `systems/boon_system/boons/your_boon.gd`
  - [ ] Extend `BaseBoon`
  - [ ] Add class_name

- [ ] **Set Required Properties in _init()**
  - [ ] `id` (unique identifier)
  - [ ] `display_name` (UI text)
  - [ ] `base_type` (categorization)
  - [ ] `icon_color` (visual identity)
  - [ ] `is_repeatable` (can stack?)

- [ ] **Implement Required Methods**
  - [ ] `get_formatted_description()` - Returns UI description
  - [ ] `_on_apply()` - Main effect logic
  - [ ] `_on_remove()` - Only if removable

- [ ] **Use Rarity Scaling**
  - [ ] Always use `get_effective_power()`
  - [ ] Never hardcode values
  - [ ] Test scaling at each rarity

### Implementation Details

- [ ] **Type Checking**
  - [ ] Verify entity is Player
  - [ ] Handle non-player entities gracefully
  - [ ] Check for required components

- [ ] **Effect Application**
  - [ ] Modify correct stat/property
  - [ ] Use appropriate scaling (MORE vs Increased)
  - [ ] Handle weapon-specific logic
  - [ ] Set meta properties if needed

- [ ] **Debug Output**
  - [ ] Print confirmation message
  - [ ] Include player name
  - [ ] Show actual values applied
  - [ ] Use appropriate emoji

### Integration

- [ ] **Add to Boon Pool**
  - [ ] Edit `boon_manager.gd`
  - [ ] Add to `common_boons` or `unique_boons`
  - [ ] Verify preload path is correct

- [ ] **Pool Placement**
  - [ ] Common pool for stat/percentage boons
  - [ ] Unique pool for special mechanics
  - [ ] Consider rarity distribution

## Testing

### Functional Testing

- [ ] **Basic Functionality**
  - [ ] Boon appears in selection
  - [ ] Selection applies effect
  - [ ] Values match description
  - [ ] Debug print shows

- [ ] **Rarity Scaling**
  - [ ] Test at Common (1x)
  - [ ] Test at Magic (2x)
  - [ ] Test at Rare (3x)
  - [ ] Test at Epic (4x)

- [ ] **Stacking Behavior**
  - [ ] Single application works
  - [ ] Multiple stacks accumulate correctly
  - [ ] MORE multipliers compound
  - [ ] Increased bonuses add

### Edge Cases

- [ ] **Entity Validation**
  - [ ] Non-player entities handled
  - [ ] Missing components handled
  - [ ] Null checks in place

- [ ] **Weapon Modifiers**
  - [ ] Correct tag checking
  - [ ] Non-matching weapons handled
  - [ ] Secondary weapons considered

- [ ] **Special Mechanics**
  - [ ] Meta properties set correctly
  - [ ] Systems check for properties
  - [ ] No conflicts with other boons

### Visual Testing

- [ ] **UI Display**
  - [ ] Name shows correctly
  - [ ] Description formats properly
  - [ ] Color matches rarity
  - [ ] Icon color applies

- [ ] **Selection Screen**
  - [ ] Card displays properly
  - [ ] Hover effects work
  - [ ] Selection feedback shows
  - [ ] Rarity effects display

## Balance Testing

- [ ] **Value Testing**
  - [ ] Base value feels right
  - [ ] Not too weak at Common
  - [ ] Not too strong at Epic
  - [ ] Compares well to similar boons

- [ ] **Stack Testing**
  - [ ] 1 stack: Noticeable
  - [ ] 3 stacks: Significant
  - [ ] 5+ stacks: Powerful but not broken
  - [ ] 10+ stacks: Still performant

- [ ] **Combination Testing**
  - [ ] Test with damage boons
  - [ ] Test with speed boons
  - [ ] Test with unique boons
  - [ ] Check for exploits

## Polish

- [ ] **Naming Convention**
  - [ ] ID uses snake_case
  - [ ] Display name is descriptive
  - [ ] Matches existing style
  - [ ] Clear and concise

- [ ] **Description Quality**
  - [ ] Uses MORE/Increased correctly
  - [ ] Shows calculated values
  - [ ] Includes units (%, points)
  - [ ] Grammar is correct

- [ ] **Code Quality**
  - [ ] Follows project style
  - [ ] Comments where needed
  - [ ] No magic numbers
  - [ ] Clean and readable

## Documentation

- [ ] **Code Documentation**
  - [ ] Class header comment
  - [ ] Method comments
  - [ ] Complex logic explained
  - [ ] TODOs resolved

- [ ] **Balance Notes**
  - [ ] Document base value choice
  - [ ] Note scaling type reason
  - [ ] List similar boons
  - [ ] Mention any limits

## Final Checks

- [ ] **Integration Complete**
  - [ ] Boon in correct pool
  - [ ] Appears in game
  - [ ] All rarities work
  - [ ] No console errors

- [ ] **Player Experience**
  - [ ] Fun to use
  - [ ] Clear effect
  - [ ] Worthwhile choice
  - [ ] Interesting decisions

- [ ] **Performance**
  - [ ] No lag on application
  - [ ] Stacking doesn't slow game
  - [ ] Effects are optimized
  - [ ] Memory usage acceptable

## Common Pitfalls

### Avoid These Mistakes

- [ ] ❌ Hardcoding values instead of using `get_effective_power()`
- [ ] ❌ Forgetting to check entity type
- [ ] ❌ Not printing debug confirmation
- [ ] ❌ Wrong pool placement (common vs unique)
- [ ] ❌ Missing from boon_manager.gd
- [ ] ❌ Incorrect scaling type (MORE vs Increased)
- [ ] ❌ No null checks for weapons/components
- [ ] ❌ Forgetting `is_repeatable` for stackable boons

### Remember These Best Practices

- [ ] ✅ One base value to rule them all
- [ ] ✅ Rarity multipliers handle scaling
- [ ] ✅ Clear descriptions with values
- [ ] ✅ Appropriate debug output
- [ ] ✅ Proper type checking
- [ ] ✅ Consistent naming
- [ ] ✅ Balanced at Common first
- [ ] ✅ Test all rarities

## Boon Type Quick Reference

### Stat Boons (Common Pool)
- Simple numerical increases
- Use Increased (additive) scaling
- Examples: Health, Damage, Speed

### Percentage Boons (Common Pool)
- Percentage modifiers
- Can use MORE or Increased
- Examples: Crit Chance, Attack Speed

### Weapon Modifiers (Common Pool)
- Check weapon tags
- Modify weapon behavior
- Examples: Arc Extension, Pierce

### Unique Boons (Unique Pool)
- Special mechanics
- Often have drawbacks
- May not use standard scaling
- Examples: Glass Cannon, Vampiric

### Stackable Uniques (Unique Pool)
- `is_repeatable = true`
- Interesting stack patterns
- Examples: Twin Slash, Echo Strike

## Notes Section

Use this space for boon-specific notes:

```
Example:
- Consider making this 6% at base instead of 5%
- Might need visual effect at 5+ stacks
- Could synergize too well with X boon
```
