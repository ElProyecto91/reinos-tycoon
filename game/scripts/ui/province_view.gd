extends Control
## Vista 3D de la provincia elegida: el paisaje de época (scripts/view/) con lo que el jugador tiene
## construido, dibujado dentro de la pantalla del juego. Solo dibuja; no toca la simulación.
##
## Cómo se dibuja: una escena 3D en un SubViewport que se vuelca en un TextureRect. Se hace así (y no
## con SubViewportContainer) porque la pantalla se escala (stretch canvas_items): el viewport 3D se
## dimensiona a los píxeles reales para que no salga borroso.
## La escena es estática, así que NO se redibuja a 60 fps: solo cuando cambia lo construido, cuando
## cambia el tamaño y una vez por segundo (por si el sistema pierde la textura al pausar la aplicación).
## Rendimiento en el móvil: SIN MEDIR (ver docs/TEST_PLAN.md).

const Layout := preload("res://scripts/view/provincia_layout.gd")
const CiudadEpoca := preload("res://scripts/view/ciudad_epoca.gd")
const StageScript := preload("res://scripts/view/stage.gd")
const GenteScript := preload("res://scripts/view/epoca_gente.gd")

const REFRESCO_SEGUNDOS := 1.0
## Con la gente en movimiento se redibuja a este ritmo (no a 60 fps: ahorra batería). Sin medir en el móvil.
const FOTOGRAMAS_ANIMACION := 15.0
## Cámara: inclinación (grados sobre el horizonte), distancia al punto mirado y campo de visión horizontal.
const INCLINACION := 44.0
const DISTANCIA := 25.5
const CAMPO := 32.0
const EXPOSICION := 1.0
## Lado máximo del viewport 3D en píxeles (límite de coste en pantallas muy grandes).
const LADO_MAXIMO := 1400

## Sombras del sol. Más bonitas, pero cuestan; se pueden quitar sin tocar nada más.
var sombras := true
## Gente en movimiento (aldeanos, obreros, humo). Si es false la escena vuelve a ser estática.
var animar := true
## Veces que se ha reconstruido la escena (para pruebas).
var reconstrucciones := 0

var _vp: SubViewport
var _tex: TextureRect
var _mundo: Node3D
var _ciudad = null
var _stage = null
var _firma := ""
var _firma_gente := ""
var _gente = null
var _acumulado := 0.0
var _aspecto := ""
var _ocultos: Dictionary = {}
var _reloj := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	_vp.size = Vector2i(64, 64)
	add_child(_vp)
	_mundo = Node3D.new()
	_vp.add_child(_mundo)
	_tex = TextureRect.new()
	_tex.texture = _vp.get_texture()
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_tex)
	resized.connect(_ajustar_tamano)
	visibility_changed.connect(dibujar_de_nuevo)
	_ajustar_tamano()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if animar and _gente != null:
		_acumulado += delta
		if _acumulado >= 1.0 / FOTOGRAMAS_ANIMACION:
			_gente.avanzar(_acumulado)
			_acumulado = 0.0
			dibujar_de_nuevo()
			return
	_reloj += delta
	if _reloj >= REFRESCO_SEGUNDOS:
		_reloj = 0.0
		dibujar_de_nuevo()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		dibujar_de_nuevo()


## Activa o quita las sombras del sol (si la escena ya existe, al momento).
func set_sombras(activas: bool) -> void:
	sombras = activas
	if _stage != null and _stage.sun != null:
		_stage.sun.shadow_enabled = activas
	dibujar_de_nuevo()


## Activa o quita la gente en movimiento (la escena queda estática y vuelve a dibujarse solo al cambiar).
func set_animacion(activa: bool) -> void:
	animar = activa
	_acumulado = 0.0
	dibujar_de_nuevo()


## Pide que se redibuje el siguiente fotograma.
func dibujar_de_nuevo() -> void:
	if _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Aspecto de la provincia dibujada (vacío si no hay ninguna).
func aspecto() -> String:
	return _aspecto


## Edificios u obras que no caben en el paisaje y por tanto no se dibujan (tipo -> cantidad).
func ocultos() -> Dictionary:
	return _ocultos


## Triángulos de los edificios generados por código en la escena actual.
func triangulos() -> int:
	return 0 if _ciudad == null else int(_ciudad.triangulos)


func firma() -> String:
	return _firma


## Dibuja la provincia (un objeto de scripts/sim/province.gd) o la vacía si es null.
## Si lo que se dibuja no ha cambiado, no hace nada.
func mostrar(province) -> void:
	if province == null:
		_limpiar()
		return
	var aspecto_nuevo := Layout.aspecto_de(province.id)
	if aspecto_nuevo == "":
		push_warning("Provincia sin aspecto 3D: " + str(province.id))
		_limpiar()
		return
	var plan := Layout.plan(aspecto_nuevo, province.buildings, province.projects, province.population, province.recruits)
	var firma_nueva := Layout.firma(aspecto_nuevo, plan)
	if firma_nueva == _firma:
		var fg := Layout.firma_gente(plan)
		if fg != _firma_gente and _gente != null:
			_firma_gente = fg
			_gente.configurar(_ciudad, plan["gente"], aspecto_nuevo != "norte")
			dibujar_de_nuevo()
		return
	_reconstruir(aspecto_nuevo, plan, firma_nueva)


func _limpiar() -> void:
	if _ciudad != null:
		_ciudad.queue_free()
		_ciudad = null
	if _gente != null:
		_gente.queue_free()
		_gente = null
	_firma = ""
	_firma_gente = ""
	_aspecto = ""
	_ocultos = {}
	dibujar_de_nuevo()


func _reconstruir(aspecto_nuevo: String, plan: Dictionary, firma_nueva: String) -> void:
	if _vp == null:
		return
	if _ciudad != null:
		_mundo.remove_child(_ciudad)
		_ciudad.queue_free()
		_ciudad = null
	if _gente != null:
		_mundo.remove_child(_gente)
		_gente.queue_free()
		_gente = null
	var ciudad = CiudadEpoca.new()
	ciudad.region = aspecto_nuevo
	var capas: Dictionary = ciudad.layers_from_cells(plan["radio"], plan["cells"])
	if not capas["errors"].is_empty():
		push_error("Diseño de provincia fuera del mapa: " + str(capas["errors"]))
		ciudad.free()
		return
	_mundo.add_child(ciudad)
	if not ciudad.build(capas["terrain"], capas["things"], capas["paths"]):
		push_error("No se pudo construir la vista 3D de la provincia.")
		_mundo.remove_child(ciudad)
		ciudad.free()
		return
	_ciudad = ciudad
	_aspecto = aspecto_nuevo
	_firma = firma_nueva
	_ocultos = plan["ocultos"]
	_gente = GenteScript.new()
	_mundo.add_child(_gente)
	_gente.configurar(_ciudad, plan["gente"], aspecto_nuevo != "norte")
	_firma_gente = Layout.firma_gente(plan)
	if _stage == null:
		_stage = StageScript.new()
		_mundo.add_child(_stage)
		_stage.exposure = EXPOSICION
		_stage.realista = true
		var foco: Vector3 = plan["foco"]
		_stage.setup(foco, sombras, INCLINACION, DISTANCIA, CAMPO)
	reconstrucciones += 1
	dibujar_de_nuevo()


## El viewport 3D mide lo que la pantalla muestre de verdad en píxeles (no en unidades de interfaz).
func _ajustar_tamano() -> void:
	if _vp == null:
		return
	var escala := 1.0
	if is_inside_tree():
		escala = get_global_transform_with_canvas().get_scale().x
		if escala <= 0.0:
			escala = 1.0
	var px := Vector2(size.x * escala, size.y * escala)
	var mayor := maxf(px.x, px.y)
	if mayor > float(LADO_MAXIMO):
		px *= float(LADO_MAXIMO) / mayor
	_vp.size = Vector2i(maxi(int(round(px.x)), 16), maxi(int(round(px.y)), 16))
	dibujar_de_nuevo()
