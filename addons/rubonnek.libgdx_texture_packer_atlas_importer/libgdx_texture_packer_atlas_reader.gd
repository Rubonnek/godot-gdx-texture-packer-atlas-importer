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

extends Reference

enum m_atlas_reader_states { READING_TEXTURE_HEADER, READING_ATLAS_TEXTURES }
var m_reader_state : int  = m_atlas_reader_states.READING_TEXTURE_HEADER
enum m_libgdx_atlas_formats { LEGACY, NEW }
var m_detected_atlas_format : int = m_libgdx_atlas_formats.LEGACY

var m_whitespace_regex : RegEx = RegEx.new()

func _init() -> void:
	# Compile the whitespace regex - we are going to use this soon to clean up the LibGDX Texture Packer Atlas text to make it easier to process:
	var _success : int = m_whitespace_regex.compile("\\s")


# Internal function for reading the atlas header -- returns the number of lines read
func __read_texture_metadata(p_libgdx_atlas_pool_string_array : PoolStringArray, p_starting_at_line : int, r_packed_texture_dictionary : Dictionary) -> int:
	assert(m_reader_state == m_atlas_reader_states.READING_TEXTURE_HEADER, "Wrong reader state for reading the texture metadata! Set \"m_reader_state\" to \"m_atlas_reader_states.READING_TEXTURE_HEADER\" before calling this function!")

	# Read the header:
	if m_detected_atlas_format == m_libgdx_atlas_formats.LEGACY:
		return __read_legacy_texture_metadata(p_libgdx_atlas_pool_string_array, p_starting_at_line, r_packed_texture_dictionary)
	elif m_detected_atlas_format == m_libgdx_atlas_formats.NEW:
		return __read_new_texture_metadata(p_libgdx_atlas_pool_string_array, p_starting_at_line, r_packed_texture_dictionary)
	else:
		push_error("Unknown atlas format! This should not happen! Unable to parse LibGDX Texture Packer Atlas!")
		r_packed_texture_dictionary["error"] = ERR_PARSE_ERROR
		return 0


# Reads the legacy format texture settings and returns the number of lines read
func __read_legacy_texture_metadata(p_libgdx_atlas_pool_string_array : PoolStringArray, p_starting_at_line : int, r_packed_texture_dictionary : Dictionary) -> int:
	var header_size_in_number_of_lines : int = 4
	var number_of_lines_read : int = 0
	for header_line_index in range(p_starting_at_line, p_starting_at_line + header_size_in_number_of_lines):
		# Do a sanity check on the line index we are about to read
		if header_line_index > p_libgdx_atlas_pool_string_array.size() - 1:
			# Sample Legacy Texture Metadata:
			var sample_legacy_texture_metadata : String = "\n"
			sample_legacy_texture_metadata += "size: 128, 256\n"
			sample_legacy_texture_metadata += "format: RGBA8888\n"
			sample_legacy_texture_metadata += "filter: Nearest, Nearest\n"
			sample_legacy_texture_metadata += "repeat: none\n"
			push_error("Malformed atlas header! Check that the LibGDX Texture Packer Atlas file is not corrupted -- the header should have six lines (including a blank line) and look similar to:\n %s" % sample_legacy_texture_metadata)
			r_packed_texture_dictionary["error"] = ERR_PARSE_ERROR
			return number_of_lines_read

		# Read the settings key-value pair:
		var key_value_pair : PoolStringArray = p_libgdx_atlas_pool_string_array[header_line_index].split(":")
		number_of_lines_read += 1
		var key : String = key_value_pair[0]
		var value : String = key_value_pair[1]

		# Properly convert supported types:
		# NOTE: Here we are only converting the texture size because
		# it's the only common setting between LibGDX TexturePacker
		# Atlas formats (i.e. the legacy and new formats).
		if key == "size":
			var xy_coordinates_pool_string_array : PoolStringArray = value.split(",")
			r_packed_texture_dictionary["settings"][key] = Vector2(int(xy_coordinates_pool_string_array[0]), int(xy_coordinates_pool_string_array[1]))
		else:
			# Inject the setting as-is into the dictionary
			r_packed_texture_dictionary["settings"][key] = value

	return number_of_lines_read


# Reads the new format texture settings and returns the number of lines read
func __read_new_texture_metadata(p_libgdx_atlas_pool_string_array : PoolStringArray, p_starting_at_line : int, r_packed_texture_dictionary : Dictionary) -> int:
	var header_size_in_number_of_lines : int = 2
	var number_of_lines_read : int = 0
	for header_line_index in range(p_starting_at_line, p_starting_at_line + header_size_in_number_of_lines):
		# Do a sanity check on the line index we are about to read
		if header_line_index > p_libgdx_atlas_pool_string_array.size() - 1:
			# Sample New Texture Metadata:
			var sample_new_texture_metadata : String = "\n"
			sample_new_texture_metadata += "size:128,256\n"
			sample_new_texture_metadata += "repeat:none\n"
			push_error("Malformed atlas header! Check the file is not corrupted -- the header should have six lines (including a blank line) and look similar to:\n %s" % sample_new_texture_metadata)
			r_packed_texture_dictionary["error"] = ERR_PARSE_ERROR
			return number_of_lines_read

		# Read the settings key-value pair:
		var key_value_pair : PoolStringArray = p_libgdx_atlas_pool_string_array[header_line_index].split(":")
		number_of_lines_read += 1
		var key : String = key_value_pair[0]
		var value : String = key_value_pair[1]

		# Properly convert supported types:
		# NOTE: Here we are only converting the texture size because
		# it's the only common setting between LibGDX TexturePacker
		# Atlas formats (i.e. the legacy and new formats).
		if key == "size":
			var xy_coordinates_pool_string_array : PoolStringArray = value.split(",")
			r_packed_texture_dictionary["settings"][key] = Vector2(int(xy_coordinates_pool_string_array[0]), int(xy_coordinates_pool_string_array[1]))
		else:
			# Inject the setting as-is into the dictionary
			r_packed_texture_dictionary["settings"][key] = value

	return number_of_lines_read


# Returns the number of lines read from the atlas texture
func __get_next_atlas_texture_entry(p_libgdx_atlas_pool_string_array : PoolStringArray, p_source_file : String, p_starting_at_line : int, r_packed_texture_dictionary : Dictionary) -> int:
	# Most of the header data can eb skippes
	assert(m_reader_state != m_atlas_reader_states.READING_TEXTURE_HEADER, "Unable to read next atlas texture. Call \"__read_texture_metadata\" first!")

	# Get the atlas texture entry
	if m_detected_atlas_format == m_libgdx_atlas_formats.LEGACY:
		return __get_next_libgdx_atlas_texture_entry_in_legacy_atlas_format(p_libgdx_atlas_pool_string_array, p_source_file, p_starting_at_line, r_packed_texture_dictionary)
	elif m_detected_atlas_format == m_libgdx_atlas_formats.NEW:
		return __get_next_libgdx_atlas_texture_entry_in_new_atlas_format(p_libgdx_atlas_pool_string_array, p_source_file, p_starting_at_line, r_packed_texture_dictionary)
	else:
		push_error("Unknown LibGDX TexturePacker Atlas format! This should not happen!")
		r_packed_texture_dictionary["error"] = ERR_PARSE_ERROR
		return 0

# In order to process the legacy LibGDX TexturePacker Atlas format, we need to know what keys we expect to read under each atlas texture.
# This constant is only meant to be used by the function: __get_next_libgdx_atlas_texture_entry_in_new_atlas_format
const m_expected_legacy_libgdx_texture_packer_atlas_format_keys : Array = [
		"rotate",
		"xy",
		"size",
		"split",
		"pad",
		"orig",
		"offset",
		"index",
	]

# Returns the number of lines read from the atlas texture
func __get_next_libgdx_atlas_texture_entry_in_legacy_atlas_format(p_libgdx_atlas_pool_string_array : PoolStringArray, p_source_file : String, p_starting_at_line : int, r_packed_texture_dictionary : Dictionary) -> int:
	# At this point the atlas HEADER should have been read.
	assert(m_reader_state == m_atlas_reader_states.READING_ATLAS_TEXTURES)

	# Grab the sprite basename -- there's a chance this could return empty
	# because we have reached the end of file:
	var current_line_to_read : int = p_starting_at_line
	var libgdx_atlas_texture_basename : String = p_libgdx_atlas_pool_string_array[current_line_to_read]
	current_line_to_read += 1

	# In-scope variables to store the values we are going to return in
	# Godot format where possible. Otherwise we'll use raw LibGDX format.
	var libgdx_atlas_texture_rotate : bool = false
	var libgdx_atlas_texture_position_vector : Vector2
	var libgdx_atlas_texture_size_vector : Vector2
	var libgdx_atlas_texture_original_size_vector : Vector2
	var libgdx_atlas_texture_offset_vector : Vector2
	var libgdx_atlas_texture_index_string : String

	# LibGDX TexturePacker atlases also support defining nine patch rects,
	# for which we can also generate NinePatchRect nodes in Godot.
	# These entries only show up when these objects are defined.
	var libgdx_nine_patch_rect_patch_margin_rect2 : Rect2
	var was_split_key_seen : bool = false
	var libgdx_nine_patch_rect_rect_region_rect2 : Rect2
	var was_pad_key_seen : bool = false

	# Start looping over the key-value pairs of the atlas -- we need to
	# make sure we read allpossible entries.
	var libgdx_atlas_texture_entry_format_lines_to_read : int = 8
	# NOTE: The GDX TexturePacker GUI tool at: https://github.com/crashinvaders/gdx-texture-packer-gui
	# Outputs each LibGDX atlas texture entry as follows, in the same order when all entries are present:
	#	libgdx_atlas_texture_basename
	#	  rotate: false
	#	  xy: 2, 2
	#	  size: 27, 31
	#	  split: 1, 2, 4, 3
	#	  pad: 0, 0, 0, 0
	#	  orig: 32, 32
	#	  offset: 3, 1
	#	  index: 3
	for libgdx_texture_packer_atlas_texture_entry_line in range(current_line_to_read, current_line_to_read + libgdx_atlas_texture_entry_format_lines_to_read):
		# Check if we have reached the end of file -- if so we are done reading the atlas
		if libgdx_texture_packer_atlas_texture_entry_line > p_libgdx_atlas_pool_string_array.size() - 1:
			break

		# Grab atlas key-value pair
		var libgdx_atlas_texture_entry_key_value_pair_array : Array = p_libgdx_atlas_pool_string_array[libgdx_texture_packer_atlas_texture_entry_line].split(":")

		# Check that the key we got is supported
		var libgdx_atlas_texture_entry_key : String = libgdx_atlas_texture_entry_key_value_pair_array[0]
		if not libgdx_atlas_texture_entry_key in m_expected_legacy_libgdx_texture_packer_atlas_format_keys:
			# The key is not supported -- we are at the beginning of the next either an atlas entry or a new atlas page.
			break

		# It's a known key.
		current_line_to_read += 1
		var libgdx_atlas_texture_entry_value : String = libgdx_atlas_texture_entry_key_value_pair_array[1]

		# Process texture atlas key-value entry
		match libgdx_atlas_texture_entry_key:
			"rotate":
				# Process Rotate entry -- if it's not false, we can't process this LibGDX TexturePacker Atlas in Godot
				if not "false" in libgdx_atlas_texture_entry_value:
					# NOTE: It's impossible to tell Godot to rotate the AtlasTextures -- need to bubble up an error if this happens.
					push_error("Found rotated texture in LibGDX TexturePacker Atlas file at \"%s\".\nGodot does not support rotated AtlasTexture resources.\nPlease disable texture rotation in your LibGDX TexturePacker project and repack the atlas." % [ p_source_file ])
					r_packed_texture_dictionary["error"] = ERR_PARSE_ERROR
					return current_line_to_read - p_starting_at_line

			"xy":
				# Process LibGDX AtlasTexture Position
				# NOTE The coordinates of sprite position on atlas are measured as follows:
				# x: from left to right
				# y: from top to bottom
				# this differs from the sprite offset in which the y coordinate is measured from bottom to top
				var libgdx_atlas_texture_position_on_atlas_array : Array = libgdx_atlas_texture_entry_value.split(",")
				var libgdx_atlas_texture_position_x_string : String = libgdx_atlas_texture_position_on_atlas_array[0]
				var libgdx_atlas_texture_position_y_string : String = libgdx_atlas_texture_position_on_atlas_array[1]
				libgdx_atlas_texture_position_vector = Vector2(int(libgdx_atlas_texture_position_x_string), int(libgdx_atlas_texture_position_y_string))

			"size":
				# Process LibGDX AtlasTexture Size
				# NOTE The coordinates of sprite position on atlas are measured as follows:
				# x: from left to right
				# y: from top to bottom
				# this differs from the sprite offset in which the y coordinate is measured from bottom to top
				# Also, this sprite size may differ from the original since
				# transparent borders may be trimmed to save space.
				var libgdx_atlas_texture_size_array : Array = libgdx_atlas_texture_entry_value.split(",")
				var libgdx_atlas_texture_size_x_string : String = libgdx_atlas_texture_size_array[0]
				var libgdx_atlas_texture_size_y_string : String = libgdx_atlas_texture_size_array[1]
				libgdx_atlas_texture_size_vector = Vector2(int(libgdx_atlas_texture_size_x_string), int(libgdx_atlas_texture_size_y_string))

			"split":
				# Process LibGDX NinePatchRect Patch Margin
				# In the following entry:
				#	split: 1, 2, 4, 3
				# the numbers represent the following:
				# 	1 represents the nine patch rect margin from the left
				# 	2 represents the nine patch rect margin from the right
				# 	4 represents the nine patch rect margin from the top
				# 	3 represents the nine patch rect margin from the bottom
				was_split_key_seen = true
				var libgdx_nine_patch_rect_patch_margin_array : Array = libgdx_atlas_texture_entry_value.split(",")
				var libgdx_patch_margin_left : int = int(libgdx_nine_patch_rect_patch_margin_array[0])
				var libgdx_patch_margin_right : int = int(libgdx_nine_patch_rect_patch_margin_array[1])
				var libgdx_patch_margin_top : int = int(libgdx_nine_patch_rect_patch_margin_array[2])
				var libgdx_patch_margin_bottom : int = int(libgdx_nine_patch_rect_patch_margin_array[3])
				libgdx_nine_patch_rect_patch_margin_rect2 = Rect2(libgdx_patch_margin_left, libgdx_patch_margin_right, libgdx_patch_margin_top, libgdx_patch_margin_bottom)

			"pad":
				# Process LibGDX NinePatchRect Content Margin
				# In entry:
				#	pad: 1, 2, 4, 3
				# the numbers represent the following:
				# 	1 represents the content margin from the left
				# 	2 represents the content margin from the right
				# 	4 represents the content margin from the top
				# 	3 represents the content margin from the bottom
				was_pad_key_seen = true
				var libgdx_nine_patch_content_margin_array : Array = libgdx_atlas_texture_entry_value.split(",")
				var libgdx_rect_region_left : int = int(libgdx_nine_patch_content_margin_array[0])
				var libgdx_rect_region_right : int = int(libgdx_nine_patch_content_margin_array[1])
				var libgdx_rect_region_top : int = int(libgdx_nine_patch_content_margin_array[2])
				var libgdx_rect_region_bottom : int = int(libgdx_nine_patch_content_margin_array[3])
				libgdx_nine_patch_rect_rect_region_rect2 = Rect2(libgdx_rect_region_left, libgdx_rect_region_right, libgdx_rect_region_top, libgdx_rect_region_bottom)

			"orig":
				# LibGDX AtlasTexture Original Size
				var libgdx_atlas_texture_original_size_array : Array = libgdx_atlas_texture_entry_value.split(",")
				var libgdx_atlas_texture_original_size_x_string : String = libgdx_atlas_texture_original_size_array[0]
				var libgdx_atlas_texture_original_size_y_string : String = libgdx_atlas_texture_original_size_array[1]
				libgdx_atlas_texture_original_size_vector = Vector2(int(libgdx_atlas_texture_original_size_x_string), int(libgdx_atlas_texture_original_size_y_string))

			"offset":
				# LibGDX AtlasTexture Offset
				# NOTE The coordinates of the sprite offset based from the original image are measured as follows:
				# x: from left to right
				# y: from bottom to top
				# this differs from the sprite position in atlas in which the y coordinate is measured from top to bottom
				var libgdx_atlas_texture_offset_array : Array = libgdx_atlas_texture_entry_value.split(",")
				var libgdx_atlas_texture_offset_x_string : String = libgdx_atlas_texture_offset_array[0]
				var libgdx_atlas_texture_offset_y_string : String = libgdx_atlas_texture_offset_array[1]
				libgdx_atlas_texture_offset_vector = Vector2(int(libgdx_atlas_texture_offset_x_string), int(libgdx_atlas_texture_offset_y_string))

			"index":
				# LibGDX AtlasTexture Index
				# NOTE: When a set of sprite filenames such as "run_0.png",
				# "run_1.png", "run_2.png" are included in an atlas, the sprite frame
				# numbers 0, 1, and 2 respectively ends up as the index entry in the
				# atlas file.
				libgdx_atlas_texture_index_string = libgdx_atlas_texture_entry_value

			_:
				push_error("Found unknown LibGDX TexturePacker Atlas texture entry key : \"%s\" in file \"%s\" at line %d" % [ libgdx_atlas_texture_entry_key, p_source_file, current_line_to_read - 1 ])
				r_packed_texture_dictionary["error"] = ERR_PARSE_ERROR
				return current_line_to_read - p_starting_at_line

	# Construct LibGDX atlas texture entry dictionary found in the atlas --
	# this is all the information that's required to construct a Godot
	# AtlasTexture resource.
	var atlas_texture_entry_dictionary : Dictionary = {
			"basename" : libgdx_atlas_texture_basename,
			"rotate" : libgdx_atlas_texture_rotate,
			"xy" : libgdx_atlas_texture_position_vector,
			"size" : libgdx_atlas_texture_size_vector,
			"orig" : libgdx_atlas_texture_original_size_vector,
			"offset" : libgdx_atlas_texture_offset_vector,
			"index" : libgdx_atlas_texture_index_string,
			}

	# Include the Godot NinePatchRect data if any was defined for this AtlasTexture
	if was_pad_key_seen or was_split_key_seen:
		if was_split_key_seen and was_pad_key_seen:
			atlas_texture_entry_dictionary["split"] = libgdx_nine_patch_rect_patch_margin_rect2
			atlas_texture_entry_dictionary["pad"] = libgdx_nine_patch_rect_rect_region_rect2
		else:
			var which_key_was_seen : String = ""
			if was_split_key_seen:
				which_key_was_seen = "split"
			else:
				which_key_was_seen = "pad"
			var error_message : String = "Malformed LibGDX TexturePacker Atlas\n"
			error_message += "Expected to see both \"split\" and \"pad\" entries defined in: %s\n" % [ p_source_file ]
			error_message += "But only saw the \"%s\" key at around line %d" % [ which_key_was_seen, current_line_to_read - 1]
			push_error(error_message)
			r_packed_texture_dictionary["error"] = ERR_PARSE_ERROR
			return current_line_to_read - p_starting_at_line

	# Push the atlas_texture_entry_dictionary into r_packed_texture_dictionary
	r_packed_texture_dictionary["atlas_textures"].push_back(atlas_texture_entry_dictionary)

	# Debug
	#print(atlas_texture_entry_dictionary)
	return current_line_to_read - p_starting_at_line


# In order to process the new LibGDX TexturePacker Atlas format, we need to know what keys we expect to read under each atlas texture.
# This constant is only meant to be used by the function: __get_next_libgdx_atlas_texture_entry_in_new_atlas_format
const m_expected_new_libgdx_texture_packer_atlas_format_keys : Array = [
		"index",
		"bounds",
		"split",
		"pad",
		"offsets",
		"rotate",
	]


# Returns the number of lines it read from the atlas texture
func __get_next_libgdx_atlas_texture_entry_in_new_atlas_format(p_libgdx_atlas_pool_string_array : PoolStringArray, p_source_file : String, p_starting_at_line : int, r_packed_texture_dictionary : Dictionary) -> int:
	# At this point the atlas HEADER should have been read.
	assert(m_reader_state == m_atlas_reader_states.READING_ATLAS_TEXTURES)

	# NOTE: The GDX TexturePacker GUI tool at: https://github.com/crashinvaders/gdx-texture-packer-gui
	# Outputs each atlas sprite entry as follows, in the same order assuming all entries are present:
	#	libgdx_atlas_texture_basename
	#		index: 3
	#		bounds: 2, 2, 27, 31
	#		split:1,2,4,3
	#		pad:1,2,4,3
	#		offsets: 3, 1, 32, 32
	#		rotate: true
	# Of the atlas texture keys above, the only constant entry is the atlas texture bounds which is required.

	# The pretty-print is the version shown above. The non-pretty-print version is the exact same except all whitespace is eliminated on each row.

	# Check if we have reached the end of file -- if so, this was a successful read of the atlas.
	if p_starting_at_line > p_libgdx_atlas_pool_string_array.size() - 1:
		return 0

	# Grab the sprite basename -- there's a chance this could return empty
	# because we have reached the end of file:
	var current_line_to_read : int = p_starting_at_line
	var libgdx_atlas_texture_basename : String = p_libgdx_atlas_pool_string_array[current_line_to_read]
	current_line_to_read += 1

	# Debug
	#print("Processing LibGDX texture: ", libgdx_atlas_texture_basename)

	# In-scope variables to store the values we are going to return in
	# Godot format where possible. Otherwise we'll use raw LibGDX format.
	var libgdx_atlas_texture_rotate : bool = false
	var libgdx_atlas_texture_position_vector : Vector2
	var libgdx_atlas_texture_size_vector : Vector2
	var libgdx_atlas_texture_original_size_vector : Vector2
	var libgdx_atlas_texture_offset_vector : Vector2
	var libgdx_atlas_texture_index_string : String = "-1" # this is the default in the legacy format and it means there are no other atlas textures with similar names

	# LibGDX TexturePacker atlases also support defining nine patch rects,
	# for which we can also generate NinePatchRect nodes in Godot.
	# These entries only show up when these objects are defined.
	var libgdx_nine_patch_rect_patch_margin_rect2 : Rect2
	var was_split_key_seen : bool = false
	var libgdx_nine_patch_rect_rect_region_rect2 : Rect2
	var was_pad_key_seen : bool = false

	# Start looping over the key-value pairs of the atlas
	var libgdx_atlas_texture_entry_format_lines_to_read : int = 6
	# NOTE: We use the following PoolStringArray and Dictionary for sanity checking later on
	# NOTE: The was_bounds_key_seen variable below is only used to make
	# sure we've at least read what we need from the new LibGDX
	# TexturePacker format in order to create the AtlasTexture resource in
	# Godot.
	var was_bounds_key_seen : bool = false
	# NOTE: The was_offsets_key_seen variable below is used to make sure we
	# know what the original texture size is (i.e. what the 'orig' entry is
	# in the legacy LibGDX TexturePacker Atlas format). If the 'offsets' key is not seen
	# within the new format, then that means the original texture size is
	# the same as what appears in the 'bounds' key.
	var was_offsets_key_seen : bool = false

	for libgdx_texture_packer_atlas_texture_entry_line in range(current_line_to_read, current_line_to_read + libgdx_atlas_texture_entry_format_lines_to_read):
		# If we reach eof, we've reached the end of the file and that's completely fine.
		if libgdx_texture_packer_atlas_texture_entry_line > p_libgdx_atlas_pool_string_array.size() - 1:
			if not was_bounds_key_seen:
				# We didn't read the necessary key -- we got to EOF before we could read it. This means this LibGDX atlas file is malformed.
				push_error("Malformed LibGDX atlas found at \"%s\".\nReached end of file before the 'bounds' key was read for the atlas texture with basename \"%s\"\n" % [ p_source_file, libgdx_atlas_texture_basename ])
				r_packed_texture_dictionary["error"] = ERR_PARSE_ERROR
				return current_line_to_read - p_starting_at_line
			break

		# Grab atlas key-value pair
		var libgdx_atlas_texture_entry_key_value_pair_array : Array = p_libgdx_atlas_pool_string_array[libgdx_texture_packer_atlas_texture_entry_line].split(":")

		# Check that the key we got is supported
		var libgdx_atlas_texture_entry_key : String = libgdx_atlas_texture_entry_key_value_pair_array[0]
		if not libgdx_atlas_texture_entry_key in m_expected_new_libgdx_texture_packer_atlas_format_keys:
			if was_bounds_key_seen:
				break
			else:
				# We didn't read the necessary key -- this LibGDX atlas file is malformed.
				push_error("Malformed LibGDX atlas found at \"%s\".\nCould not find 'bounds' key around line %d for atlas texture with basename \"%s\"" % [ p_source_file, current_line_to_read, libgdx_atlas_texture_basename ])
				r_packed_texture_dictionary["error"] = ERR_PARSE_ERROR
				return current_line_to_read - p_starting_at_line

		# We got a compatible key -- update the line to read counter
		current_line_to_read += 1

		# Extract key and value
		var libgdx_atlas_texture_entry_value : String = libgdx_atlas_texture_entry_key_value_pair_array[1]

		# Process atlas entry
		match libgdx_atlas_texture_entry_key:
			"index":
				# LibGDX AtlasTexture Index
				# NOTE: When a set of sprite filenames such as "run_0.png",
				# "run_1.png", "run_2.png" are included in an atlas, the sprite frame
				# numbers 0, 1, and 2 respectively ends up as the index entry in the
				# atlas file.
				libgdx_atlas_texture_index_string = libgdx_atlas_texture_entry_value

			"bounds":
				# The bounds include the LibGDX AtlasTexture Position and the LibGDX AtlasTexture Size
				was_bounds_key_seen = true

				# LibGDX AtlasTexture Position
				# NOTE The coordinates of sprite position on atlas are measured as follows:
				# x: from left to right
				# y: from top to bottom
				# this differs from the sprite offset in which the y coordinate is measured from bottom to top
				var libgdx_atlas_texture_bounds_array : Array = libgdx_atlas_texture_entry_value.split(",")
				var libgdx_atlas_texture_position_x_string : String = libgdx_atlas_texture_bounds_array[0]
				var libgdx_atlas_texture_position_y_string : String = libgdx_atlas_texture_bounds_array[1]
				libgdx_atlas_texture_position_vector = Vector2(int(libgdx_atlas_texture_position_x_string), int(libgdx_atlas_texture_position_y_string))

				# LibGDX AtlasTexture Size
				# NOTE The coordinates of sprite position on atlas are measured as follows:
				# x: from left to right
				# y: from top to bottom
				# this differs from the sprite offset in which the y coordinate is measured from bottom to top
				# Also, this sprite size may differ from the original since
				# transparent borders may be trimmed to save space.
				var libgdx_atlas_texture_size_x_string : String = libgdx_atlas_texture_bounds_array[2]
				var libgdx_atlas_texture_size_y_string : String = libgdx_atlas_texture_bounds_array[3]
				libgdx_atlas_texture_size_vector = Vector2(int(libgdx_atlas_texture_size_x_string), int(libgdx_atlas_texture_size_y_string))

			"split":
				# Process LibGDX NinePatchRect Patch Margin
				# On the following LibGDX Texture Packer atlas entry:
				#	split: 1, 2, 4, 3
				# the numbers represent the following:
				# 	1 represents the nine patch rect margin from the left
				# 	2 represents the nine patch rect margin from the right
				# 	4 represents the nine patch rect margin from the top
				# 	3 represents the nine patch rect margin from the bottom
				was_split_key_seen = true
				var libgdx_nine_patch_rect_patch_margin_array : Array = libgdx_atlas_texture_entry_value.split(",")
				var libgdx_patch_margin_left : int = int(libgdx_nine_patch_rect_patch_margin_array[0])
				var libgdx_patch_margin_right : int = int(libgdx_nine_patch_rect_patch_margin_array[1])
				var libgdx_patch_margin_top : int = int(libgdx_nine_patch_rect_patch_margin_array[2])
				var libgdx_patch_margin_bottom : int = int(libgdx_nine_patch_rect_patch_margin_array[3])
				libgdx_nine_patch_rect_patch_margin_rect2 = Rect2(libgdx_patch_margin_left, libgdx_patch_margin_right, libgdx_patch_margin_top, libgdx_patch_margin_bottom)

			"pad":
				# Process LibGDX NinePatchRect Content Margin
				# On the following LibGDX Texture Packer atlas entry:
				#	pad: 1, 2, 4, 3
				# the numbers represent the following:
				# 	1 represents the content margin from the left
				# 	2 represents the content margin from the right
				# 	4 represents the content margin from the top
				# 	3 represents the content margin from the bottom
				was_pad_key_seen = true
				var libgdx_nine_patch_content_margin_array : Array = libgdx_atlas_texture_entry_value.split(",")
				var libgdx_rect_region_left : int = int(libgdx_nine_patch_content_margin_array[0])
				var libgdx_rect_region_right : int = int(libgdx_nine_patch_content_margin_array[1])
				var libgdx_rect_region_top : int = int(libgdx_nine_patch_content_margin_array[2])
				var libgdx_rect_region_bottom : int = int(libgdx_nine_patch_content_margin_array[3])
				libgdx_nine_patch_rect_rect_region_rect2 = Rect2(libgdx_rect_region_left, libgdx_rect_region_right, libgdx_rect_region_top, libgdx_rect_region_bottom)

			"offsets":
				# The "offsets" entry in the new format really includes two
				# pieces of information.
				#	1) the actual position offset of the image, and
				#	2) the sprite original size.
				was_offsets_key_seen = true

				# LibGDX AtlasTexture Offset
				# NOTE The coordinates of the sprite offset based from the original image are measured as follows:
				# x: from left to right
				# y: from bottom to top
				# this differs from the sprite position in atlas in which the y coordinate is measured from top to bottom
				var libgdx_atlas_texture_offsets_array : Array = libgdx_atlas_texture_entry_value.split(",")
				var libgdx_atlas_texture_offset_x_string : String = libgdx_atlas_texture_offsets_array[0]
				var libgdx_atlas_texture_offset_y_string : String = libgdx_atlas_texture_offsets_array[1]
				libgdx_atlas_texture_offset_vector = Vector2(int(libgdx_atlas_texture_offset_x_string), int(libgdx_atlas_texture_offset_y_string))

				# LibGDX AtlasTexture Original Size
				var libgdx_atlas_texture_original_size_x_string : String = libgdx_atlas_texture_offsets_array[2]
				var libgdx_atlas_texture_original_size_y_string : String = libgdx_atlas_texture_offsets_array[3]
				libgdx_atlas_texture_original_size_vector = Vector2(int(libgdx_atlas_texture_original_size_x_string), int(libgdx_atlas_texture_original_size_y_string))

			"rotate":
				# NOTE: It's impossible to tell Godot to rotate the AtlasTextures -- need to bubble up an error if this happens.
				push_error("Found rotated texture in LibGDX TexturePacker Atlas file at \"%s\".\nGodot does not support rotated AtlasTexture resources.\nPlease disable sprites rotation in your LibGDX TexturePacker project and repack the atlas." % [ p_source_file ])
				r_packed_texture_dictionary["error"] = ERR_PARSE_ERROR
				return current_line_to_read - p_starting_at_line

			_:
				push_error("Found unknown LibGDX TexturePacker Atlas texture entry key : \"%s\" in file \"%s\" at line %d" % [ libgdx_atlas_texture_entry_key, p_source_file, current_line_to_read - 1 ])
				r_packed_texture_dictionary["error"] = ERR_PARSE_ERROR
				return current_line_to_read - p_starting_at_line

	if not was_offsets_key_seen:
		# Need to set the original size vector for the atlas texture which is implicitly given in the new LibGDX TexturePacker Atlas format
		libgdx_atlas_texture_original_size_vector = libgdx_atlas_texture_size_vector

	# Construct LibGDX atlas texture entry dictionary found in the atlas --
	# this is all the information that's required to construct a Godot
	# AtlasTexture resource.
	var atlas_texture_entry_dictionary : Dictionary = {
			"basename" : libgdx_atlas_texture_basename,
			"rotate" : libgdx_atlas_texture_rotate,
			"xy" : libgdx_atlas_texture_position_vector,
			"size" : libgdx_atlas_texture_size_vector,
			"orig" : libgdx_atlas_texture_original_size_vector,
			"offset" : libgdx_atlas_texture_offset_vector,
			"index" : libgdx_atlas_texture_index_string,
			}


	# Include the Godot NinePatchRect data if any was defined for this AtlasTexture
	if was_pad_key_seen or was_split_key_seen:
		if was_split_key_seen and was_pad_key_seen:
			atlas_texture_entry_dictionary["split"] = libgdx_nine_patch_rect_patch_margin_rect2
			atlas_texture_entry_dictionary["pad"] = libgdx_nine_patch_rect_rect_region_rect2
		else:
			var which_key_was_seen : String = ""
			if was_split_key_seen:
				which_key_was_seen = "split"
			else:
				which_key_was_seen = "pad"
			var error_message : String = "Malformed LibGDX TexturePacker Atlas\n"
			error_message += "Expected to see both \"split\" and \"pad\" entries defined in: %s\n" % [ p_source_file ]
			error_message += "But only saw the \"%s\" key at around line %d" % [ which_key_was_seen, current_line_to_read - 1]
			push_error(error_message)
			r_packed_texture_dictionary["error"] = ERR_PARSE_ERROR
			return current_line_to_read - p_starting_at_line

	# Debug
	#print("LibGDX TexturePacker AtlasTexture Dictionary: ", atlas_texture_entry_dictionary)

	# Push the atlas_texture_entry_dictionary into r_packed_texture_dictionary
	r_packed_texture_dictionary["atlas_textures"].push_back(atlas_texture_entry_dictionary)

	# Debug
	#print(atlas_texture_entry_dictionary)
	return current_line_to_read - p_starting_at_line


# Returns a Godot Dictionary that represents a parsed LibGDX Texture Packer Atlas wrapped within a parse result dictionary.
func parse(p_source_file : String) -> Dictionary:
	# LibGDXTexturePackerAtlasParseResult mimics JSONParseResult but through a Dictionary object instead
	# NOTE: We don't use a class_name for LibGDXTexturePackerAtlasParseResult class just to avoid declaring global classes unnecessarily since it is known to slow down the Editor on complex projects.
	var libgdx_texture_packer_atlas_parse_result : Dictionary = {
			"error" : OK,
			"result" : {},
			}

	# Open the LibGDX Texture Packer Atlas file
	var file_handle : File = File.new()
	var error : int = file_handle.open(p_source_file, File.READ)
	if error != OK:
		# This should not happen
		push_error("Could not open file at: " + p_source_file)
		libgdx_texture_packer_atlas_parse_result["error"] = error
		return libgdx_texture_packer_atlas_parse_result

	# Slurp the LibGDX Texture Packer Atlas file into memory.
	var libgdx_atlas_pool_string_array : PoolStringArray = file_handle.get_as_text().split("\n")
	libgdx_atlas_pool_string_array.resize(libgdx_atlas_pool_string_array.size() - 1) # the last entry is an empty string

	# Close the LibGDX Texture Packer Atlas file handle -- it's not needed anymore
	file_handle.close()

	# Remove the whitespace out of all the lines. Even if the
	# new format gets pretty-printed we'll be able to process it:
	for index in range(0, libgdx_atlas_pool_string_array.size()):
		libgdx_atlas_pool_string_array[index] = m_whitespace_regex.sub(libgdx_atlas_pool_string_array[index], "", true)

	# Debug
	#print(libgdx_atlas_pool_string_array)

	# Detect whether the LibGDX Texture Packer Atlas file is using the legacy format or the new format:
	# NOTE: In the legacy format the data structures are more granular.
	# The new format is more concise and compact. Both formats contain the
	# same information, just in different places. Since the legacy format
	# seems easier to read in my opinion, the
	# parsed_libgdx_texture_packer_atlas_dictionary will contain entries
	# using the legacy format regardless of the LibGDX Texture Packer Atlas format.
	# NOTE: Since we are going to parse the LibGDX Texture Packer Atlas line by line, we need
	# to keep track of the line index we are reading manually
	var line_index : int = 0
	if libgdx_atlas_pool_string_array[0] == "":
		line_index += 1
		m_detected_atlas_format = m_libgdx_atlas_formats.LEGACY
	else:
		m_detected_atlas_format = m_libgdx_atlas_formats.NEW

	# From now on, we'll have to keep track of the parsed LibGDX Texture Packer Atlas
	var parsed_libgdx_texture_packer_atlas_dictionary : Dictionary = {
			"path" : p_source_file,
			"packed_textures" : [],
			}

	# NOTE: The LibGDX Texture Packer Atlas format supports multi-page texture atlases within the GDX Texture Packer Atlas file (i.e. the .atlas file).
	# Here's a sample of the legacy format which includes multi-page atlases:
	#
	#	atlas1.png
	#	size: 2048, 2048
	#	format: RGBA8888
	#	filter: Nearest, Nearest
	#	repeat: none
	#	atlas_texture_1_with_defined_nine_patch
	#	  rotate: false
	#	  xy: 974, 1592
	#	  size: 484, 316
	#	  split: 0, 0, 0, 0
	#	  pad: 0, 0, 0, 0
	#	  orig: 484, 316
	#	  offset: 0, 0
	#	  index: -1
	#
	#	atlas2.png
	#	size: 2048, 1024
	#	format: RGBA8888
	#	filter: Nearest, Nearest
	#	repeat: none
	#	atlas_texture_1
	#	  rotate: false
	#	  xy: 974, 638
	#	  size: 484, 316
	#	  orig: 484, 316
	#	  offset: 0, 0
	#	  index: -1
	#
	# This means that once we parse that file, we'll end up with the following Dictionary structure that represents the GDX Texture Packer Atlas file:
	# var parsed_libgdx_texture_packer_atlas_dictionary : Dictionary = {
	#			"gdx_atlas" : source_atlas_res_path,
	#			"packed_textures" : [
	#					{
	#						"filename" : "atlas1.png",
	#						"settings" : {
	#								size: 2048, 2048,
	#								format: RGBA8888,
	#								filter: Nearest, Nearest,
	#								repeat: none,
	#							},
	#						"atlas_textures" : [
	#									{
	#										"atlas_texture" : "atlas_texture_1",
	#										"rotate" : false,
	#										"xy" : Vector2,
	#										"size" : Vector2,
	#										"split" : Rect2,
	#										"pad" : Rect2,
	#										"orig" : Vector2,
	#										"offset" : Vector2,
	#										"index" : Vector2,
	#									},
	#									{
	#										"atlas_texture" : "atlas_texture_2",
	#										"rotate" : false,
	#										"xy" : Vector2,
	#										"size" : Vector2,
	#										"orig" : Vector2,
	#										"offset" : Vector2,
	#										"index" : Vector2,
	#									}
	#							]
	#					},
	#					{
	#						"filename" : "atlas1.png",
	#						"settings" : {
	#								size: 2048, 2048,
	#								format: RGBA8888,
	#								filter: Nearest, Nearest,
	#								repeat: none,
	#							},
	#						"atlas_textures" : [
	#									{
	#										"atlas_texture" : "atlas_texture_1",
	#										"rotate" : false,
	#										"xy" : Vector2,
	#										"size" : Vector2,
	#										"orig" : Vector2,
	#										"offset" : Vector2,
	#										"index" : Vector2,
	#									},
	#									{
	#										"atlas_texture" : "atlas_texture_2",
	#										"rotate" : false,
	#										"xy" : Vector2,
	#										"size" : Vector2,
	#										"orig" : Vector2,
	#										"offset" : Vector2,
	#										"index" : Vector2,
	#									}
	#							]
	#					}
	#				]
	#			}

	# Let's parse the LibGDX Texture Packer Atlas line by line.
	# NOTE: Need to track packed texture dictionaries outside of the scope
	# below because we will need to update this dictionary across the whole
	# loop once we stumble upon a new packed texture page we need to
	# process
	var current_libgdx_packed_texture_dictionary : Dictionary = {
		"atlas_textures" : [],
		"settings" : {},
		}

	while line_index < libgdx_atlas_pool_string_array.size():
		if m_reader_state == m_atlas_reader_states.READING_TEXTURE_HEADER:
			# Read the current texture name:
			current_libgdx_packed_texture_dictionary["filename"] = libgdx_atlas_pool_string_array[line_index]
			line_index += 1

			# Make sure we able to read the header:
			var lines_read : int = __read_texture_metadata(libgdx_atlas_pool_string_array, line_index, current_libgdx_packed_texture_dictionary)
			line_index += lines_read

			# Debug
			#print(current_libgdx_packed_texture_dictionary)

			# Update reader state
			m_reader_state = m_atlas_reader_states.READING_ATLAS_TEXTURES
		if m_reader_state == m_atlas_reader_states.READING_ATLAS_TEXTURES:
			# Debug
			#print("Reading atlas textures for packed texture: " + libgdx_atlas_pool_string_array[line_index])

			# Store all the atlas entries in an array for post processing later
			while line_index < (libgdx_atlas_pool_string_array.size() - 1) and libgdx_atlas_pool_string_array[line_index] != "":
				# Extract atlas entry
				var lines_read : int = __get_next_atlas_texture_entry(libgdx_atlas_pool_string_array, p_source_file, line_index, current_libgdx_packed_texture_dictionary)

				# Check if there were any errors getting the next texture entry.
				if "error" in current_libgdx_packed_texture_dictionary: # something bad happened
					# Bubble up the error to the parsed_libgdx_texture_packer_atlas_dictionary
					parsed_libgdx_texture_packer_atlas_dictionary["error"] = current_libgdx_packed_texture_dictionary["error"]
					# Remove the key from the packed_texture_dictionary
					var _success : int = current_libgdx_packed_texture_dictionary.erase("error")
					# Push the error up the stack
					return parsed_libgdx_texture_packer_atlas_dictionary

				# Update the line_index with the amount of lines read
				line_index += lines_read

			if line_index == libgdx_atlas_pool_string_array.size():
				# We are done. This was a successful read

				# Save the current packed texture dictionary -- we are done reading it
				parsed_libgdx_texture_packer_atlas_dictionary["packed_textures"].push_back(current_libgdx_packed_texture_dictionary)

				# And exit out of the loop
				break

			# If we stumble upon a new line while reading the current atlas textures, this means we are about to start reading data about a new LibGDX packed texture -- including its settings and its atlas textures.
			# Toggle the reader state back to READING_TEXTURE_HEADER to process the data accordingly
			if libgdx_atlas_pool_string_array[line_index] == "":
				# Save the current packed texture dictionary -- we are done reading it
				parsed_libgdx_texture_packer_atlas_dictionary["packed_textures"].push_back(current_libgdx_packed_texture_dictionary)

				# Create a new dictionary and attach it to the current_libgdx_packed_texture_dictionary since we are about to read a new LibGDX Texture Packer Atlas page
				current_libgdx_packed_texture_dictionary = {
					"atlas_textures" : [],
					"settings" : {},
					}

				# Update the current line index -- we've already processed it
				line_index += 1

				# And finally update the current reader state so we start processing the new header properly.
				m_reader_state = m_atlas_reader_states.READING_TEXTURE_HEADER

	# Debug
	#print("Parsed LibGDX Texture Packer Atlas dictionary: ", parsed_libgdx_texture_packer_atlas_dictionary)

	# Attach the parsed_libgdx_texture_packer_atlas_dictionary to the parse result:
	libgdx_texture_packer_atlas_parse_result["result"] = parsed_libgdx_texture_packer_atlas_dictionary

	# And we are done
	return libgdx_texture_packer_atlas_parse_result
