extends Node3D
## Escenario de la vista 3D: cielo, luz, sombras, cámara y, en el modo realista, un suelo continuo
## que se pierde en la bruma del horizonte (sin «isla flotante»).
## Solo dibuja; no toca la simulación. Los valores son de aspecto (ver tools/captura_epoca.gd).

var camera: Camera3D
var sun: DirectionalLight3D
## Exposición del tonemap (1,0 = la de siempre). Las escenas de colores claros piden menos.
var exposure := 1.0
## Modo «adulto»: luz cálida y baja, sombras cálidas (ambiente neutro, no del cielo azul), colores algo
## apagados, sin nubes de dibujo animado y suelo continuo hasta el horizonte.
var realista := false
## Altura del suelo continuo respecto a la cara superior de las casillas (que están en y = 0).
const SUELO_Y := -0.30
const HORIZONTE := Color(0.84, 0.79, 0.68)


## shadows: sombras del sol. pitch: inclinación de la cámara en grados (90 = desde arriba).
## distance: distancia de la cámara al punto mirado. fov: ángulo horizontal (la pantalla es vertical).
func setup(target: Vector3, shadows: bool = true, pitch: float = 42.0, distance: float = 32.0, fov: float = 34.0) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	if realista:
		sky_material.sky_top_color = Color(0.36, 0.52, 0.72)
		sky_material.sky_horizon_color = HORIZONTE
		sky_material.ground_horizon_color = HORIZONTE
		sky_material.ground_bottom_color = HORIZONTE
	else:
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
	if realista:
		# Ambiente neutro y cálido: las sombras salen marrones, no turquesa.
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.66, 0.60, 0.55)
		env.ambient_light_energy = 0.52
	else:
		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = exposure
	env.fog_enabled = true
	env.fog_light_color = HORIZONTE if realista else Color(0.80, 0.89, 0.96)
	env.fog_density = 0.001
	env.fog_sky_affect = 0.0
	env.glow_enabled = false
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0 if realista else 1.08
	env.adjustment_contrast = 1.10 if realista else 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	if realista:
		sun.rotation_degrees = Vector3(-33, -58, 0)
		sun.light_color = Color(1.0, 0.86, 0.68)
		sun.light_energy = 1.18
	else:
		sun.rotation_degrees = Vector3(-42, -52, 0)
		sun.light_color = Color(1.0, 0.93, 0.82)
		sun.light_energy = 0.95
	sun.shadow_enabled = shadows
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 45.0
	add_child(sun)

	if realista:
		add_child(_suelo_continuo())
	else:
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
	camera.far = 600.0
	var a := deg_to_rad(pitch)
	camera.position = target + Vector3(0, sin(a), cos(a)) * distance
	add_child(camera)
	camera.look_at(target, Vector3.UP)
	camera.current = true


## Disco de tierra que va del color del suelo al de la bruma del horizonte. Sin sombreado: así su
## borde exterior es exactamente el color del horizonte y se funde con el cielo.
func _suelo_continuo() -> MeshInstance3D:
	var tierra := Color(0.47, 0.40, 0.29)
	var anillos := [0.0, 9.0, 14.0, 22.0, 38.0, 70.0, 120.0, 220.0, 420.0]
	var segs := 40
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var n := PackedVector3Array()
	for k in anillos.size() - 1:
		var r0: float = anillos[k]
		var r1: float = anillos[k + 1]
		var c0 := tierra.lerp(HORIZONTE, smoothstep(14.0, 200.0, r0))
		var c1 := tierra.lerp(HORIZONTE, smoothstep(14.0, 200.0, r1))
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			var p00 := Vector3(cos(a0) * r0, SUELO_Y, sin(a0) * r0)
			var p01 := Vector3(cos(a1) * r0, SUELO_Y, sin(a1) * r0)
			var p10 := Vector3(cos(a0) * r1, SUELO_Y, sin(a0) * r1)
			var p11 := Vector3(cos(a1) * r1, SUELO_Y, sin(a1) * r1)
			for tri in [[p00, p01, p11, c0, c0, c1], [p00, p11, p10, c0, c1, c1]]:
				for j in 3:
					v.append(tri[j])
					c.append(tri[3 + j])
					n.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.name = "suelo_continuo"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
