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

extends Reference

enum m_atlas_reader_states { READING_HEADER, PROCESSING_ENTRIES }
var m_reader_state : int  = m_atlas_reader_states.READING_HEADER
enum m_libgdx_atlas_formats { LEGACY, NEW }
var m_detected_atlas_format : int = m_libgdx_atlas_formats.LEGACY
var m_file_handle : File = File.new()
var m_texture_filename : String
var m_atlas_path : String
var m_whitespace_regex : RegEx = RegEx.new()


# For opening atlas file
func open(p_atlas_path : String) -> int:
	if m_file_handle.is_open():
		m_file_handle.close()
	m_atlas_path = p_atlas_path
	m_whitespace_regex.compile("\\s")
	var open_error : int = m_file_handle.open(p_atlas_path, File.READ)
	return open_error


# For closing the atlas file
func close() -> void:
	m_file_handle.close()


# For extracting the image the atlas refers to
func get_atlas_texture_filename() -> String:
	assert(m_reader_state != m_atlas_reader_states.READING_HEADER, "Unable to read next atlas texture. Call \"read_atlas_header\" first!")
	return m_texture_filename


# Internal function for reading the atlas header
func read_atlas_header() -> int:
	# If the header has been read already, no need to continue
	if m_reader_state == m_atlas_reader_states.PROCESSING_ENTRIES:
		push_warning("LibGDX Atlas header already read. Ignoring...")
		return OK

	# The header hasn't been read at this point. Let's do so.
	if m_file_handle.is_open() and m_reader_state == m_atlas_reader_states.READING_HEADER:
		# Detect the LibGDx Atlas format -- whether it's Legacy or New

		# NOTE: In the legacy format the data structures are more granular.
		# The new format is more concise and compact. Both formats contain the
		# same information, just in different places.

		# By just reading first line of the atlas we can know which format it belongs to.
		var first_line : String = m_file_handle.get_line()
		m_file_handle.seek(0)
		if first_line == "":
			m_detected_atlas_format = m_libgdx_atlas_formats.LEGACY
		else:
			m_detected_atlas_format = m_libgdx_atlas_formats.NEW

		# Read the header:
		if m_detected_atlas_format == m_libgdx_atlas_formats.LEGACY:
			var error : int = __read_legacy_atlas_header()
			if error != OK:
				return error
		elif m_detected_atlas_format == m_libgdx_atlas_formats.NEW:
			var error : int = __read_new_atlas_header()
			if error != OK:
				return error
		else:
			push_error("Unknown atlas format! This should not happen!")
			return ERR_PARSE_ERROR

		# Update reader state
		m_reader_state = m_atlas_reader_states.PROCESSING_ENTRIES
		return OK
	else:
		if not m_file_handle.is_open():
			push_warning("Unable to read header -- atlas file has not been opened for reading!")
			return ERR_PARSE_ERROR
		else:
			push_warning("Unknown reader state! This should not happen!")
			return ERR_PARSE_ERROR


# Returns an array with two entries:
# The first one is whether the entry extraction was successful. This is so we
# can bubble up any errors up to the Editor so it's aware.
# If the entry read was successful, the second entry in the array is a
# dictionary containing the atlas_texture entry.
func get_next_atlas_texture_entry() -> Dictionary:
	# Most of the header data can eb skippes
	assert(m_reader_state != m_atlas_reader_states.READING_HEADER, "Unable to read next atlas texture. Call \"read_atlas_header\" first!")

	# Get the atlas texture entry
	if m_detected_atlas_format == m_libgdx_atlas_formats.LEGACY:
		return __extract_sprite_entry_in_legacy_atlas_format()
	elif m_detected_atlas_format == m_libgdx_atlas_formats.NEW:
		return __extract_sprite_entry_in_new_atlas_format()
	else:
		push_error("Unknown LibGDX Atlas format! This should not happen!")
		return __generate_malformed_atlas_dictionary()


func __read_legacy_atlas_header() -> int:
	for header_line_index in range(0, 6):
		# At any point during the the header read. If we reach eof, it would be a malformed header.
		if m_file_handle.eof_reached():
			var sample_legacy_header : String = "\n"
			sample_legacy_header += "texture_filename.png\n"
			sample_legacy_header += "size: 128, 256\n"
			sample_legacy_header += "format: RGBA8888\n"
			sample_legacy_header += "filter: Nearest, Nearest\n"
			sample_legacy_header += "repeat: none\n"
			push_error("Malformed atlas header! Check the file is not corrupted -- the header should have six lines (including a blank line) and look similar to:\n %s" % sample_legacy_header)
			return ERR_PARSE_ERROR

		if header_line_index == 1:
			m_texture_filename = m_file_handle.get_line()
			var texture_path = m_atlas_path.get_base_dir().plus_file(m_texture_filename)
			if not m_file_handle.file_exists(texture_path):
				push_error("Unable to find atlas texture at: " + texture_path + "\nCannot continue importing LibGDX Atlas")
				return ERR_PARSE_ERROR
		else:
			var _discard : String = m_file_handle.get_line()
	return OK


func __read_new_atlas_header() -> int:
	for header_line_index in range(0, 3):
		# At any point during the the header read. If we reach eof, it would be a malformed header.
		if m_file_handle.eof_reached():
			var sample_new_header : String = "texture_filename.png\n"
			sample_new_header += "size:128,256\n"
			sample_new_header += "repeat:none\n"
			push_error("Malformed atlas header! Check the file is not corrupted -- the header should have six lines (including a blank line) and look similar to:\n %s" % sample_new_header)
			return ERR_PARSE_ERROR

		if header_line_index == 0:
			m_texture_filename = m_file_handle.get_line()
			var texture_path = m_atlas_path.get_base_dir().plus_file(m_texture_filename)
			if not m_file_handle.file_exists(texture_path):
				push_error("Unable to find atlas texture at: " + texture_path + "\nCannot continue importing LibGDX Atlas")
				return ERR_PARSE_ERROR
		else:
			var _discard : String = m_file_handle.get_line()
	return OK


# Helper function to return successful atlas read status
func __generate_eof_dictionary() -> Dictionary:
		var eof_reached : bool = true
		var extraction_success : bool = true
		var libgdx_atlas_entry : Dictionary = {
				"success" : extraction_success,
				"eof_reached" : eof_reached
				}
		return libgdx_atlas_entry


# Helper function to return successful atlas entry read status
func __generate_successful_atlas_entry_read_dictionary() -> Dictionary:
		var eof_reached : bool = false
		var extraction_success : bool = true
		var libgdx_atlas_entry : Dictionary = {
				"success" : extraction_success,
				"eof_reached" : eof_reached
				}
		return libgdx_atlas_entry


# Helper function to report issues to the Edior
func __generate_malformed_atlas_dictionary() -> Dictionary:
	# If this function is called, the GDX atlas texture is a malformed file.
	# Inform the editor with the following dictionary to bubble up this issue:
	var eof_reached : bool = true
	var extraction_success : bool = false
	var libgdx_atlas_entry : Dictionary = {
			"success" : extraction_success,
			"eof_reached" : eof_reached
			}
	return libgdx_atlas_entry


func __extract_sprite_entry_in_legacy_atlas_format() -> Dictionary:
	# At this point the atlas HEADER should have been read.
	assert(m_reader_state == m_atlas_reader_states.PROCESSING_ENTRIES)

	# NOTE: The GDX TexturePacker GUI tool at: https://github.com/crashinvaders/gdx-texture-packer-gui
	# Outputs each atlas sprite entry as follows, in the same order:
	#	sprite_basename
	#	  rotate: false
	#	  xy: 2, 2
	#	  size: 27, 31
	#	  orig: 32, 32
	#	  offset: 3, 1
	#	  index: 3

	# Grab the sprite basename -- there's a chance this could return empty
	# because we have reached the end of file:
	var sprite_basename : String = m_file_handle.get_line()

	# Check if we have reached the end of file -- if so, this was a successful read of the atlas.
	if m_file_handle.eof_reached():
		return __generate_eof_dictionary()

	# In-scope variables to store the values we are going to return
	var rotate : bool
	var sprite_position_vector : Vector2
	var sprite_size_vector : Vector2
	var sprite_original_size_vector : Vector2
	var sprite_offset_vector : Vector2
	var sprite_index_string : String
	var extraction_success : bool = true
	var eof_reached : bool = false

	# Initialized expected atlas entry error message format
	var expected_atlas_entry_error_message_format : String = "Expected \"%s\" entry. Instead got:\n"
	expected_atlas_entry_error_message_format += "\t%s\n\n"
	expected_atlas_entry_error_message_format += "Make sure the entries in the atlas are in the following format where the keys are in the same order:\n"
	expected_atlas_entry_error_message_format += "sprite_basename\n"
	expected_atlas_entry_error_message_format += "  rotate: false\n"
	expected_atlas_entry_error_message_format += "  xy: 2, 2\n"
	expected_atlas_entry_error_message_format += "  size: 27, 31\n"
	expected_atlas_entry_error_message_format += "  orig: 32, 32\n"
	expected_atlas_entry_error_message_format += "  offset: 3, 1\n"
	expected_atlas_entry_error_message_format += "  index: 3\n"


	# Start looping over the key-value pairs of the atlas
	for atlas_entry_index in range(0,6):
		# Grab atlas key-value pair
		var atlas_entry_key_value : String = m_file_handle.get_line()

		# Check if we have reached the end of file -- the file is malformed at this
		# stage if we reach eof.
		if m_file_handle.eof_reached():
			return __generate_malformed_atlas_dictionary()

		# Setup expected atlas entry
		var expected_atlas_entry_key : String
		match atlas_entry_index:
			0:
				expected_atlas_entry_key = "rotate"
			1:
				expected_atlas_entry_key = "xy"
			2:
				expected_atlas_entry_key = "size"
			3:
				expected_atlas_entry_key = "orig"
			4:
				expected_atlas_entry_key = "offset"
			5:
				expected_atlas_entry_key = "index"

		# Do a sanity check over the expected entry and what we actually read from the file
		if !(expected_atlas_entry_key in atlas_entry_key_value):
			push_error(expected_atlas_entry_error_message_format % [ expected_atlas_entry_key, atlas_entry_key_value ])
			return __generate_malformed_atlas_dictionary()

		# Process atlas entry
		match atlas_entry_index:
			0:
				# Process Rotate entry
				if expected_atlas_entry_key in atlas_entry_key_value:
					var rotate_string : String = atlas_entry_key_value.split(": ")[1]
					if "false" in rotate_string:
						rotate = false
					else:
						# NOTE: It's impossible to tell Godot to rotate the sprites.
						push_error("Godot does not support rotated sprites in atlases. Please fix your LibGDX TexturePacker project to avoid rotating sprites.")
						return __generate_malformed_atlas_dictionary()

			1:
				# Process Sprite Position
				# NOTE The coordinates of sprite position on atlas are measured as follows:
				# x: from left to right
				# y: from top to bottom
				# this differs from the sprite offset in which the y coordinate is measured from bottom to top
				if expected_atlas_entry_key in atlas_entry_key_value:
					var sprite_position_on_atlas_array : Array = atlas_entry_key_value.split(": ")[1].split(", ")
					var sprite_position_x_string : String = sprite_position_on_atlas_array[0]
					var sprite_position_y_string : String = sprite_position_on_atlas_array[1]
					sprite_position_vector = Vector2(int(sprite_position_x_string), int(sprite_position_y_string))

			2:
				# Process Sprite Size
				# NOTE The coordinates of sprite position on atlas are measured as follows:
				# x: from left to right
				# y: from top to bottom
				# this differs from the sprite offset in which the y coordinate is measured from bottom to top
				# Also, this sprite size may differ from the original since
				# transparent borders may be trimmed to save space.
				if expected_atlas_entry_key in atlas_entry_key_value:
					var sprite_size_array : Array = atlas_entry_key_value.split(": ")[1].split(", ")
					var sprite_size_x_string : String = sprite_size_array[0]
					var sprite_size_y_string : String = sprite_size_array[1]
					sprite_size_vector = Vector2(int(sprite_size_x_string), int(sprite_size_y_string))

			3:
				# Sprite Original Size
				if expected_atlas_entry_key in atlas_entry_key_value:
					var sprite_original_size_array : Array = atlas_entry_key_value.split(": ")[1].split(", ")
					var sprite_original_size_x_string : String = sprite_original_size_array[0]
					var sprite_original_size_y_string : String = sprite_original_size_array[1]
					sprite_original_size_vector = Vector2(int(sprite_original_size_x_string), int(sprite_original_size_y_string))

			4:
				# Sprite Offset
				# NOTE The coordinates of the sprite offset based from the original image are measured as follows:
				# x: from left to right
				# y: from bottom to top
				# this differs from the sprite position in atlas in which the y coordinate is measured from top to bottom
				if expected_atlas_entry_key in atlas_entry_key_value:
					var sprite_offset_array : Array = atlas_entry_key_value.split(": ")[1].split(", ")
					var sprite_offset_x_string : String = sprite_offset_array[0]
					var sprite_offset_y_string : String = sprite_offset_array[1]
					sprite_offset_vector = Vector2(int(sprite_offset_x_string), int(sprite_offset_y_string))

			5:
				# Sprite Index
				# NOTE: When a set of sprite filenames such as "run_0.png",
				# "run_1.png", "run_2.png" are included in an atlas, the sprite frame
				# numbers 0, 1, and 2 respectively ends up as the index entry in the
				# atlas file.
				if expected_atlas_entry_key in atlas_entry_key_value:
					sprite_index_string = atlas_entry_key_value.split(": ")[1]

	# Construct sprite entry found in the atlas -- this is all the information
	# that's required to construct a TextureAtlas resource.
	# The only two extra entries in the dictionary are "success" which
	# determines if the sprite entry read was successful, and "eof_reached"
	# that determines whether we are done reading the atlas file but this value
	# should always be false at this point.
	var sprite_entry_dictionary : Dictionary = {
			"basename" : sprite_basename,
			"rotate" : rotate,
			"xy" : sprite_position_vector,
			"size" : sprite_size_vector,
			"orig" : sprite_original_size_vector,
			"offset" : sprite_offset_vector,
			"index" : sprite_index_string,
			"success" : extraction_success,
			"eof_reached" : eof_reached,
			}

	# Debug
	# print(sprite_entry_dictionary)
	return sprite_entry_dictionary


func __extract_sprite_entry_in_new_atlas_format() -> Dictionary:
	# At this point the atlas HEADER should have been read.
	assert(m_reader_state == m_atlas_reader_states.PROCESSING_ENTRIES)

	# NOTE: The GDX TexturePacker GUI tool at: https://github.com/crashinvaders/gdx-texture-packer-gui
	# Outputs each atlas sprite entry as follows, in the same order:
	#	sprite_basename
	#		index: 3
	#		bounds: 2, 2, 27, 31
	#		offsets: 3, 1, 32, 32
	#		rotate: true

	# The pretty-print is the version shown above. The non-pretty-print version is the exact same except all whitespace is eliminated on each row.


	# Grab the sprite basename -- there's a chance this could return empty
	# because we have reached the end of file:
	var sprite_basename : String = m_file_handle.get_line()

	# Check if we have reached the end of file -- if so, this was a successful read of the atlas.
	if m_file_handle.eof_reached():
		return __generate_eof_dictionary()

	# In-scope variables to store the values we are going to return
	var rotate : bool
	var sprite_position_vector : Vector2
	var sprite_size_vector : Vector2
	var sprite_original_size_vector : Vector2
	var sprite_offset_vector : Vector2
	var sprite_index_string : String
	var extraction_success : bool = true
	var eof_reached : bool = false

	# Initialized expected atlas entry error message format
	var expected_atlas_entry_error_message_format : String = "Expected \"%s\" entry. Instead got:\n"
	expected_atlas_entry_error_message_format += "\t%s\n\n"
	expected_atlas_entry_error_message_format += "Make sure the entries in the atlas are in the following format where the keys are in the same order:\n"
	expected_atlas_entry_error_message_format += "\tsprite_basename\n"
	expected_atlas_entry_error_message_format += "\t\tindex: 3\n"
	expected_atlas_entry_error_message_format += "\t\tbounds: 2, 2, 27, 31\n"
	expected_atlas_entry_error_message_format += "\t\toffsets: 3, 1, 32, 32\n"
	expected_atlas_entry_error_message_format += "\t\trotate: true\n"

	# Start looping over the key-value pairs of the atlas
	for atlas_entry_index in range(0,3):
		# Grab atlas key-value pair
		var atlas_entry_key_value : String = m_file_handle.get_line()
		# Remove the whitespace from the atlas entry -- this way even if the
		# new format gets pretty-printed, we'll be able to process it:
		atlas_entry_key_value = m_whitespace_regex.sub(atlas_entry_key_value, "", true)

		# Check if we have reached the end of file -- the file is malformed at this
		# stage if we reach eof.
		if m_file_handle.eof_reached():
			return __generate_malformed_atlas_dictionary()

		# Setup expected atlas entry
		var expected_atlas_entry_key : String
		match atlas_entry_index:
			0:
				expected_atlas_entry_key = "index"
			1:
				expected_atlas_entry_key = "bounds"
			2:
				expected_atlas_entry_key = "offsets"

		# Do a sanity check over the expected entry and what we actually read from the file
		if !(expected_atlas_entry_key in atlas_entry_key_value):
			push_error(expected_atlas_entry_error_message_format % [ expected_atlas_entry_key, atlas_entry_key_value ])
			return __generate_malformed_atlas_dictionary()


		# Process atlas entry

		# Debug
		#print(atlas_entry_key_value)
		match atlas_entry_index:
			0:
				# Sprite Index
				# NOTE: When a set of sprite filenames such as "run_0.png",
				# "run_1.png", "run_2.png" are included in an atlas, the sprite frame
				# numbers 0, 1, and 2 respectively ends up as the index entry in the
				# atlas file.
				if expected_atlas_entry_key in atlas_entry_key_value:
					sprite_index_string = atlas_entry_key_value.split(":")[1]

			1:
				# The bounds include the Sprite Position and the Sprite Size
				if expected_atlas_entry_key in atlas_entry_key_value:
					# Sprite Position
					# NOTE The coordinates of sprite position on atlas are measured as follows:
					# x: from left to right
					# y: from top to bottom
					# this differs from the sprite offset in which the y coordinate is measured from bottom to top
					var sprite_bounds_array : Array = atlas_entry_key_value.split(":")[1].split(",")
					var sprite_position_x_string : String = sprite_bounds_array[0]
					var sprite_position_y_string : String = sprite_bounds_array[1]
					sprite_position_vector = Vector2(int(sprite_position_x_string), int(sprite_position_y_string))

					# Sprite Size
					# NOTE The coordinates of sprite position on atlas are measured as follows:
					# x: from left to right
					# y: from top to bottom
					# this differs from the sprite offset in which the y coordinate is measured from bottom to top
					# Also, this sprite size may differ from the original since
					# transparent borders may be trimmed to save space.
					var sprite_size_x_string : String = sprite_bounds_array[2]
					var sprite_size_y_string : String = sprite_bounds_array[3]
					sprite_size_vector = Vector2(int(sprite_size_x_string), int(sprite_size_y_string))

			2:
				# The "offsets" entry in the new format really includes two
				# pieces of information.
				#	1) the actual position offset of the image, and
				#	2) the sprite original size.
				if expected_atlas_entry_key in atlas_entry_key_value:
					# Sprite Offset
					# NOTE The coordinates of the sprite offset based from the original image are measured as follows:
					# x: from left to right
					# y: from bottom to top
					# this differs from the sprite position in atlas in which the y coordinate is measured from top to bottom
					var sprite_offsets_array : Array = atlas_entry_key_value.split(":")[1].split(",")
					var sprite_offset_x_string : String = sprite_offsets_array[0]
					var sprite_offset_y_string : String = sprite_offsets_array[1]
					sprite_offset_vector = Vector2(int(sprite_offset_x_string), int(sprite_offset_y_string))

					# Sprite Original Size
					var sprite_original_size_x_string : String = sprite_offsets_array[2]
					var sprite_original_size_y_string : String = sprite_offsets_array[3]
					sprite_original_size_vector = Vector2(int(sprite_original_size_x_string), int(sprite_original_size_y_string))


	# Need to peek at the next line to check if the rotate entry is there.
	if not m_file_handle.eof_reached():
		var current_file_handle_position : int = m_file_handle.get_position()
		var line_peeked : String = m_file_handle.get_line()
		m_file_handle.seek(current_file_handle_position)
		if "rotate" in line_peeked:
			# NOTE: It's impossible to tell Godot to rotate the sprites.
			push_error("Godot does not support rotated sprites in atlases. Please fix your LibGDX TexturePacker project to avoid rotating sprites.")
			return __generate_malformed_atlas_dictionary()

	# Construct sprite entry found in the atlas -- this is all the information
	# that's required to construct a TextureAtlas resource.
	# The only two extra entries in the dictionary are "success" which
	# determines if the sprite entry read was successful, and "eof_reached"
	# that determines whether we are done reading the atlas file but this value
	# should always be false at this point.
	# Also, for simplicity, the constructed dictionary is using the legacy LibGDX
	# Atlas key entries, just so that dictionary keys remain consistent between
	# the Legacy and New formats when read through this reader.
	var sprite_entry_dictionary : Dictionary = {
			"basename" : sprite_basename,
			"rotate" : rotate,
			"xy" : sprite_position_vector,
			"size" : sprite_size_vector,
			"orig" : sprite_original_size_vector,
			"offset" : sprite_offset_vector,
			"index" : sprite_index_string,
			"success" : extraction_success,
			"eof_reached" : eof_reached,
			}

	# Debug
	#print(sprite_entry_dictionary)
	return sprite_entry_dictionary
