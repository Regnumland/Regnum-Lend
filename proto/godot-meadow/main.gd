extends Node3D
## Пробна сцена Regnum Land на Godot 4.4: галявина-острів, герой, 20 нових 3D-попалів (кандидати з Blender),
## джойстик і кнопки для телефона, WASD / мишка для ПК. Сама гра (site/) тут не використовується й не змінюється.

const PALS := ["bambuzl", "grumrok", "hrozovyk", "ignis", "khvylezub", "koralovyk", "krylosha",
	"mirazhbr", "mororyh", "popeliukh", "sontseklyv", "zemleryi", "pukhoklub"]
const NAMES := {"bambuzl": "Бамбузл", "grumrok": "Грумрок", "hrozovyk": "Грозовик", "ignis": "Ігніс-Виверг",
	"khvylezub": "Хвилезуб", "koralovyk": "Кораловик", "krylosha": "Крилоша", "mirazhbr": "Міражбр",
	"mororyh": "Мороріг", "popeliukh": "Попелюх", "sontseklyv": "Сонцеклюв", "zemleryi": "Землерий", "pukhoklub": "Пухоклуб"}
const ISLAND_R := 58.0
const N_PALS := 20

var noise := FastNoiseLite.new()
var hero: Node3D
var hero_anim: AnimationPlayer
var hero_state := ""
var hero_act := 0.0
var hero_face := 0.0
var cam: Camera3D
var cam_yaw := 0.6
var cam_pitch := 0.42
var cam_dist := 7.5
var sun: DirectionalLight3D
var pals: Array = []
var grass: MultiMeshInstance3D
var flowers: MultiMeshInstance3D
var mobile := false
var high := true

# інтерфейс
var joy: Control
var joy_vec := Vector2.ZERO
var joy_id := -99
var drag_id := -99
var fps_label: Label
var info_label: Label
var q_button: Button
var toast: Label
var toast_t := 0.0


func h(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var base := noise.get_noise_2d(x, z) * 2.2 + noise.get_noise_2d(x * 3.1, z * 3.1) * 0.35
	var edge := clampf((r - (ISLAND_R - 10.0)) / 12.0, 0.0, 1.0)
	return lerpf(base + 0.6, -3.0, edge * edge)


func _ready() -> void:
	noise.seed = 7
	noise.frequency = 0.018
	mobile = DisplayServer.is_touchscreen_available() or OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")
	high = not mobile
	_env()
	_terrain()
	_scatter()
	_hero()
	_spawn_pals()
	_camera()
	_ui()
	_apply_quality()


# ---------------- світ ----------------
func _env() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.55, 0.88)
	sm.sky_horizon_color = Color(0.72, 0.84, 0.95)
	sm.ground_horizon_color = Color(0.72, 0.84, 0.95)
	sm.ground_bottom_color = Color(0.3, 0.45, 0.6)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.85, 0.95)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.05
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)


func _terrain() -> void:
	var size := 150.0
	var n := 110
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var g1 := Color(0.3, 0.48, 0.16)
	var g2 := Color(0.42, 0.58, 0.2)
	var sand := Color(0.78, 0.7, 0.5)
	for j in n + 1:
		for i in n + 1:
			var x := -size / 2 + size * i / n
			var z := -size / 2 + size * j / n
			var y := h(x, z)
			var c := g1.lerp(g2, clampf(noise.get_noise_2d(x * 2.0 + 50.0, z * 2.0) * 0.5 + 0.5, 0.0, 1.0))
			if y < 0.35:
				c = sand.lerp(c, clampf((y + 0.2) / 0.55, 0.0, 1.0))
			st.set_color(c)
			st.set_uv(Vector2(x, z) * 0.1)
			st.add_vertex(Vector3(x, y, z))
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			st.add_index(a); st.add_index(a + 1); st.add_index(a + n + 1)
			st.add_index(a + 1); st.add_index(a + n + 2); st.add_index(a + n + 1)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
	# море
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	sea.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.25, 0.58, 0.72, 0.92)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.roughness = 0.15
	sm.metallic_specular = 0.8
	sea.material_override = sm
	sea.position.y = -0.35
	add_child(sea)


func _rand_land(rng: RandomNumberGenerator, rmax := ISLAND_R - 12.0) -> Vector3:
	var a := rng.randf() * TAU
	var r := sqrt(rng.randf()) * rmax
	var x := cos(a) * r
	var z := sin(a) * r
	return Vector3(x, h(x, z), z)


func _mm(mesh: Mesh, xf: Array, mat: Material = null) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	if mat:
		mi.material_override = mat
	add_child(mi)
	return mi


func _glb_meshes(path: String) -> Array:
	var out := []
	var sc: Node = load(path).instantiate()
	for m in sc.find_children("*", "MeshInstance3D", true, false):
		out.append(m.mesh)
	sc.free()
	return out


func _scatter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# трава: травинка — трикутник, хитається від вітру в шейдері
	var blade := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.06, 0, 0), Vector3(0.06, 0, 0), Vector3(0.0, 1.0, 0.02),
		Vector3(0, 0, -0.06), Vector3(0, 0, 0.06), Vector3(0.02, 1.0, 0)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1), Vector2(0, 0), Vector2(1, 0), Vector2(0.5, 1)])
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	blade.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var gs := Shader.new()
	gs.code = """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform vec3 base_col : source_color = vec3(0.2, 0.36, 0.1);
uniform vec3 tip_col : source_color = vec3(0.5, 0.68, 0.24);
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = UV.y * UV.y;
	VERTEX.x += sin(TIME * 1.7 + w.x * 0.35 + w.z * 0.27) * 0.18 * k;
	VERTEX.z += cos(TIME * 1.3 + w.x * 0.21) * 0.12 * k;
	NORMAL = vec3(0.0, 1.0, 0.0);
}
void fragment() {
	ALBEDO = mix(base_col, tip_col, UV.y);
	ROUGHNESS = 1.0;
}
"""
	var gm := ShaderMaterial.new()
	gm.shader = gs
	var gx := []
	for i in (16000 if not mobile else 9000):
		var p := _rand_land(rng, ISLAND_R - 8.0)
		if p.y < 0.4:
			continue
		var s := rng.randf_range(0.28, 0.62)
		gx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * 1.3, s, s * 1.3)), p))
	grass = _mm(blade, gx, gm)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# квіти, кущі, каміння — з моделей теперішньої гри
	var fl := _glb_meshes("res://assets/env/meadow-flowers.glb")
	if fl.size():
		var fx := []
		for i in 500:
			var p := _rand_land(rng)
			fx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), p))
		flowers = _mm(fl[0], fx)
		flowers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bu := _glb_meshes("res://assets/env/berry-bush.glb")
	if bu.size():
		var bx := []
		for i in 22:
			bx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.3)), _rand_land(rng)))
		_mm(bu[0], bx)
	var rk := _glb_meshes("res://assets/env/terrain-rocks.glb")
	for k in rk.size():
		var rx := []
		for i in 9:
			var p := _rand_land(rng)
			rx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1, 0.8, 1) * rng.randf_range(0.7, 1.8)), p + Vector3(0, -0.1, 0)))
		_mm(rk[k], rx)
	# дерева: стовбур + крона з трьох куль
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12; trunk.bottom_radius = 0.2; trunk.height = 2.6; trunk.radial_segments = 7
	var tm := StandardMaterial3D.new(); tm.albedo_color = Color(0.45, 0.32, 0.2)
	trunk.material = tm
	var crown := SphereMesh.new()
	crown.radius = 1.0; crown.height = 1.8; crown.radial_segments = 9; crown.rings = 6
	var cm := StandardMaterial3D.new(); cm.albedo_color = Color(0.24, 0.45, 0.16); cm.roughness = 1.0
	crown.material = cm
	var tx := []
	var cx := []
	for i in 45:
		var p := _rand_land(rng)
		if p.length() < 9.0 or p.distance_to(Vector3(0, p.y, 4)) < 16.0:
			continue
		var s := rng.randf_range(0.8, 1.35)
		tx.append(Transform3D(Basis().scaled(Vector3.ONE * s), p + Vector3(0, 1.3 * s, 0)))
		for c in 3:
			var o := Vector3(rng.randf_range(-0.6, 0.6), 2.6 + c * 0.55, rng.randf_range(-0.6, 0.6)) * s
			cx.append(Transform3D(Basis().scaled(Vector3.ONE * s * rng.randf_range(0.8, 1.1)), p + o))
	_mm(trunk, tx)
	_mm(crown, cx)


# ---------------- герой ----------------
func _hero() -> void:
	hero = load("res://assets/env/hero-mobile.glb").instantiate()
	add_child(hero)
	hero.position = Vector3(0, h(0, 4), 4)
	hero_anim = hero.find_children("*", "AnimationPlayer", true, false)[0]
	for n in ["idle", "walk", "run", "swim"]:
		if hero_anim.has_animation(n):
			hero_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_hero_play("idle")


func _hero_play(n: String) -> void:
	if n == hero_state or not hero_anim.has_animation(n):
		return
	hero_state = n
	hero_anim.play(n, 0.2)


# ---------------- попали ----------------
func _spawn_pals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in N_PALS:
		var key: String = PALS[i % PALS.size()]
		var root: Node3D = load("res://assets/pals/%s.glb" % key).instantiate()
		add_child(root)
		var p := _rand_land(rng, ISLAND_R - 18.0)
		if p.length() < 6.0:
			p = Vector3(8, 0, 8)
		root.position = Vector3(p.x, h(p.x, p.z), p.z)
		root.rotation.y = rng.randf() * TAU
		var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
		var pal := {"key": key, "node": root, "ap": ap, "home": p, "target": p, "wait": rng.randf_range(0.5, 4.0),
			"face": root.rotation.y, "speed": 0.0, "blink": rng.randf_range(1.0, 4.0), "tree": null, "rng": rng.randi()}
		pal.tree = _pal_tree(ap)
		pals.append(pal)


## Дерево анімацій попала: стоїть ↔ іде (плавне змішування), удар/радість поверх, моргання — лише повіки.
func _pal_tree(ap: AnimationPlayer) -> AnimationTree:
	for n in ["idle", "walk"]:
		if ap.has_animation(n):
			ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	var bt := AnimationNodeBlendTree.new()
	var a_idle := AnimationNodeAnimation.new(); a_idle.animation = "idle"
	var a_walk := AnimationNodeAnimation.new(); a_walk.animation = "walk"
	var a_act := AnimationNodeAnimation.new(); a_act.animation = "attack"
	var a_bl := AnimationNodeAnimation.new(); a_bl.animation = "blink"
	var mv := AnimationNodeBlend2.new()
	var shot := AnimationNodeOneShot.new()
	shot.fadein_time = 0.12; shot.fadeout_time = 0.25
	var blink := AnimationNodeOneShot.new()
	blink.fadein_time = 0.02; blink.fadeout_time = 0.05
	if ap.has_animation("blink"):
		var an := ap.get_animation("blink")
		blink.filter_enabled = true
		for t in an.get_track_count():
			blink.set_filter_path(an.track_get_path(t), true)
	bt.add_node("idle", a_idle, Vector2(0, 0))
	bt.add_node("walk", a_walk, Vector2(0, 150))
	bt.add_node("move", mv, Vector2(200, 50))
	bt.add_node("act", a_act, Vector2(200, 200))
	bt.add_node("shot", shot, Vector2(400, 80))
	bt.add_node("bl", a_bl, Vector2(400, 250))
	bt.add_node("blink", blink, Vector2(600, 100))
	bt.connect_node("move", 0, "idle")
	bt.connect_node("move", 1, "walk")
	bt.connect_node("shot", 0, "move")
	bt.connect_node("shot", 1, "act")
	bt.connect_node("blink", 0, "shot")
	bt.connect_node("blink", 1, "bl")
	bt.connect_node("output", 0, "blink")
	var tree := AnimationTree.new()
	tree.tree_root = bt
	ap.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(ap)
	tree.active = true
	return tree


func _pal_act(pal: Dictionary, anim := "attack") -> void:
	var ap: AnimationPlayer = pal.ap
	if not ap.has_animation(anim):
		return
	var bt: AnimationNodeBlendTree = pal.tree.tree_root
	(bt.get_node("act") as AnimationNodeAnimation).animation = anim
	pal.tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _update_pals(dt: float) -> void:
	var hp := hero.position
	for pal in pals:
		var n: Node3D = pal.node
		var pos := n.position
		var to_hero := Vector3(hp.x - pos.x, 0, hp.z - pos.z)
		var dh := to_hero.length()
		var want_speed := 0.0
		var want_face: float = pal.face
		pal.wait -= dt
		var to_t := Vector3(pal.target.x - pos.x, 0, pal.target.z - pos.z)
		if dh < 3.5:
			# герой поруч — зупиняється й дивиться на нього
			want_face = atan2(to_hero.x, to_hero.z)
		elif to_t.length() > 0.4 and pal.wait <= 0.0:
			want_speed = 1.3
			want_face = atan2(to_t.x, to_t.z)
		elif pal.wait <= 0.0:
			var a := randf() * TAU
			var r := randf_range(2.0, 9.0)
			var t: Vector3 = pal.home + Vector3(cos(a) * r, 0, sin(a) * r)
			if Vector2(t.x, t.z).length() > ISLAND_R - 14.0:
				t = pal.home
			pal.target = t
			pal.wait = randf_range(1.0, 5.0)
		# плавний поворот: спершу розвертається, потім іде
		var df := wrapf(want_face - pal.face, -PI, PI)
		pal.face += df * minf(1.0, dt * 5.0)
		if absf(df) > 0.9:
			want_speed = 0.0
		pal.speed = lerpf(pal.speed, want_speed, minf(1.0, dt * 4.0))
		if pal.speed > 0.02:
			pos.x += sin(pal.face) * pal.speed * dt
			pos.z += cos(pal.face) * pal.speed * dt
		# не заходимо в героя й одне в одного
		if dh < 1.3 and dh > 0.01:
			pos -= to_hero / dh * (1.3 - dh)
		for o in pals:
			if o == pal:
				continue
			var d: Vector3 = pos - o.node.position
			d.y = 0
			var l := d.length()
			if l < 1.4 and l > 0.01:
				pos += d / l * (1.4 - l) * 0.5
		pos.y = h(pos.x, pos.z)
		n.position = pos
		n.rotation.y = pal.face
		pal.tree.set("parameters/move/blend_amount", clampf(pal.speed / 1.3, 0.0, 1.0))
		pal.blink -= dt
		if pal.blink <= 0.0:
			pal.blink = randf_range(2.0, 5.0)
			pal.tree.set("parameters/blink/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


# ---------------- камера й керування ----------------
func _camera() -> void:
	cam = Camera3D.new()
	cam.fov = 60
	cam.far = 220
	add_child(cam)


func _move_input() -> Vector2:
	var v := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_down", "ui_up"))
	if Input.is_key_pressed(KEY_A): v.x -= 1
	if Input.is_key_pressed(KEY_D): v.x += 1
	if Input.is_key_pressed(KEY_W): v.y += 1
	if Input.is_key_pressed(KEY_S): v.y -= 1
	if joy_vec.length() > 0.08:
		v = Vector2(joy_vec.x, -joy_vec.y)
	return v.limit_length(1.0)


func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	var mv := _move_input()
	var fwd := Vector3(-sin(cam_yaw), 0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
	var dir := right * mv.x + fwd * mv.y
	var spd := dir.length()
	hero_act -= dt
	if spd > 0.05:
		var run := spd > 0.75 or Input.is_key_pressed(KEY_SHIFT)
		var v := 5.2 if run else 2.4
		var np := hero.position + dir.normalized() * v * spd * dt
		if Vector2(np.x, np.z).length() < ISLAND_R - 9.0:
			hero.position = np
		var want := atan2(dir.x, dir.z)
		hero_face += wrapf(want - hero_face, -PI, PI) * minf(1.0, dt * 12.0)
		if hero_act <= 0.0:
			_hero_play("run" if run else "walk")
	elif hero_act <= 0.0:
		_hero_play("idle")
	# не заходимо в попалів
	for pal in pals:
		var d: Vector3 = hero.position - pal.node.position
		d.y = 0
		var l := d.length()
		if l < 1.1 and l > 0.01:
			hero.position += d / l * (1.1 - l)
	hero.position.y = h(hero.position.x, hero.position.z)
	hero.rotation.y = hero_face
	_update_pals(dt)
	# камера за героєм
	var tgt := hero.position + Vector3(0, 1.3, 0)
	var off := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch)) * cam_dist
	var cp := tgt + off
	cp.y = maxf(cp.y, h(cp.x, cp.z) + 0.6)
	cam.position = cam.position.lerp(cp, minf(1.0, dt * 10.0)) if cam.position != Vector3.ZERO else cp
	cam.look_at(tgt, Vector3.UP)
	sun.position = hero.position
	# інтерфейс
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if toast_t > 0.0:
		toast_t -= dt
		toast.modulate.a = clampf(toast_t, 0.0, 1.0)


func _action() -> void:
	var best = null
	var bd := 2.8
	for pal in pals:
		var d: float = (pal.node.position - hero.position).length()
		if d < bd:
			bd = d
			best = pal
	hero_act = 0.6
	hero_state = ""
	_hero_play("hit")
	if best:
		var to: Vector3 = best.node.position - hero.position
		hero_face = atan2(to.x, to.z)
		best.face = atan2(-to.x, -to.z)
		_pal_act(best, "attack" if randf() < 0.6 else "happy")
		_show(NAMES[best.key])
	else:
		_show("Поруч нікого — підійдіть до попала")


func _show(t: String) -> void:
	toast.text = t
	toast_t = 2.0


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_SPACE or e.keycode == KEY_E:
			_action()
		elif e.keycode == KEY_Q:
			_toggle_quality()
	# камера: перетягування мишкою або пальцем (не по джойстику)
	if e is InputEventMouseMotion and (e.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)):
		_orbit(e.relative)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: cam_dist = maxf(3.5, cam_dist - 0.5)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: cam_dist = minf(14.0, cam_dist + 0.5)
	elif e is InputEventScreenTouch:
		if e.pressed and drag_id == -99 and e.index != joy_id:
			drag_id = e.index
		elif not e.pressed and e.index == drag_id:
			drag_id = -99
	elif e is InputEventScreenDrag and e.index == drag_id:
		_orbit(e.relative)


func _orbit(rel: Vector2) -> void:
	cam_yaw -= rel.x * 0.006
	cam_pitch = clampf(cam_pitch + rel.y * 0.004, 0.08, 1.2)


# ---------------- якість ----------------
func _toggle_quality() -> void:
	high = not high
	_apply_quality()


func _apply_quality() -> void:
	sun.shadow_enabled = high
	get_viewport().scaling_3d_scale = 1.0 if high else 0.7
	grass.multimesh.visible_instance_count = -1 if high else int(grass.multimesh.instance_count * 0.4)
	if q_button:
		q_button.text = "Якість: " + ("висока" if high else "низька")


# ---------------- інтерфейс ----------------
class Joystick extends Control:
	var main
	var center := Vector2.ZERO
	var knob := Vector2.ZERO
	const R := 62.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var c := size / 2
		draw_circle(c, R, Color(0.05, 0.12, 0.16, 0.45))
		draw_arc(c, R, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
		draw_circle(c + knob, 30, Color(0.93, 0.83, 0.62, 0.95))

	func set_knob(p: Vector2) -> void:
		var d := p - size / 2
		knob = d.limit_length(R)
		main.joy_vec = knob / R
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventScreenTouch:
			if e.pressed:
				main.joy_id = e.index; set_knob(e.position)
			elif e.index == main.joy_id:
				main.joy_id = -99; knob = Vector2.ZERO; main.joy_vec = Vector2.ZERO; queue_redraw()
			accept_event()
		elif e is InputEventScreenDrag and e.index == main.joy_id:
			set_knob(e.position); accept_event()
		elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed: set_knob(e.position)
			else: knob = Vector2.ZERO; main.joy_vec = Vector2.ZERO; queue_redraw()
			accept_event()
		elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
			set_knob(e.position); accept_event()


func _round_btn(text: String, col: Color, sz: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(sz, sz)
	b.add_theme_font_size_override("font_size", 20)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.darkened(0.25 if st == "pressed" else 0.0)
		sb.set_corner_radius_all(int(sz / 2))
		sb.border_color = Color(1, 1, 1, 0.5)
		sb.set_border_width_all(3)
		b.add_theme_stylebox_override(st, sb)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	joy = Joystick.new()
	joy.main = self
	joy.size = Vector2(200, 200)
	joy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joy.position = Vector2(30, -230)
	joy.anchor_top = 1.0; joy.anchor_bottom = 1.0
	joy.offset_top = -190; joy.offset_bottom = -20; joy.offset_left = 20; joy.offset_right = 190
	root.add_child(joy)
	var act := _round_btn("Дія", Color(0.78, 0.6, 0.32, 0.92), 104)
	act.anchor_left = 1.0; act.anchor_right = 1.0; act.anchor_top = 1.0; act.anchor_bottom = 1.0
	act.offset_left = -134; act.offset_right = -30; act.offset_top = -134; act.offset_bottom = -30
	act.pressed.connect(_action)
	root.add_child(act)
	q_button = Button.new()
	q_button.focus_mode = Control.FOCUS_NONE
	q_button.add_theme_font_size_override("font_size", 15)
	q_button.anchor_left = 1.0; q_button.anchor_right = 1.0
	q_button.offset_left = -190; q_button.offset_right = -14; q_button.offset_top = 12; q_button.offset_bottom = 46
	q_button.pressed.connect(_toggle_quality)
	root.add_child(q_button)
	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 20)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 6)
	fps_label.position = Vector2(14, 10)
	root.add_child(fps_label)
	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_outline_color", Color.BLACK)
	info_label.add_theme_constant_override("outline_size", 5)
	info_label.position = Vector2(14, 36)
	info_label.text = "Godot 4.4 · проба · %d попалів" % N_PALS + ("\nДжойстик — рух, тягни екран — камера" if mobile else "\nWASD — рух, Shift — біг, мишка — камера, Пробіл — дія, Q — якість")
	root.add_child(info_label)
	toast = Label.new()
	toast.add_theme_font_size_override("font_size", 20)
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	toast.add_theme_constant_override("outline_size", 8)
	toast.anchor_left = 0.5; toast.anchor_right = 0.5
	toast.offset_left = -260; toast.offset_right = 260; toast.offset_top = 56
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.modulate.a = 0.0
	root.add_child(toast)
