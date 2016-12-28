# Gravl
A modern structured data language in the spirit of XML and JSON

## What is Gravl?
Gravl is a very simple but surprisingly capable structured object representation language. It is designed to be human-enterable and human-readable and avoids many of the limitations of XML and JSON.

Here is what Gravl looks like:

	[Person
		firstName="Logan"
		lastName="Murray"
		dateOfBirth=1981-09-24
		
		[ChildNode attr=value]
		[ChildNode attr=value
			[SubNode attr=value]
			[AnotherNode]
		]
	]

##Why?
Languages like XML and JSON are immensely useful, but they aren't without their limitations. Gravl aims to solve a few of the biggest problems with these two languages in particular, while keeping its syntax as simple to learn and use as possible.

##The Basics
Gravl uses a square bracket syntax to represent nodes. Like XML (and unlike JSON), nodes in Gravl are *named* and can recursively contain child nodes. Like JSON (and unlike XML), attributes in Gravl are also fully recursive and can be assigned node values themselves. (Unlike JSON, however, Gravl has no explicit support for arrays, but this is mainly because as you'll see, it doesn't need it.)

Gravl uses only 5 reserved characters: `[`, `]`, `"`, `=`, and `#`. Everything else is Unicode, and considered a valid symbol character.

Gravl also supports a few things that neither XML nor JSON do. For one, unlike XML and JSON, Gravl doesn't require that a document have precisely one root node. It does this by wrapping all documents in their own implicit document node, which typically takes the name of the file or path the document was loaded from, or "Document" by default.

This can be handy as a means to define very simple-structured config files or to attach attributes to a file as a whole.

Here's what an example config file might look like in Gravl:

####userconfig.gravl
	userId=914713
	lastLogin="2017-01-01 13:59:01"
	timeoutMs=20000
	loadImages=true
	openFiles=[@
		"file1.txt"
		"file2.txt"
	]

Like XML, Gravl supports **text nodes**, however there are a couple key differences to how text nodes are handled in XML. Specifically, while XML will automatically treat any text found outside of an attribute as a text node, in Gravl any piece of text that includes whitespace (or reserved characters) must be wrapped in double quotes:

	"I am a text node."

While not wrapping the above text in quotes is technically still valid (as the string does not make use of any of the five reserved characters), doing so would treat every word as a separate node, equivalent to the following:

	"I"
	"am"
	"a"
	"text"
	"node."

…which is probably *not* what was intended.

Gravl is an extremely permissive language in terms of allowed characters. This was one of the major limitations of XML that initially inspired the creation of Gravl. Unlike XML, Gravl allows you to use *any* character in a symbol that is not a reserved character or whitespace, and if that's not enough for you, you can wrap *any* text (including node names, attribute names, and values) in quotes to include any characters at all, including whitespace and reserved characters.

##The Structure of a Node
A node in Gravl represents an object and is always started with a `[` and ended with a `]`. It consists of three parts:

1. The node's name (required)
2. The node's attributes (optional)
3. The node's child nodes (optional)

Its structure looks like this:

	`[` `name` `attributes` `child nodes` `]`

Only the name is required, and must be the first thing inside the node, however you can use as much whitespace as you like between the parts of a node.

The name of a node is generally a **symbol**, which is any consecutive sequence of glyphs excluding reserved characters and whitespace, but like any symbol in Gravl, can also be an arbitrary string if wrapped in double-quotes.

###Attributes
Attributes are specified as an attribute name followed by an `=` character followed by a value. Attribute values can be either symbols, strings, or another node and must always be defined before any child nodes.

Attributes are represented in a form similar to XML:

	[Node attr1="value1" attr2="value2"]

Unlike XML and JSON, however, attribute values do not need to be wrapped in quotes unless they contain whitespace or reserved characters. The following is valid Gravl:

	[MyNode name=Bob age=24]

Note: Be careful to avoid accidentally using commas! The comma is *not* a reserved character in Gravl and is therefore considered a valid symbol character. If you wrote the following, the attribute's value would actually be "Bob,":

	[MyNode name=Bob, age=24]

Attributes can also recursively represent other nodes. Node-valued attributes are represented exactly the same as standalone nodes: no escaping, wrapping in quotes, or other quirks are needed:

	[MyNode attr1="value" attr2=[AnotherNode]]

Remember, any symbol can be represented as a string in Gravl, even node and attribute names. This is also completely valid:

	["Node name with spaces" "attribute name" = "attribute value"]

However it is recommended you avoid using strings for anything other than values, but Gravl is designed to be very general-purpose and therefore leaves that up to each particular implementation.

###Escaping
There are only two escaped characters in Gravl: backslash (\) and double-quote ("). Beyond this, strings are expected to contain the literal character you wish to encode.

Like most languages, characters are escaped with the backslash in Gravl:

	[Node attr="Use a \\ to \"escape\" characters in a string."]

###Child Nodes
A node in Gravl is fully recursive and can contain an ordered set of other child nodes. Everything after the final attribute of a node (if any) are considered the child nodes of that node.

	[Node attr=value
		[Child
			[Grandchild]
		]
	]

###Arrays
You may be surprised to learn that like unlike JSON, Gravl doesn't explicitly have a native syntax for arrays. The reason for this is that the Gravl syntax already implicitly supports arrays in the form of child nodes. For example, if we adopt the convention of using the name "@" to represent an array, we can wrap any ordered set of nodes in an array node like so:

	[Node
		items=[@				# this is actually just a node named @
			"first value"		# and these are its child nodes
			"second value"
			"third value"
		]
	]

We can pretend that this is the "official" syntax for arrays, but the truth is it doesn't rely on any new concepts and so is not technically part of the language spec. It's therefore up to each implementation to decide if or how arrays are to be represented, but you can consider this one suggested way.

While it may seem a bit weird at first, there is actually a lot of beauty in this approach. For one thing, it reuses all existing concepts, and is just as expressive as had there been an explicit syntax for arrays: arrays can be hierarchical, and they can contain any combination of other nodes and string values (because ultimately everything—even strings—are nodes in Gravl). As a bonus, because arrays are really just nodes, they can even have their own attributes! While you may argue the usefulness of this, it does demonstrate the power of reusing concepts and keeping the model simple.

It also means we can take full advantage of all the syntactic shorthands in Gravl when working with arrays, that being that symbols (chains of glyphs that do not include whitespace or reserved characters) do not need to be wrapped in quotes. So if the elements in our array don't need such characters, such as numbers, we can very elegantly and concisely represent them in Gravl:

	[Publication
		years=[@ 1998 2001 2009 2016]
	]

Doesn't that look nice and clean? Not bad considering we got it all for free.

###Comments
Comments in Gravl are indicated with the `#` character. Any text following (and including) a `#` up until the end of the line will be skipped over by the parser. You can put comments anywhere, but they always go to the end of the line. There are no inline comments in Gravl.

	# opening comment
	[Node					# this is a comment
		attr=value		# this is another comment
	]
	# closing comment

##Other Languages
The first Gravl parser is written in Swift, but as Gravl was designed to be a very general-purpose syntax, I also plan to add implementations in other languages, starting with JavaScript and C#.

If you'd like to contribute by implementing a Gravl parser in your own favourite language, I'd be happy to include it in the project as well. Gravl is really quite a simple syntax, and writing a parser for it can actually be a lot of fun and a great exercise!

I also welcome any feedback and suggestions concerning Gravl, and hope that others out there might find it useful too!

Happy coding!

// devios1