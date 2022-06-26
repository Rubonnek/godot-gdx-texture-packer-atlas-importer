# The MIT License (MIT)
#
# Copyright (c) 2021-2022 Wilson E. Alvarez
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
func get_importer_name() -> String:
	return "rubonnek.libgdx_texture_packer_atlas_importer"


# Returns the name of the type it imports and it will be shown to the user in the Import dock.
func get_visible_name() -> String:
	return "LibGDX Atlas"


# Godot's import system detects file types by their extension. In the
# get_recognized_extensions() method you return an array of strings to
# represent each extension that this plugin can understand.
func get_recognized_extensions() -> Array:
	return ["atlas"]


# The imported files are saved in the .import folder at the project's root.
# Their extension should match the type of resource you are importing, but
# since Godot can't tell what you'll use (because there might be multiple valid
# extensions for the same resource), you need to declare what will be used in
# the import.
func get_save_extension() -> String:
	return "res"


# The imported resource has a specific type, so the editor can know which
# property slot it belongs to. This allows drag and drop from the FileSystem
# dock to a property in the Inspector.
func get_resource_type() -> String:
	return "AtlasTexture"


# Since there might be many presets and they are identified with a number, it's a good practice to use an enum so you can refer to them using names.
enum m_presets { DEFAULT }


# Returns the amount of presets that this plugins defines. We only have one
# preset now, but we can make this method future-proof by returning the size of
# our m_presets enumeration.
func get_preset_count() -> int:
	return m_presets.size()


# Gives names to the presets as they will be presented to the user, so be sure
# to use short and clear names.
func get_preset_name(p_preset : int) -> String:
	match p_preset:
		m_presets.DEFAULT:
			return "Default"
		_:
			return "Unknown"


# This is the method which defines the available options -- get_import_options()
# returns an array of dictionaries, and each dictionary contains a few keys
# that are checked to customize the option as its shown to the user.
func get_import_options(_p_preset : int) -> Array:
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
func get_option_visibility(_p_option : String, _p_options : Dictionary) -> bool:
	return true


# Tweak the import order just so the LibGDX atlas does not get imported before
# the texture it depends on.
func get_import_order() -> int:
	# Import the atlas before the scenes
	var import_order : int = ResourceImporter.IMPORT_ORDER_SCENE - 1
	return import_order


# The import function is where the heavy lifting to import a new resource
# happens.
func import(p_source_file : String, p_save_path : String, _p_options : Dictionary, _r_platform_variants : Array, r_gen_files : Array) -> int:
	# Debug:
	# print("Source file: " + p_source_file)
	# print("Save path: " + p_save_path)
	# print("Options: " + str(p_options))

	# Load the atlas reader:
	var libgdx_texture_packer_atlas_reader_gdscript : GDScript = load(get_script().get_path().get_base_dir().plus_file("libgdx_texture_packer_atlas_reader.gd"))
	var libgdx_atlas_reader = libgdx_texture_packer_atlas_reader_gdscript.new()

	# If there was an error parsing the LibGDX TexturePacker Atlas, inform the Editor
	var libgdx_parse_result : Dictionary = libgdx_atlas_reader.parse(p_source_file)
	var error : int = libgdx_parse_result["error"]
	if error != OK:
		# NOTE: No need to print the error since it was done already. Only need to bubble up the error code to the Editor.
		return error

	# There was no error. Grab the result:
	var libgdx_atlas_data_dictionary : Dictionary = libgdx_parse_result["result"]

	# Grab the base directory:
	var libgdx_atlas_path : String = libgdx_atlas_data_dictionary["path"] # same as p_source_file in the current scope
	var atlas_texture_resources_directory : String = libgdx_atlas_path.trim_suffix("." + libgdx_atlas_path.get_extension()) + ".atlas_textures"
	# Make atlas_basename.atlas_textures folder to store all the AtlasTexture resources there. Clean up old directories if any.
	var directory : Directory = Directory.new()
	# Debug
	#if directory.dir_exists(atlas_texture_resources_directory):
	#	__remove_directory_recursively(atlas_texture_resources_directory)
	if not directory.dir_exists(atlas_texture_resources_directory):
		if directory.make_dir(atlas_texture_resources_directory) != OK:
			push_error("Can't create AtlasTextures root directory: %s\n\tUnable to continue importing LibGDX Atlas." % [ atlas_texture_resources_directory ])
			return ERR_CANT_CREATE

	# The LibGDX TexturePacker Atlas format also supports describing nine
	# patch rectangles which directly translate to a NinePatchRect node in
	# Godot. We'll create these scene in a separate folder for organization's sake.
	var nine_patch_rect_scenes_directory : String = libgdx_atlas_path.trim_suffix("." + libgdx_atlas_path.get_extension()) + ".nine_patch_rects"
	# Debug
	#if directory.dir_exists(nine_patch_rect_scenes_directory):
	#	__remove_directory_recursively(nine_patch_rect_scenes_directory)
	var is_a_nine_patch_rect_defined : bool = false
	for packed_texture_dictionary in libgdx_atlas_data_dictionary["packed_textures"]:
		for libgdx_atlas_texture_dictionary in packed_texture_dictionary["atlas_textures"]:
			if "split" in libgdx_atlas_texture_dictionary:
				is_a_nine_patch_rect_defined = true
	if is_a_nine_patch_rect_defined:
		if not directory.dir_exists(nine_patch_rect_scenes_directory):
			if directory.make_dir(nine_patch_rect_scenes_directory) != OK:
				push_error("Can't create NinePatchRects root directory: %s\n\tUnable to continue importing LibGDX Atlas." % [ nine_patch_rect_scenes_directory ])
				return ERR_CANT_CREATE

	# For each packed texture found within the GDX Atlas
	var libgdx_atlas_base_directory : String = libgdx_atlas_path.get_base_dir()
	for packed_texture_dictionary in libgdx_atlas_data_dictionary["packed_textures"]:
		# Grab the packed texture filename
		var packed_texture_filename : String = packed_texture_dictionary["filename"]

		# Generate the path of the packed texture relative to the GDX Atlas path
		var packed_texture_path : String = libgdx_atlas_base_directory.plus_file(packed_texture_filename)
		var libgdx_packed_texture_stream_texture : StreamTexture = load(packed_texture_path)
		if not is_instance_valid(libgdx_packed_texture_stream_texture):
			var error_message : String = "Unable to load texture atlas at: %s\n" % [ packed_texture_path ]
			error_message += "Image was referenced by LibGDX TexturePacker Atlas file at: %s\n" % [ libgdx_atlas_path ]
			push_error(error_message)
			return ERR_CANT_OPEN

		# Make sure that the texture size matches what we've read from disk:
		# NOTE: The texture size is the only common metadata between
		# LibGDX TexturePacker Atlas formats (i.e. between the legacy
		# and new LibGDX TexturePacker Atlas formats).
		var libgdx_packed_texture_size : Vector2 = libgdx_packed_texture_stream_texture.get_size()
		if libgdx_packed_texture_size != packed_texture_dictionary["settings"]["size"]:
			var error_message : String = "Incorrect texture size found in LibGDX TexturePacker Atlas!\n"
			error_message += "Make sure that the texture in the LibGDX TexturePacker Atlas at: %s\n" % [ p_source_file ]
			error_message += "match the loaded texture at: %s" % [ packed_texture_path ]
			push_error(error_message)
			return ERR_CANT_ACQUIRE_RESOURCE

		# Convert GDX atlas texture entries within the packed texture dictionary into Godot's AtlasTexture resources:
		for libgdx_atlas_texture_dictionary in packed_texture_dictionary["atlas_textures"]:
			# Create the AtlasTexture resource:
			var atlas_texture_resource : AtlasTexture = AtlasTexture.new()

			# Set the atlas texture in the resource:
			atlas_texture_resource.set_atlas(libgdx_packed_texture_stream_texture)

			# Set the atlas texture resource region:
			var libgdx_texture_position : Vector2 = libgdx_atlas_texture_dictionary["xy"]
			var libgdx_texture_size : Vector2 = libgdx_atlas_texture_dictionary["size"]
			atlas_texture_resource.set_region(Rect2(libgdx_texture_position, libgdx_texture_size))

			# Set the margin:
			# NOTE: The coordinate system over the y axis within the LibGDX atlas
			# changes for the texture offset and the original size -- that's the
			# reason for flipping the y axis when setting the margin below, just so
			# it conforms to Godot's coordinate system:
			var libgdx_texture_offset : Vector2 = libgdx_atlas_texture_dictionary["offset"]
			var libgdx_texture_original_size : Vector2 = libgdx_atlas_texture_dictionary["orig"]
			# NOTE: the texture offset denotes left-to-right and bottom-to-top offset,
			# basically denoting the bottom_left edge of the rectangle for the sprite.
			# The bottom_right_edge is undefined, but can be calculated:
			var bottom_right_edge : Vector2 = libgdx_texture_original_size - libgdx_texture_size

			# Debug
			#print("Bottom Right Edge margin: " + str(bottom_right_edge))
			# NOTE: Since the LibGDX texture offset y coordinate is considered to
			# be flipped in Godot's coordinate system (since the the y axis in
			# LibGDX is measured from bottom_to_top when calculating the offset,
			# whereas Godot measures it from top_to_bottom), every pixel added over
			# the y axis on the bottom_right_edge corner in Godot must be
			# substracted from the LibGDX texture offset y axis. Otherwise the
			# sprite offset location will be off over the y axis.  In other words,
			# the bottom_right_edge corner in Godot's coordinate system fills the
			# image from the right and bottom. The bottom fill minus the y offset
			# as determined by LibGDX, is what we need to calculate the image
			# offset in Godot's coordinate system.
			var texture_margin : Rect2 = Rect2(libgdx_texture_offset.x, bottom_right_edge.y - libgdx_texture_offset.y, bottom_right_edge.x, bottom_right_edge.y)

			# Debug
			#print("Texture margin: " + str(texture_margin))
			atlas_texture_resource.set_margin(texture_margin)

			# Generate new resource
			var atlas_texture_resource_path_format = "%s/%s.%s"
			var atlas_texture_resource_name : String
			if libgdx_atlas_texture_dictionary["index"] != "-1":
				atlas_texture_resource_name = "%s_%s" % [ libgdx_atlas_texture_dictionary["basename"], libgdx_atlas_texture_dictionary["index"] ]
			else:
				atlas_texture_resource_name = libgdx_atlas_texture_dictionary["basename"]

			# The LibGDX TexturePacker format may include relative paths for which we may have to create directories for, thus we handle those here.
			if "/" in atlas_texture_resource_name:
				var path_to_folder_to_create : String = atlas_texture_resources_directory.plus_file(atlas_texture_resource_name.get_base_dir())
				if not directory.dir_exists(path_to_folder_to_create):
					if directory.make_dir_recursive(path_to_folder_to_create) != OK:
						push_error("Can't create directory: %s\n\tUnable to continue importing LibGDX Atlas." % [ path_to_folder_to_create ])
						return ERR_CANT_CREATE
			var atlas_texture_resource_save_path : String = atlas_texture_resource_path_format % [atlas_texture_resources_directory, atlas_texture_resource_name, get_save_extension()]

			# Debug:
			#print("Saving to: ", atlas_texture_resource_save_path)

			if ResourceSaver.save(atlas_texture_resource_save_path, atlas_texture_resource) != OK:
				return ERR_PARSE_ERROR

			# Let Godot know about the generated files during the import process so it can recreate them if they are deleted
			r_gen_files.push_back(atlas_texture_resource_save_path)

			# We are done processing the AtlasTexture, but there's a chance the user defined a nine patch rectangle for it which we can translate into a Godot NinePatchRect node.
			if "split" in libgdx_atlas_texture_dictionary:
				# A nine patch rectangle has been defined. Let's create the node.
				var godot_nine_patch_rect : NinePatchRect = NinePatchRect.new()

				# Set the AtlasTexture path just so the resource does not get embedded into the NinePatchRect scene
				atlas_texture_resource.set_path(atlas_texture_resource_save_path)

				# Set the AtlasTexture on the NinePatchRect
				godot_nine_patch_rect.set_texture(atlas_texture_resource)

				# Set the new AtlasTexture Content Margin
				var libgdx_nine_patch_content_margin_rect2 : Rect2 = libgdx_atlas_texture_dictionary["pad"]
				var libgdx_left_margin_padding : int = int(libgdx_nine_patch_content_margin_rect2.position.x)
				var libgdx_right_margin_padding : int = int(libgdx_nine_patch_content_margin_rect2.position.y)
				var libgdx_bottom_margin_padding : int = int(libgdx_nine_patch_content_margin_rect2.size.y)
				var libgdx_top_margin_padding : int = int(libgdx_nine_patch_content_margin_rect2.size.x)
				# Debug
				#print("Left content margin: ", libgdx_left_margin_padding)
				#print("Right content margin: ", libgdx_right_margin_padding)
				#print("Bottom content margin: ", libgdx_bottom_margin_padding)
				#print("Top content margin: ", libgdx_top_margin_padding)
				var godot_content_position_offset : Vector2 = Vector2(libgdx_left_margin_padding, libgdx_top_margin_padding)
				var godot_content_size : Vector2 = Vector2(libgdx_texture_size.x - (libgdx_left_margin_padding + libgdx_right_margin_padding), libgdx_texture_size.y - (libgdx_top_margin_padding + libgdx_bottom_margin_padding))
				godot_nine_patch_rect.set_region_rect(Rect2(godot_content_position_offset, godot_content_size))

				# Debug
				#print("NinePatchRect AtlasTexture content region raw: ", libgdx_nine_patch_content_margin_rect2)

				# Set the size of the NinePatchRect node to be equal to the content size
				godot_nine_patch_rect.set_size(godot_content_size)

				# Set the NinePatchRect Patch Margin
				# In LibGDX the patch margin is calculated from the edges, but in Godot the patch margin is relative to the content position and size. Here we convert the coordinates as required.
				var libgdx_nine_patch_margin_rect : Rect2 = libgdx_atlas_texture_dictionary["split"]
				var libgdx_left_patch_margin : int = int(libgdx_nine_patch_margin_rect.position.x)
				var libgdx_right_patch_margin : int = int(libgdx_nine_patch_margin_rect.position.y)
				var libgdx_top_patch_margin : int = int(libgdx_nine_patch_margin_rect.size.x)
				var libgdx_bottom_patch_margin : int = int(libgdx_nine_patch_margin_rect.size.y)
				var godot_right_patch_margin : int = int(godot_content_position_offset.x) + int(godot_content_size.x) - libgdx_left_patch_margin
				var godot_left_patch_margin : int = int(libgdx_texture_size.x) - int(godot_content_position_offset.x) - libgdx_right_patch_margin
				var godot_top_patch_margin : int = int(libgdx_texture_size.y) - int(godot_content_position_offset.y) - libgdx_bottom_patch_margin
				var godot_bottom_patch_margin : int = int(godot_content_position_offset.y) + int(godot_content_size.y) - libgdx_top_patch_margin
				godot_nine_patch_rect.set_patch_margin(MARGIN_LEFT, godot_left_patch_margin % int(libgdx_texture_size.x))
				godot_nine_patch_rect.set_patch_margin(MARGIN_RIGHT, godot_right_patch_margin % int(libgdx_texture_size.x))
				godot_nine_patch_rect.set_patch_margin(MARGIN_TOP, godot_top_patch_margin % int(libgdx_texture_size.y))
				godot_nine_patch_rect.set_patch_margin(MARGIN_BOTTOM, godot_bottom_patch_margin % int(libgdx_texture_size.y))

				# Save the NinePatchRect node
				# NOTE: The LibGDX TexturePacker format may include relative paths for which we may have to create directories for, thus we handle those here for the NinePatchRect nodes as well.
				if "/" in atlas_texture_resource_name:
					var path_to_folder_to_create : String = nine_patch_rect_scenes_directory.plus_file(atlas_texture_resource_name.get_base_dir())
					if not directory.dir_exists(path_to_folder_to_create):
						if directory.make_dir_recursive(path_to_folder_to_create) != OK:
							push_error("Can't create directory: %s\n\tUnable to continue importing LibGDX Atlas." % [ path_to_folder_to_create ])
							return ERR_CANT_CREATE
				var godot_nine_patch_scene_save_path : String = atlas_texture_resource_path_format % [nine_patch_rect_scenes_directory, atlas_texture_resource_name, "tscn"]

				# Set the node name to be equal to its filename:
				godot_nine_patch_rect.set_name(atlas_texture_resource_name)

				# Finally save the NinePatchRect
				var godot_nine_patch_packed_scene : PackedScene = PackedScene.new()
				if godot_nine_patch_packed_scene.pack(godot_nine_patch_rect) == OK:
					# Debug:
					#print("Saving to: ", godot_nine_patch_scene_save_path)
					if ResourceSaver.save(godot_nine_patch_scene_save_path, godot_nine_patch_packed_scene) != OK:
						return ERR_PARSE_ERROR
				else:
					push_error("Unable to pack converted LibGDX nine patch rect as a NinePatchRect scene. Cannot continue.")
					return ERR_CANT_CREATE

				# Let Godot know about the generated files during the import process so it can recreate them if they are deleted
				r_gen_files.push_back(godot_nine_patch_scene_save_path)

				# And free the node. No longer need it.
				godot_nine_patch_rect.free()

	# Do the final for the original import (p_source_file):
	# NOTE: Here we save the LibGDX Atlas file as a raw Resource because
	# the atlas itself does not provide any value other than generating all
	# the other AtlasTexture resources, and also by doing this the engine
	# will also re-import the atlas resource should the atlas file change.
	return ResourceSaver.save("%s.%s" % [p_save_path, get_save_extension()], Resource.new())


# Private methods -- only used for debugging purposes.
#func __remove_directory_recursively(p_path : String) -> void:
#	var directory = Directory.new()
#	if directory.open(p_path) == OK:
#		directory.list_dir_begin(true)
#		var file_name : String = directory.get_next()
#		while (file_name != "" && file_name != "." && file_name != ".."):
#			if directory.current_is_dir():
#				__remove_directory_recursively(p_path.plus_file(file_name))
#			else:
#				directory.remove(file_name)
#			file_name = directory.get_next()
#		directory.remove(p_path)
#	else:
#		push_warning("Error removing: " + p_path)
