## A two-stage TOML parser (Tokenizer → Recursive Descent) for Godot 4.4.
##
## Supports the TOML subset used by factory-flowchart data schemas:
## key-value pairs, basic/literal strings, integers, floats, booleans,
## inline arrays, standard tables ([table]), array-of-tables ([[aot]]),
## and line comments.
##
## Usage:
## [codeblock]
## var data := TOMLParser.parse_file("res://data/recipes/steam_reforming.toml")
## var data2 := TOMLParser.parse_string('id = "water"\nname = "Water"')
## [/codeblock]
class_name TOMLParser
extends RefCounted

# ─────────────────────────────────────────────────────────────────────────────
# Token type enum
# ─────────────────────────────────────────────────────────────────────────────

enum TokenType {
	KEY,
	STRING,
	INTEGER,
	FLOAT,
	BOOLEAN,
	EQUALS,
	LBRACKET,
	RBRACKET,
	NEWLINE,
	COMMA,
	DOT,
	EOF,
}


# ─────────────────────────────────────────────────────────────────────────────
# Token data class
# ─────────────────────────────────────────────────────────────────────────────

class Token:
	var type: int  # TokenType enum value
	var value: Variant
	var line: int

	func _init(p_type: int, p_value: Variant, p_line: int) -> void:
		type = p_type
		value = p_value
		line = p_line


# ─────────────────────────────────────────────────────────────────────────────
# Tokenizer — cursor-based character-by-character scanner
# ─────────────────────────────────────────────────────────────────────────────

class Tokenizer:
	var _source: String
	var _pos: int = 0
	var _line: int = 1
	var _length: int = 0
	var _tokens: Array[Token] = []
	var _error: bool = false

	func _init(source: String) -> void:
		_source = source
		_length = source.length()

	## Tokenize the entire source and return the token list.
	func tokenize() -> Array[Token]:
		while _pos < _length:
			if _error:
				return []
			var ch: String = _current()

			# Skip spaces and tabs (NOT newlines)
			if ch == " " or ch == "\t":
				_advance()
				continue

			# Carriage-return: skip (handle \r\n as single newline)
			if ch == "\r":
				_advance()
				if _pos < _length and _current() == "\n":
					_advance()
				_tokens.append(Token.new(TokenType.NEWLINE, "\n", _line))
				_line += 1
				continue

			# Newline
			if ch == "\n":
				_tokens.append(Token.new(TokenType.NEWLINE, "\n", _line))
				_line += 1
				_advance()
				continue

			# Comment — skip to end of line
			if ch == "#":
				_skip_comment()
				continue

			# Single-character tokens
			if ch == "=":
				_tokens.append(Token.new(TokenType.EQUALS, "=", _line))
				_advance()
				continue
			if ch == "[":
				_tokens.append(Token.new(TokenType.LBRACKET, "[", _line))
				_advance()
				continue
			if ch == "]":
				_tokens.append(Token.new(TokenType.RBRACKET, "]", _line))
				_advance()
				continue
			if ch == ",":
				_tokens.append(Token.new(TokenType.COMMA, ",", _line))
				_advance()
				continue
			if ch == ".":
				_tokens.append(Token.new(TokenType.DOT, ".", _line))
				_advance()
				continue

			# Basic string (double-quoted)
			if ch == "\"":
				_read_basic_string()
				continue

			# Literal string (single-quoted)
			if ch == "'":
				_read_literal_string()
				continue

			# Number (digit or sign followed by digit)
			if _is_digit(ch) or ((ch == "+" or ch == "-") and _peek_is_digit()):
				_read_number()
				continue

			# Bare key or boolean/keyword
			if _is_bare_key_char(ch):
				_read_bare_key_or_keyword()
				continue

			# Unknown character
			push_error("TOMLParser: Unexpected character '%s' at line %d" % [ch, _line])
			_error = true
			return []

		_tokens.append(Token.new(TokenType.EOF, "", _line))
		return _tokens

	func has_error() -> bool:
		return _error

	# ── Character helpers ──────────────────────────────────────────────────

	func _current() -> String:
		return _source[_pos]

	func _advance() -> void:
		_pos += 1

	func _peek(offset: int = 1) -> String:
		var idx: int = _pos + offset
		if idx < _length:
			return _source[idx]
		return ""

	func _peek_is_digit() -> bool:
		var nxt: String = _peek()
		return nxt != "" and _is_digit(nxt)

	func _is_digit(ch: String) -> bool:
		var o: int = ch.unicode_at(0)
		return o >= 48 and o <= 57  # '0'..'9'

	func _is_alpha(ch: String) -> bool:
		var o: int = ch.unicode_at(0)
		return (o >= 65 and o <= 90) or (o >= 97 and o <= 122)

	func _is_bare_key_char(ch: String) -> bool:
		return _is_alpha(ch) or _is_digit(ch) or ch == "-" or ch == "_"

	# ── Skippers ───────────────────────────────────────────────────────────

	func _skip_comment() -> void:
		while _pos < _length and _current() != "\n" and _current() != "\r":
			_advance()

	# ── Readers ────────────────────────────────────────────────────────────

	func _read_basic_string() -> void:
		var start_line: int = _line
		_advance()  # skip opening "
		var result: String = ""
		while _pos < _length:
			var ch: String = _current()
			if ch == "\n" or ch == "\r":
				push_error("TOMLParser: Unterminated basic string at line %d" % start_line)
				_error = true
				return
			if ch == "\\":
				_advance()
				if _pos >= _length:
					push_error("TOMLParser: Unterminated escape in string at line %d" % start_line)
					_error = true
					return
				var esc: String = _current()
				match esc:
					"\"": result += "\""
					"\\": result += "\\"
					"n": result += "\n"
					"t": result += "\t"
					"r": result += "\r"
					_:
						push_error("TOMLParser: Unknown escape '\\%s' at line %d" % [esc, _line])
						_error = true
						return
				_advance()
				continue
			if ch == "\"":
				_advance()  # skip closing "
				_tokens.append(Token.new(TokenType.STRING, result, start_line))
				return
			result += ch
			_advance()
		push_error("TOMLParser: Unterminated basic string at line %d" % start_line)
		_error = true

	func _read_literal_string() -> void:
		var start_line: int = _line
		_advance()  # skip opening '
		var result: String = ""
		while _pos < _length:
			var ch: String = _current()
			if ch == "\n" or ch == "\r":
				push_error("TOMLParser: Unterminated literal string at line %d" % start_line)
				_error = true
				return
			if ch == "'":
				_advance()  # skip closing '
				_tokens.append(Token.new(TokenType.STRING, result, start_line))
				return
			result += ch
			_advance()
		push_error("TOMLParser: Unterminated literal string at line %d" % start_line)
		_error = true

	func _read_number() -> void:
		var start: int = _pos
		var start_line: int = _line
		var has_dot: bool = false

		# Optional sign
		if _pos < _length and (_current() == "+" or _current() == "-"):
			_advance()

		# Integer part
		while _pos < _length and _is_digit(_current()):
			_advance()
			# Allow underscores in numbers (TOML spec)
			if _pos < _length and _current() == "_" and _pos + 1 < _length and _is_digit(_peek()):
				_advance()

		# Fractional part
		if _pos < _length and _current() == ".":
			# Make sure the dot is followed by a digit so we don't
			# accidentally consume a dotted-key separator.
			if _pos + 1 < _length and _is_digit(_source[_pos + 1]):
				has_dot = true
				_advance()  # skip '.'
				while _pos < _length and _is_digit(_current()):
					_advance()
					if _pos < _length and _current() == "_" and _pos + 1 < _length and _is_digit(_peek()):
						_advance()

		var raw: String = _source.substr(start, _pos - start).replace("_", "")

		if has_dot:
			_tokens.append(Token.new(TokenType.FLOAT, raw.to_float(), start_line))
		else:
			_tokens.append(Token.new(TokenType.INTEGER, raw.to_int(), start_line))

	func _read_bare_key_or_keyword() -> void:
		var start: int = _pos
		var start_line: int = _line
		while _pos < _length and _is_bare_key_char(_current()):
			_advance()
		var word: String = _source.substr(start, _pos - start)

		if word == "true":
			_tokens.append(Token.new(TokenType.BOOLEAN, true, start_line))
		elif word == "false":
			_tokens.append(Token.new(TokenType.BOOLEAN, false, start_line))
		else:
			_tokens.append(Token.new(TokenType.KEY, word, start_line))


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

## Parse a TOML-formatted string and return the resulting [Dictionary].
## Returns an empty dictionary and pushes an error on parse failure.
static func parse_string(toml_text: String) -> Dictionary:
	var tokenizer := Tokenizer.new(toml_text)
	var tokens: Array[Token] = tokenizer.tokenize()
	if tokenizer.has_error():
		return {}
	var parser := _Parser.new(tokens)
	return parser.parse()


## Parse a TOML file at the given [param file_path] and return the resulting
## [Dictionary]. Returns an empty dictionary and pushes an error on failure.
static func parse_file(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_error("TOMLParser: File not found: %s" % file_path)
		return {}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("TOMLParser: Cannot open file: %s (error %d)" % [file_path, FileAccess.get_open_error()])
		return {}
	var text: String = file.get_as_text()
	return parse_string(text)


# ─────────────────────────────────────────────────────────────────────────────
# Recursive Descent Parser (internal)
# ─────────────────────────────────────────────────────────────────────────────

class _Parser:
	var _tokens: Array[Token]
	var _pos: int = 0
	var _root: Dictionary = {}
	var _current_table: Dictionary = {}
	var _error: bool = false

	func _init(tokens: Array[Token]) -> void:
		_tokens = tokens
		_current_table = _root

	# ── Main entry point ───────────────────────────────────────────────────

	func parse() -> Dictionary:
		_parse_document()
		if _error:
			return {}
		return _root

	# ── Token access helpers ───────────────────────────────────────────────

	func _current() -> Token:
		return _tokens[_pos]

	func _current_type() -> int:
		return _tokens[_pos].type

	func _advance() -> Token:
		var tok: Token = _tokens[_pos]
		if _pos < _tokens.size() - 1:
			_pos += 1
		return tok

	func _expect(type: int) -> Token:
		if _current_type() != type:
			_set_error("Expected token type %d but got %d" % [type, _current_type()])
			return _current()
		return _advance()

	func _skip_newlines() -> void:
		while _current_type() == TokenType.NEWLINE:
			_advance()

	func _set_error(msg: String) -> void:
		if not _error:
			push_error("TOMLParser: %s at line %d" % [msg, _current().line])
			_error = true

	# ── Document ───────────────────────────────────────────────────────────

	func _parse_document() -> void:
		_skip_newlines()
		while _current_type() != TokenType.EOF:
			if _error:
				return

			# Table header: [ or [[
			if _current_type() == TokenType.LBRACKET:
				_parse_table_header()
			# Key-value pair
			elif _current_type() == TokenType.KEY or _current_type() == TokenType.STRING:
				_parse_key_value()
			else:
				_set_error("Unexpected token (type %d, value '%s')" % [_current_type(), str(_current().value)])
				return

			_skip_newlines()

	# ── Table headers ──────────────────────────────────────────────────────

	func _parse_table_header() -> void:
		_advance()  # consume first '['

		var is_array_of_tables: bool = false
		if _current_type() == TokenType.LBRACKET:
			is_array_of_tables = true
			_advance()  # consume second '['

		# Read the dotted key path  e.g.  server.network
		var key_path: Array[String] = _parse_key_path()
		if _error:
			return

		if is_array_of_tables:
			# Expect ]]
			_expect(TokenType.RBRACKET)
			if _error:
				return
			_expect(TokenType.RBRACKET)
			if _error:
				return
		else:
			# Expect ]
			_expect(TokenType.RBRACKET)
			if _error:
				return

		# Navigate / create the target table in _root
		if is_array_of_tables:
			_current_table = _resolve_array_of_tables(key_path)
		else:
			_current_table = _resolve_standard_table(key_path)

	## Read a dotted key path like  a.b.c  and return ["a", "b", "c"].
	func _parse_key_path() -> Array[String]:
		var path: Array[String] = []
		var key: String = _read_key_name()
		if _error:
			return path
		path.append(key)

		while _current_type() == TokenType.DOT:
			_advance()  # skip '.'
			key = _read_key_name()
			if _error:
				return path
			path.append(key)

		return path

	## Read a single key name (bare key or quoted string).
	func _read_key_name() -> String:
		if _current_type() == TokenType.KEY:
			return str(_advance().value)
		if _current_type() == TokenType.STRING:
			return str(_advance().value)
		_set_error("Expected key name but got token type %d" % _current_type())
		return ""

	## Traverse _root to find or create the sub-dictionary for a standard
	## [table] header. Returns the target dictionary for subsequent k/v pairs.
	func _resolve_standard_table(path: Array[String]) -> Dictionary:
		var table: Dictionary = _root
		for i in range(path.size()):
			var key: String = path[i]
			if not table.has(key):
				var new_dict: Dictionary = {}
				table[key] = new_dict
				table = new_dict
			else:
				var existing: Variant = table[key]
				if existing is Dictionary:
					table = existing
				elif existing is Array:
					# Point to the last element in an array-of-tables
					var arr: Array = existing
					if arr.size() > 0 and arr.back() is Dictionary:
						table = arr.back()
					else:
						_set_error("Cannot define table '%s'; key exists as non-dict array" % key)
						return _root
				else:
					_set_error("Cannot define table '%s'; key already exists as %s" % [key, typeof(existing)])
					return _root
		return table

	## Traverse _root to find or create the array-of-tables entry for a
	## [[array_of_tables]] header. Appends a new dictionary and returns it.
	func _resolve_array_of_tables(path: Array[String]) -> Dictionary:
		var table: Dictionary = _root

		# Navigate to the parent (all segments except the last)
		for i in range(path.size() - 1):
			var key: String = path[i]
			if not table.has(key):
				var new_dict: Dictionary = {}
				table[key] = new_dict
				table = new_dict
			else:
				var existing: Variant = table[key]
				if existing is Dictionary:
					table = existing
				elif existing is Array:
					var arr: Array = existing
					if arr.size() > 0 and arr.back() is Dictionary:
						table = arr.back()
					else:
						_set_error("Cannot navigate path '%s' for array-of-tables" % key)
						return _root
				else:
					_set_error("Key '%s' is not a table or array" % key)
					return _root

		# Handle the last segment — must be or become an Array
		var last_key: String = path[path.size() - 1]
		if not table.has(last_key):
			table[last_key] = [] as Array

		var arr_val: Variant = table[last_key]
		if not (arr_val is Array):
			_set_error("Key '%s' already exists and is not an array" % last_key)
			return _root

		var new_entry: Dictionary = {}
		(arr_val as Array).append(new_entry)
		return new_entry

	# ── Key-value pairs ────────────────────────────────────────────────────

	func _parse_key_value() -> void:
		# Read a (possibly dotted) key
		var key_path: Array[String] = _parse_key_path()
		if _error:
			return

		_expect(TokenType.EQUALS)
		if _error:
			return

		var val: Variant = _parse_value()
		if _error:
			return

		# Store the value — support dotted keys (a.b.c = val)
		_store_dotted(key_path, val)

	## Store a value at a dotted key path within _current_table.
	func _store_dotted(path: Array[String], value: Variant) -> void:
		var table: Dictionary = _current_table
		for i in range(path.size() - 1):
			var key: String = path[i]
			if not table.has(key):
				var sub: Dictionary = {}
				table[key] = sub
				table = sub
			elif table[key] is Dictionary:
				table = table[key]
			else:
				_set_error("Key '%s' already exists as a non-table value" % key)
				return
		var final_key: String = path[path.size() - 1]
		if table.has(final_key):
			_set_error("Duplicate key '%s'" % final_key)
			return
		table[final_key] = value

	# ── Value parsing ──────────────────────────────────────────────────────

	func _parse_value() -> Variant:
		match _current_type():
			TokenType.STRING:
				return _advance().value
			TokenType.INTEGER:
				return _advance().value
			TokenType.FLOAT:
				return _advance().value
			TokenType.BOOLEAN:
				return _advance().value
			TokenType.LBRACKET:
				return _parse_array()
			_:
				_set_error("Expected value but got token type %d" % _current_type())
				return null

	# ── Array parsing ──────────────────────────────────────────────────────

	func _parse_array() -> Array:
		_advance()  # consume '['
		var arr: Array = []

		_skip_newlines()

		if _current_type() == TokenType.RBRACKET:
			_advance()
			return arr

		while true:
			if _error:
				return []

			_skip_newlines()
			var val: Variant = _parse_value()
			if _error:
				return []
			arr.append(val)
			_skip_newlines()

			if _current_type() == TokenType.COMMA:
				_advance()
				_skip_newlines()
				# Allow trailing comma before ']'
				if _current_type() == TokenType.RBRACKET:
					_advance()
					return arr
				continue

			if _current_type() == TokenType.RBRACKET:
				_advance()
				return arr

			_set_error("Expected ',' or ']' in array but got token type %d" % _current_type())
			return []

		return arr
