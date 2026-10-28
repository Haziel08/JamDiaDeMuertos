extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
var posicion_sprite_original: Vector2

var speed = 75.0
var last_direction = "down"
var vidas: int = 3
var invulnerable: bool = false
var tiempo_invulnerable: float = 2.0

#Variables de salto
var saltando: bool = false
var altura_salto: float = 0.0
var duracion_salto: float = 0.4
var tiempo_salto: float = 0.0


@export var corazon_lleno: Texture2D
@export var corazon_vacio: Texture2D

@onready var corazones: Array[TextureRect]=[
	$"../HUD/Corazones/Corazon1",
	$"../HUD/Corazones/Corazon2",
	$"../HUD/Corazones/Corazon3"
]

func actualizar_corazones()-> void:
	for i in range(corazones.size()):
		if i < vidas:
			corazones[i].texture = corazon_lleno
		else:
			corazones[i].texture = corazon_vacio

#Reaparición al tocar el agua
func respawn():
	self.global_position = Vector2(-198.0, -5.0)

#Daño al tocar el agua
func recibir_dano() -> void:
	if invulnerable or saltando:
		return
		
	vidas -=1
	print("Vidas restantes: " , vidas)
	actualizar_corazones()
	
	if vidas <=0:
		morir()
		return
		
	invulnerable = true
	
	await parpadear()
		
		
func parpadear() -> void:
		var tiempo_transcurrido: float = 0.0
		
		while tiempo_transcurrido < tiempo_invulnerable:
			animated_sprite_2d.visible = false
			await get_tree().create_timer(0.1).timeout
			
			animated_sprite_2d.visible = true
			await get_tree().create_timer(0.1).timeout
			
			tiempo_transcurrido += 0.5
			
		animated_sprite_2d.visible = true
		invulnerable = false
	
		print("Fin de la invulnerabilidad")

func morir() -> void:
	print("Moriste")
	queue_free()

func _physics_process(delta):
	get_input()
	move_and_slide()
	
func get_input():
	var input_direction = Input.get_vector("left", "right", "up", "down")
	
	if input_direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		update_animation("idle")
		return
	
	if abs(input_direction.x) > abs(input_direction.y):
		#Movimiento horizontal
		if input_direction.x > 0:
			last_direction = "right"
		else:
			last_direction = "left"
	else:
		if input_direction.y > 0:
			last_direction = "down"
		else:
			last_direction = "up"
			
	update_animation("run")	
	velocity = input_direction * speed

func update_animation(state):
	animated_sprite_2d.play(state + "_" + last_direction)

func _on_hit_box_body_entered(body: Node2D) -> void:
	pass 
	
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") and not saltando:
		saltando = true
		tiempo_salto = 0.0
		
func actualizar_salto(delta: float) -> void:
	if not saltando:
		return
	tiempo_salto += delta
	
	#Calcula la altura del salto
	var progreso: float = tiempo_salto / duracion_salto
	altura_salto = sin(progreso * PI) * 20.0
	
	#Termina el salto
	if tiempo_salto >= duracion_salto:
		saltando = false
		altura_salto = 0.0
	
	animated_sprite_2d.position.y = posicion_sprite_original.y - altura_salto

func _process(delta: float) -> void:
	actualizar_salto(delta)
	
func _ready() -> void:
	posicion_sprite_original = animated_sprite_2d.position
