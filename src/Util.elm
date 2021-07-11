module Util exposing
    ( ListOperationResult(..)
    , anyWhere
    , aspect
    , equalIgnoringOrder
    , firstWhere
    , removeFirstWithResult
    )

{-| **Should not be exposed.**

Utility functions.

-}


{-| Give a result only regarding a specific aspect of a value.

    aspect .name (==)
      { name= "smile", symbol= '😊' }
      { symbol= '🙂', name= "smile" }
    --> True

    (aspect abs) (>) 10 -20
    --> False

-}
aspect :
    (value -> aspect)
    -> (aspect -> aspect -> result)
    -> value
    -> value
    -> result
aspect accessAspect resultFromAspects a b =
    resultFromAspects
        (accessAspect a)
        (accessAspect b)


{-| The first (from head) element in a `List` where `isFound` is `True`.

    [ 0, 2, 8, 16, 22 ]
        |> firstWhere (\el -> el > 10)
    --> Just 16

    [ { x = 3, y = 5 }, { y = 9, x = 7 } ]
        |> firstWhere (.x >> (==) 0)
    --> Nothing

-}
firstWhere :
    (element -> Bool)
    -> List element
    -> Maybe element
firstWhere isFound list =
    case list of
        [] ->
            Nothing

        element :: rest ->
            if isFound element then
                Just element

            else
                firstWhere isFound rest


{-| Is there any element in a `List` where a test succeeds?

    [ 0, 2, 8, 16, 22 ]
        |> anyWhere (\el -> el > 10)
    --> True

    [ { x = 3, y = 5 }, { y = 9, x = 7 } ]
        |> anyWhere (.x >> (==) 0)
    --> False

-}
anyWhere : (element -> Bool) -> List element -> Bool
anyWhere isFound =
    firstWhere isFound >> (/=) Nothing


{-| Do 2 `List`s contain the same elements but in a different order?

    equalIgnoringOrder
        [ 1, 2, 3 ]
        [ 3, 1, 2 ]
    --> True

_Elements must not contain functions or json. Elm will crash trying to see if they are equal._

-}
equalIgnoringOrder : List element -> List element -> Bool
equalIgnoringOrder aList bList =
    case ( aList, bList ) of
        ( [], [] ) ->
            True

        ( [], _ :: _ ) ->
            False

        ( _ :: _, [] ) ->
            False

        ( _, bElement :: bAfter ) ->
            case removeFirstWithResult bElement aList of
                AsBeforeList _ ->
                    False

                ChangedList aWithoutBElement ->
                    equalIgnoringOrder aWithoutBElement bAfter


{-| Remove the first element (from head to right) in a `List` where the element is equal to `toRemove`.
-}
removeFirstWithResult : el -> List el -> ListOperationResult el
removeFirstWithResult toRemove =
    removeFirstWithResultHelp toRemove []


removeFirstWithResultHelp :
    el
    -> List el
    -> List el
    -> ListOperationResult el
removeFirstWithResultHelp toRemove notToRemove list =
    case list of
        [] ->
            AsBeforeList []

        head :: after ->
            if toRemove == head then
                ChangedList
                    ((notToRemove |> List.reverse) ++ after)

            else
                removeFirstWithResultHelp
                    toRemove
                    (head :: notToRemove)
                    after


{-| Did a operation on a List leave the a `ChangedList` or a `AsBeforeList`.
-}
type ListOperationResult element
    = AsBeforeList (List element)
    | ChangedList (List element)
