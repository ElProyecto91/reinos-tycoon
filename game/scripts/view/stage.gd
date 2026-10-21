extends Node3D
## Escenario de la vista 3D: cielo, niebla, luz, sombras, nubes y cámara.
## Solo dibuja; no toca la simulación. Los valores son de aspecto (ver tools/captura_diorama.gd).

var camera: Camera3D
var sun: DirectionalLight3D


## shadows: sombras del sol. pitch: inclinación de la cámara en grados (90 = desde arriba).
## distance: distancia de la cámara al punto mirado. fov: ángulo horizontal (la pantalla es vertical).
func setup(target: Vector3, shadows: bool = true, pitch: float = 42.0, distance: float = 32.0, fov: float = 34.0) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.30, 0.52, 0.86)
	sky_material.sky_horizon_color = Color(0.80, 0.89, 0.96)
	sky_material.ground_horizon_color = Color(0.80, 0.89, 0.96)
	sky_material.ground_bottom_color = Color(0.62, 0.78, 0.92)
	sky_material.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.80, 0.89, 0.96)
	env.fog_density = 0.001
	env.fog_sky_affect = 0.0
	env.glow_enabled = false
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -52, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 0.95
	sun.shadow_enabled = shadows
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)

	# Unas nubes alrededor, lejos de la cámara (decoración; no cambian con el juego).
	var cloud_scene := load("res://assets/kaykit/models/cloud_big.gltf") as PackedScene
	var small_scene := load("res://assets/kaykit/models/cloud_small.gltf") as PackedScene
	var cloud_spots := [
		[cloud_scene, Vector3(-9, 8.0, -17), 2.4], [cloud_scene, Vector3(10, 9.0, -19), 2.8],
		[small_scene, Vector3(-3, 7.0, -21), 2.0],
	]
	for spot in cloud_spots:
		if spot[0] != null:
			var cloud := (spot[0] as PackedScene).instantiate() as Node3D
			cloud.position = target + (spot[1] as Vector3)
			cloud.scale = Vector3.ONE * float(spot[2])
			add_child(cloud)

	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = fov
	camera.far = 200.0
	var a := deg_to_rad(pitch)
	camera.position = target + Vector3(0, sin(a), cos(a)) * distance
	add_child(camera)
	camera.look_at(target, Vector3.UP)
	camera.current = true
