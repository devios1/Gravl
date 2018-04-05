# Gravl

**Gravl** (pronounced *gravel*) is a concise but powerful universal data representation format. It follows a very basic syntax and uses only six reserved characters, yet is capable of representing a wide range of complex information. Its syntax is very logical and well-defined, and as such it is very easy to learn and use.

> **Note:** Version 1.2 of the parser is extremely customizable, even to the degree of allowing you to fine-tune what features you need and which symbols they use, resulting in a very customizable syntax capable of handling a large number of special-purpose needs. (See below for more on this capability.)
>
> Since the new parser options introduce a huge degree of variability in what the Gravl parser may interpret, I will use the term **standard** Gravl when referring to the language as envisioned—represented by the default parser options—if I need to differentiate.

## The Basics

The atom of Gravl is the **node**, and it is simply an ordered collection of other nodes (called its **children**), or a **symbol**.

A **symbol** is any string of consecutive characters not including any (unescaped) reserved characters or whitespace.

The six reserved characters are:

> `[`&nbsp;`]`&nbsp;`=`&nbsp;`,`&nbsp;`"`&nbsp;`\`

A `[` begins a **node**, and a `]` ends it. A **node** has the following structure:

`[`
&nbsp;&nbsp;&nbsp;&nbsp;**attribute** `=` **value**
&nbsp;&nbsp;&nbsp;&nbsp;…
`]`

An **attribute** must be a **symbol**. A **value** can be a **symbol** or another **node**.

A **child** without an attribute is called an **unattributed value** (or **value node** for short):

`[`
&nbsp;&nbsp;&nbsp;&nbsp;**value**
`]`

> A **symbol** on its own (not paired with an `=`) is always assumed to be a **value** with an empty (`nil`) **attribute**.

A `,` can be used to combine **attributes**, **values**, or both:

`[`
&nbsp;&nbsp;&nbsp;&nbsp;**attribute** `=` **value1** `,` **value2**
`]`

is equivalent to:

`[`
&nbsp;&nbsp;&nbsp;&nbsp;**attribute** `=` **value1**
&nbsp;&nbsp;&nbsp;&nbsp;**attribute** `=` **value2**
`]`

while:

`[`
&nbsp;&nbsp;&nbsp;&nbsp;**attribute1** `,` **attribute2** `=` **value**
`]`

is equivalent to:

`[`
&nbsp;&nbsp;&nbsp;&nbsp;**attribute1** `=` **value**
&nbsp;&nbsp;&nbsp;&nbsp;**attribute2** `=` **value**
`]`

This also applies to **value nodes**, but in standard Gravl this is redundant, as:

`[` **value1** `,` **value2** `]` **=** `[` **value1**&nbsp;&nbsp;**value2** `]`

*Note that because of this, I will often represent arrays of values with commas to make them more visually apparent. Just bear in mind the comma is not strictly needed:* `[a, b, c]` **=** `[a b c]`

A `\` can be used to **escape** any character that would otherwise have an unintended meaning (such as a reserved character or whitespace) and turn it into a valid **symbol** character.

A **symbol** may also be wrapped with `"` to turn it into a **string**. The only characters you need to escape inside a string are `\` and `"`.

`[`
&nbsp;&nbsp;&nbsp;&nbsp;**attribute** `=` `"`**string**`"`
`]`

A `//` indicates a **comment**. Any text following a `//` until the end of the line is ignored. Slashes may also be **escaped** to avoid unintentional comments.

`[`
&nbsp;&nbsp;&nbsp;&nbsp;`//` **comment**
`]`

> **Note:** Because Gravl has such a terse syntax, it lends itself well to a helpful mathematical notation that I will use throughout this book. It's worth pointing out that these expressions involve real Gravl and are used as demonstrations and occasionally proofs.
>
> For example: `[a b]` → `[a [b]]`

Some important points to keep in mind. We take these as **axioms**:

- The **order** of a node's children matters:
`a` **≠** `b` **⟺** `[a b]` **≠** `[b a]`

- The attributes of sibling children are **not** necessarily **unique**:
`[a=1 a=2]` is valid.

## Gravl vs. JSON vs. XML

The capability of Gravl can be demonstrated by the fact that any JSON or XML document can be represented naturally in Gravl, yet there is no natural way to convert between XML and JSON. As such, the opposite direction does not hold: not every Gravl document can be represented naturally as JSON, and likewise for XML.
