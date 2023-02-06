module Map exposing
    ( Mapping, Altering
    , identity, Identity
    , over, Over, OverTag
    , with
    )

{-| Map content inside a nested structure

@docs Mapping, Altering


## create

Just [`Typed.tag`](https://dark.elm.dmy.fr/packages/lue-bird/elm-typed-value/latest/Typed#tag) any function `a -> b`.

@docs identity, Identity


## combine

@docs over, Over, OverTag


## transform

@docs with

-}

import Typed exposing (Checked, Public, Typed)


{-| [`Typed`](https://dark.elm.dmy.fr/packages/lue-bird/elm-typed-value/latest/) change

To create, combine

  - a tag that uniquely describes the part
  - a function that changes the `unmapped` to `mapped`

```
-- module Record.Map exposing (Score, score)


import Typed

type Score
    = Score

score : Mapping { record | score : score } Score score
score =
    Typed.tag Score .score
```

    -- module String.Map exposing (each, Each, ToList, toList)
    type ToList
        = ToList

    toList : Mapping String ToList (List Char)
    toList =
        Typed.tag ToList String.toList

    type Each
        = Each

    each :
        Mapping element elementMapTag elementMapped
        -> Mapping (List element) ( Each, elementMapTag ) (List elementMapped)
    each elementMapping =
        Typed.mapToWrap Each List.map elementMapping

There's nothing more to it

Use [`Alter`] if `unmapped` and `mapped` types are the same

-}
type alias Mapping unmapped mapTag mapped =
    Typed Checked mapTag Public (unmapped -> mapped)


{-| [`Mapping`](#Mapping) that will preserve the element type.

[`Altering`](#Altering) can be used to simplify argument and result types

    module User.Map exposing (onHead)

    import Map

    type alias User =
        { name : String, ... }

    type Name
        = Name

    name : Altering String nameAlterTag -> Altering User ( Name, nameAlterTag )
    name =
        Typed.mapToWrap Name (\f user -> { user | name = user.name |> f })

This applies to records, `type`s without any type variables or mapping some of many equal-typed elements

-}
type alias Altering subject alterTag =
    Mapping subject alterTag subject



-- create


{-| Opaque tag for [`identity`](#identity)
-}
type Identity
    = Identity


{-| Returns what comes in without changing anything

    "please edit"
        |> Map.with Map.identity
    --> "please edit"

-}
identity : Altering subject_ Identity
identity =
    Typed.tag Identity Basics.identity



--


{-| Transform elements
as shown in a given [`Mapping`](#Mapping) with a given function

    import Typed

    type Book
        = Book

    book : Mapping { book : { sales : Int } } Book { sales : Int }
    book =
        Typed.tag Book .book

    type Sales
        = Sales

    sales : Mapping { sales : Int } Sales Int
    sales =
        Typed.tag Sales .sales

    { book = { sales = 0 } }
        |> Map.with (book |> Map.over sales)
    --> 0

-}
over :
    Mapping mapped nextMapTag nextMapped
    ->
        (Mapping unmapped structureTag mapped
         -> Mapping unmapped (Over structureTag nextMapTag) nextMapped
        )
over nextMap =
    \map ->
        map
            |> Typed.wrapAnd nextMap
            |> Typed.mapToWrap Over
                (\( a, b ) -> a >> b)


{-| Tag for [`over`](#over)
-}
type alias Over mapTag nextMapTag =
    ( OverTag, ( mapTag, nextMapTag ) )


{-| Wrapper tag in [`Over`](#Over)
-}
type OverTag
    = Over



-- transform


{-| Apply the given change

    import Typed

    [ 'h', 'i' ]
        |> Map.with (Typed.tag { whatever = () } String.fromList)
    --> "hi"

-}
with :
    Mapping unmapped mapTag_ mapped
    -> (unmapped -> mapped)
with mapped =
    mapped |> Typed.untag
