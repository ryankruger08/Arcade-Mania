@tool
extends Node3D

@export var room: Node3D
@export var imported_light_energy: float = 0.8
@export var imported_light_range: float = 9.0

func _ready() -> void:
	if not room:
		return
	for light in room.find_children("*", "OmniLight3D", true, false):
		# Blender imports these with a range of 4096, lighting every room at once.
		light.light_energy = imported_light_energy
		light.omni_range = imported_light_range
		light.omni_attenuation = 2.0
		light.light_size = 0.15
		light.shadow_enabled = true
		light.shadow_normal_bias = 0.5
		light.distance_fade_enabled = true
		light.distance_fade_begin = 18.0
		light.distance_fade_length = 8.0
		if light.name in ["Ceiling Light 77", "Ceiling Light 78", "Ceiling Light 79", "Ceiling Light 80"]:
			light.visible = false
	_setup_materials()
	_setup_screens()

func _setup_materials() -> void:
	var materials = {}
	for mesh in room.find_children("*", "MeshInstance3D", true, false):
		var floor_tile = str(mesh.name).begins_with("Checker Floor Tile")
		var ceiling_beam = str(mesh.name).begins_with("Ceiling Beam")
		if not floor_tile and not ceiling_beam:
			continue
		for i in mesh.mesh.get_surface_count():
			var original = mesh.get_active_material(i)
			if not original is StandardMaterial3D:
				continue
			if not materials.has(original):
				var material = original.duplicate()
				material.roughness = 0.45 if floor_tile else 0.4
				materials[original] = material
			mesh.set_surface_override_material(i, materials[original])

func _setup_screens() -> void:
	for cabinet in get_parent().get_children():
		if not cabinet.has_node("SubViewport") or not cabinet.has_node("arcade-machine1/Cube_018"):
			continue
		var screen = cabinet.get_node("arcade-machine1/Cube_018")
		var original = screen.get_active_material(0)
		if original is StandardMaterial3D:
			var material = original.duplicate()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.emission_enabled = false
			screen.set_surface_override_material(0, material)
