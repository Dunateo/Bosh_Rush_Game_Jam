extends CharacterBody3D

signal hp_changed
signal spell_changed
signal swap_positon
signal player_dead

@export_subgroup("Components")
@export var view: Node3D

@export_subgroup("Properties")
@export var movement_speed = 250
@export var max_hp = 100
@export var sword_damage = 10
@export var spell_range : int = 10

@export_subgroup("Hurt")
@export var HURT_FORCE =3000



enum Swap_State {MOVEMENT, SWAP, COOLDOWN,HURT}
enum State {STANDARD,HURT}


var movement_velocity: Vector3
var rotation_direction: float
var gravity = 0

var previously_floored = false

var swap_state_mode = Swap_State.MOVEMENT
var state = State.STANDARD
var hover_on_swappable_object : bool = false
var swappable_object_position : Vector3 = Vector3.ZERO

var sword_state : bool = false

var target = Vector3.ZERO
 
var hp: int

var game_state: bool = true
var hurt_direction:Vector3 = Vector3.ZERO
var hurt_force
var HURT_DECELERATION = HURT_FORCE * 0.1

@onready var particles_trail = $ParticlesTrail
@onready var model = $Character
@onready var animation = $Character/AnimationPlayer
@onready var animation_weapon = $Character/AnimationWeapon
@onready var swap_cooldown_timer = $SwapCooldownTimer
@onready var hurt_timer = $HurtTimer
@onready var spell_indicator = $SpellIndicator

# Functions
func _ready():
	hp = max_hp

func _physics_process(delta):
	# Handle functions
	handle_hp()
	if state == State.STANDARD:
		handle_action(delta)
		handle_controls(delta)
		handle_effects()
	elif  state ==State.HURT:
		push_back(delta)
	handle_gravity(delta)
		
	
	handle_movement(delta)
		

# Handle the action when you press your spell or sword
func handle_action(_delta):
	if Input.is_action_just_released("swap_button") :
			spell_indicator.visible = false
			if hover_on_swappable_object and swap_state_mode != Swap_State.COOLDOWN:
				start_swap()
	if Input.is_action_just_pressed("swap_button"):
			prepare_swap()
	if Input.is_action_just_pressed("right_click"):
		start_melee_attack()


#---SWAP---
func start_swap():
	swap_state_mode = Swap_State.SWAP
	emit_signal("swap_positon")
	swap_state_mode = Swap_State.COOLDOWN
	swap_cooldown_timer.start()
	emit_signal("spell_changed", "Cooldown")
	
func prepare_swap():
	spell_indicator.visible = true
	spell_indicator.scale.x = spell_range
	spell_indicator.scale.z = spell_range

# when the timer cooldown is finish reset the swap_state_mode
func _on_swap_cooldown_timer_timeout():
	swap_state_mode = Swap_State.MOVEMENT
	emit_signal("spell_changed", "Swap Ready")

#---HP---
func handle_hp():
	if hp <= 0:
		game_state = false
		emit_signal("player_dead", "Youu Loosee!")
	
func update_hp(value:int):
	hp=hp+value
	hp_changed.emit((float(hp)/float(max_hp))*100)

#--- HURT---
func hurt(impact_position):
	hurt_direction = (position - impact_position).normalized()
	hurt_direction = hurt_direction.rotated(Vector3.UP,-1.5708)
	print(hurt_direction)
	state = State.HURT
	hurt_force = HURT_FORCE
	hurt_timer.start()
	update_hp(-10)
	
func push_back(delta):
	hurt_force -= HURT_DECELERATION
	if hurt_force > 0:
		movement_velocity = hurt_direction * hurt_force *delta
	else:
		movement_velocity = Vector3.ZERO

func _on_hurt_timer_timeout():
	state = State.STANDARD
#---MELEE ATTACK---
func start_melee_attack():
	animation_weapon.play("knife", 0.5)
# detect collision with the boss and sword is pressed
func _on_area_3d_body_entered(body:Node3D):
	if body.get_name() == "Boss":
		body.hurted(-sword_damage)
		
#---UTIL---
func handle_movement(delta):
	var applied_velocity: Vector3
	applied_velocity = velocity.lerp(movement_velocity, delta * 10)
	applied_velocity.y = -gravity
	velocity = applied_velocity
	move_and_slide()
	if Vector2(velocity.z, velocity.x).length() > 0:
		rotation_direction = Vector2(velocity.z, velocity.x).angle()
		rotation.y = lerp_angle(rotation.y, rotation_direction, delta * 10)
	if position.y < -10:
		get_tree().reload_current_scene()
	previously_floored = is_on_floor()
	
	# Handle animation(s)
func handle_effects():
	particles_trail.emitting = false
	if is_on_floor():
		if abs(velocity.x) > 1 or abs(velocity.z) > 1:
			animation.play("walk", 0.5)
			particles_trail.emitting = true
			FMODRuntime.play_one_shot_path("event:/SFX/Hero/HeroFootsteps")
		else:
			animation.play("idle", 0.5)
			FMODRuntime.play_one_shot_path("event:/SFX/Hero/HeroFootstepsStop")

# old function to Handle movement input with keyboard
func handle_controls(delta):
	var input := Vector3.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.z = Input.get_axis("move_forward", "move_back")
	input = input.rotated(Vector3.UP, view.rotation.y).normalized()
	movement_velocity = input * movement_speed * delta
	
# Handle gravity
func handle_gravity(delta):
	gravity += 25 * delta
	if gravity > 0 and is_on_floor():
		gravity = 0



