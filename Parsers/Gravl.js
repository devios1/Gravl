//
//  Gravl.js
//  Gravl
//
//  Created by Logan Murray on 2016-12-28.
//  Copyright © 2016 Logan Murray. All rights reserved.
//

Gravl = {}; // namespace

Gravl.Node = function(value, attributes, childNodes) {
	this.value = value;
	this.attributes = attributes;
	this.childNodes = childNodes;
}

Gravl.TextNode = function(value) {
	this.value = value;
	this.attributes = {};
	this.childNodes = [];
}
Gravl.TextNode.prototype = Object.create(Gravl.Node.prototype); // inherit

Gravl.Parser = function(name = "Document") {
	var reservedChars = "[]\"=#";
	var whitespaceChars = " \t\n\r";

	var documentName = name;
	var buffer = "";
	var index = 0;
	var glyphIndex = null; // the index of the next glyph, or null if unknown
	var line = 1;
	var col = 0;

	this.document = null;
	this.error = null;

	this.parse = function(string) {
		buffer = string;
		index = 0;
		glyphIndex = null;
		line = 1;
		col = 0;

		try {
			this.document = recordNodeBody(documentName);

			var char = peekGlyph()
			if (char != null)
				throw new ParserError("Extraneous character: " + char);
		} catch (e) {
			this.error = e;
			if (e instanceof ParserError)
				console.error("Gravl parse error: " + e.message + " (line " + line + ", col " + col + ")");
			return null;
		}

		return this.document;
	}

	function recordNode() {
		var char = readGlyph();
		console.assert(char == "[");

		var name = recordSymbol();

		if (name == "")
			throw new ParserError("Nodes must be named.");

		var node = recordNodeBody(name);

		char = readGlyph();
		console.assert(char == "]");

		return node;
	}

	function recordNodeBody(name) {
		var attributes = {};
		var childNodes = [];

		// look for attributes
		while (true) {
			var symbol = recordSymbol();

			if (symbol == "")
				break;

			if (peekGlyph() == "=") { // this is an attribute
				readGlyph() // absorb the =

				if (attributes[symbol] !== undefined)
					throw new ParserError("Duplicate attribute \"" + symbol + "\".");

				if (peekGlyph() == "[") {
					var value = recordNode();
					attributes[symbol] = value;
				} else {
					var value = recordSymbol();

					if (value == "")
						throw new ParserError("Attributes must have values.");

					attributes[symbol] = new Gravl.TextNode(value);
				}
			} else {
				childNodes.push(new Gravl.TextNode(symbol));
				break;
			}
		}

		// add remaining nodes as children
		while (peekGlyph() != null && peekGlyph() != "]") {
			if (peekGlyph() == "=")
				throw new ParserError("Attributes must be defined before child nodes.");

			var node;

			if (peekGlyph() == "[") {
				node = recordNode();
			} else {
				value = recordSymbol();
				console.assert(value != "");
				node = new Gravl.TextNode(value);
			}

			childNodes.push(node);
		}

		return new Gravl.Node(name, attributes, childNodes);
	}

	function recordSymbol() {
		if (peekGlyph() == "\"")
			return recordString();

		var symbol = "";

		while (glyphIndex != null && index != glyphIndex)
			readChar();

		while (peekChar() != null && !isReservedChar(peekChar()) && !isWhitespace(peekChar()))
			symbol += readChar();

		return symbol;
	}

	function recordString() {
		var char = readGlyph();
		console.assert(char == "\"");

		var string = "";

		while (peekChar() != null && peekChar() != "\"") {
			if (peekChar() == "\\")
				string += recordEscapedChar();
			else
				string += readChar();
		}

		char = readGlyph();
		console.assert(char == "\"");

		return string;
	}

	function recordEscapedChar() {
		var char = readChar(); // absorb \
		console.assert(char == "\\");

		char = readChar();
		if (char != "\\" && char != "\"")
			throw new ParserError("A backslash must be followed by either \" or \\.");

		return char;
	}

	// Helper Methods

	function peekChar() {
		if (index == buffer.length)
			return null;

		return buffer[index];
	}

	function readChar() {
		if (glyphIndex == index)
			glyphIndex = null;

		var char = peekChar();
		if (char == null)
			throw new ParserError("Unexpected EOF.");

		if (char == "\n") {
			line += 1;
			col = 0;
		} else {
			col += 1;
		}

		index += 1;

		return char;
	}

	function peekGlyph() {
		if (glyphIndex != null)
			return buffer[glyphIndex];

		var insideComment = false;
		glyphIndex = index;

		while (true) {
			if (glyphIndex == buffer.length) {
				glyphIndex = null;
				return null;
			}

			// handle # comments
			if (!insideComment && buffer[glyphIndex] == "#") {
				insideComment = true;
			} else if (insideComment && buffer[glyphIndex] == "\n") {
				insideComment = false;
			}

			if (!insideComment && !isWhitespace(buffer[glyphIndex])) {
				break;
			}

			glyphIndex += 1;
		}

		return buffer[glyphIndex];
	}

	function readGlyph() {
		var glyph = peekGlyph();
		if (glyph == null)
			throw new ParserError("Unexpected EOF.");

		while (glyphIndex != null) {
			readChar(); // advances the index and increments line/col counts
		}

		return glyph;
	}

	function isWhitespace(char) {
		console.assert(char.length == 1);

		return whitespaceChars.indexOf(char) != -1;
	}

	function isReservedChar(char) {
		console.assert(char.length == 1);

		return reservedChars.indexOf(char) != -1;
	}

	// ParserError

	function ParserError(message) {
		this.message = message;
		this.line = line;
		this.col = col;
	}
}
