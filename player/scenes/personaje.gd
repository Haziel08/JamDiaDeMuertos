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
var altura_salto: float = 32.0
var duracion_salto: float = 0.5
var tiempo_salto: float = 0.0

#Variables de barco
var sobre_barco: bool = false
var barco_actual: Node2D = null
var posicion_anterior_barco: Vector2 = Vector2.ZERO

@onready var dectector_aterrizaje: Area2D = $DetectorAterrizaje

@export var corazon_lleno: Texture2D
@export var corazon_vacio: Texture2D

#Reaparición: el jugador reaparece en la última orilla que pisó
@export var reaparicion_izquierda: Vector2 = Vector2(-198.0, -5.0)
@export var reaparicion_derecha: Vector2 = Vector2(196.0, -5.0)
#Límites del agua: más a la izquierda de esto es la orilla izquierda, más a la derecha es la derecha
@export var orilla_izquierda_x: float = -165.0
@export var orilla_derecha_x: float = 178.0
var punto_reaparicion: Vector2 = Vector2(-198.0, -5.0)

#Flores recolectables
var flores_recogidas: int = 0
var total_flores: int = 0

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

#Reaparición al tocar el agua: en la orilla donde estuvo por última vez
func respawn():
	self.global_position = punto_reaparicion

#Revisa en qué orilla está parado para saber dónde reaparecer
func actualizar_orilla() -> void:
	if saltando or sobre_barco:
		return
	if global_position.x <= orilla_izquierda_x:
		punto_reaparicion = reaparicion_izquierda
	elif global_position.x >= orilla_derecha_x:
		punto_reaparicion = reaparicion_derecha

#Se llama desde la flor cuando el jugador la toca
func recoger_flor() -> void:
	flores_recogidas += 1
	print("Flores: ", flores_recogidas, "/", total_flores)
	$"../HUD".actualizar_flores(flores_recogidas, total_flores)

	if flores_recogidas >= total_flores:
		print("¡Recolectaste todas las flores!")

#Daño al tocar el agua
func recibir_dano() -> void:
	if invulnerable or saltando or sobre_barco:
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
			
			tiempo_transcurrido += 0.2   # cada vuelta dura 0.1 + 0.1 segundos
			
		animated_sprite_2d.visible = true
		invulnerable = false
	
		print("Fin de la invulnerabilidad")

func morir() -> void:
	print("Moriste")
	# Antes se borraba al jugador (queue_free) y el juego se quedaba congelado.
	# Ahora se detiene, se desvanece y el minijuego vuelve a empezar.
	set_physics_process(false)
	set_process(false)
	set_process_input(false)
	var tween := create_tween()
	tween.tween_property(animated_sprite_2d, "modulate:a", 0.0, 0.6)
	await get_tree().create_timer(1.5).timeout
	get_tree().reload_current_scene()

func _physics_process(delta: float) -> void:
	get_input()
	move_and_slide()
	seguir_barco()
	revisar_agua()
	actualizar_orilla()


func revisar_agua() -> void:
	## El agua se revisa en cada cuadro (no solo al entrar), así el jugador no puede
	## quedarse caminando en el agua cuando se le acaba la invulnerabilidad.
	if invulnerable or saltando or sobre_barco:
		return
	for area in $Hurtbox.get_overlapping_areas():
		if area.is_in_group("agua"):
			caer_al_agua()
			return
	
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

func _on_hit_box_area_entered(area: Area2D) -> void:
	print("Área detectada: ", area.name)

	if area.name != "Hurtbox":
		return

	var jugador = area.get_parent()

	if jugador.saltando:
		return

	if jugador.sobre_barco:
		return

	jugador.recibir_dano()
	
	
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") and not saltando:
		saltando = true
		tiempo_salto = 0.0
		
func actualizar_salto(delta: float) -> void:
	if not saltando:
		return
	tiempo_salto += delta
	
	#Calcula la altura visual del salto
	var progreso: float = tiempo_salto / duracion_salto
	progreso = clampf(progreso, 0.0, 1.0)
	
	altura_salto = sin(progreso * PI) * 20.0
	
	#Eleva el sprite visualmente
	animated_sprite_2d.position.y = (
		posicion_sprite_original.y - altura_salto
	)
	
	#Comprueba si el salto ha terminado
	if tiempo_salto >= duracion_salto:
		saltando = false
		altura_salto = 0.0
		
		animated_sprite_2d.position = posicion_sprite_original
		
		#Espera a que actualice las colisiones
		await get_tree().physics_frame
	 
		comprobar_aterrizaje()
	
func comprobar_aterrizaje() -> void:
	barco_actual = null
	sobre_barco = false

	# Buscar un barco
	for area in dectector_aterrizaje.get_overlapping_areas():
		if area.is_in_group("zona_barco"):
			barco_actual = area.get_parent() as Node2D

			if barco_actual != null:
				sobre_barco = true
				posicion_anterior_barco = barco_actual.global_position

				print("¡Aterrizaje correcto!")
				print("Sobre barco: ", sobre_barco)
				return

	# Si no hay barco, comprobar si estamos en el agua
	for area in $Hurtbox.get_overlapping_areas():
		if area.is_in_group("agua"):
			print("¡Aterrizaste en el agua!")
			caer_al_agua()
			return

	# No se encontró ni barco ni agua
	print("Aterrizaste en suelo seguro")
		
	

func seguir_barco()-> void:
	if saltando:
		return
		
	if not is_instance_valid(barco_actual):
		barco_actual = null
		sobre_barco = false
		return
		
	var desplazamiento: Vector2 = (
		barco_actual.global_position - posicion_anterior_barco
	)
	
	global_position += desplazamiento
	
	posicion_anterior_barco = barco_actual.global_position	

func _process(delta: float) -> void:
	actualizar_salto(delta)
	
func _ready() -> void:
	posicion_sprite_original = animated_sprite_2d.position
	punto_reaparicion = reaparicion_izquierda

	#Cuenta cuántas flores hay en el nivel
	total_flores = get_tree().get_nodes_in_group("flor").size()
	$"../HUD".actualizar_flores(flores_recogidas, total_flores)
	actualizar_corazones()

func iniciar_salto() -> void:
	if saltando:
		return
	saltando = true
	tiempo_salto = 0.0
	
	#Dejar de seguir al barco anterior
	barco_actual = null
	sobre_barco = false

#Caer en agua
func caer_al_agua() -> void:
	if invulnerable or saltando or sobre_barco:
		return

	vidas -= 1

	print("¡Caíste al agua!")
	print("Vidas restantes: ", vidas)

	actualizar_corazones()

	if vidas <= 0:
		morir()
		return

	# Evita recibir daño repetido durante la reaparición
	invulnerable = true
	respawn()

	await parpadear()
	
func caer_de_borde() -> void:
	# Evitar procesar dos veces la misma caída
	if barco_actual == null:
		return

	# Dejar de seguir a la trajinera
	barco_actual = null
	sobre_barco = false
	saltando = false
	altura_salto = 0.0

	animated_sprite_2d.position = posicion_sprite_original

	# Si no está invulnerable, pierde una vida
	if not invulnerable:
		vidas -= 1

		print("¡Caíste del borde!")
		print("Vidas restantes: ", vidas)

		actualizar_corazones()

		if vidas <= 0:
			morir()
			return

		invulnerable = true

		# Inicia el parpadeo sin bloquear el movimiento del barco
		parpadear()

	# Reaparecer en la posición inicial
	respawn()
	
