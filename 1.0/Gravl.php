<?php

//
//  Gravl.php
//  Gravl
//
//  Created by Logan Murray on 2017-01-05.
//  Copyright © 2017 Logan Murray. All rights reserved.
//

namespace Gravl;

class Node {
	public $value;
	public $attributes;
	public $childNodes;

	function __construct($value, $attributes, $childNodes) {
		$this->value = $value;
		$this->attributes = $attributes;
		$this->childNodes = $childNodes;
	}
}

class TextNode extends Node {
	function __construct($value) {
		$this->value = $value;
		$this->attributes = array();
		$this->childNodes = array();
	}
}

class Parser {
	private $reservedChars = "[]\"=#";
	private $whitespaceChars = " \t\n\r";

	private $name;
	private $buffer = "";
	private $index = 0;
	private $glyphIndex = null; // the index of the next glyph, or null if unknown
	private $line = 1;
	private $col = 0;

	public $document = null;
	public $error = null;

	function __construct($name = "Document") {
		$this->name = $name;
	}

	function parse($string) {
		$this->buffer = $string;
		$this->index = 0;
		$this->glyphIndex = null;
		$this->line = 1;
		$this->col = 0;

		try {
			$this->document = $this->recordNodeBody($this->name);

			$char = $this->peekGlyph();
			if ($char !== null)
				throw new ParserError("Extraneous character: $char", $this->line, $this->col);
		} catch (ParserError $e) {
			$this->error = e;
			fwrite(STDERR, "Gravl parse error: ".$e->message." (line ".$e->line.", col ".$e->col.")\n");
			$this->document = null;
		}

		return $this->document;
	}

	private function recordNode() {
		$char = $this->readGlyph();
		assert($char == "[");

		$name = $this->recordSymbol();

		if (empty($name))
			throw new ParserError("Nodes must be named.", $this->line, $this->col);

		$node = $this->recordNodeBody($name);

		$char = $this->readGlyph();
		assert($char == "]");

		return $node;
	}

	private function recordNodeBody($name) {
		$attributes = array();
		$childNodes = array();

		// look for attributes
		while (true) {
			$symbol = $this->recordSymbol();

			if (empty($symbol))
				break;

			if ($this->peekGlyph() == "=") {
				$this->readGlyph(); // absorb the =

				if (array_key_exists($symbol, $attributes))
					throw new ParserError("Duplicate attribute: $symbol", $this->line, $this->col);

				if ($this->peekGlyph() == "[") {
					$value = $this->recordNode();
					$attributes[$symbol] = $value;
				} else {
					$value = $this->recordSymbol();
					if (empty($value))
						throw new ParserError("Attributes must have values.", $this->line, $this->col);
					$attributes[$symbol] = new TextNode($value);
				}
			} else {
				$childNodes []= new TextNode($symbol);
				break;
			}
		}

		while ($this->peekGlyph() !== null && $this->peekGlyph() != "]") {
			if ($this->peekGlyph() == "=") {
				if (empty($childNodes))
					throw new ParserError("Nodes must be named.", $this->line, $this->col);
				else
					throw new ParserError("Attributes must be defined before child nodes.", $this->line, $this->col);
			}

			if ($this->peekGlyph() == "[") {
				$childNodes []= $this->recordNode();
			} else {
				$value = $this->recordSymbol();
				assert(!empty($value));
				$childNodes []= new TextNode($value);
			}
		}

		return new Node($name, $attributes, $childNodes);
	}

	private function recordSymbol() {
		if ($this->peekGlyph() == "\"")
			return $this->recordString();

		$symbol = "";

		while ($this->glyphIndex !== null && $this->index !== $this->glyphIndex)
			$this->readChar();

		while ($this->peekChar() !== null && !$this->isReservedChar($this->peekChar()) && !$this->isWhitespace($this->peekChar()))
			$symbol .= $this->readChar();

		return $symbol;
	}

	private function recordString() {
		$char = $this->readGlyph();
		assert($char == "\"");

		$string = "";

		while ($this->peekChar() !== null && $this->peekChar() != "\"") {
			if ($this->peekChar() == "\\")
				$string .= $this->recordEscapedChar();
			else
				$string .= $this->readChar();
		}

		$char = $this->readChar();
		assert($char == "\"");

		return $string;
	}

	private function recordEscapedChar() {
		$char = $this->readChar();
		assert($char == "\\");

		$char = $this->readChar();
		if ($char != "\\" && $char != "\"")
			throw new ParserError("A backslash must be followed by either \" or \\.", $this->line, $this->col);

		return $char;
	}

	// Helper Methods

	private function peekChar() {
		if ($this->index == strlen($this->buffer))
			return null;

		return $this->buffer[$this->index];
	}

	private function readChar() {
		if ($this->glyphIndex === $this->index)
			$this->glyphIndex = null;

		$char = $this->peekChar();
		if ($char === null)
			throw new ParserError("Unexpected EOF.", $this->line, $this->col);

		if ($char == "\n") {
			$this->line += 1;
			$this->col = 0;
		} else {
			$this->col += 1;
		}

		$this->index += 1;

		return $char;
	}

	private function peekGlyph() {
		if ($this->glyphIndex === strlen($this->buffer))
			return null;
		if ($this->glyphIndex !== null)
			return $this->buffer[$this->glyphIndex];

		$insideComment = false;
		$this->glyphIndex = $this->index;

		while (true) {
			if ($this->glyphIndex === strlen($this->buffer))
				return null;

			if (!$insideComment && $this->buffer[$this->glyphIndex] == "#") {
				$insideComment = true;
			} else if ($insideComment && $this->buffer[$this->glyphIndex] == "\n") {
				$insideComment = false;
			}

			if (!$insideComment && !$this->isWhitespace($this->buffer[$this->glyphIndex])) {
				break;
			}

			$this->glyphIndex += 1;
		}

		return $this->buffer[$this->glyphIndex];
	}

	private function readGlyph() {
		$glyph = $this->peekGlyph();
		if ($glyph === null)
			throw new ParserError("Unexpected EOF.", $this->line, $this->col);

		while ($this->glyphIndex !== null)
			$this->readChar(); // advances the index and increments line/col counts

		return $glyph;
	}

	private function isReservedChar($char) {
		return strpos($this->reservedChars, $char) !== false;
	}

	private function isWhitespace($char) {
		return strpos($this->whitespaceChars, $char) !== false;
	}
}

class ParserError extends \Exception {
	public $message;
	public $line;
	public $col;

	function __construct($message, $line, $col) {
		$this->message = $message;
		$this->line = $line;
		$this->col = $col;
	}
}
