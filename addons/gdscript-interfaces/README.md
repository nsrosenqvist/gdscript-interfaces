#  GDScript Interfaces

This is a utility library, which provides a very naive GDScript implementation of interfaces for Godot. It can by its nature only check for implementations at runtime and cannot validate method parameter definitions due to the language's lack of introspection. By default are all implementations validated when the application is loaded, so it behaves quite similarly to how one would expect interfaces to work in other languages. So it may serve as a helpful tool until a native solution is developed for GDScript.

## Contributions

Improvements and suggestions are very welcome. If you have the time and know-how to extend the GDScript runtime as a GDExtension or something, then that would be a much better solution than this.

## Usage

Add the `addons/Interfaces.gd` script to your project's autoloaded singletons. Any script which "implements" an interface should have a property constant set called `implements`, which is an Array listing all its implementations (as GDScript references, so simply write the class name).

```GDScript
const implements = [
	CanTakeDamage,
	CanHeal
]
```

Then, wherever you wish to check for an implementation, you call the function `implements` on the singleton (the function can either take a single GDScript reference or an array of GDScripts).

```GDScript
func _on_body_entered(body : Node):
	if Interfaces.implements(body, CanTakeDamage):
		# Deal damage
```

There's also a helper method, called `implementations` that allows you to filter a list of objects and only keep those that implements the specified interface(s).

```GDScript
var destroyable = Interfaces.implementations([obj1, obj2, obj3], CanTakeDamage)
```

An interface is just a GDScript, defined with a `class_name`, that details the properties, signals, and methods that the implementations must provide.

```GDScript
class_name CanTakeDamage extends Object

var required = true

signal foobar

func deal_damage():
	pass
```

Since GDScript doesn't provide introspection, the validation can only take the existence of these properties, variables, and signals into account, and not types or parameters.

### Options

By default, the script validates all found GDScripts in the project when the application is loaded, since this mimics the expected behavior from other languages most closely. However, a few options may be tweaked to change this behavior (these are properties on the singleton). 

#### export(bool) var runtime_validation = false

This toggles whether all implementations should be validated immediately upon load, or if they should first be validated when they're tested against. If you have a lot of classes that may not always be loaded in a play session then this might be preferable for performance reasons, but it introduces the risk of never discovering incomplete implementations.

#### export(Array, String) var validate_dirs = ["res://"]

This option sets what directories the library should scan for classes that implements interfaces in. By default it's set to the project root, but it should preferably be changed to something more specific like "res://src/", or "res://src/contracts/". The option has no effect if the library is configured to only do runtime validation.

#### export(bool) var strict_validation = true

If strict validation is off, the `implements` method will only check if an entity has the provided interfaces in its `implements` constant. This may be preferable if proper validation turns out to incur a significant performance penalty (I haven't tested this system on larger projects). However, each check are usually only run once, since the results of validations are cached. Note that disabling strict validation pretty much removes the benefits of having interfaces in the first place.

## License

MIT