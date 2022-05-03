# eotl_class_limits

This is a TF2 sourcemod plugin.

This is meant to be a drop in replacement for the [classrestrict](https://forums.alliedmods.net/showpost.php?p=2696880&postcount=479) plugin.  The original plugin was causing server crashes, which prompted the creation of eotl_class_limits plugin.  I did not implement the sm_classrestrict_(flags|immunity) ConVars from the original plug, as no use to us.

The classrestrict plugin would allow the player to switch to any class and then would check to see if there are too many of that class.  If player caused an over limit it would force change the player to another (previous) class and respawn them.  This force change/respawn is what was causing the crashes.

Th eotl_class_limits plugin takes a different approach in that it will block the class change (joinclass [class]) if it will cause there to be too many of that class.

A check is also done on player death to see if there are excessive players for the player's current class.  If there is the plugin will pick a valid random class and spoof a "joinclass [class]" command for them to force them off the over limit class.  If this happens the player will receive the following notice in chat.

```
WARNING: Number of [class] over allowed limit ([limit]), forcing you to random class [new class]
```

In theory this check should only trigger under 2 conditions:
  * A ConVar update that results in a class overage
  * When the team swap happens at the end of a round and there ends up being to many of a class after the swap.  (ie: red team has 3 pyros, blue team has a 2 pyro limit, team swap happens, first pyro to die will get forced off the class).

This plugin also has a extra feature (!wantclass) to allow players to indicate that they want to play a class that is full.  When the player dies, it will auto switch to their wanted class if its under its limit.

### Say Commands
<hr>

**!wantclass [class]**

This will flag the player as wanting to be [class].  When the player dies it will switch them to [class] if [class] is below its class limit.

!wantclass is persistent across rounds but not map changes.  When a client becomes their wanted class, it will auto-remove the wanted for them.

!wantclass called without any args will clear the wanted class if they have a one, else it will print the command usage.

Example: !wantclass pyro

### ConVars
<hr>

With eotl_class_limits meant to be a drop in replacement for the classrestrict plugin it has a number of the same convars instead of the expected eotl_class_limits_*

**sm_classrestrict_enabled [0/1]**

Enable/Disable the plugin

Default: 1 (enabled)

**sm_classrestrict_sounds [0/1]**

When a player is denied changing a class the plugin can be configured to play one of TF2's built in 'no' sounds for the class.  This option disables/enables this feature.

Default: 1 (enabled)

**sm_classrestrict_blu_demomen [num]<br/>
sm_classrestrict_blu_engineers [num]<br/>
sm_classrestrict_blu_heavies [num]<br/>
sm_classrestrict_blu_medics [num]<br/>
sm_classrestrict_blu_pyros [num]<br/>
sm_classrestrict_blu_scouts [num]<br/>
sm_classrestrict_blu_snipers [num]<br/>
sm_classrestrict_blu_soldiers [num]<br/>
sm_classrestrict_blu_spies [num]**<p>

**sm_classrestrict_red_demomen [num]<br/>
sm_classrestrict_red_engineers [num]<br/>
sm_classrestrict_red_heavies [num]<br/>
sm_classrestrict_red_medics [num]<br/>
sm_classrestrict_red_pyros [num]<br/>
sm_classrestrict_red_scouts [num]<br/>
sm_classrestrict_red_snipers [num]<br/>
sm_classrestrict_red_soldiers [num]<br/>
sm_classrestrict_red_spies [num]<br/>**

This restricts the number of each class for each team.  A value of -1 will disable any limit.

Default: -1 (no limit)

**eotl_class_limits_wantclass [0/1]**

Disable/Enable the !wantclass command

Default: 1 (enabled)

**eotl_class_limits_debug [0/1]**

Disable/Enable debug logging

Default: 0 (disabled)