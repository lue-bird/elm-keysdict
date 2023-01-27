module KeysSet.Test exposing (suite)

import ArraySized
import Atom
import BracketPair exposing (BracketPair)
import Character exposing (Character)
import Emptiable exposing (Emptiable(..), filled)
import Expect
import Fuzz
import Keys exposing (Keys)
import KeysSet exposing (KeysSet, PreferenceOnCollisions(..))
import Linear exposing (Direction(..))
import List.Extra
import List.Linear
import N exposing (In, N, N1, To, Up, n1)
import Possibly exposing (Possibly(..))
import Stack
import Test exposing (Test, describe, fuzz, fuzz2, test)
import Tree2 exposing (Branch)
import Typed
import User
import Util exposing (recover)


suite : Test
suite =
    describe "KeysSet"
        [ createSuite
        , alterSuite
        , scanTest
        , transformTest
        , combineSuite
        , readmeExamplesTest
        ]


createSuite : Test
createSuite =
    describe "create"
        [ fromListSuite
        , fromStackSuite
        ]


validate :
    Keys element tags keys_ lastKeyIndex
    ->
        (Emptiable (KeysSet element tags lastKeyIndex) Possibly
         -> Result String ()
        )
validate keys =
    \keysSet ->
        let
            keysArray =
                keys |> Keys.toArray |> Typed.untag
        in
        keysArray
            |> ArraySized.and
                (ArraySized.upTo (keysArray |> ArraySized.length |> N.subtract n1))
            |> ArraySized.map
                (\( order, index ) ->
                    let
                        tree =
                            keysSet |> Emptiable.mapFlat (treeForIndex index)
                    in
                    case tree |> validateHelp order of
                        Err error ->
                            [ error
                            , " for index "
                            , index |> N.toString
                            , " in\n\n"
                            , tree |> treeToString
                            ]
                                |> String.concat
                                |> Err

                        Ok _ ->
                            if (tree |> Tree2.size) == (keysSet |> KeysSet.size) then
                                () |> Ok

                            else
                                [ "tracking size ["
                                , keysSet |> KeysSet.size |> String.fromInt
                                , "] does not match with real one ["
                                , tree |> Tree2.size |> String.fromInt
                                , "]"
                                , " for\n"
                                , keysSet |> KeysSet.foldFrom [] (::) |> List.map Debug.toString |> String.join " "
                                , " :\n\n"
                                , keysSet |> Debug.toString
                                , "\n\nwhere the tree instead is\n"
                                , tree |> treeToString
                                ]
                                    |> String.concat
                                    |> Err
                )
            |> ArraySized.foldFrom
                (() |> Ok)
                Down
                (\result soFar ->
                    case soFar of
                        Ok _ ->
                            result |> Result.mapError List.singleton

                        Err soFarErrors ->
                            case result of
                                Ok _ ->
                                    soFarErrors |> Err

                                Err another ->
                                    soFarErrors |> (::) another |> Err
                )
            |> Result.mapError (String.join "\n\n\n")


treeForIndex :
    N (In min_ (Up maxToLastKeyIndex_ To lastKeyIndex))
    ->
        (KeysSet element tags_ lastKeyIndex
         -> Emptiable (Tree2.Branch element) never_
        )
treeForIndex index =
    \keysSet ->
        keysSet
            |> Typed.untag
            |> .byKeys
            |> ArraySized.inToOn
            |> ArraySized.element ( Up, index )
            |> Emptiable.filled


validateHelp :
    (( element, element ) -> Order)
    ->
        (Emptiable (Tree2.Branch element) Possibly
         -> Result String { height : Int }
        )
validateHelp order tree =
    case tree |> Emptiable.map filled of
        Empty _ ->
            { height = 0 } |> Ok

        Filled treeFilled ->
            let
                checkFurther =
                    Result.andThen
                        (\children ->
                            if ((children.left.height - children.right.height) |> abs) <= 1 then
                                { height =
                                    1 + max children.left.height children.right.height
                                }
                                    |> Ok

                            else
                                [ "height below "
                                , treeFilled |> Tree2.trunk |> Debug.toString
                                , ": "
                                , children.left.height |> String.fromInt
                                , " vs "
                                , children.right.height |> String.fromInt
                                , " - so \n\n"
                                , treeFilled |> Tree2.children |> .left |> Tree2.foldFrom [] Down (::) |> Debug.toString
                                , "\nvs\n"
                                , treeFilled |> Tree2.children |> .right |> Tree2.foldFrom [] Down (::) |> Debug.toString
                                , "\n"
                                ]
                                    |> String.concat
                                    |> Err
                        )
                        (Result.map2 (\left right -> { left = left, right = right })
                            (treeFilled |> Tree2.children |> .left |> validateHelp order)
                            (treeFilled |> Tree2.children |> .right |> validateHelp order)
                        )
            in
            if
                case treeFilled |> Tree2.children |> .left of
                    Empty _ ->
                        False

                    Filled left ->
                        (( treeFilled |> Tree2.trunk
                         , left |> filled |> Tree2.trunk
                         )
                            |> order
                        )
                            /= GT
            then
                [ "element "
                , treeFilled |> Tree2.trunk |> Debug.toString
                , " is <= left"
                ]
                    |> String.concat
                    |> Err

            else if
                case treeFilled |> Tree2.children |> .right of
                    Empty _ ->
                        False

                    Filled right ->
                        (( treeFilled |> Tree2.trunk
                         , right |> filled |> Tree2.trunk
                         )
                            |> order
                        )
                            /= LT
            then
                [ "element "
                , treeFilled |> Tree2.trunk |> Debug.toString
                , " is >= right"
                ]
                    |> String.concat
                    |> Err

            else
                checkFurther


treeToString : Emptiable (Tree2.Branch element_) Possibly -> String
treeToString =
    \tree ->
        case tree |> Emptiable.map filled of
            Emptiable.Empty _ ->
                "()"

            Emptiable.Filled treeFilled ->
                [ treeFilled
                    |> Tree2.children
                    |> .right
                    |> treeToString
                    |> String.split "\n"
                    |> List.map (\s -> "\t\t\t" ++ s)
                    |> String.join "\n"
                , "\n"
                , treeFilled |> Tree2.trunk |> Debug.toString
                , "\n"
                , treeFilled
                    |> Tree2.children
                    |> .left
                    |> treeToString
                    |> String.split "\n"
                    |> List.map (\s -> "\t\t\t" ++ s)
                    |> String.join "\n"
                ]
                    |> String.concat


fromStackSuite : Test
fromStackSuite =
    describe "fromStack"
        [ fuzz (Stack.filledFuzz Character.fuzz)
            "validate"
            (\stack ->
                KeysSet.fromStack Character.byIdOrChar stack
                    |> validate Character.byIdOrChar
                    |> Result.map (\_ -> Expect.pass)
                    |> recover Expect.fail
            )
        ]


fromListSuite : Test
fromListSuite =
    describe "fromList"
        [ test "hardcoded"
            (\() ->
                KeysSet.fromList
                    BracketPair.byOpenClosed
                    [ { open = 'b', closed = 'B' }
                    , { open = 'a', closed = 'A' }
                    , { open = 'b', closed = 'C' }
                    , { open = 'c', closed = 'A' }
                    , { open = 'c', closed = 'C' }
                    ]
                    |> KeysSet.toList ( BracketPair.byOpenClosed, .open )
                    |> Expect.equalLists
                        (KeysSet.fromList
                            BracketPair.byOpenClosed
                            [ { open = 'b', closed = 'B' }
                            , { open = 'a', closed = 'A' }
                            , { open = 'c', closed = 'C' }
                            ]
                            |> KeysSet.toList ( BracketPair.byOpenClosed, .open )
                        )
            )
        , fuzz (Fuzz.list Character.fuzz)
            "validate"
            (\list ->
                KeysSet.fromList Character.byIdOrChar list
                    |> validate Character.byIdOrChar
                    |> Result.map (\_ -> Expect.pass)
                    |> recover Expect.fail
            )
        ]


alterSuite : Test
alterSuite =
    describe "alter"
        [ elementAlterSuite
        , insertSuite
        , mapSuite
        , mapTrySuite
        , removeSuite
        ]


insertSuite : Test
insertSuite =
    let
        element0 : Character
        element0 =
            { id = 0, char = 'A' }

        element1 : Character
        element1 =
            { id = 1, char = 'B' }
    in
    describe "insert"
        [ test "hardcoded does ignores duplicate"
            (\() ->
                KeysSet.fromList
                    Character.byIdOrChar
                    [ element0, element1 ]
                    |> KeysSet.insert PreferExisting Character.byIdOrChar element0
                    |> KeysSet.insert PreferExisting Character.byIdOrChar element1
                    |> KeysSet.toList ( Character.byIdOrChar, .id )
                    |> Expect.equalLists
                        [ element0, element1 ]
            )
        , fuzz (Stack.filledFuzz Character.fuzz)
            "ignores partial duplicate"
            (\stack ->
                let
                    initial =
                        stack
                            |> Stack.foldFrom Emptiable.empty
                                Up
                                (KeysSet.insert PreferExisting Character.byIdOrChar)
                in
                initial
                    |> KeysSet.insert PreferExisting Character.byIdOrChar (stack |> Stack.top)
                    |> Expect.equal
                        initial
            )
        , test "hardcoded insert |> element works"
            (\() ->
                Emptiable.empty
                    |> KeysSet.insert PreferExisting Character.byIdOrChar element1
                    |> KeysSet.element ( Character.byIdOrChar, .id ) element1.id
                    |> Emptiable.map .char
                    |> Expect.equal (filled element1.char)
            )
        , test "hardcoded element of absent element is empty by id"
            (\() ->
                Emptiable.empty
                    |> KeysSet.insert PreferExisting Character.byIdOrChar element1
                    |> KeysSet.element ( Character.byIdOrChar, .id ) element0.id
                    |> Expect.equal Emptiable.empty
            )
        , test "hardcoded element of absent element 1 is empty by char"
            (\() ->
                Emptiable.empty
                    |> KeysSet.insert PreferExisting Character.byIdOrChar element1
                    |> KeysSet.element ( Character.byIdOrChar, .char ) element1.char
                    |> Emptiable.map .id
                    |> Expect.equal (filled element1.id)
            )
        , test "hardcoded element of absent element 0 is empty by char"
            (\() ->
                Emptiable.empty
                    |> KeysSet.insert PreferExisting Character.byIdOrChar element1
                    |> KeysSet.element ( Character.byIdOrChar, .char ) element0.char
                    |> Expect.equal Emptiable.empty
            )
        , fuzz Character.fuzz
            "Emptiable.empty"
            (\element ->
                Emptiable.empty
                    |> KeysSet.insert PreferExisting Character.byIdOrChar element
                    |> validate Character.byIdOrChar
                    |> Result.map (\() -> Expect.pass)
                    |> recover Expect.fail
            )
        , test "hardcoded validate to left"
            (\() ->
                KeysSet.one Character.byIdOrChar { id = 10, char = 'a' }
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 5, char = 'b' }
                    |> validate Character.byIdOrChar
                    |> Result.map (\() -> Expect.pass)
                    |> recover Expect.fail
            )
        , test "hardcoded validate to left left"
            (\() ->
                KeysSet.one Character.byIdOrChar { id = 10, char = 'a' }
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 5, char = 'b' }
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 2, char = 'c' }
                    |> validate Character.byIdOrChar
                    |> Result.map (\() -> Expect.pass)
                    |> recover Expect.fail
            )
        , test "hardcoded validate to left right"
            (\() ->
                KeysSet.one Character.byIdOrChar { id = 10, char = 'a' }
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 5, char = 'b' }
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 2, char = 'c' }
                    |> validate Character.byIdOrChar
                    |> Result.map (\() -> Expect.pass)
                    |> recover Expect.fail
            )
        , test "hardcoded validate to right"
            (\() ->
                KeysSet.one Character.byIdOrChar { id = 10, char = 'a' }
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 15, char = 'b' }
                    |> validate Character.byIdOrChar
                    |> Result.map (\() -> Expect.pass)
                    |> recover Expect.fail
            )
        , test "hardcoded validate to right left"
            (\() ->
                KeysSet.one Character.byIdOrChar { id = 10, char = 'a' }
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 15, char = 'b' }
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 12, char = 'c' }
                    |> validate Character.byIdOrChar
                    |> Result.map (\() -> Expect.pass)
                    |> recover Expect.fail
            )
        , test "hardcoded validate to right right"
            (\() ->
                KeysSet.one Character.byIdOrChar { id = 10, char = 'a' }
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 15, char = 'b' }
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 20, char = 'c' }
                    |> validate Character.byIdOrChar
                    |> Result.map (\() -> Expect.pass)
                    |> recover Expect.fail
            )
        , test "validate M-N-O-L-K-Q-P-H-I-A"
            (\() ->
                "MNOLKQPHIA"
                    |> String.toList
                    |> List.foldl
                        (\char ->
                            Result.andThen
                                (\keysSet ->
                                    keysSet
                                        |> KeysSet.insert PreferExisting
                                            Character.byIdOrChar
                                            { char = char, id = Char.toCode char }
                                        |> validate Character.byIdOrChar
                                        |> Result.map (\() -> keysSet)
                                )
                        )
                        (Emptiable.empty |> Ok)
                    |> Result.map (\_ -> Expect.pass)
                    |> recover Expect.fail
            )
        , fuzz2
            (Fuzz.intRange -40 -10)
            (Fuzz.intRange 10 40)
            "validate descending keys"
            (\idLow idHigh ->
                List.range idLow idHigh
                    |> List.foldr
                        (\id ->
                            Result.andThen
                                (\keysSet ->
                                    keysSet
                                        |> KeysSet.insert PreferExisting
                                            Character.byIdOrChar
                                            { id = id
                                            , char = Char.fromCode (40 + ('A' |> Char.toCode) + id)
                                            }
                                        |> validate Character.byIdOrChar
                                        |> Result.map (\() -> keysSet)
                                )
                        )
                        (Emptiable.empty |> Ok)
                    |> Result.map (\_ -> Expect.pass)
                    |> recover Expect.fail
            )
        , fuzz2
            (Fuzz.intRange -40 -10)
            (Fuzz.intRange 10 40)
            "validate ascending keys"
            (\idLow idHigh ->
                List.range idLow idHigh
                    |> List.foldl
                        (\id ->
                            Result.andThen
                                (\keysSet ->
                                    keysSet
                                        |> KeysSet.insert PreferExisting
                                            Character.byIdOrChar
                                            { id = id
                                            , char = Char.fromCode (40 + ('A' |> Char.toCode) + id)
                                            }
                                        |> validate Character.byIdOrChar
                                        |> Result.map (\() -> keysSet)
                                )
                        )
                        (Emptiable.empty |> Ok)
                    |> Result.map (\_ -> Expect.pass)
                    |> recover Expect.fail
            )
        , fuzz
            (Fuzz.list Character.fuzz)
            "validate"
            (\characters ->
                characters
                    |> List.foldl
                        (\character ->
                            Result.andThen
                                (\keysSet ->
                                    keysSet
                                        |> KeysSet.insert PreferExisting Character.byIdOrChar character
                                        |> Emptiable.emptyAdapt (\_ -> Possible)
                                        |> validate Character.byIdOrChar
                                        |> Result.map (\() -> keysSet)
                                )
                        )
                        (Emptiable.empty |> Ok)
                    |> Result.map (\_ -> Expect.pass)
                    |> recover Expect.fail
            )
        ]


removeSuite : Test
removeSuite =
    let
        openClosedBrackets =
            KeysSet.one BracketPair.byOpenClosed
                { open = '(', closed = ')' }
    in
    describe "remove"
        [ let
            ab : Emptiable (KeysSet Character Character.ByIdOrChar N1) Possibly
            ab =
                KeysSet.fromList
                    Character.byIdOrChar
                    [ { id = 0, char = 'A' }
                    , { id = 1, char = 'B' }
                    ]
          in
          test "hardcoded insert |> remove id leaves it unchanged"
            (\() ->
                ab
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 2, char = 'C' }
                    |> KeysSet.remove ( Character.byIdOrChar, .id ) 2
                    |> KeysSet.toList ( Character.byIdOrChar, .id )
                    |> Expect.equalLists
                        (ab
                            |> KeysSet.toList ( Character.byIdOrChar, .id )
                        )
            )
        , test "hardcoded nothing to remove"
            (\() ->
                openClosedBrackets
                    |> KeysSet.remove ( BracketPair.byOpenClosed, .open ) ')'
                    --> no change, .open is never ')'
                    |> Expect.equal openClosedBrackets
            )
        , test "hardcoded something to remove"
            (\() ->
                openClosedBrackets
                    |> KeysSet.remove ( BracketPair.byOpenClosed, .closed ) ')'
                    |> KeysSet.toList ( BracketPair.byOpenClosed, .closed )
                    |> Expect.equalLists []
            )
        , fuzz Fuzz.int
            "Emptiable.empty"
            (\id ->
                Emptiable.empty
                    |> KeysSet.remove ( Character.byIdOrChar, .id ) id
                    |> validate Character.byIdOrChar
                    |> Result.map (\() -> Expect.pass)
                    |> recover Expect.fail
            )
        , fuzz2
            Fuzz.int
            Fuzz.int
            "one"
            (\put delete ->
                KeysSet.one Character.byIdOrChar { id = put, char = '0' }
                    |> KeysSet.remove ( Character.byIdOrChar, .id ) delete
                    |> validate Character.byIdOrChar
                    |> Result.map (\() -> Expect.pass)
                    |> recover Expect.fail
            )
        , fuzz2
            (Fuzz.list Character.fuzz)
            (Fuzz.list Fuzz.int)
            "fromList"
            (\puts deletes ->
                deletes
                    |> List.foldl
                        (\id ->
                            Result.andThen
                                (\keysSet ->
                                    keysSet
                                        |> KeysSet.remove ( Character.byIdOrChar, .id ) id
                                        |> validate Character.byIdOrChar
                                        |> Result.map (\() -> keysSet)
                                )
                        )
                        (KeysSet.fromList Character.byIdOrChar puts |> Ok)
                    |> Result.map (\_ -> Expect.pass)
                    |> recover Expect.fail
            )
        , fuzz (Fuzz.list Character.fuzz)
            "fromList clear"
            (\characters ->
                let
                    full =
                        KeysSet.fromList Character.byIdOrChar characters
                in
                characters
                    |> List.Linear.foldFrom
                        (full
                            |> validate Character.byIdOrChar
                            |> Result.map (\() -> full)
                        )
                        Up
                        (\{ id } ->
                            Result.andThen
                                (\keysSet ->
                                    let
                                        removed =
                                            keysSet
                                                |> KeysSet.remove ( Character.byIdOrChar, .id ) id
                                    in
                                    removed
                                        |> validate Character.byIdOrChar
                                        |> Result.map (\() -> removed)
                                )
                        )
                    |> Result.map (Expect.equal Emptiable.empty)
                    |> recover Expect.fail
            )
        ]


elementAlterSuite : Test
elementAlterSuite =
    describe "elementAlter"
        [ describe "PreferExisting"
            [ test "replace to same key"
                (\() ->
                    KeysSet.fromList Character.byIdOrChar
                        [ { id = 0, char = 'A' }, { id = 1, char = 'B' } ]
                        |> KeysSet.elementAlter PreferExisting
                            ( Character.byIdOrChar, .id )
                            1
                            (\c -> { c | char = 'C' })
                        |> KeysSet.toList ( Character.byIdOrChar, .id )
                        |> Expect.equalLists
                            [ { id = 0, char = 'A' }, { id = 1, char = 'C' } ]
                )
            , test "replace to multiple collisions"
                (\() ->
                    KeysSet.fromList Character.byIdOrChar
                        [ { id = 0, char = 'A' }, { id = 1, char = 'B' } ]
                        |> KeysSet.elementAlter PreferExisting
                            ( Character.byIdOrChar, .id )
                            1
                            (\c -> { c | id = 0 })
                        |> KeysSet.toList ( Character.byIdOrChar, .id )
                        |> Expect.equalLists
                            [ { id = 0, char = 'A' }, { id = 1, char = 'B' } ]
                )
            ]
        ]


mapSuite : Test
mapSuite =
    describe "map"
        [ test "hardcoded alter"
            (\() ->
                KeysSet.fromList Character.byIdOrChar
                    [ { id = 3, char = 'A' }
                    , { id = 1, char = 'B' }
                    , { id = 4, char = 'C' }
                    , { id = 5, char = 'D' }
                    , { id = 3, char = 'E' }
                    ]
                    |> KeysSet.map (\element -> { element | id = element.id * 10 })
                        Character.byIdOrChar
                    |> KeysSet.toList ( Character.byIdOrChar, .id )
                    |> Expect.equalLists
                        [ { id = 10, char = 'B' }
                        , { id = 30, char = 'A' }
                        , { id = 40, char = 'C' }
                        , { id = 50, char = 'D' }
                        ]
            )
        ]


mapTrySuite : Test
mapTrySuite =
    describe "mapTry"
        [ test "hardcoded filter"
            (\() ->
                KeysSet.fromList Character.byIdOrChar
                    [ { id = 3, char = 'A' }
                    , { id = 1, char = 'B' }
                    , { id = 4, char = 'C' }
                    , { id = 5, char = 'D' }
                    , { id = 2, char = 'E' }
                    ]
                    |> KeysSet.mapTry
                        (\element ->
                            if element.id > 3 || element.char == 'B' then
                                filled element

                            else
                                Emptiable.empty
                        )
                        Character.byIdOrChar
                    |> KeysSet.toList ( Character.byIdOrChar, .id )
                    |> Expect.equalLists
                        [ { id = 1, char = 'B' }
                        , { id = 4, char = 'C' }
                        , { id = 5, char = 'D' }
                        ]
            )
        ]


combineSuite : Test
combineSuite =
    describe "combine"
        [ unifyWithSuite
        , intersectSuite
        , exceptSuite
        , fold2FromSuite
        ]


unifyWithSuite : Test
unifyWithSuite =
    describe "unifyWith"
        [ test "left is empty"
            (\() ->
                Emptiable.empty
                    |> KeysSet.unifyWith Character.byIdOrChar
                        (KeysSet.one Character.byIdOrChar { id = 0, char = 'A' })
                    |> KeysSet.toList ( Character.byIdOrChar, .id )
                    |> Expect.equalLists [ { id = 0, char = 'A' } ]
            )
        , test "right is empty"
            (\() ->
                KeysSet.one Character.byIdOrChar { id = 0, char = 'A' }
                    |> KeysSet.unifyWith Character.byIdOrChar Emptiable.empty
                    |> KeysSet.toList ( Character.byIdOrChar, .id )
                    |> Expect.equalLists [ { id = 0, char = 'A' } ]
            )
        , test "unions"
            (\() ->
                KeysSet.fromList Character.byIdOrChar
                    [ { id = 0, char = 'A' }
                    , { id = 1, char = 'B' }
                    , { id = 2, char = 'c' }
                    , { id = 3, char = 'd' }
                    ]
                    |> KeysSet.unifyWith Character.byIdOrChar
                        (KeysSet.fromList Character.byIdOrChar
                            [ { id = 2, char = 'c' }
                            , { id = 3, char = 'd' }
                            , { id = 4, char = 'e' }
                            , { id = 5, char = 'f' }
                            ]
                        )
                    |> KeysSet.toList ( Character.byIdOrChar, .id )
                    |> Expect.equalLists
                        [ { id = 0, char = 'A' }
                        , { id = 1, char = 'B' }
                        , { id = 2, char = 'c' }
                        , { id = 3, char = 'd' }
                        , { id = 4, char = 'e' }
                        , { id = 5, char = 'f' }
                        ]
            )
        ]


intersectSuite : Test
intersectSuite =
    describe "intersect"
        [ test "left is empty"
            (\() ->
                KeysSet.one Character.byIdOrChar { id = 0, char = 'A' }
                    |> KeysSet.intersect ( Character.byIdOrChar, .id ) Emptiable.empty
                    |> KeysSet.toList ( Character.byIdOrChar, .id )
                    |> Expect.equalLists []
            )
        , test "right is empty"
            (\() ->
                Emptiable.empty
                    |> KeysSet.intersect ( Character.byIdOrChar, .id )
                        (KeysSet.one Character.byIdOrChar { id = 0, char = 'A' })
                    |> KeysSet.toList ( Character.byIdOrChar, .id )
                    |> Expect.equalLists []
            )
        , test "hardcoded"
            (\() ->
                KeysSet.fromList Character.byIdOrChar
                    [ { id = 2, char = 'c' }
                    , { id = 3, char = 'd' }
                    , { id = 4, char = 'e' }
                    , { id = 5, char = 'f' }
                    ]
                    |> KeysSet.intersect ( Character.byIdOrChar, .id )
                        (KeysSet.fromList Character.byIdOrChar
                            [ { id = 0, char = 'A' }
                            , { id = 1, char = 'B' }
                            , { id = 2, char = 'c' }
                            , { id = 3, char = 'd' }
                            ]
                        )
                    |> KeysSet.toList ( Character.byIdOrChar, .id )
                    |> Expect.equalLists
                        [ { id = 2, char = 'c' }
                        , { id = 3, char = 'd' }
                        ]
            )
        ]


exceptSuite : Test
exceptSuite =
    describe "diff"
        [ test "left is empty"
            (\() ->
                Emptiable.empty
                    |> KeysSet.except ( Character.byIdOrChar, .id )
                        (KeysSet.one Character.byIdOrChar { id = 0, char = 'A' })
                    |> KeysSet.toList ( Character.byIdOrChar, .id )
                    |> Expect.equalLists []
            )
        , test "right is empty"
            (\() ->
                KeysSet.one Character.byIdOrChar { id = 0, char = 'A' }
                    |> KeysSet.except ( Character.byIdOrChar, .id ) Emptiable.empty
                    |> KeysSet.toList ( Character.byIdOrChar, .id )
                    |> Expect.equalLists [ { id = 0, char = 'A' } ]
            )
        , test "hardcoded"
            (\() ->
                KeysSet.fromList Character.byIdOrChar
                    [ { id = 0, char = 'A' }
                    , { id = 1, char = 'B' }
                    , { id = 2, char = 'c' }
                    , { id = 3, char = 'd' }
                    ]
                    |> KeysSet.except ( Character.byIdOrChar, .id )
                        (KeysSet.fromList Character.byIdOrChar
                            [ { id = 2, char = 'c' }
                            , { id = 3, char = 'd' }
                            , { id = 4, char = 'e' }
                            , { id = 5, char = 'f' }
                            ]
                        )
                    |> KeysSet.toList ( Character.byIdOrChar, .id )
                    |> Expect.equalLists
                        [ { id = 0, char = 'A' }
                        , { id = 1, char = 'B' }
                        ]
            )
        ]


fold2FromSuite : Test
fold2FromSuite =
    let
        testFold2 =
            KeysSet.fold2From
                []
                (\toBeMerged soFar ->
                    soFar
                        |> (::)
                            (case toBeMerged of
                                KeysSet.First first ->
                                    (first.id |> String.fromInt) ++ (first.char |> String.fromChar)

                                KeysSet.Second second ->
                                    String.fromList (List.repeat second.id second.char)

                                KeysSet.FirstSecond ( first, second ) ->
                                    String.fromList (List.repeat first.id first.char)
                                        ++ ((second.id |> String.fromInt)
                                                ++ (second.char |> String.fromChar)
                                           )
                            )
                )
    in
    describe "fold2From"
        [ test "hardcoded second is empty"
            (\() ->
                { first =
                    { key = ( Character.byIdOrChar, .id )
                    , set = KeysSet.one Character.byIdOrChar { id = 0, char = 'A' }
                    }
                , second =
                    { key = ( Character.byIdOrChar, .id )
                    , set = Emptiable.empty
                    }
                }
                    |> testFold2
                    |> Expect.equalLists
                        [ "0A"
                        ]
            )
        , test "hardcoded first is empty"
            (\() ->
                { first =
                    { key = ( Character.byIdOrChar, .id )
                    , set = Emptiable.empty
                    }
                , second =
                    { key = ( Character.byIdOrChar, .id )
                    , set = KeysSet.one Character.byIdOrChar { id = 3, char = 'A' }
                    }
                }
                    |> testFold2
                    |> Expect.equalLists
                        [ "AAA"
                        ]
            )
        , test "hardcoded"
            (\() ->
                testFold2
                    { first =
                        { key = ( Character.byIdOrChar, .id )
                        , set =
                            KeysSet.fromList Character.byIdOrChar
                                [ { id = 2, char = 'C' }
                                , { id = 3, char = 'd' }
                                , { id = 4, char = 'e' }
                                , { id = 5, char = 'f' }
                                ]
                        }
                    , second =
                        { key = ( Character.byIdOrChar, .id )
                        , set =
                            KeysSet.fromList Character.byIdOrChar
                                [ { id = 0, char = 'A' }
                                , { id = 1, char = 'B' }
                                , { id = 2, char = 'c' }
                                , { id = 3, char = 'd' }
                                ]
                        }
                    }
                    |> Expect.equalLists
                        [ "5f"
                        , "4e"
                        , "ddd3d"
                        , "CC2c"
                        , "B"
                        , ""
                        ]
            )
        ]


scanTest : Test
scanTest =
    describe "scan"
        [ sizeSuite
        , elementSuite
        , endSuite
        ]


sizeSuite : Test
sizeSuite =
    describe "size"
        [ test "Emptiable.empty"
            (\() ->
                Emptiable.empty
                    |> KeysSet.size
                    |> Expect.equal 0
            )
        , fuzz Character.fuzz
            "one"
            (\character ->
                KeysSet.one Character.byIdOrChar character
                    |> KeysSet.size
                    |> Expect.equal 1
            )
        , fuzz (Fuzz.list Character.fuzz)
            "fromList unique"
            (\list ->
                let
                    unique =
                        list
                            |> List.Extra.uniqueBy .id
                            |> List.Extra.uniqueBy .char
                in
                KeysSet.fromList Character.byIdOrChar unique
                    |> KeysSet.size
                    |> Expect.equal (unique |> List.length)
            )
        ]


elementSuite : Test
elementSuite =
    describe "element"
        [ fuzz Fuzz.int
            "Emptiable.empty"
            (\id ->
                Emptiable.empty
                    |> KeysSet.element ( Character.byIdOrChar, .id ) id
                    |> Expect.equal Emptiable.empty
            )
        , fuzz2 Fuzz.int
            Fuzz.int
            "one"
            (\x y ->
                KeysSet.one Character.byIdOrChar { id = x, char = 'A' }
                    |> KeysSet.element ( Character.byIdOrChar, .id ) y
                    |> Expect.equal
                        (if x == y then
                            filled { id = x, char = 'A' }

                         else
                            Emptiable.empty
                        )
            )
        , fuzz2
            Fuzz.int
            (Fuzz.list Character.fuzz
                |> Fuzz.map (List.Extra.uniqueBy .char)
            )
            "fromList"
            (\id list ->
                KeysSet.fromList Character.byIdOrChar list
                    |> KeysSet.element ( Character.byIdOrChar, .id ) id
                    |> Expect.equal
                        (list
                            |> List.Extra.find (\character -> character.id == id)
                            |> Emptiable.fromMaybe
                        )
            )
        , let
            casedLetters =
                KeysSet.fromList
                    BracketPair.byOpenClosed
                    [ { open = 'a', closed = 'A' }
                    , { open = 'b', closed = 'B' }
                    ]

            open char =
                casedLetters
                    |> KeysSet.element ( BracketPair.byOpenClosed, .closed ) char
                    |> Emptiable.map .open

            closed char =
                casedLetters
                    |> KeysSet.element ( BracketPair.byOpenClosed, .open ) char
                    |> Emptiable.map .closed
          in
          test "fromList hardcoded"
            (\() ->
                [ open 'a', open 'B', closed 'b', closed 'A' ]
                    |> Expect.equal
                        [ Emptiable.empty, filled 'b', filled 'B', Emptiable.empty ]
            )
        ]


endSuite : Test
endSuite =
    describe "end"
        [ fuzz (Fuzz.pair Linear.directionFuzz Character.fuzz)
            "one"
            (\( direction, character ) ->
                KeysSet.one Character.byIdOrChar character
                    |> KeysSet.end ( Character.byIdOrChar, .id ) direction
                    |> Expect.equal character
            )
        , describe "Up"
            [ fuzz
                (Character.fuzz
                    |> Fuzz.andThen
                        (\top ->
                            Fuzz.list Character.fuzz
                                |> Fuzz.map
                                    (\list ->
                                        Stack.topBelow
                                            top
                                            (list
                                                |> List.filter (\c -> c.char /= top.char)
                                                |> List.Extra.uniqueBy .char
                                            )
                                    )
                        )
                )
                "fromStack"
                (\stack ->
                    KeysSet.fromStack Character.byIdOrChar stack
                        |> KeysSet.end ( Character.byIdOrChar, .id ) Up
                        |> Expect.equal
                            (stack
                                |> Stack.fold Up
                                    (\element soFar ->
                                        if element.id > soFar.id then
                                            element

                                        else
                                            soFar
                                    )
                            )
                )
            ]
        , describe "Down"
            [ fuzz
                (Character.fuzz
                    |> Fuzz.andThen
                        (\top ->
                            Fuzz.list Character.fuzz
                                |> Fuzz.map
                                    (\list ->
                                        Stack.topBelow
                                            top
                                            (list
                                                |> List.filter (\c -> c.char /= top.char)
                                                |> List.Extra.uniqueBy .char
                                            )
                                    )
                        )
                )
                "fromStack"
                (\stack ->
                    KeysSet.fromStack Character.byIdOrChar stack
                        |> KeysSet.end ( Character.byIdOrChar, .id ) Down
                        |> Expect.equal
                            (stack
                                |> Stack.fold Up
                                    (\element soFar ->
                                        if element.id < soFar.id then
                                            element

                                        else
                                            soFar
                                    )
                            )
                )
            , test "hardcoded"
                (\() ->
                    KeysSet.fromStack
                        BracketPair.byOpenClosed
                        (Stack.topBelow
                            { open = 'a', closed = 'B' }
                            [ { open = 'b', closed = 'A' }
                            ]
                        )
                        |> KeysSet.end ( BracketPair.byOpenClosed, .open ) Down
                        |> Expect.equal
                            { open = 'a', closed = 'B' }
                )
            ]
        ]


transformTest : Test
transformTest =
    describe "transform"
        [ foldFromSuite
        , toListSuite
        ]


toListSuite : Test
toListSuite =
    describe "toList"
        [ test "empty"
            (\() ->
                Emptiable.empty
                    |> KeysSet.toList ( Character.byIdOrChar, .id )
                    |> Expect.equalLists []
            )
        , test "one"
            (\() ->
                KeysSet.one Character.byIdOrChar { id = 0, char = 'A' }
                    |> KeysSet.toList ( Character.byIdOrChar, .id )
                    |> Expect.equalLists [ { id = 0, char = 'A' } ]
            )
        , test "hardcoded insert"
            (\() ->
                Emptiable.empty
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 2, char = 'A' }
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 0, char = 'B' }
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 5, char = 'C' }
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 3, char = 'E' }
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 1, char = 'F' }
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 4, char = 'G' }
                    |> KeysSet.insert PreferExisting Character.byIdOrChar { id = 3, char = 'B' }
                    |> KeysSet.toList ( Character.byIdOrChar, .id )
                    |> Expect.equalLists
                        [ { id = 0, char = 'B' }
                        , { id = 1, char = 'F' }
                        , { id = 2, char = 'A' }
                        , { id = 3, char = 'E' }
                        , { id = 4, char = 'G' }
                        , { id = 5, char = 'C' }
                        ]
            )
        , test "hardcoded fromList"
            (\() ->
                KeysSet.fromList
                    BracketPair.byOpenClosed
                    [ { open = 'a', closed = 'A' }
                    , { open = 'b', closed = 'B' }
                    ]
                    |> KeysSet.toList ( BracketPair.byOpenClosed, .open )
                    |> Expect.equalLists
                        [ { open = 'a', closed = 'A' }
                        , { open = 'b', closed = 'B' }
                        ]
            )
        , fuzz (Fuzz.list Character.fuzz)
            "toList is unique"
            (\list ->
                let
                    toListResult =
                        KeysSet.fromList Character.byIdOrChar list
                            |> KeysSet.toList ( Character.byIdOrChar, .id )
                in
                toListResult
                    |> Expect.equalLists
                        (toListResult
                            |> List.Extra.uniqueBy .char
                            |> List.Extra.uniqueBy .id
                        )
            )
        ]


foldFromSuite : Test
foldFromSuite =
    describe "foldFrom"
        [ fuzz
            (Fuzz.list Character.fuzz
                |> Fuzz.map
                    (\list ->
                        list
                            |> List.Extra.uniqueBy .id
                            |> List.Extra.uniqueBy .char
                    )
            )
            "hardcoded sum"
            (\list ->
                KeysSet.fromList Character.byIdOrChar list
                    |> KeysSet.foldFrom 0 (\c soFar -> soFar + c.id)
                    |> Expect.equal
                        (list
                            |> List.map .id
                            |> List.sum
                        )
            )
        , test "hardcoded any"
            (\() ->
                KeysSet.fromList
                    User.byEmail
                    [ { username = "fred", priority = 1, email = "higgi@outlook.com" }
                    , { username = "gria", priority = 3, email = "miggo@inlook.com" }
                    ]
                    |> KeysSet.foldFrom False (\user soFar -> soFar || (user.priority > 4))
                    |> Expect.equal False
            )
        , test "hardcoded all"
            (\() ->
                KeysSet.fromList
                    User.byEmail
                    [ { username = "fred", priority = 1, email = "higgi@outlook.com" }
                    , { username = "gria", priority = 3, email = "miggo@inlook.com" }
                    ]
                    |> KeysSet.foldFrom True (\user soFar -> soFar && (user.priority < 4))
                    |> Expect.equal True
            )
        ]


readmeExamplesTest : Test
readmeExamplesTest =
    describe "readme examples"
        [ test "braces"
            (\() ->
                let
                    brackets :
                        Emptiable
                            (KeysSet BracketPair BracketPair.ByOpenClosed N1)
                            Possibly
                    brackets =
                        KeysSet.fromList
                            BracketPair.byOpenClosed
                            [ { open = '(', closed = ')' }
                            , { open = '{', closed = '}' }
                            ]

                    typeChar char =
                        case
                            brackets |> KeysSet.element ( BracketPair.byOpenClosed, .open ) char
                        of
                            Emptiable.Filled { closed } ->
                                [ char, closed ] |> String.fromList

                            Emptiable.Empty _ ->
                                case
                                    brackets |> KeysSet.element ( BracketPair.byOpenClosed, .closed ) char
                                of
                                    Emptiable.Filled { open } ->
                                        [ open, char ] |> String.fromList

                                    Emptiable.Empty _ ->
                                        char |> String.fromChar
                in
                Expect.equal ([ '(', '}' ] |> List.map typeChar)
                    [ "()", "{}" ]
            )
        , test "cased letters"
            (\() ->
                let
                    lowerUppercaseLetters =
                        KeysSet.fromList BracketPair.byOpenClosed
                            [ { open = 'a', closed = 'A' }
                            , { open = 'b', closed = 'B' }
                            , { open = 'c', closed = 'C' }
                            ]

                    closedFor char =
                        lowerUppercaseLetters
                            |> KeysSet.element ( BracketPair.byOpenClosed, .open ) char
                            |> Emptiable.map .closed
                in
                [ 'c', 'a', 'x' ]
                    |> List.map closedFor
                    |> Expect.equal
                        [ filled 'C', filled 'A', Emptiable.empty ]
            )
        , test "periodic table"
            (\() ->
                let
                    elements =
                        KeysSet.fromList Atom.byNumberOrSymbol
                            [ { symbol = "H", name = "Hydrogen", atomicNumber = 1 }
                            , { symbol = "He", name = "Helium", atomicNumber = 2 }
                            ]

                    atomicNumberOfElementWithSymbol : String -> Emptiable Int Possibly
                    atomicNumberOfElementWithSymbol symbol =
                        elements
                            |> KeysSet.element ( Atom.byNumberOrSymbol, .symbol ) symbol
                            |> Emptiable.map .atomicNumber
                in
                [ atomicNumberOfElementWithSymbol "He"
                , atomicNumberOfElementWithSymbol "Wtf"
                , atomicNumberOfElementWithSymbol "H"
                ]
                    |> Expect.equal
                        [ filled 2, Emptiable.empty, filled 1 ]
            )
        ]
