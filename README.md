# 🗃️ [`KeysSet`](KeysSet)

> lookup for multiple arbitrary keys. safe. log n

🌏 Let's build a country lookup with `.code` and `.flag` as keys
```elm
KeysSet.fromList keys
    [ { flag = "🇦🇺", code = "AU", name = "Australia" }
    , { flag = "🇦🇶", code = "AQ", name = "Antarctica" }
    , { flag = "🇱🇧", code = "LB", name = "Lebanon" }
    ]

type alias Country =
    { flag : String, code : String, name : String }
```

With a key to compare against, you can find the matching element
in `log n` time:

```elm
|> KeysSet.element (key .flag keys) "🇦🇶"
--→ Just { flag = "🇦🇶", code = "AQ", name = "Antarctica" }

|> KeysSet.element (key .code keys) "LB"
--→ Just { flag = "🇱🇧", code = "LB", name = "Lebanon" }

|> KeysSet.end (key .code keys) Down -- minimum
--→ { flag = "🇦🇶", code = "AQ", name = "Antarctica" } no Maybe
```

We supplied `keys` to construct and operate on our [`KeysSet`](KeysSet#KeysSet),
so... Which aspects do we want it to be sorted by?
```elm
keys : Keys Country CountryKeys N2
keys =
    Keys.for (\flag_ code_ -> { flag = flag_, code = code_ })
        |> Keys.by ( .flag, flag )
            (String.Order.earlier Char.Order.unicode)
        |> Keys.by ( .code, code )
            (String.Order.earlier (Char.Order.aToZ Order.tie))
```

[`KeysSet`](KeysSet#KeysSet) holds no functions, so the [`Keys`](Keys#Keys) have to be supplied on every operation.

To ensure these given [`Keys`](Keys#Keys) are always the same for one [`KeysSet`](KeysSet#KeysSet),
we need some boilerplate,
attaching opaque tags:

```elm
type Flag =
    -- ! no exposing (..) → only constructable in this module
    Flag

flag : Mapping Country Flag String
flag =
    Map.tag Flag .flag

type Code
    -- no exposing (..)
    = Code

code : Mapping Country Code String
code =
    Typed.tag Code .code

type alias CountryKeys =
    -- you can just infer this
    { flag : Key Country (Order.By Flag (String.Order.Earlier Char.Order.Unicode)) N2
    , code : Key Country (Order.By Code (String.Order.Earlier (Char.Order.AToZ Order.Tie))) N2
    }
```

Feels somewhat like "explicit typeclasses" :)

→ Solves problems listed in [prior art](#prior-art)
alongside other [goodies](#goodies)

🧩

  - when annotating a [`KeysSet`](KeysSet#KeysSet), you'll run into types like
    ```elm
    Emptiable (KeysSet ...) Never -> ...
    ```
    ```elm
    -> Emptiable (KeysSet ...) never_
    ```
    which say: the [`KeysSet`](KeysSet#KeysSet) can never be empty

    and
    ```elm
    -> Emptiable (KeysSet ...) Possibly
    ```
    ```elm
    Emptiable (KeysSet ...) possiblyOrNever -> ...
    ```
    which say: the [`KeysSet`](KeysSet#KeysSet) can possibly be empty.

    [`emptiness-typed`](https://dark.elm.dmy.fr/packages/lue-bird/elm-emptiness-typed/latest/) lets us conveniently use one API
    for both non-empty and emptiable types.
  - the types of key counts like `N2` can be found in [`bounded-nat`](https://dark.elm.dmy.fr/packages/lue-bird/elm-bounded-nat/latest/). No need to understand the details; type inference has your back.
  - Wanna dig a bit deeper? Giving an [`Ordering`](Order#Ordering) or [`Mapping`](Map#Mapping) a unique tag is enabled by [`typed-value`](https://dark.elm.dmy.fr/packages/lue-bird/elm-typed-value/latest/): convenient control of reading and writing for tagged things.

### another example: operator

```elm
import KeysSet exposing (KeysSet)
import Emptiable exposing (Emptiable)
import Possibly exposing (Possibly)
import Keys exposing (Key, key, Keys)
import Order
import String.Order
import Char.Order
import Map exposing (Mapping)
import N exposing (N2)

type alias Operator =
    { symbol : String, name : String, kind : OperatorKind }

operatorKeys : Keys Operator OperatorKeys N2
operatorKeys =
    Keys.for (\symbol_ name_ -> { symbol = symbol_, name = name_ })
        |> Keys.by ( .symbol, symbol )
            (String.Order.earlier Char.Order.unicode)
        |> Keys.by ( .name, name )
            (String.Order.earlier (Char.Order.aToZ Order.tie))

type alias OperatorKeys =
    { symbol : Key Operator (Order.By Symbol (String.Order.Earlier Char.Order.Unicode)) String N2
    , name : Key Operator (Order.By Name (String.Order.Earlier Char.Order.AToZ (Order.Tie))) String N2
    }

operators : Emptiable (KeysSet Operator OperatorKeys N2) never_
operators =
    KeysSet.fromStack operatorKeys
        (Stack.topBelow
            { symbol = ">", name = "gt", kind = Binary }
            [ { symbol = "<", name = "lt", kind = Binary }
            , { symbol = "==", name = "eq", kind = Binary }
            , { symbol = "-", name = "negate", kind = Unary }
            ]
        )

nameOfOperatorSymbol : String -> Emptiable String Possibly
nameOfOperatorSymbol operatorSymbol =
    operators
        |> KeysSet.element (key .symbol operatorKeys) operatorSymbol

type Name
    = Name

name : Mapping Operator Name String
name =
    Map.tag Name .name

type Symbol
    = Symbol

symbol : Mapping Operator Symbol String
symbol =
    Map.tag Symbol .symbol
```

### example: automatic answers
```elm
type alias ConversationStep =
    { youSay : String, answer : String }

type alias ByYouSay =
    Key ConversationStep (Order.By YouSay (String.Order.Earlier (Char.Order.AToZ Order.Tie))) String N1

youSayKey : Keys ConversationStep ByYouSay N1
youSayKey =
    Keys.oneBy youSay (String.Order.earlier (Char.Order.aToZ Order.tie))

answers : Emptiable (KeysSet ConversationStep ByYouSay N1) Possibly
answers =
    KeysSet.fromList youSayKey
        [ { youSay = "Hi"
          , answer = "Hi there!"
          }
        , { youSay = "Bye"
          , answer = "Ok, have a nice day and spread some love."
          }
        , { youSay = "How are you"
          , answer = "I don't have feelings :("
          }
        , { youSay = "Are you a robot"
          , answer = "I think the most human answer is 'Haha... yes'"
          }
        ]
```

### example: user

```elm
import Emptiable exposing (Emptiable)
import Stack
import KeysSet exposing (KeysSet)
import N exposing (N2)
import User exposing (User(..))

exampleUsers : Emptiable (KeysSet User User.Keys N2) never_
exampleUsers =
    KeySet.fromStack User.keys
        (Stack.topBelow
            (User { name = "Fred", email = ..@out.tech.. })
            [ User { name = "Ann", email = ..ann@mail.xyz.. }
            , User { name = "Annother", email = ..ann@mail.xyz.. }
            , User { name = "Bright", email = ..@snail.studio.. }
            ]
        )

exampleUsers |> KeySet.size
--→ 3

exampleUsers |> KeySet.element User.keys ..ann@mail.xyz..
--→ Emptiable.filled { name = "Ann", email = ..ann@mail.xyz.. }
```
```elm
-- module User exposing (User(..), Keys, keys)

import KeySet
import Keys
import Order
import String.Order
import Char.Order
import Map exposing (Mapping)
import N exposing (N2)
import Email

type User
    = User
        { email : Email
        , name : String
        , settings : Settings
        }

type EmailTag
    = Email

email : Mapping User EmailTag Email
email =
    Map.tag Email (\(User userData) -> userData.email)

type NameTag
    = Name

name : Mapping User NameTag String
name =
    Map.tag Name (\(User userData) -> userData.name)

keys : Keys.Keys User Keys N2
keys =
    Keys.for (\email_ name_ -> { email = email_, name = name_ })
       |> Keys.by ( .email, email ) Email.byHostFirst
       |> Keys.by ( .name, name )
            (String.Order.earlier (Char.Order.aToZ Order.tie))

type alias Keys =
    { email : Key User (Order.By EmailTag Email.ByHostFirst) Email N2
    , name : Key User (Order.By NameTag (String.Order.Earlier (Char.Order.AToZ Order.Tie))) String N2
    }
```
```elm
-- module Email exposing (Email, byHostFirst, ByHostFirst)
type alias Email =
    { host : String, label : String }

type alias ByHostFirst =
    Order.OnTieNext
        (Order.By Email.HostTag (String.Order.Earlier (Char.Order.AToZ Order.Tie)))
        (Order.By Email.LabelTag (String.Order.Earlier (Char.Order.AToZ Order.Tie)))

byHostFirst : Ordering Email ByHostFirst 
byHostFirst =
    Order.by Email.host
        (String.Order.earlier (Char.Order.aToZ Order.tie))
        |> Order.onTie
            (Order.by Email.label
                (String.Order.earlier (Char.Order.aToZ Order.tie))
            )
```

```elm
import KeysSet exposing (KeysSet)
import Keys exposing (key)
import Emptiable exposing (Emptiable)
import Possibly exposing (Possibly)
import N exposing (N2)

type alias State =
    { users : Emptiable (KeysSet User UserKeys N2) Possibly
    , activeUserName : String
    }

initialState : State
initialState =
    { users = exampleUsers }

reactTo event =
    case event of
        Registered { name, email } ->
            \state ->
                case state.users |> KeysSet.element (key .name User.keys) name of
                    Emptiable.Filled _ ->
                        -- name taken already
                
                    Emptiable.Empty _ ->
                        case state.users |> KeysSet.element (key .email User.keys) email of
                            Emptiable.Filled _ ->
                                -- email taken already

                            Emptiable.Empty _ ->
                                { state
                                    | users =
                                        state.users
                                            |> KeysSet.insert User.keys
                                                { name = name
                                                , email = email
                                                , settings = defaultSettings
                                                }
                                }
        
        SettingsChanged settingsChange ->
            \state ->
                { state
                    | users =
                        state.users
                            |> KeysSet.elementAlterIfNoCollision
                                (key .name User.keys)
                                state.activeUserName
                                (applySettingsChange settingsChange)
                }
        
        UserSwitched name ->
            \state -> { state | activeUserName = name }
```

  - [↑ more examples](https://github.com/lue-bird/elm-keysset/tree/master/example)
  - [↑ other examples of `Keys`: `Atom`](https://github.com/lue-bird/elm-keysset/tree/master/tests/Atom.elm)

### anti-example: partners, synonyms, opposites...

```elm
partnerKeys =
    Keys.for
        (\partner_ partnerOfPartner_ ->
            { partner = partner_, partnerOfPartner = partnerOfPartner_ }
        )
        |> Keys.by ( .partner, partner )
            (String.Order...)
        |> Keys.by ( .partnerOfPartner, partnerOfPartner )
            (String.Order...)

partners =
    KeysSet.fromList partnerKeys
        [ { partner = "Ann", partnerOfPartner = "Alan" }
        , { partner = "Alex", partnerOfPartner = "Alistair" }
        , { partner = "Alan", partnerOfPartner = "Ann" }
        -- wait, this is no duplicate and is inserted
        ]
```
A `KeysSet` ony makes sense when the **keys describe something different**

Maybe take a look at graphs or [elm-bidict](https://github.com/Janiczek/elm-bidict) instead.

## goodies

  - 🦄 multiple possible `log n` keys
  - ⚖ sorted by [`Ordering key = ... key, key -> Order`](Order#Ordering)
      - 👍 no reliance on `comparable`
      - 👍 no inconvenient `key -> String`
      - 👍 no extra type argument for `comparableKey`
      - 👍 highly customizable with stuff like `Order.reverse`
  - 🔑 `element -> key` function as part of a given [`Key`](Keys#Key)
      - 👍 simpler type
      - 👍 simpler internals :)
      - same idea is also implemented in
          - [`escherlies/elm-ix-dict`: `IxDict`](https://dark.elm.dmy.fr/packages/escherlies/elm-ix-dict/latest/IxDict)
          - [`Orasund/elm-bag` `Bag`](https://dark.elm.dmy.fr/packages/Orasund/elm-bag/latest/Bag)
  - no stored function but tags to ensure the given [`Keys`](Keys#Keys) are the same
      - 👍 debugger, json import/export work
      - 👍 lamdera works
      - 👍 hot module reloading → never have an old model
      - 👍 no accidental (==) crash
  - 🗃 emptiability is part of the type
      - just use the same API with emptiable or non-empty conveniently
      - 👍 extra safety possible. Got enough elements? → `KeySet.minimum`, `maximum`, `foldFromOne`, `fold` don't need `Maybe`
      - 🧩 [`allowable-state`](https://dark.elm.dmy.fr/packages/lue-bird/elm-allowable-state/latest/)
      - 🧩 [`emptiness-typed`](https://dark.elm.dmy.fr/packages/lue-bird/elm-emptiness-typed/latest/)

## prior art

  - `comparableKey`
      - examples
          - [`elm/core` `Dict`](https://dark.elm.dmy.fr/packages/elm/core/latest/Dict)
          - [`miniBill/elm-fast-dict` `FastDict`](https://dark.elm.dmy.fr/packages/miniBill/elm-fast-dict/latest/)
          - [`wittjosiah/elm-ordered-dict` `OrderedDict`](https://dark.elm.dmy.fr/packages/wittjosiah/elm-ordered-dict/latest/OrderedDict)
      - 👎 requires a new `Dict`/`Set` wrapper when its key contains a custom `type`.
        Often more a hindrance than helpful
      - 👎 no way to provide a different sorting, e.g. saying `'a'` should be less than `'A'`
  - using an ordering function (to `comparable` or `k -> k -> Order` or a wrapper)
      - `key -> key -> Order`
          - examples
              - [`owanturist/elm-avl-dict` `AVL.Set`, `AVL.Dict`](https://dark.elm.dmy.fr/packages/owanturist/elm-avl-dict/latest/)
          - 👍 simple to create
              - see for example [`Order`'s prior art](Order#prior-art)
          - 👍 simple type
          - 👍 not limited to `comparable` keys. Therefore simpler while not relying on magic
      - `... -> comparable`
          - examples
              - [`timo-weike/generic-collections`](https://dark.elm.dmy.fr/packages/timo-weike/generic-collections/latest/)
              - [`turboMaCk/any-dict`](https://dark.elm.dmy.fr/packages/turboMaCk/any-dict/latest/)
              - [`Orasund/elm-bag` `Bag`](https://dark.elm.dmy.fr/packages/Orasund/elm-bag/latest/Bag)
              - [`escherlies/elm-ix-dict`: `IxDict`](https://dark.elm.dmy.fr/packages/escherlies/elm-ix-dict/latest/)
              - [`bburdette/typed-collections` `TSet`, `TDict`](https://dark.elm.dmy.fr/packages/bburdette/typed-collections/latest/)
          - 👎 no nice way to provide a different sorting, e.g. saying `'a'` should be less than `'A'`
          - 👎 more prone to bugs in `toComparable` implementation not returning a unique `comparable` for all keys
          - 👎 slightly less performant when `toComparable` needs to do heavy work (e.g. convert to a list)
          - `key -> String`
              - examples (in no specific order)
                  - [`matzko/elm-opaque-dict` `OpaqueDict`](https://dark.elm.dmy.fr/packages/matzko/elm-opaque-dict/latest/)
                  - [`edkv/elm-generic-dict` `GenericDict`](https://dark.elm.dmy.fr/packages/edkv/elm-generic-dict/latest/)
              - 👍 avoid having an extra type variable
              - 👎 requires more work
      - custom ordering wrapper
          - examples
              - [`red-g/service-collections` `Service.Dict`, `Service.Set`](https://dark.elm.dmy.fr/packages/red-g/service-collections/latest/) using [`red-g/sort`](https://dark.elm.dmy.fr/packages/red-g/sort/latest/)
              - [`rtfeldman/elm-sorter-experiment` `Sort.Dict`, `Sort.Set`](https://dark.elm.dmy.fr/packages/rtfeldman/elm-sorter-experiment/latest/)
          - 👍 simple to create
          - 👍 simple type
          - 👍 not limited to `comparable` keys. Therefore simpler while not relying on magic
          - 👍 guided experience – no getting confused that a type aliases a function
            ```elm
            choiceTypeOrder : Ordering ChoiceType
            choiceTypeOrder what the = ???
            ```
          - 👎 libraries often duplicate the ordering wrapper API instead of using a pre-existing one
      - build the complete API from a given function
          - examples
              - [`edkelly303/elm-any-type-collections` `Any.Set`, `Any.Dict`](https://dark.elm.dmy.fr/packages/edkelly303/elm-any-type-collections/latest/) with a `toComparable` function
                  - 👎 dead code elimination doesn't work
                  - 👎 obscure API and interface type
              - [`miniBill/elm-generic-dict` `GenericDict` `GenericSet`](https://dark.elm.dmy.fr/packages/miniBill/elm-generic-dict/latest/) with a `toComparable` function
                  - 👎 code duplication
          - using the constructed API is rather simple
          - 👎 semantic versioning doesn't work
          - 👍 simple type
          - 👍 nicely compact
          - 👍 functions aren't stored in the data structure
          - using for example `insert` from the wrong API "instance" with a different function is still possible but less likely to happen in practice
      - specify that users should wrap the dict/set type for a specific ordering (not code generation)
          - 👍 simple type
          - 👍 nicely compact
          - 👍 functions aren't stored in the data structure
          - 👎 quite a bit of manual labour without a clear need
          - 👎 API changes to the original dict/set type do not get propagated
      - stored in the data structure
          - 👍 minimal clutter while still being explicit
          - 👎 needs to be stored in the type → `==` among other things will fail
          - 👎 slightly more cluttered API including `clear` to only remove all elements but keep the function
      - ordering given on every insertion/removal operation
          - 👎 a tiny bit less compact
          - 👎 no guarantee that the given functions are the same
            between operations or
            when trying to combine (`union`, `intersection`, ...)
      - ordering given on each access and operation
          - 👎 a bit less compact
          - 👎 no guarantee that the given functions are the same
  - association-list
      - examples
          - [`pzp1997/assoc-list` `AssocList`](https://dark.elm.dmy.fr/packages/pzp1997/assoc-list/latest/)
          - [`erlandsona/assoc-set` `AssocSet`](https://dark.elm.dmy.fr/packages/erlandsona/assoc-set/latest/)
          - [`Orasund/elm-bag` `List.Bag`](https://dark.elm.dmy.fr/packages/Orasund/elm-bag/latest/List-Bag)
      - 👎 `n` runtime
      - 👍 no setup
      - 👍 simple type
  - tagging keys and the structure
      - examples
          - [`joneshf/elm-tagged` `Tagged.Set`, `Tagged.Dict`](https://dark.elm.dmy.fr/packages/joneshf/elm-tagged/latest/Tagged-Dict)
      - idea is quite similar to `KeysSet` but
      - 👎 relies on `comparable`
      - 👎 everyone can tag without the tag name so only security by a bit more obscurity
  - just the function `key -> Maybe value` instead of a data structure
      - examples
          - [`jjant/elm-dict` `AllDict`](https://dark.elm.dmy.fr/packages/jjant/elm-dict/latest/AllDict)
      - 👎 `>= n` runtime
      - 👎 doesn't simplify it's structure. Every remove, insert, union, difference, _adds_ to the function logic
      - 👍 pretty easy to understand and build on with powerful features like assigning a specific value x whenever a condition is met

# future ideas

  - set with multiple elements per key (= multi-set/bag) add?
    or is this already covered good enough
  - ✨ your idea
