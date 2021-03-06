# Gravl

**Gravl** (pronounced *gravel*) is a concise but powerful universal data representation format. It follows a very basic syntax and uses only six reserved characters, yet is capable of representing a wide range of complex information. Its syntax is very logical and well-defined, and as such it is very easy to learn and use.

> **Note:** Version 1.2 of the parser is extremely customizable, even to the degree of allowing you to fine-tune what features you need and which symbols they use, resulting in a very customizable syntax capable of handling a large number of special-purpose needs.
>
> Since the new parser options introduce a huge degree of variability in what the Gravl parser may interpret, I will use the term **standard** Gravl when referring to the language as envisioned—represented by the default parser options—if I need to differentiate.

## The Basics

The atom of Gravl is the **node**, and it is simply an ordered collection of other nodes (called its **children**), or a **symbol**.

A **symbol** is any string of consecutive characters not including (unescaped) reserved characters or whitespace.

The six reserved characters are:

`[`&nbsp;`]`&nbsp;`=`&nbsp;`,`&nbsp;`"`&nbsp;`\`

A `[` begins a **node**, and a `]` ends it. A **node** has the following structure:

`[`<br />
&nbsp;&nbsp;&nbsp;&nbsp;**attribute** `=` **value**<br />
&nbsp;&nbsp;&nbsp;&nbsp;…<br />
`]`

An **attribute** must be a **symbol**. A **value** can be a **symbol** or another **node**.

A **value** can be placed on its own without specifying an attribute. Such a value is called an **unattributed value** (or **value node** for short):

`[`<br />
&nbsp;&nbsp;&nbsp;&nbsp;**value**<br />
`]`

A **symbol** on its own (not paired with an `=`) is always assumed to be a **value** with an empty (`nil`) **attribute**.

A `,` can be used to combine **attributes**, **values**, or both:

`[`<br />
&nbsp;&nbsp;&nbsp;&nbsp;**attribute** `=` **value1** `,` **value2**<br />
`]`

is equivalent to:

`[`<br />
&nbsp;&nbsp;&nbsp;&nbsp;**attribute** `=` **value1**<br />
&nbsp;&nbsp;&nbsp;&nbsp;**attribute** `=` **value2**<br />
`]`

while:

`[`<br />
&nbsp;&nbsp;&nbsp;&nbsp;**attribute1** `,` **attribute2** `=` **value**<br />
`]`

is equivalent to:

`[`<br />
&nbsp;&nbsp;&nbsp;&nbsp;**attribute1** `=` **value**<br />
&nbsp;&nbsp;&nbsp;&nbsp;**attribute2** `=` **value**<br />
`]`

This also applies to **value nodes**, but in standard Gravl this is redundant, as:

`[` **value1** `,` **value2** `]` **=** `[` **value1**&nbsp;&nbsp;**value2** `]`

*Note that because of this, I will often represent arrays of values with commas to make them more visually apparent. Just bear in mind the comma is optional in these cases.

A `\` can be used to **escape** any character that would otherwise have an unintended meaning (such as a reserved character or whitespace) and turn it into a valid **symbol** character.

A **symbol** may also be wrapped with `"` to turn it into a **string**. The only characters you need to escape inside a string are `\` and `"`.

`[`<br />
&nbsp;&nbsp;&nbsp;&nbsp;**attribute** `=` `"`**string**`"`<br />
`]`

A `//` indicates a **comment**. Any text following a `//` until the end of the line is ignored. Slashes may also be **escaped** to avoid unintentional comments.

`[`<br />
&nbsp;&nbsp;&nbsp;&nbsp;`//` **comment**<br />
`]`

> **Note:** Because Gravl has such a terse syntax, it lends itself well to a helpful mathematical notation that I will use throughout this book. It's worth pointing out that these expressions involve real Gravl and are used as demonstrations and occasionally proofs.
>
> For example: `[a b]` → `[a [b]]`

Some important points to keep in mind. We take these as **axioms**:

- The **order** of a node's children matters:<br />
`a` **≠** `b` **⟹** `[a b]` **≠** `[b a]`

- The attributes of sibling children are **not** necessarily **unique**:<br />
`[a=1 a=2]` is valid.

*Work in progress.*
