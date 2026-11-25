extends Node3D
## Regnum Land — «цукерка» на Godot 4.4: та сама галявина, але з повною графікою рушія.
## ПК (Windows) — рендер Forward+, Android — рендер Mobile. Сама гра (site/) не змінюється.
## Тест у контейнері: --shot=/шлях.png [--t=8] [--walk] [--act] — знімок екрана й вихід.

const PALS := ["bambuzl", "grumrok", "hrozovyk", "ignis", "khvylezub", "koralovyk", "krylosha",
	"mirazhbr", "mororyh", "popeliukh", "sontseklyv", "zemleryi", "pukhoklub"]
const NAMES := {"bambuzl": "Бамбузл", "grumrok": "Грумрок", "hrozovyk": "Грозовик", "ignis": "Ігніс-Виверг",
	"khvylezub": "Хвилезуб", "koralovyk": "Кораловик", "krylosha": "Крилоша", "mirazhbr": "Міражбр",
	"mororyh": "Мороріг", "popeliukh": "Попелюх", "sontseklyv": "Сонцеклюв", "zemleryi": "Землерий", "pukhoklub": "Пухоклуб"}
const ISLAND_R := 62.0
const HSIZE := 160.0
const HRES := 256
const N_PALS := 20

var noise := FastNoiseLite.new()
var hmap_tex: ImageTexture
var hero: Node3D
var hero_anim: AnimationPlayer
var hero_state := ""
var hero_act := 0.0
var hero_face := 0.0
var cam: Camera3D
var cam_yaw := 0.55
var cam_pitch := 0.34
var cam_dist := 7.0
var sun: DirectionalLight3D
var env: Environment
var pals: Array = []
var grass_mat: ShaderMaterial
var grass: MultiMeshInstance3D
var particles: Array = []
var fx_live: Array = []
var mobile := false
var high := true

var joy_vec := Vector2.ZERO
var joy_id := -99
var drag_id := -99
var fps_label: Label
var q_button: Button
var toast: Label
var toast_t := 0.0
var shot_path := ""
var shot_t := 8.0
var auto_walk := false
var auto_act := false
var start_pos := Vector3(0, 0, 4)


func h(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	var base := noise.get_noise_2d(x, z) * 2.4 + noise.get_noise_2d(x * 3.1, z * 3.1) * 0.35
	var edge := clampf((r - (ISLAND_R - 12.0)) / 14.0, 0.0, 1.0)
	return lerpf(base + 1.2, -3.2, edge * edge * (3.0 - 2.0 * edge))


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): shot_path = a.substr(7)
		elif a.begins_with("--t="): shot_t = float(a.substr(4))
		elif a == "--walk": auto_walk = true
		elif a == "--act": auto_act = true
		elif a.begins_with("--yaw="): cam_yaw = float(a.substr(6))
		elif a.begins_with("--pitch="): cam_pitch = float(a.substr(8))
		elif a.begins_with("--dist="): cam_dist = float(a.substr(7))
		elif a.begins_with("--pos="):
			var q := a.substr(6).split(",")
			start_pos = Vector3(float(q[0]), 0, float(q[1]))
	noise.seed = 7
	noise.frequency = 0.016
	mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	high = not mobile
	_heightmap()
	_env()
	_terrain()
	_water()
	_grass()
	_trees()
	_scatter()
	_hero()
	_spawn_pals()
	_camera()
	_particles()
	_ui()
	_apply_quality()


func _noise_tex(freq: float, seed_: int, normal := false, size := 256) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = size; t.height = size
	t.seamless = true
	t.as_normal_map = normal
	t.bump_strength = 6.0
	t.generate_mipmaps = true
	return t


func _heightmap() -> void:
	var img := Image.create(HRES, HRES, false, Image.FORMAT_RF)
	for j in HRES:
		for i in HRES:
			var x := (float(i) / (HRES - 1) - 0.5) * HSIZE
			var z := (float(j) / (HRES - 1) - 0.5) * HSIZE
			img.set_pixel(i, j, Color(h(x, z), 0, 0))
	hmap_tex = ImageTexture.create_from_image(img)


# ---------------- небо, світло, атмосфера ----------------
func _env() -> void:
	env = Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky.gdshader")
	sm.set_shader_parameter("clouds", _noise_tex(0.012, 3))
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.8, 0.93)
	env.fog_density = 0.004
	env.fog_aerial_perspective = 0.5
	env.fog_sky_affect = 0.15
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -40, 0)
	sun.light_energy = 1.6
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 55.0
	add_child(sun)


func _terrain() -> void:
	var size := HSIZE
	var n := 160
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n + 1:
		for i in n + 1:
			var x := -size / 2 + size * i / n
			var z := -size / 2 + size * j / n
			st.set_uv(Vector2(x, z) * 0.1)
			st.add_vertex(Vector3(x, h(x, z), z))
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			st.add_index(a); st.add_index(a + 1); st.add_index(a + n + 1)
			st.add_index(a + 1); st.add_index(a + n + 2); st.add_index(a + n + 1)
	st.generate_normals()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("detail", _noise_tex(0.02, 5))
	mat.set_shader_parameter("detail_n", _noise_tex(0.06, 9, true))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


func _water() -> void:
	var w := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(700, 700)
	pm.subdivide_width = 120
	pm.subdivide_depth = 120
	w.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	m.set_shader_parameter("hmap", hmap_tex)
	m.set_shader_parameter("hsize", HSIZE)
	m.set_shader_parameter("n1", _noise_tex(0.03, 21, true))
	m.set_shader_parameter("n2", _noise_tex(0.05, 22, true))
	m.set_shader_parameter("foam_noise", _noise_tex(0.05, 23))
	w.material_override = m
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(w)


func _blade() -> ArrayMesh:
	var v := PackedVector3Array(); var uv := PackedVector2Array(); var nm := PackedVector3Array(); var idx := PackedInt32Array()
	var seg := 4
	for s in seg + 1:
		var t := float(s) / seg
		var w := 0.055 * pow(1.0 - t, 0.9) + 0.004
		var z := 0.12 * t * t
		v.append(Vector3(-w, t, z)); uv.append(Vector2(0, t)); nm.append(Vector3(0, 0, -1))
		v.append(Vector3(w, t, z)); uv.append(Vector2(1, t)); nm.append(Vector3(0, 0, -1))
	for s in seg:
		var a := s * 2
		idx.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v; arr[Mesh.ARRAY_TEX_UV] = uv; arr[Mesh.ARRAY_NORMAL] = nm; arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


func _grass() -> void:
	var count := 24000 if mobile else 90000
	var g := 34.0 if mobile else 52.0
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _blade()
	mm.instance_count = count
	for i in count:
		var x := rng.randf_range(-g / 2, g / 2)
		var z := rng.randf_range(-g / 2, g / 2)
		var s := rng.randf_range(0.2, 0.48)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rng.randf_range(0.8, 1.4), s, 1.0))
		mm.set_instance_transform(i, Transform3D(b, Vector3(x, 0, z)))
	grass = MultiMeshInstance3D.new()
	grass.multimesh = mm
	grass_mat = ShaderMaterial.new()
	grass_mat.shader = load("res://shaders/grass.gdshader")
	grass_mat.set_shader_parameter("hmap", hmap_tex)
	grass_mat.set_shader_parameter("hsize", HSIZE)
	grass_mat.set_shader_parameter("gsize", g)
	grass_mat.set_shader_parameter("wind_noise", _noise_tex(0.05, 31))
	grass.material_override = grass_mat
	grass.custom_aabb = AABB(Vector3(-300, -20, -300), Vector3(600, 60, 600))
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)


func _rand_land(rng: RandomNumberGenerator, rmax := ISLAND_R - 14.0, min_h := 0.7) -> Vector3:
	for k in 30:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * rmax
		var x := cos(a) * r
		var z := sin(a) * r
		var y := h(x, z)
		if y > min_h:
			return Vector3(x, y, z)
	return Vector3(0, h(0, 0), 0)


func _mm(mesh: Mesh, xf: Array, mat: Material = null, shadow := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	if mat: mi.material_override = mat
	if not shadow: mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Крона: кілька «горбистих» куль, зсунутих шумом; колір вершин R — освітленість (верх світлий), G — теплі плями.
func _crown(seed_: int, lobes: int, spread: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	var nz := FastNoiseLite.new(); nz.seed = seed_; nz.frequency = 1.4
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sph := SphereMesh.new(); sph.radial_segments = 14; sph.rings = 9
	var base: Array = sph.get_mesh_arrays()
	var bv: PackedVector3Array = base[Mesh.ARRAY_VERTEX]
	var bi: PackedInt32Array = base[Mesh.ARRAY_INDEX]
	var top := 0.0
	var parts := []
	for l in lobes:
		var c := Vector3(rng.randf_range(-spread, spread), rng.randf_range(0.0, spread * 1.2), rng.randf_range(-spread, spread))
		if l == 0: c = Vector3(0, spread * 0.6, 0)
		var r := rng.randf_range(0.75, 1.15)
		parts.append([c, r])
		top = maxf(top, c.y + r)
	for p in parts:
		var c: Vector3 = p[0]; var r: float = p[1]
		for k in bi.size():
			var v: Vector3 = bv[bi[k]]
			var dn := v.normalized()
			var d := 1.0 + nz.get_noise_3dv(dn * 1.5 + c) * 0.28
			var pos := c + dn * r * d
			var lit := clampf(0.35 + 0.65 * ((pos.y + 0.5) / (top + 0.5)) * (0.6 + 0.4 * dn.y), 0.0, 1.0)
			var warm := clampf(nz.get_noise_3dv(pos * 0.7) * 1.5 + 0.2, 0.0, 1.0)
			st.set_color(Color(lit, warm, 0))
			st.set_normal(dn)
			st.add_vertex(pos)
	return st.commit()


func _pine(seed_: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.02; cone.bottom_radius = 1.5 - k * 0.3; cone.height = 1.7; cone.radial_segments = 10; cone.rings = 1
		var arr: Array = cone.get_mesh_arrays()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]; var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]; var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in ix:
			var p: Vector3 = v[i] + Vector3(0, 0.85 + k * 0.95, 0)
			st.set_color(Color(clampf(0.3 + (p.y / 4.5) * 0.6 + nn[i].y * 0.2, 0.0, 1.0), 0.0, 0))
			st.set_normal(nn[i])
			st.add_vertex(p)
	return st.commit()


func _trees() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	var fol := ShaderMaterial.new(); fol.shader = load("res://shaders/foliage.gdshader")
	var pine_m := ShaderMaterial.new(); pine_m.shader = load("res://shaders/foliage.gdshader")
	pine_m.set_shader_parameter("dark", Color(0.03, 0.12, 0.07)); pine_m.set_shader_parameter("light", Color(0.16, 0.38, 0.18)); pine_m.set_shader_parameter("warm", Color(0.2, 0.4, 0.2))
	var crowns := [_crown(1, 5, 0.9), _crown(2, 6, 1.1), _crown(3, 4, 0.8)]
	var pine := _pine(4)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.13; trunk.bottom_radius = 0.24; trunk.height = 3.0; trunk.radial_segments = 8
	var tm := StandardMaterial3D.new(); tm.albedo_color = Color(0.36, 0.25, 0.16); tm.roughness = 1.0
	trunk.material = tm
	var xs := [[], [], []]; var px := []; var tx := []
	for i in 70:
		var p := _rand_land(rng, ISLAND_R - 13.0, 0.9)
		if p.distance_to(Vector3(0, p.y, 4)) < 14.0:
			continue
		var s := rng.randf_range(0.85, 1.4)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s)
		tx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), p + Vector3(0, 1.4 * s, 0)))
		if rng.randf() < 0.3:
			px.append(Transform3D(b, p + Vector3(0, 1.2 * s, 0)))
		else:
			xs[rng.randi() % 3].append(Transform3D(b, p + Vector3(0, 2.4 * s, 0)))
	_mm(trunk, tx)
	for k in 3:
		_mm(crowns[k], xs[k], fol)
	_mm(pine, px, pine_m)


func _glb_meshes(path: String) -> Array:
	var out := []
	var sc: Node = load(path).instantiate()
	for m in sc.find_children("*", "MeshInstance3D", true, false):
		out.append(m.mesh)
	sc.free()
	return out


func _scatter() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 43
	var fl := _glb_meshes("res://assets/env/meadow-flowers.glb")
	if fl.size():
		var fx := []
		for i in 900:
			var c := _rand_land(rng)
			for k in 3:
				var p := c + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
				p.y = h(p.x, p.z)
				fx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), p))
		_mm(fl[0], fx, null, false)
	var bu := _glb_meshes("res://assets/env/berry-bush.glb")
	if bu.size():
		var bx := []
		for i in 30:
			bx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.5)), _rand_land(rng)))
		_mm(bu[0], bx)
	var rk := _glb_meshes("res://assets/env/terrain-rocks.glb")
	var rm := StandardMaterial3D.new()
	rm.albedo_texture = _noise_tex(0.08, 51)
	rm.albedo_color = Color(0.62, 0.6, 0.56)
	rm.normal_enabled = true
	rm.normal_texture = _noise_tex(0.12, 52, true)
	rm.normal_scale = 1.4
	rm.roughness = 0.9
	rm.uv1_triplanar = true
	rm.uv1_scale = Vector3(0.6, 0.6, 0.6)
	for k in rk.size():
		var rx := []
		for i in 10:
			var p := _rand_land(rng, ISLAND_R - 6.0, -1.0)
			rx.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1, 0.75, 1) * rng.randf_range(0.8, 2.2)), p + Vector3(0, -0.15, 0)))
		_mm(rk[k], rx, rm)


# ---------------- герой ----------------
func _hero() -> void:
	hero = load("res://assets/env/hero-mobile.glb").instantiate()
	add_child(hero)
	hero.position = Vector3(start_pos.x, h(start_pos.x, start_pos.z), start_pos.z)
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
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	for i in N_PALS:
		var key: String = PALS[i % PALS.size()]
		var root: Node3D = load("res://assets/pals/%s.glb" % key).instantiate()
		add_child(root)
		var p := _rand_land(rng, 26.0)
		if p.distance_to(Vector3(0, p.y, 4)) < 4.0:
			p += Vector3(6, 0, 6)
		if i < 3:
			p = Vector3(-3.0 + i * 3.0, 0, -1.5 - i)
		p.y = h(p.x, p.z)
		root.position = p
		root.rotation.y = rng.randf() * TAU
		var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
		var pal := {"key": key, "node": root, "ap": ap, "home": p, "target": p, "wait": rng.randf_range(0.5, 4.0),
			"face": root.rotation.y, "speed": 0.0, "blink": rng.randf_range(1.0, 4.0), "tree": null, "busy": 0.0}
		pal.tree = _pal_tree(ap)
		pals.append(pal)


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
	var shot := AnimationNodeOneShot.new(); shot.fadein_time = 0.1; shot.fadeout_time = 0.25
	var blink := AnimationNodeOneShot.new(); blink.fadein_time = 0.02; blink.fadeout_time = 0.05
	if ap.has_animation("blink"):
		var an := ap.get_animation("blink")
		blink.filter_enabled = true
		for t in an.get_track_count():
			blink.set_filter_path(an.track_get_path(t), true)
	bt.add_node("idle", a_idle); bt.add_node("walk", a_walk); bt.add_node("move", mv)
	bt.add_node("act", a_act); bt.add_node("shot", shot); bt.add_node("bl", a_bl); bt.add_node("blink", blink)
	bt.connect_node("move", 0, "idle"); bt.connect_node("move", 1, "walk")
	bt.connect_node("shot", 0, "move"); bt.connect_node("shot", 1, "act")
	bt.connect_node("blink", 0, "shot"); bt.connect_node("blink", 1, "bl")
	bt.connect_node("output", 0, "blink")
	var tree := AnimationTree.new()
	tree.tree_root = bt
	ap.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(ap)
	tree.active = true
	return tree


## Атака попала: тіло грає кліп атаки, а поруч з'являється модель ефекту (блискавки, вогонь, лід…) з тим самим кліпом.
func _pal_attack(pal: Dictionary) -> void:
	var fx_root: Node3D = load("res://assets/pals/%s_fx.glb" % pal.key).instantiate()
	var fap: AnimationPlayer = fx_root.find_children("*", "AnimationPlayer", true, false)[0]
	var names := []
	for n in fap.get_animation_list():
		if pal.ap.has_animation(n):
			names.append(n)
	if names.is_empty():
		fx_root.free()
		return
	var clip: String = names[randi() % names.size()]
	var bt: AnimationNodeBlendTree = pal.tree.tree_root
	(bt.get_node("act") as AnimationNodeAnimation).animation = clip
	pal.tree.set("parameters/shot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	add_child(fx_root)
	fx_root.global_transform = pal.node.global_transform
	fap.play(clip)
	var len := fap.get_animation(clip).length
	pal.busy = len
	fx_live.append([fx_root, len + 0.1])
	var light := OmniLight3D.new()
	light.light_energy = 2.5; light.omni_range = 6.0
	light.light_color = Color(1.0, 0.8, 0.5)
	light.position = Vector3(0, 1.2, 1.2)
	fx_root.add_child(light)


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
		pal.busy -= dt
		var to_t := Vector3(pal.target.x - pos.x, 0, pal.target.z - pos.z)
		if pal.busy > 0.0:
			pass
		elif dh < 3.5:
			want_face = atan2(to_hero.x, to_hero.z)
		elif to_t.length() > 0.4 and pal.wait <= 0.0:
			want_speed = 1.3
			want_face = atan2(to_t.x, to_t.z)
		elif pal.wait <= 0.0:
			var a := randf() * TAU
			var r := randf_range(2.0, 9.0)
			var t: Vector3 = pal.home + Vector3(cos(a) * r, 0, sin(a) * r)
			if h(t.x, t.z) < 0.8:
				t = pal.home
			pal.target = t
			pal.wait = randf_range(1.0, 5.0)
		var df := wrapf(want_face - pal.face, -PI, PI)
		pal.face += df * minf(1.0, dt * 5.0)
		if absf(df) > 0.9:
			want_speed = 0.0
		pal.speed = lerpf(pal.speed, want_speed, minf(1.0, dt * 4.0))
		if pal.speed > 0.02:
			pos.x += sin(pal.face) * pal.speed * dt
			pos.z += cos(pal.face) * pal.speed * dt
		if dh < 1.3 and dh > 0.01:
			pos -= to_hero / dh * (1.3 - dh)
		for o in pals:
			if o == pal: continue
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


# ---------------- частинки: пилок і метелики ----------------
func _particles() -> void:
	# пилок
	var pp := GPUParticles3D.new()
	pp.amount = 160 if mobile else 400
	pp.lifetime = 9.0
	pp.preprocess = 9.0
	pp.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 20, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 2.5, 18)
	pm.gravity = Vector3(0, 0.02, 0)
	pm.initial_velocity_min = 0.05; pm.initial_velocity_max = 0.25
	pm.direction = Vector3(1, 0.3, 0.4); pm.spread = 180
	pm.turbulence_enabled = true; pm.turbulence_noise_strength = 0.6; pm.turbulence_noise_scale = 3.0
	pm.scale_min = 0.5; pm.scale_max = 1.3
	var ramp := Gradient.new(); ramp.set_color(0, Color(1, 1, 1, 0)); ramp.set_color(1, Color(1, 1, 1, 0)); ramp.add_point(0.2, Color(1, 1, 1, 1)); ramp.add_point(0.8, Color(1, 1, 1, 1))
	var rt := GradientTexture1D.new(); rt.gradient = ramp
	pm.color_ramp = rt
	pp.process_material = pm
	var q := QuadMesh.new(); q.size = Vector2(0.07, 0.07)
	var qm := ShaderMaterial.new(); qm.shader = load("res://shaders/pollen.gdshader")
	q.material = qm
	pp.draw_pass_1 = q
	pp.local_coords = false
	add_child(pp)
	particles.append([pp, Vector3(0, 1.8, 0)])
	# метелики
	var bp := GPUParticles3D.new()
	bp.amount = 14 if mobile else 26
	bp.lifetime = 14.0
	bp.preprocess = 14.0
	bp.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 20, 60))
	var bm := ParticleProcessMaterial.new()
	bm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	bm.emission_box_extents = Vector3(16, 0.6, 16)
	bm.gravity = Vector3.ZERO
	bm.initial_velocity_min = 0.5; bm.initial_velocity_max = 1.0
	bm.direction = Vector3(1, 0, 0); bm.spread = 180; bm.flatness = 0.8
	bm.turbulence_enabled = true; bm.turbulence_noise_strength = 2.0; bm.turbulence_noise_scale = 4.0; bm.turbulence_influence_min = 0.2; bm.turbulence_influence_max = 0.4
	bm.particle_flag_align_y = false
	bm.hue_variation_min = -0.5; bm.hue_variation_max = 0.5
	bm.color = Color(1.0, 0.75, 0.25)
	bm.scale_min = 0.9; bm.scale_max = 1.3
	bp.process_material = bm
	var wm := ArrayMesh.new()
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.14, 0, -0.09), Vector3(0.14, 0, -0.09), Vector3(0.14, 0, 0.09), Vector3(-0.14, 0, 0.09)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	wm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var wmat := ShaderMaterial.new(); wmat.shader = load("res://shaders/butterfly.gdshader")
	wm.surface_set_material(0, wmat)
	bp.draw_pass_1 = wm
	bp.local_coords = false
	add_child(bp)
	particles.append([bp, Vector3(0, 1.2, 0)])


# ---------------- камера й керування ----------------
func _camera() -> void:
	cam = Camera3D.new()
	cam.fov = 58
	cam.far = 400
	add_child(cam)
	if not mobile and RenderingServer.get_current_rendering_method() == "forward_plus":
		var ca := CameraAttributesPractical.new()
		ca.dof_blur_far_enabled = true
		ca.dof_blur_far_distance = 45.0
		ca.dof_blur_far_transition = 25.0
		ca.dof_blur_amount = 0.06
		cam.attributes = ca


func _move_input() -> Vector2:
	var v := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_down", "ui_up"))
	if Input.is_key_pressed(KEY_A): v.x -= 1
	if Input.is_key_pressed(KEY_D): v.x += 1
	if Input.is_key_pressed(KEY_W): v.y += 1
	if Input.is_key_pressed(KEY_S): v.y -= 1
	if joy_vec.length() > 0.08:
		v = Vector2(joy_vec.x, -joy_vec.y)
	if auto_walk:
		v = Vector2(0.15, 0.55)
	return v.limit_length(1.0)


var _t := 0.0
func _process(dt: float) -> void:
	dt = minf(dt, 0.05)
	_t += dt
	if shot_path != "":
		if auto_act and absf(_t - (shot_t - 0.35)) < dt:
			_action()
		if _t >= shot_t:
			get_viewport().get_texture().get_image().save_png(shot_path)
			get_tree().quit()
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
		if h(np.x, np.z) > 0.2:
			hero.position = np
		hero_face += wrapf(atan2(dir.x, dir.z) - hero_face, -PI, PI) * minf(1.0, dt * 12.0)
		if hero_act <= 0.0:
			_hero_play("run" if run else "walk")
	elif hero_act <= 0.0:
		_hero_play("idle")
	for pal in pals:
		var d: Vector3 = hero.position - pal.node.position
		d.y = 0
		var l := d.length()
		if l < 1.1 and l > 0.01:
			hero.position += d / l * (1.1 - l)
	hero.position.y = h(hero.position.x, hero.position.z)
	hero.rotation.y = hero_face
	_update_pals(dt)
	grass_mat.set_shader_parameter("center", hero.position)
	grass_mat.set_shader_parameter("hero", hero.position)
	for p in particles:
		p[0].global_position = hero.position + p[1]
	for i in range(fx_live.size() - 1, -1, -1):
		fx_live[i][1] -= dt
		if fx_live[i][1] <= 0.0:
			fx_live[i][0].queue_free()
			fx_live.remove_at(i)
	var tgt := hero.position + Vector3(0, 1.25, 0)
	var off := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch)) * cam_dist
	var cp := tgt + off
	cp.y = maxf(cp.y, maxf(h(cp.x, cp.z), 0.2) + 0.6)
	cam.position = cp if cam.position == Vector3.ZERO else cam.position.lerp(cp, minf(1.0, dt * 10.0))
	cam.look_at(tgt, Vector3.UP)
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	if toast_t > 0.0:
		toast_t -= dt
		toast.modulate.a = clampf(toast_t, 0.0, 1.0)


func _action() -> void:
	var best = null
	var bd := 3.0
	for pal in pals:
		var d: float = (pal.node.position - hero.position).length()
		if d < bd:
			bd = d; best = pal
	hero_act = 0.6
	hero_state = ""
	_hero_play("hit")
	if best:
		var to: Vector3 = best.node.position - hero.position
		hero_face = atan2(to.x, to.z)
		best.face = atan2(-to.x, -to.z)
		best.node.rotation.y = best.face
		_pal_attack(best)
		_show(NAMES[best.key])
	else:
		_show("Поруч нікого — підійдіть до попала")


func _show(t: String) -> void:
	toast.text = t
	toast_t = 2.0


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_SPACE or e.keycode == KEY_E: _action()
		elif e.keycode == KEY_Q: _toggle_quality()
		elif e.keycode == KEY_F11: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if e is InputEventMouseMotion and (e.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)):
		_orbit(e.relative)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: cam_dist = maxf(3.5, cam_dist - 0.5)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN: cam_dist = minf(14.0, cam_dist + 0.5)
	elif e is InputEventScreenTouch:
		if e.pressed and drag_id == -99 and e.index != joy_id: drag_id = e.index
		elif not e.pressed and e.index == drag_id: drag_id = -99
	elif e is InputEventScreenDrag and e.index == drag_id:
		_orbit(e.relative)


func _orbit(rel: Vector2) -> void:
	cam_yaw -= rel.x * 0.006
	cam_pitch = clampf(cam_pitch + rel.y * 0.004, 0.06, 1.2)


# ---------------- якість ----------------
func _toggle_quality() -> void:
	high = not high
	_apply_quality()


func _apply_quality() -> void:
	var rd := ProjectSettings.get_setting("rendering/renderer/rendering_method", "") as String
	var fplus := RenderingServer.get_current_rendering_method() == "forward_plus"
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if high else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 60.0 if high else 35.0
	env.ssao_enabled = high and fplus
	env.ssao_radius = 1.2; env.ssao_intensity = 1.6
	env.ssil_enabled = high and fplus
	env.volumetric_fog_enabled = high and fplus
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.9, 0.93, 1.0)
	env.volumetric_fog_anisotropy = 0.6
	env.sdfgi_enabled = false
	grass.multimesh.visible_instance_count = -1 if high else int(grass.multimesh.instance_count * 0.55)
	get_viewport().msaa_3d = Viewport.MSAA_4X if high else Viewport.MSAA_2X
	get_viewport().scaling_3d_scale = 1.0 if (high or not mobile) else 0.85
	if q_button:
		q_button.text = "Якість: " + ("висока" if high else "звичайна")


# ---------------- інтерфейс ----------------
class Joystick extends Control:
	var main
	var knob := Vector2.ZERO
	const R := 62.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _draw() -> void:
		var c := size / 2
		draw_circle(c, R, Color(0.05, 0.12, 0.16, 0.42))
		draw_arc(c, R, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
		draw_circle(c + knob, 28, Color(0.95, 0.85, 0.62, 0.95))

	func set_knob(p: Vector2) -> void:
		knob = (p - size / 2).limit_length(R)
		main.joy_vec = knob / R
		queue_redraw()

	func release() -> void:
		knob = Vector2.ZERO; main.joy_vec = Vector2.ZERO; queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventScreenTouch:
			if e.pressed:
				main.joy_id = e.index; set_knob(e.position)
			elif e.index == main.joy_id:
				main.joy_id = -99; release()
			accept_event()
		elif e is InputEventScreenDrag and e.index == main.joy_id:
			set_knob(e.position); accept_event()
		elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed: set_knob(e.position)
			else: release()
			accept_event()
		elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT):
			set_knob(e.position); accept_event()


func _btn_style(col: Color, r: int) -> Dictionary:
	var d := {}
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.darkened(0.25 if st == "pressed" else 0.0)
		sb.set_corner_radius_all(r)
		sb.border_color = Color(1, 1, 1, 0.5)
		sb.set_border_width_all(2)
		sb.content_margin_left = 10; sb.content_margin_right = 10
		d[st] = sb
	return d


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	if mobile or DisplayServer.is_touchscreen_available():
		var joy := Joystick.new()
		joy.main = self
		joy.anchor_top = 1.0; joy.anchor_bottom = 1.0
		joy.offset_top = -190; joy.offset_bottom = -20; joy.offset_left = 30; joy.offset_right = 200
		root.add_child(joy)
	var act := Button.new()
	act.text = "Дія"
	act.focus_mode = Control.FOCUS_NONE
	act.add_theme_font_size_override("font_size", 22)
	for k in _btn_style(Color(0.8, 0.6, 0.3, 0.92), 52).keys():
		act.add_theme_stylebox_override(k, _btn_style(Color(0.8, 0.6, 0.3, 0.92), 52)[k])
	act.anchor_left = 1.0; act.anchor_right = 1.0; act.anchor_top = 1.0; act.anchor_bottom = 1.0
	act.offset_left = -140; act.offset_right = -36; act.offset_top = -134; act.offset_bottom = -30
	act.pressed.connect(_action)
	root.add_child(act)
	q_button = Button.new()
	q_button.focus_mode = Control.FOCUS_NONE
	q_button.add_theme_font_size_override("font_size", 15)
	for k in ["normal", "hover", "pressed", "focus"]:
		q_button.add_theme_stylebox_override(k, _btn_style(Color(0.05, 0.12, 0.16, 0.6), 10)[k])
	q_button.anchor_left = 1.0; q_button.anchor_right = 1.0
	q_button.offset_left = -200; q_button.offset_right = -20; q_button.offset_top = 14; q_button.offset_bottom = 48
	q_button.pressed.connect(_toggle_quality)
	root.add_child(q_button)
	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 18)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 6)
	fps_label.position = Vector2(22, 12)
	root.add_child(fps_label)
	var info := Label.new()
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_outline_color", Color.BLACK)
	info.add_theme_constant_override("outline_size", 5)
	info.position = Vector2(22, 38)
	info.text = "Regnum Land · Godot 4.4 · " + RenderingServer.get_current_rendering_method() + (
		"\nДжойстик — рух, тягни екран — камера" if mobile else "\nWASD — рух, Shift — біг, мишка — камера, Пробіл — дія, Q — якість, F11 — на весь екран")
	root.add_child(info)
	toast = Label.new()
	toast.add_theme_font_size_override("font_size", 22)
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	toast.add_theme_constant_override("outline_size", 8)
	toast.anchor_left = 0.5; toast.anchor_right = 0.5
	toast.offset_left = -260; toast.offset_right = 260; toast.offset_top = 60
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.modulate.a = 0.0
	root.add_child(toast)
