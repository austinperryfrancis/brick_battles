# Agent Handoff

This is the working memory for future agents on this project. Read this before making changes.

## Product Direction

The user is building an open-source brick-style arcade vehicle combat game. The design target is broadly: a brick-built, arcade stunt/combat arena racer inspired by the feel of Rush 2049 battle mode, but implemented as an original Godot project with LEGO-like brick visuals.

The current priority is not polish. The project is still a playable prototype for tuning driving feel, pickups, mounted weapons, projectiles, explosions, and target interactions.

Keep work pragmatic:

- Use Godot 4.x. Current local version used successfully: Godot 4.5.1.
- Do not use Blender.
- BrickLink Studio exported DAE assets are visual-only.
- Physics should use simple collision shapes, not brick-by-brick collision.
- Prefer small, testable changes over broad rewrites.
- Preserve user tuning unless explicitly asked to change it.

## Current High-Level State

Main scene:

- `res://scenes/TestArena.tscn`
- Configured in `project.godot` as `run/main_scene`.

The playable prototype currently has:

- A flat gray 480x480 test arena.
- Multiple ramps, including longer angled gliding ramps around the outer arena.
- Perimeter walls.
- Barrels as knockable targets.
- A dummy car target using the same police car visual.
- A player car using a custom `RigidBody3D` raycast suspension/arcade tire controller.
- Follow camera.
- HUD with inventory text and pickup/fire flash messages.
- Pickups for rocket, grenade launcher, and minigun.
- Default 3-round bullet burst.
- Inventory weapon firing with `E`.
- Airborne side wings that deploy while holding Space to slow descent.

## Controls

Defined in `project.godot`:

- Enter: accelerate.
- Shift: brake/reverse.
- `A` / Left: steer left.
- `D` / Right: steer right.
- Space: handbrake while grounded; deploy airborne side wings while in the air.
- `R`: reset car upright above arena.
- `F` or left mouse: default bullet burst.
- `E`: use current inventory weapon.

Inventory is currently one slot only.

## Important Files

Project config:

- `project.godot`

Scenes:

- `scenes/TestArena.tscn`: main test arena.
- `scenes/BrickCar.tscn`: player car.
- `scenes/DummyCar.tscn`: passive target car.
- `scenes/Barrel.tscn`: simple rigid-body target.
- `scenes/ItemPickup.tscn`: floating orb pickup.
- `scenes/Bullet.tscn`: default bullet.
- `scenes/Rocket.tscn`: rocket projectile.
- `scenes/Grenade.tscn`: grenade projectile.
- `scenes/RocketMountVisual.tscn`: mounted rocket launcher visual.
- `scenes/RocketHolderVisual.tscn`: empty rocket holder visual, currently not used by `BrickCar`.
- `scenes/GrenadeLauncherVisual.tscn`: mounted grenade launcher visual.
- `scenes/WingVisual.tscn`: placeholder side wing visual used by airborne deployable wings.
- `scenes/ExplosionFlash.tscn`: simple explosion visual.
- `scenes/TruckTownMap.tscn`: alternate GLB map experiment, not the active main scene.

Scripts:

- `scripts/arcade_car.gd`: main driving, shooting, inventory, mounted weapon logic.
- `scripts/follow_camera.gd`: smooth chase camera.
- `scripts/item_pickup.gd`: orb pickup behavior and respawn.
- `scripts/inventory_hud.gd`: HUD label and pickup/fire flash.
- `scripts/bullet.gd`: raycast-moving bullet with impulse on hit.
- `scripts/rocket.gd`: straight rocket with explosion impulse.
- `scripts/grenade.gd`: arcing/bouncing grenade with explosion impulse.
- `scripts/explosion_flash.gd`: temporary explosion flash scale/fade.
- `scripts/map_collision_builder.gd`: creates trimesh collisions for the experimental GLB map.

## Vehicle Physics

The player car is now a `RigidBody3D` in `scenes/BrickCar.tscn`, with four named `RayCast3D` wheel probes. The visual car is not used for physics.

This replaced the previous `VehicleBody3D`/`VehicleWheel3D` setup after repeated handling problems. The intended model is the more professional Godot pattern found in deeper vehicle projects: a rigid body plus raycast suspension, explicit tire/grip forces, and arcade yaw control.

Important current car tuning values in `scripts/arcade_car.gd`:

- `max_speed = 48.0`
- `max_reverse_speed = 16.0`
- `engine_acceleration = 34.0`
- `reverse_acceleration = 16.0`
- `brake_deceleration = 38.0`
- `handbrake_deceleration = 8.0`
- `low_speed_boost = 1.35`
- `rolling_deceleration = 0.5`
- `coast_deceleration = 2.2`
- `lateral_grip = 6.5`
- `handbrake_lateral_grip = 2.0`
- `max_turn_rate = 1.9`
- `high_speed_turn_rate = 1.05`
- `steering_response = 5.5`
- `steering_return_response = 8.0`
- `yaw_response = 7.0`
- `minimum_turn_authority = 0.28`
- `steering_sign = 1.0`
- `no_steer_yaw_damping = 4.0`
- `wheel_ray_length = 0.85`
- `suspension_rest_length = 0.45`
- `suspension_strength = 34.0`
- `suspension_damping = 6.5`
- `grounded_upright_strength = 18.0`
- `pitch_roll_damping = 7.0`
- `extra_air_gravity = 4.0`
- `max_jump_up_speed = 7.0`
- `air_angular_damping = 1.0`
- `wing_max_fall_speed = 6.0`
- `wing_descent_brake = 35.0`
- `wing_extra_gravity_scale = 0.2`
- `wing_air_angular_damping = 2.4`

Physics intent:

- Arcade, not realistic sim.
- Stable enough to drive without tipping constantly.
- `scripts/arcade_car.gd` owns suspension, drive, braking, sideways grip, yaw steering, grounded pitch/roll damping, and airborne wing descent control.
- The four wheel probes are still named `FrontLeftWheel`, `FrontRightWheel`, `RearLeftWheel`, and `RearRightWheel`, but they are `RayCast3D` nodes now.
- The imported police car visual is mirrored/rotated relative to raw Godot X-side intuition. In `BrickCar.tscn`, visual left is mapped to positive X, so `FrontLeftWheel`, `RearLeftWheel`, and `LeftWingMount` intentionally use positive X. Do not swap them back just because negative X normally reads as left.
- Steering input is intentionally `steer_left - steer_right`, multiplied by `steering_sign`. If a future visual/model import flips the turn direction, change `steering_sign` before rewriting controller math.
- Reduced air steering: drive and steering forces are ignored when no probes are grounded.
- The car damps yaw when there is no steering input, which prevents it from continuing to rotate after input is released.
- Handbrake applies extra deceleration and lowers sideways grip for slides.
- Upright correction aligns to the averaged wheel-probe ground normal, so ramps should not feel like the car is fighting the slope.
- Holding Space while airborne deploys side wings and slows descent by reducing extra air gravity, capping fall speed, and adding extra air damping.

Tuning guidance:

- Faster acceleration: raise `engine_acceleration` or `low_speed_boost`.
- Higher top speed: raise `max_speed`.
- More nimble: raise `max_turn_rate`, `high_speed_turn_rate`, or `yaw_response`, but watch high-speed twitch.
- More planted grip: raise `lateral_grip`.
- More handbrake slide: lower `handbrake_lateral_grip`.
- Faster coast-down: raise `coast_deceleration` or `rolling_deceleration`.
- Less bouncing: raise `suspension_damping` or lower `suspension_strength`.
- Less flipping/lean: lower `center_of_mass` in `BrickCar.tscn`, raise `grounded_upright_strength`, or raise `pitch_roll_damping`.
- Less jumping/flying: lower `max_jump_up_speed` or raise `extra_air_gravity`.
- More wing float: lower `wing_max_fall_speed` or raise `wing_descent_brake`.
- Less wing float: raise `wing_max_fall_speed` or lower `wing_descent_brake`.

## Weapons And Inventory

The car has:

- `Muzzle`: front marker used for bullets and grenades.
- `WeaponMounts/PrimaryMount`: top marker where mounted weapon visuals attach.
- `WeaponMounts/PrimaryMount/RocketLaunchPoint`: roof launch marker for rockets.
- `WingMounts/LeftWingMount` and `WingMounts/RightWingMount`: side markers where airborne wing visuals attach dynamically. Their X positions follow the visible car sides, not raw Godot side intuition.

Inventory logic:

- `add_inventory_item(item_id, display_name, item_count)` rejects pickups if inventory is not empty.
- Inventory dictionary stores one item key with `display_name` and `count`.
- `use_inventory_item()` handles `minigun`, `rocket`, and `grenade_launcher`.
- When inventory becomes empty, `_clear_mounted_weapon_visual()` removes the mounted visual.

Current weapons:

- Default fire (`F` / left mouse): 3-round bullet burst.
- Minigun pickup: uses bullet scene with faster interval and more shots.
- Rocket pickup: mounts rocket launcher visual, fires one straight rocket from roof marker, then clears mount.
- Grenade launcher pickup: mounts grenade launcher visual, grants 3 grenades, fires arcing/bouncing grenade one per `E`, clears mount when count reaches zero.

Airborne wings:

- Use the existing `handbrake` input action, currently Space.
- Only affect physics while the car is airborne.
- Visuals are mounted dynamically from `wing_visual_scene` in `BrickCar.tscn`.
- The placeholder `WingVisual.tscn` is visual-only and can be replaced later with brick wing assets.
- The right wing is mirrored from the same visual by default. If a future wing visual needs custom animation, give its root script a `set_deploy_amount(deploy_amount, side_sign)` method.

Important weapon tuning values:

- `bullet_speed = 300.0`
- `bullet_impact_force = 35.0`
- `burst_count = 3`
- `minigun_burst_count = 50`
- `minigun_burst_interval = 0.035`
- `minigun_bullet_speed = 360.0`
- `rocket_speed = 42.0`
- `rocket_explosion_radius = 7.0`
- `rocket_explosion_force = 190.0`
- `grenade_forward_speed = 24.0`
- `grenade_upward_speed = 5.0`
- `grenade_gravity = 20.0`
- `grenade_fuse_time = 2.5`
- `grenade_explosion_radius = 5.5`
- `grenade_explosion_force = 140.0`
- `grenade_max_bounces = 4`
- `grenade_bounce_damping = 0.65`
- `grenade_min_bounce_speed = 4.0`

## Pickups

Pickups use `scenes/ItemPickup.tscn` and `scripts/item_pickup.gd`.

Current pickup IDs:

- `rocket`: blue orb, count 1.
- `grenade_launcher`: green orb, count 3.
- `minigun`: orange orb, count 1.

Pickup behavior:

- Floating/bobbing/spinning orb.
- On car body enter, calls `add_inventory_item`.
- If inventory accepts, orb hides, collision disables, and it respawns after `respawn_time` default 60 seconds.
- If inventory is already occupied, pickup is ignored and remains available.

## Asset Workflow

Raw Studio-exported files currently exist at the project root:

- `Classic Police Car.dae`
- `rocket_mount.dae`
- `rocket_holder_raw.dae`
- `rocket_raw_small.dae`
- `grenade Launcher.dae`
- `grenade.dae`
- `truck_town.glb`

Flattened game-ready DAE files live under:

- `assets/vehicles/brick_car/classic_police_car_flattened.dae`
- `assets/weapons/rocket_mount_flattened.dae`
- `assets/weapons/rocket_holder_flattened.dae`
- `assets/weapons/rocket_raw_small_flattened.dae`
- `assets/weapons/grenade_launcher_flattened.dae`
- `assets/weapons/grenade_flattened.dae`

Why flattening matters:

- Studio DAEs often contain `library_nodes` with `instance_node` references.
- Godot sometimes imports those as camera/light shells without the mesh.
- Studio DAEs can also include cameras and directional lights. If instanced directly, those can change scene lighting when a weapon is mounted.
- Flattened versions inline the geometry nodes and remove cameras/lights.

Do not point gameplay scenes directly at raw root-level Studio DAEs unless testing. Use flattened copies in `assets/`.

If a new Studio DAE is added:

1. Flatten it into `assets/weapons/` or the appropriate asset folder.
2. Remove imported cameras/lights and unresolved `instance_node` structure.
3. Run Godot import:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

4. Reference the flattened DAE from a small visual wrapper scene.
5. Run a headless load:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit
```

The user explicitly prefers direct DAE import and no Blender.

## Current Visual Orientation Notes

The police car visual uses a transform in `BrickCar.tscn` to align it with the physics body. Do not rotate the physics root to fix visual orientation.

Rocket and grenade launcher visuals are wrapper scenes with transform corrections:

- `RocketMountVisual.tscn`
- `GrenadeLauncherVisual.tscn`
- `Rocket.tscn` for the fired rocket DAE child.
- `Grenade.tscn` for the grenade DAE child.

Previous issue: rocket was sideways, then backwards. Current rocket orientation was corrected by editing child visual transforms, not projectile physics.

If a mounted weapon looks wrong:

- Adjust the wrapper scene child transform first.
- Do not move `WeaponMounts/PrimaryMount` unless the mount location itself is wrong.
- Do not rotate `BrickCar` root.

## Test Arena

`TestArena.tscn` is intentionally simple:

- Flat gray 480x480 floor.
- Five short central ramps.
- Ten longer outer gliding ramps with varied pitch/yaw angles for testing airborne wings.
- Four perimeter walls.
- Barrels.
- Dummy target car.
- Pickups.
- Directional light.
- Follow camera.
- HUD.

The user currently prefers this flat map for physics testing. `TruckTownMap.tscn` is an experimental alternate map from `truck_town.glb`; it has a helper that builds trimesh collision from mesh nodes. It is not the current active main scene.

## Known Quirks / Watch Items

- The car physics have been heavily tuned by feel. Avoid replacing `VehicleBody3D` with a totally different controller unless the user explicitly asks.
- The game uses simple collision shapes for cars and projectiles. Keep brick meshes visual-only.
- `RocketHolderVisual.tscn` exists but is not currently used by the player car. The user asked that after firing a rocket, the entire mount disappears instead of leaving an empty holder.
- The raw root-level DAE files may have `.import` files because Godot imported them during testing. Gameplay should still use flattened assets.
- Some validation scripts can produce `.uid` files. Remove temporary scripts and any temp UID files before finishing.
- The user often tests visually and reports "it feels wrong." Prefer small iterative tuning and explain the lever changed.
- Git state can change between sessions. Always run `git status --short` before committing or pushing.

## Verification Commands

Basic load check:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit
```

Import new assets:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
```

Useful search:

```bash
rg --files
rg -n "grenade_launcher|rocket|inventory|WeaponMount|Muzzle" scripts scenes
```

## Git / Remote

This project has been set up as a git repo and pushed previously to:

```text
git@github.com:austinperryfrancis/brick_battles.git
```

If asked to push:

1. Run `git status --short`.
2. Inspect diffs for files you touched.
3. Do not revert user changes.
4. Commit only relevant project changes.
5. Push to the configured remote.

Network/git push may require escalation in the Codex environment.

## Future Work Ideas

Near-term likely work:

- Tune car handling toward an arcade battle mode feel.
- Better mounted weapon positioning per car using `Marker3D`.
- Add more weapon types and pickups.
- Make weapon visual mounting data-driven instead of match statements in `arcade_car.gd`.
- Add health/damage, respawn, arena rounds, and score.
- Improve dummy targets or add simple AI cars.
- Replace placeholder barrels with brick-style destructibles.
- Add split-screen or multiplayer only later, not during current physics/weapon prototype phase.

Design direction:

- First make the car fun to drive.
- Then make shooting and explosions satisfying.
- Then add battle rules.
- Keep everything open-source-friendly and original.
