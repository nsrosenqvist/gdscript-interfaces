extends Node

## 
## A library providing a runtime interface system for GDScript
## 
## @desc:
##     This library provides interfaces for GDScript that can either be validated
##     at runtime when they are used or at application start (also runtime).
##     The code is MIT-licensed.
## 
## @tutorial: https://github.com/nsrosenqvist/gdscript-interfaces/tree/main/addons/gdscript-interfaces#readme
##

@export var runtime_validation: bool = false
# TODO: This can be removed as soon as global script names are allow as constants again.
## If this is true, a list of all interfaces is saved in memory to enable using "const implements = ['InterfaceName']" instead of preloads only.
## For big projects with lots of "class_name" scripts this should be off to safe memory (preloads have to be used in that case).
## WARNING: only works if none of the interfaces are outside of the "validate_dirs" directories. Use at your own risk.
@export var allow_string_classes: bool = false
@export var strict_validation: bool = true
@export var validate_dirs: Array[String] = ["res://"]

var _interfaces := {}
var _identifiers := {}
var _implements := {}

var _named_classes := {}

## Validate that an entity implements an interface
##
## implementation [Object]: Any GDscript or a node with script attached
## interfaces [GDScript|Array]: The interface(s) to validate against
## validate [bool]: Whether validation should run or if only the
##                  implements constant should be checked
## assert_on_fail [bool]: Instead of returning false, cause an assertion.
##                        This is an option that gets set automatically
##                        enabling runtime validation.
##
## Returns a [bool] indicating the result of the validation
func implements(implementation, interfaces, validate = strict_validation, assert_on_fail = runtime_validation) -> bool:
	if not (interfaces is Array):
		interfaces = [interfaces]
		
	var script : GDScript = _get_script(implementation)
	var implemented : Array = _get_implements(script)
	
	if implemented.size() == 0:
		return false
	
	for i in interfaces:
		if not implemented.has(i):
			return false
		
		if validate:
			if not _validate(script, i, assert_on_fail):
				return false
		else:
			if not (i in implemented):
				if assert_on_fail:
					var implementation_id : String = _get_identifier(script)
					var interface_id : String = _get_identifier(i)
					var lookup : String = str(script)+"=="+str(i)
					
					assert(false, implementation_id + " does not implement " + interface_id)
				else:
					return false
	
	return true

## Filter an array of objects and keep the ones implementing the interfaces
##
## objects [Array]: List of objects to filter
## interface [GDScript|Array]: The interface(s) to validate against
## validate [bool]: Indicate wheter to 
##
## Returns an [Array] containing the objects that implements the interface(s)
func implementations(objects : Array, interfaces, validate = false) -> Array:
	var result = []
	
	for object in objects:
		if implements(object, interfaces, validate):
			result.append(object)
	
	return result

func _ready():
	# Load all "class_name" scripts
	if allow_string_classes:
		_build_class_name_cache()
	# Pre-validate all interfaces on game start
	if not runtime_validation:
		_validate_all_implementations()

func _build_class_name_cache() -> void:
	var files = []
	for d in validate_dirs:
		files.append_array(_files(d, true))
	var scripts = _filter(files, _only_scripts)
	
	for s in scripts:
		var script = load(s)
		var identifier := _get_interface_identifier(script)
		if identifier != "":
			_named_classes[identifier] = _get_script(script)
	print(_named_classes)

func _validate_all_implementations() -> void:
	# Get all script files
	var files = []
	
	for d in validate_dirs:
		files.append_array(_files(d, true))

	var scripts = _filter(files, _only_scripts)

	# Validate all scripts that has the constant "implements"
	for s in scripts:
		var script = load(s)
		var implemented = _get_implements(script)
		var identifier = _get_identifier(script)

		if implemented.size() > 0:
			implements(script, implemented, strict_validation, true)

func _only_scripts(file : String) -> bool:
	return file.ends_with(".gd")

func _files(path : String, recursive = false) -> Array:
	var result = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not (file_name == "." or file_name == ".."):
				if dir.current_is_dir():
					if recursive:
						result.append_array(_files(path.path_join(file_name)))
				else:
					result.append(path.path_join(file_name))
			
			file_name = dir.get_next()
	else:
		printerr("An error occurred when trying to access '"+path+"'")
	
	return result

func _filter(objects : Array, function : Callable) -> Array:
	var result = []
	
	for object in objects:
		if function.call(object):
			result.append(object)
	
	return result

func _column(rows : Array, key : String) -> Array:
	var result := []
	
	for row in rows:
		result.append(row.get(key))
	
	return result

func _get_script(implementation) -> GDScript:
	if not implementation is GDScript:
		return implementation.get_script()
	
	return implementation

func _get_implements(implementation) -> Array:
	var script : GDScript = _get_script(implementation)
	var lookup : String = str(script)
	
	if _implements.has(lookup):
		return _implements[lookup]
	
	# Get implements constant from script
	var consts : Dictionary = script.get_script_constant_map()
	
	if consts.has("implements"):
		var interfaces: Array[GDScript] = []
		for interface in consts["implements"]:
			if interface is String:
				if not allow_string_classes:
					assert(false, "Cannot use string type in implements as 'allow_string_classes' is false. ('%s' in %s)" % [interface, lookup])
				interfaces.append(_named_classes[interface])
			elif interface is GDScript:
				interfaces.append(interface)
		_implements[lookup] = interfaces
	else:
		_implements[lookup] = []
	
	return _implements[lookup]

func _get_identifier(implementation, strict = false) -> String:
	var script : GDScript = _get_script(implementation)
	var lookup : String = str(script)
	
	if _identifiers.has(lookup):
		return _identifiers[lookup]
	
	# Extract class_name from script
	if script.has_source_code():
		var regex : RegEx = RegEx.new()
		regex.compile("class_name\\W+(\\w+)");
		var result = regex.search(script.source_code);
		
		if result:
			_identifiers[lookup] = result.get_string().substr(11)
		else:
			_identifiers[lookup] = "" if strict else script.resource_path
		
		return _identifiers[lookup]
	
	return "Unknown"

func _get_interface_identifier(implementation) -> String:
	var script : GDScript = _get_script(implementation)
	
	if script.has_source_code():
		var regex: RegEx = RegEx.new()
		regex.compile("#\\s*[iI]nterface\\n")
		var result = regex.search(script.source_code)
		if result:
			return _get_identifier(implementation, true)
	
	return ""

func _validate_implementation(script : GDScript, interface : GDScript, assert_on_fail = false) -> bool:
	var implementation_id = _get_identifier(script)
	var interface_id = _get_identifier(interface)
	
	if not interface.has_source_code():
		return true
	elif not script.has_source_code():
		if assert_on_fail:
			assert(false, implementation_id + " does not implement " + interface_id)
		else:
			return false
	
	# Check signals
	var signals = _column(script.get_script_signal_list(), "name")
	
	for s in _column(interface.get_script_signal_list(), "name"):
		if not (s in signals):
			if assert_on_fail:
				assert(false, implementation_id + ' does not implement the signal "'+s+'" on the interface ' + interface_id)
			else:
				return false

	# Check methods
	var methods = _column(script.get_script_method_list(), "name")
	
	for m in _column(interface.get_script_method_list(), "name"):
		if not (m in methods):
			if assert_on_fail:
				assert(false, implementation_id + ' does not implement the method "'+m+'" on the interface ' + interface_id)
			else:
				return false
	
	# Check properties
	var props = _column(script.get_script_property_list(), "name")
	
	for p in _column(interface.get_script_property_list(), "name"):
		if (p.ends_with(".gd")):
			continue
		if not (p in props):
			if assert_on_fail:
				assert(false, implementation_id + ' does not implement the property "'+p+'" on the interface ' + interface_id)
			else:
				return false

	return true

func _validate(implementation, interface : GDScript, assert_on_fail = false) -> bool:
	var script : GDScript = _get_script(implementation)
	var lookup : String = str(script)+"=="+str(interface)
	
	if _interfaces.has(lookup):
		return _interfaces[lookup]
	
	# Save to look up dictionary
	_interfaces[lookup] = _validate_implementation(script, interface, assert_on_fail)

	return _interfaces[lookup]
