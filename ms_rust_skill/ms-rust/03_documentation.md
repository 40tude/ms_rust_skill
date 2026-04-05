# Documentation



## Documentation Has Canonical Sections 

Why this version exists: To follow established and expected Rust best practices.
Version: 1.0

Public library items must contain the canonical doc sections. The summary sentence must always be present. Extended documentation and examples
are strongly encouraged. The other sections must be present when applicable.

```rust
/// Summary sentence < 15 words.
///
/// Extended documentation in free form.
///
/// # Examples
/// One or more examples that show API usage like so.
///
/// # Errors
/// If fn returns `Result`, list known error conditions
///
/// # Panics
/// If fn may panic, list when this may happen
///
/// # Safety
/// If fn is `unsafe` or may otherwise cause UB, this section must list
/// all conditions a caller must uphold.
///
/// # Abort
/// If fn may abort the process, list when this may happen.
pub fn foo() {}
```

In contrast to other languages, you should not create a table of parameters. Instead parameter use is explained in plain text. In other words, do not

```rust,ignore
/// Copies a file.
///
/// # Parameters
/// - src: The source.
/// - dst: The destination.
fn copy(src: File, dst: File) {}
```

but instead:

```rust,ignore
/// Copies a file from `src` to `dst`.
fn copy(src: File, dst: File) {}
```

### Related Reading

- Function docs include error, panic, and safety considerations ([C-FAILURE](https://rust-lang.github.io/api-guidelines/documentation.html#c-failure))



## Mark `pub use` Items with `#[doc(inline)]` 

Why this version exists: To make re-exported items 'fit in' with their non re-exported siblings.
Version: 1.0

When publicly re-exporting crate items via `pub use foo::Foo` or `pub use foo::*`, they show up in an opaque re-export block. In most cases, this is not
helpful to the reader:

```
Re-Exports
----------
pub use view::*;
```

Instead, you should annotate them with `#[doc(inline)]` at the `use` site, for them to be inlined organically:

```rust,edition2021,ignore
# pub(crate) mod foo { pub struct Foo; }
#[doc(inline)]
pub use foo::*;

// or

#[doc(inline)]
pub use foo::Foo;
```

```
View -- A view over a configuration of type T, containing data for a specific context.
```

This does not apply to `std` or 3rd party types; these should always be re-exported without inlining to make it clear they are external.

> ### <alert></alert> Still avoid glob exports
>
> The `#[doc(inline)]` trick above does not change [M-NO-GLOB-REEXPORTS]; you generally should not re-export items via wildcards.

[M-NO-GLOB-REEXPORTS]: ../libs/resilience/#M-NO-GLOB-REEXPORTS



## First Sentence is One Line; Approx. 15 Words 

Why this version exists: To make API docs easily skimmable.
Version: 1.0

When you document your item, the first sentence becomes the "summary sentence" that is extracted and shown in the module summary:

```rust
/// This is the summary sentence, shown in the module summary.
///
/// This is other documentation. It is only shown in that item's detail view.
/// Sentences here can be as long as you like and it won't cause any issues.
fn some_item() { }
```

Since Rust API documentation is rendered with a fixed max width, there is a naturally preferred sentence length you should not
exceed to keep things tidy on most screens.

If you keep things in a line, your docs will become easily skimmable. Compare, for example, the standard library:

| Module     | Description                                                                 |
|------------|-----------------------------------------------------------------------------|
| alloc      | Memory allocation APIs.                                                     |
| any        | Utilities for dynamic typing or type reflection.                            |
| arch       | SIMD and vendor intrinsics module.                                          |
| array      | Utilities for the array primitive type.                                     |
| ascii      | Operations on ASCII strings and characters.                                 |
| backtrace  | Support for capturing a stack backtrace of an OS thread.                    |
| borrow     | A module for working with borrowed data.                                    |
| boxed      | The `Box<T>` type for heap allocation.                                      |
| cell       | Shareable mutable containers.                                               |
| char       | Utilities for the `char` primitive type.                                    |
| clone      | The `Clone` trait for types that cannot be 'implicitly copied'.             |
| cmp        | Utilities for comparing and ordering values.                                |

Otherwise, you might end up with _widows_ and a generally unpleasant reading flow:

| Item                          | Description                                                                 |
|-------------------------------|-----------------------------------------------------------------------------|
| DuplicateKeysError            | If you try to merge two Contexts together which have duplicate keys, this is the error you get. |
| Fragment                      | Contains a single layer of configuration data (from one source) which can be merged with data from other sources to yield a merged fragment to be deserialized into a concrete configuration type. |
| InternalContractViolationError| An error that signals some internal API contract or logical precondition was violated. |
| MergedContext                 |                                                                             |
| Snapshot                      | A snapshot of a config value T, allowing the value to be read. This type transparently takes care of resource management concerns required to expose the values efficiently. |
| View                          | A view over a configuration of type T, containing data for a specific context. |

As a rule of thumb, the first sentence should not exceed **15 words**.



## Has Comprehensive Module Documentation 

Why this version exists: To allow for better API docs navigation.
Version: 1.1

Any public library module must have `//!` module documentation, and the first sentence must follow [M-DOC-FIRST-SENTENCE].

```rust,edition2021,ignore
pub mod ffi {
    //! Contains FFI abstractions.

    pub struct String {};
}
```

The rest of the module documentation should be comprehensive, i.e., cover the most relevant technical aspects of the contained items, including

- what the module contains
- when it should be used, possibly when not
- examples
- subsystem specifications (e.g., `std::fmt` [also describes its formatting language](https://doc.rust-lang.org/stable/std/fmt/index.html#formatting-parameters))
- observable side effects, including what guarantees are made about these, if any
- relevant implementation details, e.g., the used system APIs

 Great examples include:

- [`std::fmt`](https://doc.rust-lang.org/stable/std/fmt/index.html)
- [`std::pin`](https://doc.rust-lang.org/stable/std/pin/index.html)
- [`std::option`](https://doc.rust-lang.org/stable/std/option/index.html)

This does not mean every module should contain all of these items. But if there is something to say about the interaction of the contained types,
their module documentation is the right place.

[M-DOC-FIRST-SENTENCE]: ./#M-DOC-FIRST-SENTENCE


