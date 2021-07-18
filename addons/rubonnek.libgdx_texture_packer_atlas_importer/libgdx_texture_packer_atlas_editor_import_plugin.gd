# The MIT License (MIT)
#
# Copyright (c) 2021 Wilson E. Alvarez
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
    #    m_presets.DEFAULT:
    #        return [{
    #                   "name": "use_red_anyway",
    #                   "default_value": false,
    #                   "property_hint": PropertyHint.FLAG
    #                   "hint_string": "Available Hint"
    #                   "usage": PropertyUsage.FLAG
    #                }]
    #    _:
    #        return []
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
	var atlas_reader_gdscript : GDScript = load(get_script().get_path().get_base_dir().plus_file("libgdx_texture_packer_atlas_reader.gd"))
	var libgdx_atlas_reader = atlas_reader_gdscript.new()

	# If there was an error opening the file -- inform the Editor
	var error : int = libgdx_atlas_reader.open(p_source_file)
	if error != OK:
		push_error("Unable to open atlas file: " + p_source_file)
		return ERR_PARSE_ERROR

	# Make sure we were able to read the header:
	error = libgdx_atlas_reader.read_atlas_header()
	if error != OK:
		return error

	# Grab the atlas texture filename
	var atlas_texture_filename : String = libgdx_atlas_reader.get_atlas_texture_filename()
	var atlas_texture_path : String = p_source_file.get_base_dir().plus_file(atlas_texture_filename)
	var atlas_texture : StreamTexture = ResourceLoader.load(atlas_texture_path)
	if not is_instance_valid(atlas_texture):
		push_error("Required atlas texture hasn't been imported yet. This should not happen!")
		libgdx_atlas_reader.close()
		return ERR_CANT_OPEN

	# Store all the atlas entries in an array for post processing later
	var libgdx_atlas_entries_array : Array = []
	while true:
		# Extract atlas entry
		var entry_dictionary : Dictionary = libgdx_atlas_reader.get_next_atlas_texture_entry()

		# Store for post processing
		libgdx_atlas_entries_array.push_back(entry_dictionary)

		# Check if we are done processing the atlas
		if entry_dictionary["eof_reached"] or entry_dictionary["success"] == false:
			libgdx_atlas_reader.close()

			# If there was an issue parsing the atlas entries, inform the Editor
			if entry_dictionary["success"] == false:
				return ERR_PARSE_ERROR

			# No error occured, but we've reached eof.
			# Need to break out of the infinite loop.
			break

	# Debug
	#print(libgdx_atlas_entries_array)

	# Make atlas_basename.sprites folder to store all the AtlasTexture resources there
	var atlas_texture_resources_directory : String = p_source_file.get_basename() + ".sprites"
	var directory : Directory = Directory.new()
	if not directory.dir_exists(atlas_texture_resources_directory):
		if directory.make_dir(atlas_texture_resources_directory) != OK:
			push_error("Can't create directory: %s\n\tUnable to continue importing LibGDX Atlas.")
			return ERR_CANT_CREATE

	# Convert libgdx atlas entries to AtlasTexture resources:
	# NOTE: The last entry from the from the LibGDX Atlas reader only contains
	# info on whether or not the atlas read was successful. This data was
	# already processed in the loop above and can be ignored at this point.
	# Convert atlas entries to texture
	for libgdx_atlas_entry_index in range(0, libgdx_atlas_entries_array.size() - 1):

		var libgdx_atlas_entry : Dictionary = libgdx_atlas_entries_array[libgdx_atlas_entry_index]
		var atlas_texture_resource : AtlasTexture = AtlasTexture.new()

		# Set the atlas texture in the resource:
		atlas_texture_resource.set_atlas(atlas_texture)

		# Set the atlas texture resource region:
		var libgdx_texture_position : Vector2 = libgdx_atlas_entry["xy"]
		var libgdx_texture_size : Vector2 = libgdx_atlas_entry["size"]
		atlas_texture_resource.set_region(Rect2(libgdx_texture_position, libgdx_texture_size))

		# Set the margin:
		# NOTE: The coordinate system over the y axis within the LibGDX atlas
		# changes for the texture offset and the original size -- that's the
		# reason for flipping the y axis when setting the margin below, just so
		# it conforms to Godot's standard:
		var libgdx_texture_offset : Vector2 = libgdx_atlas_entry["offset"]
		var libgdx_texture_original_size : Vector2 = libgdx_atlas_entry["orig"]
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
		var atlas_texture_resource_name : String = "%s_%s" % [ libgdx_atlas_entry["basename"], libgdx_atlas_entry["index"] ]
		var atlas_texture_resource_save_path : String = atlas_texture_resource_path_format % [atlas_texture_resources_directory, atlas_texture_resource_name, get_save_extension()]
		# Debug:
		# print(atlas_texture_resource_save_path)
		var is_save_successful : int = ResourceSaver.save(atlas_texture_resource_save_path, atlas_texture_resource)
		if is_save_successful != OK:
			return ERR_PARSE_ERROR

		# Let Godot know about the generated files during the import process
		r_gen_files.push_back(atlas_texture_resource_save_path)

	# Do the final for the original import (p_source_file):
	# NOTE: Here we save the LibGDX Atlas file as a raw Resource because the
	# atlas itself does not provide any value, other than generating all the
	# other AtlasTexture resources.
	return ResourceSaver.save("%s.%s" % [p_save_path, get_save_extension()], Resource.new())
