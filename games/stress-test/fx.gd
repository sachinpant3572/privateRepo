extends Node
## Visual quality tiers: animated background, glow (bloom) and Ultra screen
## effects.
##
## Glow redraws the bright layers into a small offscreen viewport, blurs it
## horizontally into a second viewport, then blurs it vertically while adding
## it over the scene. It uses only canvas shaders, so it works on the
## Compatibility renderer that budget phones need.

const TIERS := {
	"Low": {"glow": 0.0, "glow_strength": 0.0, "trails": false, "sparks": 4, "rings": 0, "background": 0.0, "post": false, "fps_cap": 30},
	"Medium": {"glow": 0.35, "glow_strength": 0.9, "trails": false, "sparks": 6, "rings": 0, "background": 0.5, "post": false, "fps_cap": 60},
	"High": {"glow": 0.5, "glow_strength": 1.1, "trails": true, "sparks": 10, "rings": 150, "background": 1.0, "post": false, "fps_cap": 60},
	"Ultra": {"glow": 1.0, "glow_strength": 1.3, "trails": true, "sparks": 16, "rings": 400, "background": 1.0, "post": true, "fps_cap": 0},
}
const ORDER := ["Low", "Medium", "High", "Ultra"]
const ABERRATION := 0.004
const ABERRATION_SHAKE := 0.05

var tier: Dictionary = TIERS["Ultra"]
var glow_scale := 0.0

var bg_layer: CanvasLayer
var bg_mat: ShaderMaterial
var glow_vp: SubViewport
var glow_world: Node2D
var player_glow: Sprite2D
var blur_vp: SubViewport
var blur_rect: TextureRect
var glow_layer: CanvasLayer
var glow_mat: ShaderMaterial
var post_layer: CanvasLayer
var post_mat: ShaderMaterial


## layers: one entry per MultiMesh to glow, as
## [MultiMesh, Texture2D, additive: bool, glow modulate: Color].
func setup(layers: Array, player_texture: Texture2D) -> void:
	bg_layer = CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	bg_mat = ShaderMaterial.new()
	bg_mat.shader = preload("res://background.gdshader")
	bg_layer.add_child(_full_rect(ColorRect.new(), bg_mat))

	glow_vp = _offscreen_viewport()
	glow_world = Node2D.new()
	glow_vp.add_child(glow_world)
	for layer in layers:
		var inst := MultiMeshInstance2D.new()
		inst.multimesh = layer[0]
		inst.texture = layer[1]
		inst.modulate = layer[3]
		if layer[2]:
			var add := CanvasItemMaterial.new()
			add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			inst.material = add
		glow_world.add_child(inst)
	player_glow = Sprite2D.new()
	player_glow.texture = player_texture
	player_glow.visible = false
	glow_world.add_child(player_glow)

	blur_vp = _offscreen_viewport()
	blur_rect = TextureRect.new()
	blur_rect.texture = glow_vp.get_texture()
	blur_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blur_rect.stretch_mode = TextureRect.STRETCH_SCALE
	blur_rect.material = _blur_material(Vector2(1, 0))
	blur_vp.add_child(blur_rect)

	glow_layer = CanvasLayer.new()
	glow_layer.layer = 1
	add_child(glow_layer)
	glow_mat = _blur_material(Vector2(0, 1))
	var glow_rect := TextureRect.new()
	glow_rect.texture = blur_vp.get_texture()
	glow_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow_rect.stretch_mode = TextureRect.STRETCH_SCALE
	glow_layer.add_child(_full_rect(glow_rect, glow_mat))

	post_layer = CanvasLayer.new()
	post_layer.layer = 5
	add_child(post_layer)
	post_mat = ShaderMaterial.new()
	post_mat.shader = preload("res://post.gdshader")
	post_layer.add_child(_full_rect(ColorRect.new(), post_mat))


func apply(tier_name: String, size: Vector2) -> void:
	tier = TIERS[tier_name]
	glow_scale = tier["glow"]
	var glow_on := glow_scale > 0.0
	var mode := SubViewport.UPDATE_ALWAYS if glow_on else SubViewport.UPDATE_DISABLED
	glow_vp.render_target_update_mode = mode
	blur_vp.render_target_update_mode = mode
	glow_layer.visible = glow_on
	glow_mat.set_shader_parameter("strength", tier["glow_strength"])
	bg_layer.visible = tier["background"] > 0.0
	bg_mat.set_shader_parameter("detail", tier["background"])
	post_layer.visible = tier["post"]
	resize(size)


func resize(size: Vector2) -> void:
	if glow_scale <= 0.0:
		return
	var px := Vector2i(maxi(1, int(size.x * glow_scale)), maxi(1, int(size.y * glow_scale)))
	glow_vp.size = px
	blur_vp.size = px
	blur_rect.size = Vector2(px)
	glow_world.scale = Vector2(glow_scale, glow_scale)


## Called every frame with the world's shake offset and the player position.
func update(shake_offset: Vector2, player_pos: Vector2, player_visible: bool, trauma: float) -> void:
	if glow_scale > 0.0:
		glow_world.position = shake_offset * glow_scale
		player_glow.position = player_pos
		player_glow.visible = player_visible
	if tier["post"]:
		post_mat.set_shader_parameter("aberration", ABERRATION + trauma * ABERRATION_SHAKE)
	if tier["background"] > 0.0:
		bg_mat.set_shader_parameter("pulse", trauma)


func _offscreen_viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.size = Vector2i(4, 4)
	add_child(vp)
	return vp


func _blur_material(direction: Vector2) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://blur.gdshader")
	mat.set_shader_parameter("direction", direction)
	return mat


func _full_rect(control: Control, mat: Material) -> Control:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.material = mat
	return control
