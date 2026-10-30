extends Control
## Panel de créditos. Emite "closed" al cerrarse.

signal closed

## Equipo: nombre y enlaces (en orden).
const PEOPLE := [
	{
		"name": "Diego Alan Aldrighetti",
		"github": "https://github.com/Sorx4s",
		"linkedin": "https://www.linkedin.com/in/dgantti",
	},
	{
		"name": "Haziel Ibares Sánchez",
		"github": "https://github.com/Haziel08",
		"linkedin": "https://www.linkedin.com/in/haziel-is/",
	},
]
const ICON_GITHUB := preload("res://menus/credits/icono_github.png")
const ICON_LINKEDIN := preload("res://menus/credits/icono_linkedin.png")
const STONE_BUTTON := preload("res://common/ui/stone_button.gd")

@onready var back_button: Button = %BackButton
@onready var people_box: VBoxContainer = %People


func _ready() -> void:
	back_button.pressed.connect(close)
	_build_people()


func _build_people() -> void:
	## Por cada persona: su nombre y abajo los íconos de GitHub y LinkedIn (abren su perfil).
	for person in PEOPLE:
		var name_label := Label.new()
		name_label.text = person.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		people_box.add_child(name_label)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		people_box.add_child(row)
		row.add_child(_link_icon(ICON_GITHUB, person.github, "GitHub"))
		row.add_child(_link_icon(ICON_LINKEDIN, person.linkedin, "LinkedIn"))
		var space := Control.new()
		space.custom_minimum_size = Vector2(0, 4)
		people_box.add_child(space)


func _link_icon(icon: Texture2D, url: String, site: String) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = icon
	b.tooltip_text = site
	b.set_script(STONE_BUTTON)   # crece un poco al pasar el cursor
	b.pressed.connect(func(): OS.shell_open(url))
	return b


func open() -> void:
	show()
	back_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	# Esc también cierra el panel
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
