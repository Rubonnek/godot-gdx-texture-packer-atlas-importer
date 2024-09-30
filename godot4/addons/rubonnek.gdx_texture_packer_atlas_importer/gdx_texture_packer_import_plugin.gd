# The MIT License (MIT)
#
# Copyright (c) 2021-present Wilson E. Alvarez
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

extends EditorImportPlugin

# EditorImport Plugin documentation taken from:
# https://docs.godotengine.org/en/stable/tutorials/plugins/editor/import_plugins.html


# Unique name for the import plugin to let Godot know which import was used
func _get_importer_name() -> String:
	return "rubonnek.gdx_texture_packer_atlas_importer"


# Returns the name of the type it imports and it will be shown to the user in the Import dock.
func _get_visible_name() -> String:
	return "GDX Atlas"


# Returns the processing priority of the plugin. Higher priority import plugins will be preferred over the recognized extension.
func _get_priority() -> float:
	return 1.0


# Godot's import system detects file types by their extension. In the
# get_recognized_extensions() method you return an array of strings to
# represent each extension that this plugin can understand.
func _get_recognized_extensions() -> PackedStringArray:
	return ["atlas"]


# The imported files are saved in the .import folder at the project's root.
# Their extension should match the type of resource you are importing, but
# since Godot can't tell what you'll use (because there might be multiple valid
# extensions for the same resource), you need to declare what will be used in
# the import.
func _get_save_extension() -> String:
	return "tres"


# The imported resource has a specific type, so the editor can know which
# property slot it belongs to. This allows drag and drop from the FileSystem
# dock to a property in the Inspector.
func _get_resource_type() -> String:
	return "AtlasTexture"


# Since there might be many presets and they are identified with a number, it's a good practice to use an enum so you can refer to them using names.
enum m_presets { DEFAULT }


# Returns the amount of presets that this plugins defines. We only have one
# preset now, but we can make this method future-proof by returning the size of
# our m_presets enumeration.
func _get_preset_count() -> int:
	return m_presets.size()


# Gives names to the presets as they will be presented to the user, so be sure
# to use short and clear names.
func _get_preset_name(p_preset : int) -> String:
	match p_preset:
		m_presets.DEFAULT:
			return "Default"
		_:
			return "Unknown"


# This is the method which defines the available options -- get_import_options()
# returns an array of dictionaries, and each dictionary contains a few keys
# that are checked to customize the option as its shown to the user.
func _get_import_options(_p_string : String, _p_int : int) -> Array[Dictionary]:
	#match p_preset:
	#	m_presets.DEFAULT:
	#		return [{
	#			"name": "use_red_anyway",
	#			"default_value": false,
	#			"property_hint": PropertyHint.FLAG
	#			"hint_string": "Available Hint"
	#			"usage": PropertyUsage.FLAG
	#			}]
	#		_:
	#			return []
	return []



# Sets whether an import option should be shown in the import settings or not.
func _get_option_visibility(_p_option : String, _p_string_name : StringName, _p_options : Dictionary) -> bool:
	return true


# Tweak the import order just so the GDX atlas does not get imported before
# the texture it depends on.
func _get_import_order() -> int:
	# Import the atlas before the scenes
	var import_order : int = ResourceImporter.IMPORT_ORDER_SCENE - 1
	return import_order


# The import function is where the heavy lifting to import a new resource
# happens.
func _import(p_source_file: String, p_save_path: String, _p_options: Dictionary, _p_platform_variants: Array[String], r_gen_files: Array[String]) -> Error:

	# Debug:
	# print("Source file: " + p_source_file)
	# print("Save path: " + p_save_path)
	# print("Options: " + str(p_options))
	# print("Platform Variants: " + str(_p_platform_variants))
	# print("R_Gen_Files: " + str(r_gen_files))

	# Load the atlas reader:
	@warning_ignore("unsafe_cast", "unsafe_call_argument", "unsafe_method_access")
	var gdx_texture_packer_atlas_reader_gdscript : GDScript = load(get_script().get_path().get_base_dir().path_join("gdx_texture_packer_atlas_reader.gd"))
	@warning_ignore("untyped_declaration")
	var gdx_atlas_reader = gdx_texture_packer_atlas_reader_gdscript.new()

	# If there was an error parsing the GDX TexturePacker Atlas, inform the Editor
	@warning_ignore("unsafe_method_access")
	var gdx_parse_result : Dictionary = gdx_atlas_reader.parse(p_source_file)
	var error : Error = gdx_parse_result["error"]
	if error != OK:
		# NOTE: No need to print the error since it was done already. Only need to bubble up the error code to the Editor.
		return error

	# There was no error. Grab the result:
	var gdx_atlas_data_dictionary : Dictionary = gdx_parse_result["result"]

	# Grab the base directory:
	var gdx_atlas_path : String = gdx_atlas_data_dictionary["path"] # same as p_source_file in the current scope
	var atlas_texture_resources_directory : String = gdx_atlas_path.trim_suffix("." + gdx_atlas_path.get_extension()) + ".atlas_textures"
	# Make atlas_basename.atlas_textures folder to store all the AtlasTexture resources there. Clean up old directories if any.
	# Debug
	#if DirAccess.dir_exists(atlas_texture_resources_directory):
	#	__remove_directory_recursively(atlas_texture_resources_directory)
	var directory : DirAccess = DirAccess.open(gdx_atlas_path.get_base_dir())
	if not directory.dir_exists(atlas_texture_resources_directory):
		if directory.make_dir(atlas_texture_resources_directory) != OK:
			__push_error("Can't create AtlasTextures root directory: %s\n\tUnable to continue importing GDX Atlas." % [ atlas_texture_resources_directory ])
			return ERR_CANT_CREATE

	# The GDX TexturePacker Atlas format also supports describing nine
	# patch rectangles which directly translate to a NinePatchRect node in
	# Godot. We'll create these scene in a separate folder for organization's sake.
	var nine_patch_rect_scenes_directory : String = gdx_atlas_path.trim_suffix("." + gdx_atlas_path.get_extension()) + ".nine_patch_rects"
	# Debug
	#if directory.dir_exists(nine_patch_rect_scenes_directory):
	#	__remove_directory_recursively(nine_patch_rect_scenes_directory)
	var is_a_nine_patch_rect_defined : bool = false
	for packed_texture_dictionary : Dictionary in gdx_atlas_data_dictionary["packed_textures"]:
		for gdx_atlas_texture_dictionary : Dictionary in packed_texture_dictionary["atlas_textures"]:
			if "split" in gdx_atlas_texture_dictionary:
				is_a_nine_patch_rect_defined = true
	if is_a_nine_patch_rect_defined:
		if not directory.dir_exists(nine_patch_rect_scenes_directory):
			if directory.make_dir(nine_patch_rect_scenes_directory) != OK:
				__push_error("Can't create NinePatchRects root directory: %s\n\tUnable to continue importing GDX Atlas." % [ nine_patch_rect_scenes_directory ])
				return ERR_CANT_CREATE

	# For each packed texture found within the GDX Atlas
	var gdx_atlas_base_directory : String = gdx_atlas_path.get_base_dir()
	for packed_texture_dictionary : Dictionary in gdx_atlas_data_dictionary["packed_textures"]:
		# Grab the packed texture filename
		var packed_texture_filename : String = packed_texture_dictionary["filename"]

		# Generate the path of the packed texture relative to the GDX Atlas path
		var packed_texture_path : String = gdx_atlas_base_directory.path_join(packed_texture_filename)
		var gdx_packed_texture_stream_texture : CompressedTexture2D = load(packed_texture_path)
		if not is_instance_valid(gdx_packed_texture_stream_texture):
			var error_message : String = "Unable to load texture atlas at: %s\n" % [ packed_texture_path ]
			error_message += "Image was referenced by GDX TexturePacker Atlas file at: %s\n" % [ gdx_atlas_path ]
			__push_error(error_message)
			return ERR_CANT_OPEN

		# Make sure that the texture size matches what we've read from disk:
		# NOTE: The texture size is the only common metadata between
		# GDX TexturePacker Atlas formats (i.e. between the legacy
		# and new GDX TexturePacker Atlas formats).
		var gdx_packed_texture_size : Vector2i = gdx_packed_texture_stream_texture.get_size()
		if gdx_packed_texture_size != packed_texture_dictionary["settings"]["size"]:
			var error_message : String = "Incorrect texture size found in GDX TexturePacker Atlas!\n"
			error_message += "Make sure that the texture in the GDX TexturePacker Atlas at: %s\n" % [ p_source_file ]
			error_message += "match the loaded texture at: %s" % [ packed_texture_path ]
			__push_error(error_message)
			return ERR_CANT_ACQUIRE_RESOURCE

		# Convert GDX atlas texture entries within the packed texture dictionary into Godot's AtlasTexture resources:
		for gdx_atlas_texture_dictionary : Dictionary in packed_texture_dictionary["atlas_textures"]:
			# Create the AtlasTexture resource:
			var atlas_texture_resource : AtlasTexture = AtlasTexture.new()

			# Set the atlas texture in the resource:
			atlas_texture_resource.set_atlas(gdx_packed_texture_stream_texture)

			# Set the atlas texture resource region:
			var gdx_texture_position : Vector2i = gdx_atlas_texture_dictionary["xy"]
			var gdx_texture_size : Vector2i = gdx_atlas_texture_dictionary["size"]
			atlas_texture_resource.set_region(Rect2(gdx_texture_position, gdx_texture_size))

			# Set the margin:
			# NOTE: The coordinate system over the y axis within the GDX atlas
			# changes for the texture offset and the original size -- that's the
			# reason for flipping the y axis when setting the margin below, just so
			# it conforms to Godot's coordinate system:
			var gdx_texture_offset : Vector2i = gdx_atlas_texture_dictionary["offset"]
			var gdx_texture_original_size : Vector2i = gdx_atlas_texture_dictionary["orig"]
			# NOTE: the texture offset denotes left-to-right and bottom-to-top offset,
			# basically denoting the bottom_left edge of the rectangle for the sprite.
			# The bottom_right_edge is undefined, but can be calculated:
			var bottom_right_edge : Vector2i = gdx_texture_original_size - gdx_texture_size

			# Debug
			#print("Bottom Right Edge margin: " + str(bottom_right_edge))
			# NOTE: Since the GDX texture offset y coordinate is considered to
			# be flipped in Godot's coordinate system (since the the y axis in
			# GDX is measured from bottom_to_top when calculating the offset,
			# whereas Godot measures it from top_to_bottom), every pixel added over
			# the y axis on the bottom_right_edge corner in Godot must be
			# substracted from the GDX texture offset y axis. Otherwise the
			# sprite offset location will be off over the y axis.  In other words,
			# the bottom_right_edge corner in Godot's coordinate system fills the
			# image from the right and bottom. The bottom fill minus the y offset
			# as determined by GDX, is what we need to calculate the image
			# offset in Godot's coordinate system.
			var texture_margin : Rect2 = Rect2(gdx_texture_offset.x, bottom_right_edge.y - gdx_texture_offset.y, bottom_right_edge.x, bottom_right_edge.y)

			# Debug
			#print("Texture margin: " + str(texture_margin))
			atlas_texture_resource.set_margin(texture_margin)

			# Generate new resource
			var atlas_texture_resource_path_format : String = "%s/%s.%s"
			var atlas_texture_resource_name : String
			if gdx_atlas_texture_dictionary["index"] != "-1":
				atlas_texture_resource_name = "%s_%s" % [ gdx_atlas_texture_dictionary["basename"], gdx_atlas_texture_dictionary["index"] ]
			else:
				atlas_texture_resource_name = gdx_atlas_texture_dictionary["basename"]

			# The GDX TexturePacker format may include relative paths for which we may have to create directories for, thus we handle those here.
			if "/" in atlas_texture_resource_name:
				var path_to_folder_to_create : String = atlas_texture_resources_directory.path_join(atlas_texture_resource_name.get_base_dir())
				if not directory.dir_exists(path_to_folder_to_create):
					if directory.make_dir_recursive(path_to_folder_to_create) != OK:
						__push_error("Can't create directory: %s\n\tUnable to continue importing GDX Atlas." % [ path_to_folder_to_create ])
						return ERR_CANT_CREATE
			var atlas_texture_resource_save_path : String = atlas_texture_resource_path_format % [atlas_texture_resources_directory, atlas_texture_resource_name, _get_save_extension()]

			# Debug:
			#print("Saving to: ", atlas_texture_resource_save_path)

			if ResourceSaver.save(atlas_texture_resource, atlas_texture_resource_save_path) != OK:
				return ERR_PARSE_ERROR

			# Let Godot know about the generated files during the import process so it can recreate them if they are deleted
			r_gen_files.push_back(atlas_texture_resource_save_path)

			# We are done processing the AtlasTexture, but there's a chance the user defined a nine patch rectangle for it which we can translate into a Godot NinePatchRect node.
			if "split" in gdx_atlas_texture_dictionary:
				# A nine patch rectangle has been defined. Let's create the node.
				var godot_nine_patch_rect : NinePatchRect = NinePatchRect.new()

				# Set the AtlasTexture path just so the resource does not get embedded into the NinePatchRect scene
				atlas_texture_resource.set_path(atlas_texture_resource_save_path)

				# Set the AtlasTexture on the NinePatchRect
				godot_nine_patch_rect.set_texture(atlas_texture_resource)

				# Set the size of the NinePatchRect node to be equal to the texture size
				var texture_size : Vector2i = gdx_atlas_texture_dictionary["size"]
				godot_nine_patch_rect.set_size(texture_size)

				# Set the new AtlasTexture Content Margin
				var gdx_nine_patch_content_margin_rect2 : Rect2 = gdx_atlas_texture_dictionary["pad"]
				var gdx_left_content_margin_padding : int = int(gdx_nine_patch_content_margin_rect2.position.x)
				var gdx_right_content_margin_padding : int = int(gdx_nine_patch_content_margin_rect2.position.y)
				var gdx_bottom_content_margin_padding : int = int(gdx_nine_patch_content_margin_rect2.size.y)
				var gdx_top_content_margin_padding : int = int(gdx_nine_patch_content_margin_rect2.size.x)

				# Debug
				#print("Name: ", atlas_texture_resource_name)
				#print("GDX Left content margin padding: ", gdx_left_content_margin_padding)
				#print("GDX Right content margin padding: ", gdx_right_content_margin_padding)
				#print("GDX Bottom content margin padding: ", gdx_bottom_content_margin_padding)
				#print("GDX Top content margin padding: ", gdx_top_content_margin_padding)

				# The padding in GDX corresponds to the patch margin in Godot
				var godot_right_patch_margin : int = gdx_right_content_margin_padding
				var godot_left_patch_margin : int = gdx_left_content_margin_padding
				var godot_top_patch_margin : int = gdx_top_content_margin_padding
				var godot_bottom_patch_margin : int = gdx_bottom_content_margin_padding

				# Debug
				#print("Godot Left patch margin: ", godot_left_patch_margin)
				#print("Godot Right patch margin: ", godot_right_patch_margin)
				#print("Godot Bottom patch margin: ", godot_bottom_patch_margin)
				#print("Godot Top patch margin: ", godot_top_patch_margin)

				godot_nine_patch_rect.set_patch_margin(SIDE_LEFT, godot_left_patch_margin)
				godot_nine_patch_rect.set_patch_margin(SIDE_RIGHT, godot_right_patch_margin)
				godot_nine_patch_rect.set_patch_margin(SIDE_TOP, godot_top_patch_margin)
				godot_nine_patch_rect.set_patch_margin(SIDE_BOTTOM, godot_bottom_patch_margin)

				# Save the NinePatchRect node
				# NOTE: The GDX TexturePacker format may include relative paths for which we may have to create directories for, thus we handle those here for the NinePatchRect nodes as well.
				if "/" in atlas_texture_resource_name:
					var path_to_folder_to_create : String = nine_patch_rect_scenes_directory.path_join(atlas_texture_resource_name.get_base_dir())
					if not directory.dir_exists(path_to_folder_to_create):
						if directory.make_dir_recursive(path_to_folder_to_create) != OK:
							__push_error("Can't create directory: %s\n\tUnable to continue importing GDX Atlas." % [ path_to_folder_to_create ])
							return ERR_CANT_CREATE
				var godot_nine_patch_scene_save_path : String = atlas_texture_resource_path_format % [nine_patch_rect_scenes_directory, atlas_texture_resource_name, "tscn"]

				# Set the node name to be equal to its filename:
				godot_nine_patch_rect.set_name(atlas_texture_resource_name)

				# Finally save the NinePatchRect
				var godot_nine_patch_packed_scene : PackedScene = PackedScene.new()
				if godot_nine_patch_packed_scene.pack(godot_nine_patch_rect) == OK:
					# Debug:
					#print("Saving to: ", godot_nine_patch_scene_save_path)
					if ResourceSaver.save(godot_nine_patch_packed_scene, godot_nine_patch_scene_save_path) != OK:
						return ERR_PARSE_ERROR
				else:
					__push_error("Unable to pack converted GDX nine patch rect as a NinePatchRect scene. Cannot continue.")
					return ERR_CANT_CREATE

				# Let Godot know about the generated files during the import process so it can recreate them if they are deleted
				r_gen_files.push_back(godot_nine_patch_scene_save_path)

				# And free the node. No longer need it.
				godot_nine_patch_rect.free()

	# Do the final for the original import (p_source_file):
	# NOTE: Here we save the GDX Atlas file as a raw Resource because
	# the atlas itself does not provide any value other than generating all
	# the other AtlasTexture resources, and also by doing this the engine
	# will also re-import the atlas resource should the atlas file change.
	return ResourceSaver.save(Resource.new(), "%s.%s" % [p_save_path, _get_save_extension()])


# Private methods
var _m_plugin_name : String = "GDX Texture2D Packer Atlas Importer"
func __push_error(p_message : String) -> void:
		push_error("%s: %s" % [ _m_plugin_name, p_message ])

func __push_warning(p_message : String) -> void:
		push_warning("%s: %s" % [ _m_plugin_name, p_message ])

# Private methods -- only used for debugging purposes.
#func __remove_directory_recursively(p_path : String) -> void:
#	var directory = Directory.new()
#	if directory.open(p_path) == OK:
#		directory.list_dir_begin(true)
#		var file_name : String = directory.get_next()
#		while (file_name != "" && file_name != "." && file_name != ".."):
#			if directory.current_is_dir():
#				__remove_directory_recursively(p_path.path_join(file_name))
#			else:
#				directory.remove(file_name)
#			file_name = directory.get_next()
#		directory.remove(p_path)
#	else:
#		push_warning("Error removing: " + p_path)
