module Equal exposing
    ( Equaling, Equality(..)
    , structurally, Structurally
    , by, By
    , with
    )

{-| A check on whether 2 values are equal in some aspect.

@docs Equaling, Equality
@docs structurally, Structurally


## combine

@docs by, By


## transform

@docs with

-}

import Map exposing (Mapping)
import Typed exposing (Checked, Public, Typed)


{-| A check on whether 2 values are equal in some aspect.
See [`unique`](#unique)

    -- ↓ and tag should be opaque in practice
    casedLetter : KeysSet.Keys CasedLetter { casedLetter : () } { inAlphabet : CasedLetter -> Int, lowercase : CasedLetter -> Char, uppercase : CasedLetter -> Char }
    casedLetter =
        KeysSet.keys
            { tag = { casedLetter = () }
            , keys =
                { inAlphabet = .inAlphabet, lowercase = .lowercase, uppercase = .uppercase }
            , unique =
                [ unique .inAlphabet, unique .lowercase, unique .uppercase ]
            }

    KeysSet.promising
        |> KeysSet.insert casedLetter
            { inAlphabet = 0, lowercase = 'a', uppercase = 'A' }
        |> KeysSet.insert casedLetter
            { inAlphabet = 0, lowercase = 'b', uppercase = 'B' }
        -- not inserted
        -- There's already an element where .inAlphabet is 0

-}
type alias Equaling complete tag =
    Mapping ( complete, complete ) tag Equality


{-| The result of checking multiple things for
whether they are equal or different
-}
type Equality
    = Equal
    | Different


{-| Tag for [`by`](#by) and [`key`](#key)
-}
type By mapTag mappedEqualTag
    = By


{-| Tag for [`structurally`](#structurally)
-}
type Structurally
    = Structurally


{-| Default elm `==` behavior

    import Set

    ( [ { score = Set.singleton -5 |> Set.insert -5 } ]
    , [ { score = Set.empty |> Set.insert -5 } ]
    )
        |> Equal.with Equal.structurally
    --> Equal

-}
structurally : Equaling complete Structurally
structurally =
    Typed.tag Structurally
        (\( a, b ) ->
            if a == b then
                Equal

            else
                Different
        )


{-| Check for [`Equality`](#Equality) by a transformed value
-}
by :
    Mapping complete mapTag mapped
    -> Equaling mapped mappedEqualTag
    -> Equaling complete (By mapTag mappedEqualTag)
by aspectMap mappedEqualing =
    aspectMap
        |> Typed.wrapAnd mappedEqualing
        |> Typed.mapTo By
            (\( toAspect, mappedEqual ) ->
                \toCheck ->
                    toCheck
                        |> Tuple.mapBoth toAspect toAspect
                        |> mappedEqual
            )


{-| Convert to a function in the form `( a, a ) -> Equality`
that can be used to directly check for equality.

    import Set

    ( [ { score = Set.singleton -5 |> Set.insert -5 } ]
    , [ { score = Set.empty |> Set.insert -5 } ]
    )
        |> Equal.with Equal.structurally
    --> Equal

-}
with :
    Equaling complete tag_
    -> (( complete, complete ) -> Equality)
with equaling =
    equaling |> Typed.untag
